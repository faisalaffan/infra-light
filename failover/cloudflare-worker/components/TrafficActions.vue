<script setup lang="ts">
defineProps<{
  currentOrigin?: 'HOMELAB' | 'TENCENT' | 'UNKNOWN'
}>()

const emit = defineEmits<{
  (e: 'switch', target: 'tencent' | 'homelab'): void
}>()
</script>

<template>
  <section class="card">
    <div class="card-title-row">
      <span class="card-title">Pilih Tindakan Pengalihan</span>
    </div>
    <p class="section-desc">
      Pilih lokasi server sesuai kondisi saat ini. Sistem akan menyiapkan server dan memindahkan akses secara otomatis.
    </p>

    <div class="actions-stack">
      <!-- Switch ke Cloud Standby -->
      <button
        type="button"
        class="action-card"
        :class="{
          'primary-cloud': currentOrigin === 'HOMELAB',
          'is-current': currentOrigin === 'TENCENT'
        }"
        @click="emit('switch', 'tencent')"
      >
        <div class="action-icon cloud-icon">
          <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M17.5 19H9a7 7 0 1 1 6.71-9h1.79a4.5 4.5 0 1 1 0 9Z"/>
          </svg>
        </div>

        <div class="action-info">
          <div class="action-title-row">
            <h3>Gunakan Server Cadangan (Cloud)</h3>
            <span v-if="currentOrigin === 'TENCENT'" class="active-tag">Sedang Aktif</span>
          </div>
          <p>
            Pilih ini jika listrik atau internet di Malang mati. Server Cloud otomatis dinyalakan dan mengambil alih website.
          </p>
        </div>

        <div class="action-chevron">
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="m9 18 6-6-6-6"/>
          </svg>
        </div>
      </button>

      <!-- Switch ke Homelab Primary -->
      <button
        type="button"
        class="action-card"
        :class="{
          'primary-home': currentOrigin === 'TENCENT',
          'is-current': currentOrigin === 'HOMELAB'
        }"
        @click="emit('switch', 'homelab')"
      >
        <div class="action-icon home-icon">
          <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="m3 9 9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/>
          </svg>
        </div>

        <div class="action-info">
          <div class="action-title-row">
            <h3>Gunakan Server Utama (Malang)</h3>
            <span v-if="currentOrigin === 'HOMELAB'" class="active-tag home">Sedang Aktif</span>
          </div>
          <p>
            Pilih ini saat listrik dan internet di Malang sudah kembali normal. Server Cloud akan otomatis dimatikan agar hemat biaya.
          </p>
        </div>

        <div class="action-chevron">
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="m9 18 6-6-6-6"/>
          </svg>
        </div>
      </button>
    </div>
  </section>
</template>

<style lang="scss" scoped>
@use '~/assets/scss/variables' as *;

.section-desc {
  font-size: 13.5px;
  color: var(--text-muted);
  margin-bottom: 16px;
  line-height: 1.45;
}

.actions-stack {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.action-card {
  width: 100%;
  background: var(--card-inner-bg);
  border: 1px solid var(--card-border);
  border-radius: 14px;
  padding: 16px 18px;
  display: flex;
  align-items: center;
  gap: 16px;
  cursor: pointer;
  transition: $transition-base;
  text-align: left;
  color: var(--text);
  font-family: inherit;

  &:hover {
    border-color: var(--card-border-hover);
    transform: translateY(-1px);
  }

  &.primary-cloud {
    border-color: rgba(59, 130, 246, 0.35);
    background: linear-gradient(135deg, rgba(37, 99, 235, 0.08) 0%, rgba(14, 165, 233, 0.03) 100%);

    &:hover {
      border-color: rgba(59, 130, 246, 0.6);
      box-shadow: 0 8px 20px -6px rgba(37, 99, 235, 0.2);
    }
  }

  &.primary-home {
    border-color: rgba(16, 185, 129, 0.35);
    background: linear-gradient(135deg, rgba(16, 185, 129, 0.08) 0%, rgba(5, 150, 105, 0.03) 100%);

    &:hover {
      border-color: rgba(16, 185, 129, 0.6);
      box-shadow: 0 8px 20px -6px rgba(16, 185, 129, 0.2);
    }
  }

  &.is-current {
    opacity: 0.78;
  }
}

.action-icon {
  width: 44px;
  height: 44px;
  border-radius: 11px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;

  &.cloud-icon {
    background: rgba(59, 130, 246, 0.14);
    color: #3b82f6;
  }

  &.home-icon {
    background: rgba(16, 185, 129, 0.14);
    color: #10b981;
  }
}

.action-info {
  flex: 1;

  .action-title-row {
    display: flex;
    align-items: center;
    gap: 8px;
    flex-wrap: wrap;
    margin-bottom: 4px;
  }

  h3 {
    font-size: 15px;
    font-weight: 600;
    color: var(--text);
  }

  p {
    font-size: 13px;
    line-height: 1.45;
    color: var(--text-muted);
  }
}

.active-tag {
  font-size: 11px;
  font-weight: 600;
  padding: 2px 8px;
  border-radius: 999px;
  background: rgba(59, 130, 246, 0.16);
  color: #60a5fa;

  &.home {
    background: rgba(16, 185, 129, 0.16);
    color: #10b981;
  }
}

.action-chevron {
  color: var(--text-subtle);
  display: flex;
  align-items: center;
}
</style>
