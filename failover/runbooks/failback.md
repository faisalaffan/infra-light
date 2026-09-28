# Runbook: Prosedur Failback & Restore ke Server Baremetal

Dokumen ini menjelaskan langkah-langkah mengembalikan operasional dari Cloud (Vultr/AWS) kembali ke server baremetal fisik (atau server cadangan fisik milik orang lain) menggunakan **Ansible**.

---

## 🧭 Alur Pemulihan Baremetal

### 1. Persiapan Server Baremetal
- Pastikan server baremetal hidup, jaringan stabil, dan OS Linux (Ubuntu/Debian) dapat diakses via SSH.
- Daftarkan IP / Hostname server target di [`ansible/inventory/hosts.yml`](file:///home/it-helpdesk/DEVOPS/ansible/inventory/hosts.yml).

### 2. Freeze Write di Cloud (Maintenance Mode)
- Pasang maintenance mode di Ingress Cloudflare.
- Simpan snapshot k3s etcd & database terbaru di instance cloud ke B2:
  ```bash
  k3s etcd-snapshot save --etcd-s3 \
    --etcd-s3-endpoint="$B2_ENDPOINT" \
    --etcd-s3-bucket="$B2_BUCKET" \
    --etcd-s3-access-key="$B2_KEY_ID" \
    --etcd-s3-secret-key="$B2_APPLICATION_KEY" \
    --etcd-s3-snapshot-name="failback-snapshot-$(date +%s)"
  ```

### 3. Eksekusi Restorasi Otomatis via Ansible Playbook
Jalankan playbook restorasi dari mesin manajemen / laptop Anda:
```bash
# Melalui root Makefile:
make baremetal-restore TARGET=k3s_server

# Atau jalankan playbook langsung:
cd ansible
ansible-playbook playbooks/failover-restore.yml -i inventory/hosts.yml -e "target_hosts=k3s_server" --ask-vault-pass
```

Playbook ini akan secara otomatis:
1. Memasang paket dependensi (`awscli`, `curl`, `jq`, `git`).
2. Mengambil snapshot etcd terbaru dari Backblaze B2.
3. Menghentikan K3s lama (jika ada) dan melakukan restore cluster (`--cluster-reset`).
4. Memulai service K3s dan menunggu node berstatus **Ready**.
5. Menarik dan menerapkan manifest GitOps ke cluster.
6. Menampilkan ringkasan status node & pod.

### 4. Arahkan Kembali DNS / Cloudflare Tunnel
- Arahkan kembali DNS/Tunnel Cloudflare ke IP baremetal tujuan.
- Uji akses publik ke domain utama.

### 5. Teardown Cloud Instance (Vultr / AWS)
Setelah baremetal stabil:
```bash
# Jika sebelumnya menggunakan Vultr:
make failover-destroy ENV=prod PROVIDER=vultr

# Jika sebelumnya menggunakan AWS:
make failover-destroy ENV=prod PROVIDER=aws
```
Infrastruktur cloud dihancurkan dan biaya kembali ke Rp 0.
