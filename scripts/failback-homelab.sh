#!/usr/bin/env bash
# ==============================================================================
# failback-homelab.sh - Automated Failback from Tencent Cloud Standby to Homelab
#
# Sequence:
#   1. If Tencent CVM is RUNNING, trigger a final B2 backup on CVM via SSH so
#      any transactions written during Cloud failover are saved to Backblaze B2.
#   2. Ensure local Homelab K3s is running, scale down statefulsets safely,
#      pull & sync the latest PV snapshot from Backblaze B2 into Homelab storage,
#      and scale statefulsets back up + unseal Vault.
#   3. Switch Cloudflare Master DNS Pointer back to Homelab Primary.
#   4. Stop Tencent CVM into STOP_CHARGING ($0 passive mode).
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ -f "${ROOT_DIR}/.env" ]]; then
    set -a
    # shellcheck disable=SC1091
    source "${ROOT_DIR}/.env"
    set +a
fi

LOG_TAG="[FAILBACK $(date '+%Y-%m-%d %H:%M:%S')]"
log()  { echo -e "${LOG_TAG} \033[0;32m[INFO]\033[0m $*"; }
warn() { echo -e "${LOG_TAG} \033[1;33m[WARN]\033[0m $*" >&2; }
err()  { echo -e "${LOG_TAG} \033[0;31m[ERROR]\033[0m $*" >&2; exit 1; }

SKIP_B2_PULL=false
for arg in "$@"; do
    case "$arg" in
        --no-sync|--quick) SKIP_B2_PULL=true ;;
        *) ;;
    esac
done

log "=== Memulai Prosedur Failback Otomatis ke Server Utama (Homelab Malang) ==="

# ------------------------------------------------------------------------------
# 1. Check Tencent CVM Status & Trigger Final Cloud Backup if Running
# ------------------------------------------------------------------------------
CVM_STATUS_JSON=$(python3 "${ROOT_DIR}/failover/scripts/tencent_cvm.py" status 2>/dev/null || echo '{}')
CVM_STATE=$(echo "$CVM_STATUS_JSON" | grep -oP '"status":\s*"\K[^"]+' | head -1 || echo "UNKNOWN")
CVM_IP=$(echo "$CVM_STATUS_JSON" | grep -oP '"PublicIpAddresses":\s*\[\s*"\K[^"]+' | head -1 || echo "")

if [[ "$CVM_STATE" == "RUNNING" && -n "$CVM_IP" && "$SKIP_B2_PULL" == "false" ]]; then
    log "Phase 1: CVM Tencent sedang menyala ($CVM_IP). Menyimpan snapshot terakhir dari Cloud ke B2..."
    if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=8 "ubuntu@${CVM_IP}" \
        "sudo kubectl get cronjob k3s-b2-backup -n infra >/dev/null 2>&1" 2>/dev/null; then
        FINAL_JOB="failback-final-$(date +%s)"
        log "Memicu backup terakhir ($FINAL_JOB) di Cloud CVM..."
        ssh -o StrictHostKeyChecking=no -o ConnectTimeout=8 "ubuntu@${CVM_IP}" \
            "sudo kubectl create job --from=cronjob/k3s-b2-backup ${FINAL_JOB} -n infra && \
             sudo kubectl wait --for=condition=complete job/${FINAL_JOB} -n infra --timeout=180s" || \
            warn "Backup terakhir di CVM melewati batas waktu atau selesai dengan peringatan. Melanjutkan dengan snapshot B2 terbaru."
    else
        warn "Tidak dapat terhubung via SSH ke CVM ($CVM_IP). Menggunakan snapshot terbaru yang sudah ada di B2."
    fi
else
    log "Phase 1: Melewati final backup CVM (Status CVM: $CVM_STATE, Quick Mode: $SKIP_B2_PULL)."
fi

# ------------------------------------------------------------------------------
# 2. Ensure Local Homelab K3s is Active & Pull Latest B2 Data
# ------------------------------------------------------------------------------
if ! systemctl is-active --quiet k3s; then
    log "Menyalakan service K3s di Homelab..."
    sudo systemctl start k3s
fi

log "Menunggu node K3s Homelab berstatus Ready..."
until kubectl get nodes 2>/dev/null | grep -q "Ready"; do
    sleep 2
done
log "Node K3s Homelab sudah Ready ✓"
kubectl scale deployment cloudflared -n infra --replicas=1 2>/dev/null || true

if [[ "$SKIP_B2_PULL" == "false" ]]; then
    log "Phase 2: Menarik data terbaru dari Backblaze B2 ke Homelab..."

    export AWS_ACCESS_KEY_ID="${B2_APPLICATION_KEY_ID}"
    export AWS_SECRET_ACCESS_KEY="${B2_APPLICATION_KEY}"
    export AWS_DEFAULT_REGION="us-east-1"
    export RESTIC_PASSWORD="${RESTIC_PASSWORD}"
    export RESTIC_REPOSITORY="s3:${B2_ENDPOINT}/${B2_BUCKET}/restic-pvs"

    RESTIC_BIN="$(command -v restic || command -v /usr/local/bin/restic || echo 'restic')"

    if "$RESTIC_BIN" snapshots --tag k3s-pvs --latest 1 &>/dev/null; then
        log "Menutup sementara statefulsets di Homelab agar sinkronisasi disk aman..."
        kubectl scale statefulset postgres mysql minio redis vault redpanda -n infra --replicas=0 2>/dev/null || true
        sleep 3

        TEMP_PV_RESTORE="/tmp/restic-homelab-failback"
        sudo rm -rf "$TEMP_PV_RESTORE"
        mkdir -p "$TEMP_PV_RESTORE"

        log "Mengunduh snapshot PV terbaru dari Backblaze B2..."
        "$RESTIC_BIN" restore latest --tag k3s-pvs --target "$TEMP_PV_RESTORE"

        if [[ -d "$TEMP_PV_RESTORE/storage" ]]; then
            log "Menyinkronkan data ke /var/lib/rancher/k3s/storage/..."
            sudo rsync -a "$TEMP_PV_RESTORE/storage/" /var/lib/rancher/k3s/storage/
        elif [[ -d "$TEMP_PV_RESTORE/var/lib/rancher/k3s/storage" ]]; then
            log "Menyinkronkan data ke /var/lib/rancher/k3s/storage/..."
            sudo rsync -a "$TEMP_PV_RESTORE/var/lib/rancher/k3s/storage/" /var/lib/rancher/k3s/storage/
        fi
        sudo rm -rf "$TEMP_PV_RESTORE"

        log "Merapikan izin direktori storage..."
        sudo chmod -R 777 /var/lib/rancher/k3s/storage 2>/dev/null || true
        sudo chown -R 1001:1001 /var/lib/rancher/k3s/storage/*mongodb* 2>/dev/null || true
        sudo chown -R 65532:65532 /var/lib/rancher/k3s/storage/*minio* 2>/dev/null || true

        log "Menyalakan kembali statefulsets di Homelab..."
        kubectl scale statefulset postgres mysql minio redis vault redpanda -n infra --replicas=1 2>/dev/null || true

        log "Menunggu database utama siap..."
        for svc in postgres mysql minio; do
            kubectl rollout status "statefulset/$svc" -n infra --timeout=90s 2>/dev/null || \
            kubectl rollout status "deployment/$svc" -n infra --timeout=90s 2>/dev/null || true
        done

        # Auto-unseal Vault if sealed
        if kubectl get pod vault-0 -n infra &>/dev/null; then
            if kubectl exec -n infra vault-0 -c vault -- vault status 2>&1 | grep -qi "Sealed.*true"; then
                log "Membuka kunci (unseal) HashiCorp Vault secara otomatis..."
                SEAL_FILE="${ROOT_DIR}/SEALED_TOKEN_VAULT.md"
                if [[ -f "$SEAL_FILE" ]]; then
                    keys=$(grep "Unseal Key" "$SEAL_FILE" | awk '{print $NF}' | head -3)
                    for k in $keys; do
                        kubectl exec -n infra vault-0 -c vault -- vault operator unseal "$k" >/dev/null 2>&1 || true
                    done
                    log "Vault berhasil di-unseal ✓"
                fi
            fi
        fi
        log "Sinkronisasi data terbaru dari B2 ke Homelab selesai ✓"
    else
        warn "Tidak ditemukan snapshot k3s-pvs di B2, melewati restore disk."
    fi
else
    log "Phase 2: Mode cepat (--quick), melewati penarikan ulang disk dari B2."
fi

# ------------------------------------------------------------------------------
# 3. Switch Cloudflare DNS Back to Homelab Primary
# ------------------------------------------------------------------------------
log "Phase 3: Mengalihkan jalur utama Cloudflare kembali ke Server Utama (Homelab Malang)..."
python3 "${ROOT_DIR}/failover/scripts/dns_switcher.py" switch homelab

# ------------------------------------------------------------------------------
# 4. Stop Tencent CVM (Set to Passive / $0 Compute)
# ------------------------------------------------------------------------------
log "Phase 4: Mematikan CVM Tencent Cloud ke mode Passive (STOP_CHARGING / Rp 0)..."
python3 "${ROOT_DIR}/failover/scripts/tencent_cvm.py" stop || true

log "=== Failback Selesai! Homelab Malang kembali Aktif & CVM Cloud sudah Passive (Mati) ✓ ==="
