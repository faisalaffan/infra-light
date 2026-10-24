<script setup lang="ts">
import type { StatusResponse } from '~/composables/useFailover'

defineProps<{
  statusData?: StatusResponse | null
}>()

const emit = defineEmits<{
  (e: 'compute', action: 'start' | 'stop'): void
}>()
</script>

<template>
  <section class="card">
    <div class="card-title-row">
      <span class="card-title">Kontrol Mesin Cloud Manual</span>
      <span class="sub-label">Opsional</span>
    </div>

    <div class="compute-box">
      <div class="compute-header">
        <div>
          <strong class="cvm-title">Server Cadangan ({{ statusData?.cvm?.instanceName || 'Cloud Singapore' }})</strong>
          <span class="cvm-meta">
            {{ statusData?.cvm?.publicIp ? `IP: ${statusData.cvm.publicIp} • ` : '' }}{{ statusData?.cvm?.zone || 'ap-singapore-2' }}
          </span>
        </div>
        <div
          class="compute-badge"
          :class="{
            running: statusData?.cvm?.status === 'RUNNING',
            stopped: statusData?.cvm?.status === 'STOPPED' || !statusData?.cvm
          }"
        >
          <span class="pulse-dot"></span>
          <span>
            {{
              statusData?.cvm?.status === 'RUNNING'
                ? 'Menyala'
                : statusData?.cvm?.status === 'STOPPED'
                ? 'Mati (Mode Hemat)'
                : statusData?.cvm?.status || 'Memeriksa...'
            }}
          </span>
        </div>
      </div>

      <p class="compute-desc">
        Gunakan tombol di bawah jika Anda hanya ingin menyalakan atau mematikan mesin Cloud secara terpisah tanpa memindahkan jalur website.
      </p>

      <div class="compute-buttons-row">
        <button
          type="button"
          class="btn-compute btn-compute-start"
          :disabled="statusData?.cvm?.status === 'RUNNING'"
          @click="emit('compute', 'start')"
        >
          Nyalakan Mesin Cloud
        </button>
        <button
          type="button"
          class="btn-compute btn-compute-stop"
          :disabled="statusData?.cvm?.status === 'STOPPED'"
          @click="emit('compute', 'stop')"
        >
          Matikan Mesin (Mode Hemat)
        </button>
      </div>

      <div class="tech-meta-grid">
        <div class="meta-item">
          <span>Domain Pengarah Utama</span>
          <code>{{ statusData?.masterRecord || '-' }}</code>
        </div>
        <div class="meta-item">
          <span>Jalur Tunnel Aktif</span>
          <code>{{ statusData?.targetContent || '-' }}</code>
        </div>
      </div>
    </div>
  </section>
</template>

<style lang="scss" scoped>
@use '~/assets/scss/variables' as *;

.sub-label {
  font-size: 11px;
  color: var(--text-subtle);
  background: var(--badge-bg);
  padding: 2px 8px;
  border-radius: 99px;
}

.compute-box {
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
  font-weight: 600;
}

.cvm-meta {
  font-size: 12px;
  color: var(--text-subtle);
  margin-left: 8px;
}

.compute-badge {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 4px 11px;
  border-radius: 999px;
  font-size: 12px;
  font-weight: 600;

  &.running {
    background: rgba(16, 185, 129, 0.14);
    color: #10b981;
  }

  &.stopped {
    background: var(--badge-bg);
    color: var(--text-muted);
  }
}

.compute-desc {
  font-size: 13px;
  color: var(--text-muted);
  line-height: 1.45;
}

.compute-buttons-row {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 10px;

  @media (max-width: 520px) {
    grid-template-columns: 1fr;
  }
}

.btn-compute {
  padding: 10px 14px;
  border-radius: 10px;
  font-size: 13px;
  font-weight: 600;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  transition: $transition-base;
  border: 1px solid var(--card-border);
  font-family: inherit;

  &:disabled {
    opacity: 0.4;
    cursor: not-allowed;
  }
}

.btn-compute-start {
  background: rgba(37, 99, 235, 0.12);
  border-color: rgba(59, 130, 246, 0.3);
  color: #60a5fa;

  &:hover:not(:disabled) {
    background: #2563eb;
    color: white;
  }
}

.btn-compute-stop {
  background: rgba(239, 68, 68, 0.1);
  border-color: rgba(239, 68, 68, 0.25);
  color: #f87171;

  &:hover:not(:disabled) {
    background: #dc2626;
    color: white;
  }
}

.tech-meta-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 10px;
  padding-top: 12px;
  border-top: 1px solid var(--card-border);

  @media (max-width: 520px) {
    grid-template-columns: 1fr;
  }
}

.meta-item {
  display: flex;
  flex-direction: column;
  gap: 3px;

  span {
    font-size: 11px;
    color: var(--text-subtle);
  }

  code {
    font-family: $font-mono;
    font-size: 11.5px;
    color: var(--text-muted);
    word-break: break-all;
  }
}
</style>
