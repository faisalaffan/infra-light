# Setup Failover: Better Stack Webhook ➔ Cloudflare Worker ➔ GitHub Actions (Terraform Provisioning)

Dokumen ini menjelaskan alur **Better Stack Webhook** yang memicu **Cloudflare Worker**, lalu Worker memanggil **GitHub Actions (`dr-failover.yml`)** untuk mem-provisioning atau menyalakan Standby Cloud (Tencent / Terraform).

---

## 1. Arsitektur Alur

```
[ Homelab Malang ] ── (Down!)
       │
       ▼
[ Better Stack ] ── Outgoing Webhook (incident.started) ──▶ [ Cloudflare Worker ]
                                                                     │
                                                   repository_dispatch (GitHub API)
                                                                     │
                                                                     ▼
                                                     [ GitHub Actions: dr-failover.yml ]
                                                                     │
                                           ┌─────────────────────────┴────────────────────────┐
                                           ▼                                                  ▼
                                 [ Path A: Warm Boot ]                             [ Path B: Cold Apply ]
                          (Tencent CVM StartInstances - $0 Idle)             (Terraform apply -auto-approve)
                                           │                                                  │
                                           └─────────────────────────┬────────────────────────┘
                                                                     ▼
                                                       [ Startup Gatekeeper ]
                                                    (Delta B2 Sync ➔ Test DB ➔ cloudflared 1)
```

---

## 2. Cara Pasang Cloudflare Worker

### Opsi A: Buat Langsung di Cloudflare Dashboard (Mudah & Cepat)
1. Buka [dash.cloudflare.com](https://dash.cloudflare.com) → Masuk ke menu **Workers & Pages** → **Create application** → **Create Worker**.
2. Beri nama Worker, misalnya: `betterstack-failover-bridge`.
3. Klik **Deploy**.
4. Klik **Edit code**, lalu salin & tempel seluruh kode dari file:
   [`failover/cloudflare-worker/worker.js`](file:///home/it-helpdesk/DEVOPS/failover/cloudflare-worker/worker.js).
5. Klik **Deploy**.

### Pengaturan Environment Variables di Worker:
Masuk ke tab **Settings** → **Variables and Secrets** di Worker Anda:
| Variable Name | Value | Secret? | Keterangan |
|---|---|---|---|
| `GITHUB_PAT` | `ghp_xxxxxxxx` | Yes (Encrypt) | GitHub Personal Access Token dengan scope `repo` |
| `GITHUB_REPO` | `faisalaffan/infra-light` | No | Target repositori GitHub Anda |
| `WEBHOOK_SECRET` | *(Bebas, misal `supersecret123`)* | Yes | Keamanan otentikasi webhook (opsional) |
| `DEFAULT_PROVIDER` | `tencent` | No | Provider target (`tencent` atau `vultr`) |
| `DEFAULT_ENV` | `prod` | No | Environment target (`prod` atau `drill`) |

URL Worker Anda akan berbentuk:
`https://betterstack-failover-bridge.<subdomain>.workers.dev`

---

## 3. Sambungkan di Better Stack

1. Buka Dashboard **Better Stack** (Uptime).
2. Masuk ke **Integrations** → **Outgoing Webhooks** (atau di pengaturan Monitor Homelab Anda → **Alerting** / **Integrations**).
3. Masukkan:
   * **Webhook URL**: `https://betterstack-failover-bridge.<subdomain>.workers.dev` (atau sertakan `?secret=supersecret123` jika pakai secret)
   * **HTTP Method**: `POST`
   * **Events**: Centang `incident.started` (dan opsional `incident.resolved`).
4. Klik **Save**.

---

## 4. Keunggulan Arsitektur Ini
1. **Zero Server / Zero Cost di Sisi Webhook**: Cloudflare Worker gratis (100.000 request/hari).
2. **Tidak Perlu Mengurus Compute Standby Sendiri**: Saat Better Stack teriak down, Worker langsung memerintahkan GitHub Actions runner untuk menjalankan provisioning Terraform atau boot CVM.
3. **Penuh Log & Audit Trail**: Semua riwayat failover tercatat rapi di tab **Actions** repositori `faisalaffan/infra-light`.
