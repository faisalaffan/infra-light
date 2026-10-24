# Panduan Operasional: Failover Manual (Zero-Cost & Single Master Pointer)

Sistem ini mengimplementasikan failover **100% manual, bebas biaya ($0/bulan)**, dan **tanpa limit kuota (unlimited requests)** dengan memisahkan Data Plane (traffic pengguna langsung ke Cloudflare Tunnel) dari Control Plane (pengalihan via Cloudflare API).

---

## 1. Desain DNS di Cloudflare Dashboard (Cara 1: Single Master Pointer)

Hanya ada **1 record CNAME master** yang diubah saat failover. Semua subdomain pengguna mengarah ke record master ini.

### A. Buat Master Pointer Record
| Type | Name | Content / Target | Proxy Status | Keterangan |
|---|---|---|---|---|
| `CNAME` | `origin.homelab.faisalaffan.com` | `<HOMELAB_UUID>.cfargotunnel.com` | 🟧 **Proxied** | Master switch origin |

### B. Subdomain Layanan Aplikasi (Cukup Sekali Setup)
| Type | Name | Target | Proxy Status |
|---|---|---|---|
| `CNAME` | `app.homelab.faisalaffan.com` | `origin.homelab.faisalaffan.com` | 🟧 **Proxied** |
| `CNAME` | `api.homelab.faisalaffan.com` | `origin.homelab.faisalaffan.com` | 🟧 **Proxied** |
| `CNAME` | `grafana.homelab.faisalaffan.com` | `origin.homelab.faisalaffan.com` | 🟧 **Proxied** |
| `CNAME` | `*.homelab.faisalaffan.com` | `origin.homelab.faisalaffan.com` | 🟧 **Proxied** |

---

## 2. Tiga Cara Menjalankan Switch

### Cara A: Melalui Makefile (Paling Rapi & Standar)
```bash
# 1. Cek status origin aktif & status CVM Tencent
make failover-status

# 2. Alihkan SEMUA 29 subdomain ke Tencent Cloud Standby
make failover-switch-tencent

# 3. Kembalikan SEMUA 29 subdomain ke Homelab Malang
make failover-switch-homelab

# 4. Manajemen Komputasi Tencent CVM ($0 Idle):
make failover-start-tencent     # Start CVM
make failover-stop-tencent      # Stop CVM ($0 compute cost)
```

---

### Cara B: Melalui HP via GitHub Mobile App ([dr-failover.yml](file:///home/it-helpdesk/DEVOPS/.github/workflows/dr-failover.yml))
1. Buka aplikasi **GitHub** di ponsel Anda.
2. Masuk ke repositori `faisalaffan/infra-light` ➔ Tab **Actions**.
3. Pilih workflow **"Automated DR Failover Sentinel (Tencent Standby)"**.
4. Klik **Run workflow**:
   - Untuk menyalakan standby CVM: Pilih `action = start`
   - Untuk memindahkan traffic ke Tencent: Pilih `action = switch-tencent`
   - Untuk mengembalikan traffic ke Homelab: Pilih `action = switch-homelab`
   - Untuk mematikan CVM setelah selesai ($0 idle): Pilih `action = stop`

---

### Cara C: Melalui HP via Mini Web Dashboard ([cloudflare-worker](file:///home/it-helpdesk/DEVOPS/failover/cloudflare-worker))
1. Deploy worker:
   ```bash
   cd failover/cloudflare-worker
   npx wrangler deploy
   npx wrangler secret put CLOUDFLARE_API_TOKEN
   npx wrangler secret put GITHUB_PAT
   ```
2. Buka URL worker di browser HP Anda (misal `https://dr-failover-controller.<subdomain>.workers.dev`).
3. Masukkan PIN keamanan (default: `2026`, dapat diubah di [wrangler.toml](file:///home/it-helpdesk/DEVOPS/failover/cloudflare-worker/wrangler.toml)).
4. Tersedia tombol:
   - `[ 🚀 Switch ke Tencent Standby ]`
   - `[ 🏠 Switch ke Homelab Primary ]`
   - `[ ⚡ Start CVM ]` & `[ 🛑 Stop CVM ]`

---

## 3. Konfigurasi Monitoring Better Stack (100% Free Tier - $0)

1. Buka dashboard **Better Stack Uptime** (tier gratis).
2. Buat Monitor HTTP:
   - **URL**: `https://homelab-origin.faisalaffan.me/healthz` (arah langsung ke Tunnel Homelab)
   - **Check Interval**: 60 detik.
3. Notifikasi:
   - Install aplikasi **Better Uptime** di ponsel Android / iPhone untuk menerima push notification real-time.
   - Atau aktifkan integrasi Telegram Bot / Email.
4. **Tanpa Outgoing Webhooks**: Menghindari biaya $29/bulan. Keputusan failover 100% aman di tangan Anda.
