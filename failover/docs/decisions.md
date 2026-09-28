# Architectural Decision Records (ADR)

## ADR 001: Arsitektur Cold-Standby vs Active-Active
- **Status**: Diterima
- **Konteks**: Homelab berjalan pada single-node baremetal k3s. Biaya idle bulanan di cloud harus sekecil mungkin.
- **Keputusan**: Menggunakan arsitektur **Cold-Standby**. Tidak ada compute EC2 yang berjalan pada kondisi normal. Compute AWS hanya dibuat saat terjadi insiden atau saat latihan (*drill*).
- **Konsekuensi**: RTO berkisar antara 15–45 menit (waktu provisioning EC2 + download & restore etcd/state). Biaya idle harian cloud mendekati nol (hanya storage backup B2).

---

## ADR 002: Gerbang Persetujuan Manual (Manual Approval Gate)
- **Status**: Diterima
- **Konteks**: Gangguan ISP atau restart listrik singkat dapat menyebabkan false-positive outage.
- **Keputusan**: Failover memerlukan persetujuan manual (1-klik / instruksi eksplisit dari Operator) dan tidak otomatis mempromosikan database ke AWS tanpa konfirmasi, guna mencegah risiko split-brain.
- **Konsekuensi**: Memerlukan keterlibatan operator saat insiden, namun mencegah kerusakan konsistensi data.

---

## ADR 003: Penyimpanan Backup Off-Site di Backblaze B2 (S3-Compatible)
- **Status**: Diterima
- **Konteks**: Diperlukan penyimpanan snapshot cluster dan data volume yang terpisah secara fisik dan provider dari homelab dan AWS.
- **Keputusan**: Menggunakan Backblaze B2 dengan API S3-compatible untuk snapshot etcd k3s dan snapshot database.
- **Konsekuensi**: Biaya penyimpanan jauh lebih hemat dibanding S3 Standard, namun ada pertimbangan latensi dan throughput saat download snapshot ke region AWS Jakarta/Singapura saat failover.

---

## ADR 004: Modularitas Provider IaC (Provider-Agnostic Modules)
- **Status**: Diterima
- **Konteks**: Target utama adalah AWS, tetapi alternatif seperti Hetzner Cloud atau DigitalOcean dipertimbangkan di masa depan.
- **Keputusan**: Memisahkan modul Terraform menjadi `network`, `compute`, `iam`, dan `dns` yang memiliki input/output standar sehingga compute layer dapat diganti bila diperlukan tanpa merusak logika bootstrap.
- **Konsekuensi**: Struktur kode lebih rapi, terisolasi, dan mudah dipelihara.
