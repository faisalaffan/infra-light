# Runbook: Cold-Standby Failover Drill (Uji Coba Terisolasi)

Dokumen ini memandu pelaksanaan latihan pemulihan bencana (*disaster recovery drill*) secara terisolasi tanpa mengganggu layanan produksi.

---

## 🎯 Sasaran Drill
1. Memvalidasi otomatisasi IaC Terraform/OpenTofu dan bootstrap cloud-init di AWS.
2. Menguji restorasi etcd snapshot dari Backblaze B2 ke K3s instance baru.
3. Mengukur **RTO nyata** (durasi dari trigger hingga seluruh workload siap).
4. Memverifikasi integritas data hasil restore.
5. Memastikan teardown menghapus seluruh resource tanpa sisa biaya.

---

## 📋 Pra-Syarat
- Akun AWS dengan kuota EC2 di region target (default: `ap-southeast-3` Jakarta atau `ap-southeast-1` Singapura).
- Kredensial B2 Application Key dengan akses read-only ke bucket backup.
- Terraform CLI (v1.5+) terinstal.

---

## 🛠️ Langkah-Langkah Eksekusi

### 1. Persiapan Environment Drill
```bash
cd /home/it-helpdesk/DEVOPS/failover/terraform/envs/drill
cp terraform.tfvars.example terraform.tfvars
```
Edit [terraform.tfvars](file:///home/it-helpdesk/DEVOPS/failover/terraform/envs/drill/terraform.tfvars) untuk mengisi kredensial B2 dan nama bucket.

### 2. Jalankan Provisioning
Catat waktu mulai ($T_0$):
```bash
terraform init
terraform plan
terraform apply -auto-approve
```

### 3. Pantau Proses Bootstrap & Restore
Setelah Terraform selesai menampilkan Public IP dan Instance ID, hubungi instance melalui AWS SSM atau periksa log:
```bash
# Connect via AWS SSM
aws ssm start-session --target <INSTANCE_ID> --region ap-southeast-3

# Di dalam EC2 instance:
tail -f /var/log/failover/restore.log
```

### 4. Verifikasi Status Workload
Jalankan verifikasi kesehatan:
```bash
/usr/local/bin/healthcheck.sh
kubectl get nodes -o wide
kubectl get pods -A
```
Catat waktu selesai ($T_1$). Hitung $RTO = T_1 - T_0$.

### 5. Verifikasi Integritas Data
- Hubungkan ke database (misal PostgreSQL) di dalam cluster drill.
- Periksa jumlah baris tabel dan waktu timestamp transaksi terakhir.
- Hitung selisih waktu data terbaru dengan waktu drill ($RPO$).

### 6. Teardown Lingkungan Drill
Setelah seluruh pengujian selesai, hapus seluruh infrastruktur uji coba:
```bash
terraform destroy -auto-approve
```
Verifikasi di AWS Management Console bahwa tidak ada instance, volume EBS, atau EIP yang tertinggal.
