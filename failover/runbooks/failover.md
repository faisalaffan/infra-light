# Runbook: Eksekusi Failover ke AWS saat Insiden Produksi

Dokumen ini memandu tindakan ketika server baremetal Homelab mati total dan keputusan failover telah disetujui oleh Operator.

---

## ⚠️ Gerbang Persetujuan (Approval Gate)
**JANGAN EKSEKUSI FAILOVER JIKA BAREMETAL HANYA TERGANGGU SEMENTARA (< 5 Menit).**
Pastikan:
1. Baremetal tidak dapat dihubungi melalui jaringan internal maupun eksternal.
2. Operator telah mengonfirmasi bahwa pemulihan fisik memerlukan waktu lebih lama dari RTO yang ditargetkan (mis. pemadaman listrik berkepanjangan / kerusakan hardware).

---

## 🚀 Prosedur Failover

### Tahap 1: Fencing (Mencegah Split-Brain)
1. Matikan Cloudflare Tunnel atau arahkan DNS lama ke halaman maintenance sementara untuk mencegah penulisan data ke baremetal jika tiba-tiba hidup kembali.

### Tahap 2: Provisioning Infrastruktur AWS
```bash
cd /home/it-helpdesk/DEVOPS/failover/terraform/envs/prod
cp terraform.tfvars.example terraform.tfvars  # jika belum ada
terraform init
terraform apply
```

### Tahap 3: Verifikasi Kesiapan Node & Restorasi
Pantau eksekusi `restore.sh`:
```bash
INSTANCE_ID=$(terraform output -raw instance_id)
aws ssm start-session --target "$INSTANCE_ID" --region ap-southeast-3

# Di dalam server:
tail -f /var/log/failover/restore.log
/usr/local/bin/healthcheck.sh
```

### Tahap 4: Switch Traffic DNS ke AWS
Hanya setelah `/usr/local/bin/healthcheck.sh` mengembalikan status **PASSED**:
1. Edit [terraform.tfvars](file:///home/it-helpdesk/DEVOPS/failover/terraform/envs/prod/terraform.tfvars):
   ```hcl
   enable_dns_switch = true
   ```
2. Jalankan apply untuk memperbarui DNS:
   ```bash
   terraform apply -target=module.dns
   ```
3. Uji akses publik ke domain utama.
