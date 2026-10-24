<script setup lang="ts">
const emit = defineEmits<{
  (e: 'switch', target: 'tencent' | 'homelab'): void
}>()
</script>

<template>
  <section class="card">
    <div class="card-title-row">
      <span class="card-title">🔀 Tombol Pengalihan Lalu Lintas (Failover)</span>
    </div>
    <p class="section-desc">
      Pilih tindakan di bawah sesuai kondisi server saat ini. Semua 29 subdomain akan otomatis berpindah dalam 5-15 detik.
    </p>

    <div class="actions-stack">
      <!-- Switch ke Tencent Standby Button -->
      <div class="action-btn-card btn-tencent-card" @click="emit('switch', 'tencent')">
        <div class="btn-icon">🚀</div>
        <div class="btn-info">
          <h3>Alihkan ke Cloud Standby (Tencent Singapore)</h3>
          <p>Tekan tombol ini saat Server Malang / Homelab mati lampu atau internet padam. Otomatis menyalakan CVM, sync B2, dan mengalihkan 29 subdomain ke Cloud.</p>
        </div>
        <div class="btn-arrow-right">➔</div>
      </div>

      <!-- Switch ke Homelab Primary Button -->
      <div class="action-btn-card btn-homelab-card" @click="emit('switch', 'homelab')">
        <div class="btn-icon">🏠</div>
        <div class="btn-info">
          <h3>Kembalikan ke Server Utama (Homelab Malang)</h3>
          <p>Tekan tombol ini saat Server Malang sudah online normal kembali untuk mengembalikan seluruh traffic ke rumah.</p>
        </div>
        <div class="btn-arrow-right">➔</div>
      </div>
    </div>
  </section>
</template>

<style lang="scss" scoped>
@use '~/assets/scss/variables' as *;

.section-desc {
  font-size: 13px;
  color: var(--text-muted);
  margin-bottom: 16px;
}

.actions-stack {
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.action-btn-card {
  border: 2px solid transparent;
  border-radius: 16px;
  padding: 18px 22px;
  display: flex;
  align-items: center;
  gap: 18px;
  cursor: pointer;
  transition: $transition-base;
  text-align: left;

  &:hover {
    transform: translateY(-2px);
    box-shadow: 0 12px 24px -6px rgba(0, 0, 0, 0.25);
  }

  .btn-icon {
    font-size: 32px;
    width: 56px;
    height: 56px;
    border-radius: 14px;
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
  }

  .btn-info {
    flex: 1;

    h3 {
      font-size: 16px;
      font-weight: 700;
      margin-bottom: 4px;
    }

    p {
      font-size: 13px;
      line-height: 1.4;
      opacity: 0.9;
    }
  }

  .btn-arrow-right {
    font-size: 22px;
    opacity: 0.7;
    transition: $transition-base;
  }

  &:hover .btn-arrow-right {
    opacity: 1;
    transform: translateX(4px);
  }
}

.btn-tencent-card {
  background: linear-gradient(135deg, #0284c7 0%, #0369a1 100%);
  color: white;
  box-shadow: 0 8px 20px rgba(2, 132, 199, 0.35);

  .btn-icon {
    background: rgba(255, 255, 255, 0.18);
  }

  &:hover {
    border-color: #38bdf8;
  }
}

.btn-homelab-card {
  background: linear-gradient(135deg, #059669 0%, #047857 100%);
  color: white;
  box-shadow: 0 8px 20px rgba(5, 150, 105, 0.35);

  .btn-icon {
    background: rgba(255, 255, 255, 0.18);
  }

  &:hover {
    border-color: #34d399;
  }
}
</style>
