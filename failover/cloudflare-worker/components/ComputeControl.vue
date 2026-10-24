<script setup lang="ts">
import type { StatusResponse } from '~/composables/useFailover'

defineProps<{
  cvm?: StatusResponse['cvm']
}>()

const emit = defineEmits<{
  (e: 'compute', action: 'start' | 'stop'): void
}>()
</script>

<template>
  <section class="card">
    <div class="card-title-row">
      <span class="card-title">☁️ Server Cloud Standby (Tencent CVM - $0 Idle)</span>
    </div>

    <div class="compute-box">
      <div class="compute-header">
        <div>
          <strong class="cvm-title">{{ cvm?.instanceName || 'k3s-failover-prod' }}</strong>
          <span class="cvm-meta">
            {{ cvm?.publicIp ? `IP: ${cvm.publicIp} • ` : '' }}{{ cvm?.zone || 'ap-singapore-2' }}
          </span>
        </div>
        <div
          class="compute-badge"
          :class="{
            running: cvm?.status === 'RUNNING',
            stopped: cvm?.status === 'STOPPED' || !cvm
          }"
        >
          <span class="pulse-dot"></span>
          <span>
            {{
              cvm?.status === 'RUNNING'
                ? '🟢 MENYALA (RUNNING)'
                : cvm?.status === 'STOPPED'
                ? '🛑 MATI ($0 STOP_CHARGING)'
                : cvm?.status || 'Memeriksa...'
            }}
          </span>
        </div>
      </div>

      <p class="compute-desc">
        Server Cloud ini diatur dalam mode <b>STOP_CHARGING</b> sehingga <b>bebas biaya komputasi ($0/bulan)</b> saat mati.
        Pastikan server dinyalakan terlebih dahulu sebelum mengalihkan traffic jika diperlukan, atau matikan kembali untuk menghemat biaya.
      </p>

      <div class="compute-buttons-row">
        <button
          class="btn-compute btn-compute-start"
          :disabled="cvm?.status === 'RUNNING'"
          @click="emit('compute', 'start')"
        >
          ⚡ Nyalakan Server (Start)
        </button>
        <button
          class="btn-compute btn-compute-stop"
          :disabled="cvm?.status === 'STOPPED'"
          @click="emit('compute', 'stop')"
        >
          🛑 Matikan Server ($0 STOP_CHARGING)
        </button>
      </div>
    </div>
  </section>
</template>

<style lang="scss" scoped>
@use '~/assets/scss/variables' as *;

.compute-box {
  background: var(--card-inner-bg);
  border: 1px solid var(--card-border);
  border-radius: 16px;
  padding: 18px;
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.compute-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  flex-wrap: wrap;
  gap: 10px;
}

.cvm-title {
  font-size: 14px;
}

.cvm-meta {
  font-size: 12px;
  color: var(--text-muted);
  margin-left: 8px;
}

.compute-badge {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 5px 12px;
  border-radius: 9999px;
  font-size: 12px;
  font-weight: 700;

  &.running {
    background: rgba(16, 185, 129, 0.15);
    color: #10b981;
    border: 1px solid rgba(16, 185, 129, 0.35);
  }

  &.stopped {
    background: rgba(100, 116, 139, 0.15);
    color: #94a3b8;
    border: 1px solid rgba(100, 116, 139, 0.35);
  }
}

.compute-desc {
  font-size: 13px;
  color: var(--text-muted);
  line-height: 1.5;
}

.compute-buttons-row {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px;
}

.btn-compute {
  padding: 12px 16px;
  border-radius: 12px;
  font-size: 13px;
  font-weight: 700;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  transition: $transition-base;
  border: 1px solid transparent;

  &:disabled {
    opacity: 0.5;
    cursor: not-allowed;
    transform: none !important;
  }
}

.btn-compute-start {
  background: rgba(59, 130, 246, 0.15);
  color: $primary;
  border-color: rgba(59, 130, 246, 0.3);

  &:hover:not(:disabled) {
    background: $primary;
    color: white;
  }
}

.btn-compute-stop {
  background: rgba(239, 68, 68, 0.12);
  color: $danger;
  border-color: rgba(239, 68, 68, 0.25);

  &:hover:not(:disabled) {
    background: $danger;
    color: white;
  }
}
</style>
