# 🛡️ Panduan Operasional: K3s Disaster Recovery (Restic + Backblaze B2)

Dokumen ini menjelaskan prosedur setup, operasional rutin, monitoring, dan simulasi pemulihan (disaster recovery) untuk backup **K3s Cluster State** dan **Kubernetes Persistent Volumes** ke **Backblaze B2** menggunakan **Restic**.

---

## 1. Arsitektur & Strategi Backup

| Lapisan | Target | Frekuensi | Metode |
| :--- | :--- | :--- | :--- |
| **K3s Cluster State** | `/var/lib/rancher/k3s/server/db` | Tiap 6 jam (`0 */6 * * *`) | Snapshot etcd/SQLite + Restic |
| **Data Persistent Volumes (PV)** | `/var/lib/rancher/k3s/storage` | Tiap 6 jam (`0 */6 * * *`) | Restic incremental chunk-dedup (AES-256) |
| **Failover Restore** | VM Baru (Vultr / AWS / Hetzner) | Saat Bencana / Drill | `restore.sh` & Ansible Playbook |

---

## 2. Langkah Setup Kredensial Backblaze B2

### A. Buat Bucket di Backblaze B2
1. Login ke [Backblaze B2 Console](https://secure.backblaze.com/b2_buckets.htm).
2. Klik **Create a Bucket**:
   * **Bucket Name**: `my-homelab-k3s-backups` (atau nama unik Anda).
   * **Files in Bucket are**: `Private`.
   * **Default Encryption**: `Enabled (Server-Side Encryption SSE-B2)` *(opsional, karena Restic sudah mengenkripsi di sisi client)*.
   * **Object Lock**: `Disabled` (atau Enabled jika ingin proteksi ransomware/immutability).

### B. Buat Application Key
1. Buka menu **Application Keys** di dashboard Backblaze.
2. Klik **Add a New Application Key**:
   * **Name of Key**: `k3s-restic-backup-key`
   * **Allow access to Bucket(s)**: Pilih bucket yang baru Anda buat (`my-homelab-k3s-backups`).
   * **Type of Access**: `Read and Write`.
3. Salin:
   * **keyID** -> Masukkan ke `B2_APPLICATION_KEY_ID` di `DEVOPS/.env`.
   * **applicationKey** -> Masukkan ke `B2_APPLICATION_KEY` di `DEVOPS/.env`.

---

## 3. Konfigurasi di `DEVOPS/.env`

Pastikan variabel berikut terisi di file `DEVOPS/.env`:

```env
# ── Backblaze B2 & Restic Disaster Recovery ─────────────────
B2_ENDPOINT=https://s3.us-west-004.backblazeb2.com
B2_BUCKET=my-homelab-k3s-backups
B2_PREFIX=k3s-snapshots
B2_APPLICATION_KEY_ID=your_key_id_here
B2_APPLICATION_KEY=your_secret_key_here

# Restic Client-Side Encrypted PV Backup
RESTIC_PASSWORD=your_strong_generated_password
RESTIC_REPOSITORY=s3:https://s3.us-west-004.backblazeb2.com/my-homelab-k3s-backups/restic-pvs
RESTIC_BACKUP_SCHEDULE="0 */6 * * *"
RESTIC_RETENTION_KEEP_DAILY='"7"'
RESTIC_RETENTION_KEEP_WEEKLY='"4"'
RESTIC_RETENTION_KEEP_MONTHLY='"3"'
RESTIC_EXCLUDE_REGISTRY='"true"'
```

Setelah mengisi kredensial, perbarui secret Kubernetes:
```bash
make setup  # Atau jalankan ./setup.sh
```

---

## 4. Perintah Operasional Harian (Makefile)

Gunakan perintah `make` untuk operasional cepat:

```bash
# 1. Menjalankan backup on-demand sekarang (host level)
make b2-backup

# 2. Menjalankan backup via Kubernetes CronJob
make b2-cron-trigger

# 3. Melihat daftar snapshot yang tersimpan di Backblaze B2
make b2-snapshots

# 4. Memverifikasi integritas kriptografi repository Restic
make b2-check

# 5. Menampilkan bantuan perintah B2
make b2-help
```

---

## 5. Simulasi Pemulihan / Drill Restore

Untuk menguji pemulihan tanpa mengganggu data cluster yang sedang berjalan:

### Uji Restore ke Direktori Temporary (`/tmp/dr-test/`)
```bash
./scripts/restore-restic-b2.sh --target /tmp/dr-test/
```

### Uji Restore Volume Tertentu (Misal Postgres saja)
```bash
./scripts/restore-restic-b2.sh --target /tmp/dr-test/ --include "*data-postgres-0*"
```

---

## 6. Alur Otomatisasi Saat Terjadi Bencana (Failover)

Jika server baremetal crash atau ISP down total:

1. **Provision VM Cold-Standby di Cloud (Vultr / AWS)**:
   ```bash
   cd failover
   ./failover.sh
   ```
2. **Eksekusi Restore**:
   * Skrip `failover/bootstrap/restore.sh` akan:
     1. Menarik snapshot etcd K3s terbaru dari Backblaze B2 -> Me-reset cluster K3s ke state snapshot.
     2. Menginstall `restic` -> Menarik seluruh volume data `/var/lib/rancher/k3s/storage` dari repository `restic-pvs`.
     3. Mengkloning repo GitOps -> Mengaplikasikan manifest Kubernetes.
     4. Mengalihkan DNS Cloudflare ke IP publik VM baru.
3. Seluruh database (PostgreSQL, ClickHouse, MySQL, Mongo, MinIO, Grafana) pulih dengan data terakhir yang tersimpan di Backblaze B2!
