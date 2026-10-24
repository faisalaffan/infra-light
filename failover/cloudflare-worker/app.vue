<script setup lang="ts">
const {
  statusData,
  lastUpdated,
  logHistory,
  authRequired,
  confirmModal,
  isLoading,
  toasts,
  setPin,
  openConfirmSwitch,
  openConfirmCompute,
  closeConfirm,
  executeConfirm,
  clearLogs,
  showToast
} = useFailover()

const showAdvanced = ref(false)

function handleCopyLogs() {
  const text = logHistory.value.map(l => `[${l.time}] [${l.tag}] ${l.message}`).join('\n')
  navigator.clipboard.writeText(text || 'Riwayat kosong').then(() => {
    showToast('Riwayat berhasil disalin')
  })
}
</script>

<template>
  <div class="app-container">
    <TheNavbar />

    <PinModal :visible="authRequired" @save="setPin" />

    <main class="dashboard-stack">
      <StatusHero
        :status-data="statusData"
        :last-updated="lastUpdated"
        @compute="openConfirmCompute"
      />

      <TrafficActions
        :current-origin="statusData?.currentOrigin"
        @switch="openConfirmSwitch"
      />

      <!-- Clean Collapsible Advanced Section -->
      <div class="advanced-section">
        <button
          type="button"
          class="btn-toggle-advanced"
          @click="showAdvanced = !showAdvanced"
        >
          <span>{{ showAdvanced ? 'Sembunyikan Pengaturan Lanjutan & Riwayat' : 'Tampilkan Pengaturan Lanjutan & Riwayat' }}</span>
          <svg
            :class="{ rotated: showAdvanced }"
            width="16"
            height="16"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
          >
            <path d="m6 9 6 6 6-6"/>
          </svg>
        </button>

        <div v-if="showAdvanced" class="advanced-content">
          <ComputeControl
            :status-data="statusData"
            @compute="openConfirmCompute"
          />
          <ActivityLog
            :logs="logHistory"
            @clear="clearLogs"
            @copy="handleCopyLogs"
          />
        </div>
      </div>
    </main>

    <ConfirmModal
      :visible="confirmModal.visible"
      :type="confirmModal.type"
      :title="confirmModal.title"
      :description="confirmModal.description"
      :confirm-text="confirmModal.confirmText"
      :confirm-color="confirmModal.confirmColor"
      :is-loading="isLoading"
      @confirm="executeConfirm"
      @cancel="closeConfirm"
    />

    <ToastNotification :toasts="toasts" />

    <footer>
      Server Utama Malang • Server Cadangan Cloud Singapore
    </footer>
  </div>
</template>

<style lang="scss" scoped>
@use '~/assets/scss/variables' as *;

.advanced-section {
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.btn-toggle-advanced {
  background: transparent;
  border: 1px dashed var(--card-border);
  color: var(--text-muted);
  padding: 11px 16px;
  border-radius: 12px;
  font-size: 13px;
  font-weight: 500;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  transition: $transition-base;
  font-family: inherit;

  &:hover {
    border-color: var(--card-border-hover);
    color: var(--text);
    background: var(--card-inner-bg);
  }

  svg {
    transition: transform 0.2s ease;

    &.rotated {
      transform: rotate(180deg);
    }
  }
}

.advanced-content {
  display: flex;
  flex-direction: column;
  gap: 16px;
  animation: slideDown 0.18s ease-out;
}

@keyframes slideDown {
  from {
    opacity: 0;
    transform: translateY(-6px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}
</style>
