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

function handleCopyLogs() {
  const text = logHistory.value.map(l => `[${l.time}] [${l.tag}] ${l.message}`).join('\n')
  navigator.clipboard.writeText(text || 'Log kosong').then(() => {
    showToast('📋 Log berhasil disalin ke clipboard!')
  })
}
</script>

<template>
  <div class="app-container">
    <TheNavbar />

    <PinModal :visible="authRequired" @save="setPin" />

    <main class="dashboard-grid">
      <div class="col-left">
        <StatusHero :status-data="statusData" :last-updated="lastUpdated" />
        <TrafficActions @switch="openConfirmSwitch" />
        <ComputeControl :cvm="statusData?.cvm" @compute="openConfirmCompute" />
      </div>

      <div class="col-right">
        <ActivityLog :logs="logHistory" @clear="clearLogs" @copy="handleCopyLogs" />
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
      Zero-Cost Architecture • Cloudflare Edge Router • Tencent Cloud $0 Idle Standby • Malang Baremetal Primary
    </footer>
  </div>
</template>
