# Failover Homelab k3s (Baremetal) ke Vultr / AWS Cold-Standby

Infrastruktur sebagai Kode (IaC) dan otomatisasi pemulihan bencana (*Disaster Recovery*) cold-standby untuk Homelab baremetal k3s ke **Vultr** (Jakarta/Singapura) dan **AWS**.

## 📁 Struktur Direktori

```
failover/
├── failover.sh                   # Unified CLI Switcher (Vultr / AWS)
├── README.md
├── docs/
│   └── decisions.md              # Architectural Decision Records (ADR)
├── terraform/
│   ├── modules/
│   │   ├── vultr_compute/        # Vultr VPS & Firewall Group
│   │   ├── compute/              # AWS EC2, SG, EBS
│   │   ├── network/              # AWS VPC & Subnet
│   │   ├── iam/                  # AWS IAM SSM Role
│   │   └── dns/                  # DNS Switcher (Cloudflare / Route53)
│   └── envs/
│       ├── drill-vultr/          # Drill Test Vultr (Jakarta cgk / SGP)
│       ├── prod-vultr/           # Prod Failover Vultr
│       ├── drill/                # Drill Test AWS
│       └── prod/                 # Prod Failover AWS
├── bootstrap/
│   ├── cloud-init.yaml.tpl       # Universal cloud-init bootstrap
│   ├── restore.sh                # Skrip idempotent restore k3s & state dari B2
│   └── healthcheck.sh            # Skrip verifikasi kesiapan cluster
├── watcher/
│   └── watcher.py                # Heartbeat watcher eksternal + Telegram alert
└── runbooks/
    ├── drill.md                  # Panduan drill
    ├── failover.md               # Panduan failover insiden
    └── failback.md               # Panduan failback & teardown
```

---

## ⚡ Cara Menjalankan (Seamless Switcher)

Anda dapat menggunakan **`failover.sh`** atau **`make`** untuk memilih provider dan environment secara instan:

### 1. Menggunakan Vultr (Default)
```bash
# Drill Test di Vultr (Jakarta)
make failover-plan ENV=drill PROVIDER=vultr
make failover-apply ENV=drill PROVIDER=vultr

# Teardown Drill Vultr setelah selesai
make failover-destroy ENV=drill PROVIDER=vultr

# Production Failover ke Vultr
make failover-apply ENV=prod PROVIDER=vultr
```

### 2. Menggunakan AWS
```bash
# Drill Test di AWS
make failover-apply ENV=drill PROVIDER=aws

# Production Failover ke AWS
make failover-apply ENV=prod PROVIDER=aws
```

### 3. Menggunakan Script Langsung:
```bash
./failover/failover.sh apply drill vultr
./failover/failover.sh destroy drill vultr
```
