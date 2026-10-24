<script setup lang="ts">
import type { StatusResponse } from '~/composables/useFailover'

defineProps<{
  statusData: StatusResponse | null
  lastUpdated: string
}>()

const emit = defineEmits<{
  (e: 'compute', action: 'start' | 'stop'): void
}>()
</script>

<template>
  <section class="card">
    <div class="card-title-row">
      <span class="card-title">Status Layanan Saat Ini</span>
      <span class="last-refresh">Diperbarui {{ lastUpdated || '...' }}</span>
    </div>

    <div class="hero-main">
      <div class="status-header">
        <div
          class="status-pill"
          :class="{
            homelab: statusData?.currentOrigin === 'HOMELAB',
            tencent: statusData?.currentOrigin === 'TENCENT',
            unknown: !statusData || statusData?.currentOrigin === 'UNKNOWN'
          }"
        >
          <span class="pulse-dot"></span>
          <span>
            {{
              statusData?.currentOrigin === 'HOMELAB'
                ? 'Berjalan Normal • Server Utama (Malang)'
                : statusData?.currentOrigin === 'TENCENT'
                ? 'Mode Cadangan • Server Cloud (Singapore)'
                : 'Memeriksa koneksi server...'
            }}
          </span>
        </div>
      </div>

      <p class="hero-summary">
        <template v-if="statusData?.currentOrigin === 'HOMELAB'">
          Seluruh website dan aplikasi saat ini dilayani langsung oleh <strong>Server Utama di Malang</strong>.
        </template>
        <template v-else-if="statusData?.currentOrigin === 'TENCENT'">
          Seluruh website dan aplikasi saat ini dialihkan sementara ke <strong>Server Cadangan di Cloud</strong>.
        </template>
        <template v-else>
          Sedang memuat informasi jalur server aktif...
        </template>
      </p>

      <!-- Clean 2-Server Comparison Grid -->
      <div class="servers-grid">
        <!-- Server Malang -->
        <div class="server-item" :class="{ active: statusData?.currentOrigin === 'HOMELAB' }">
          <div class="server-top">
            <div class="server-icon">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <path d="m3 9 9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/>
              </svg>
            </div>
            <span class="server-badge" :class="statusData?.currentOrigin === 'HOMELAB' ? 'badge-green' : 'badge-muted'">
              {{ statusData?.currentOrigin === 'HOMELAB' ? 'Aktif Melayani' : 'Siaga' }}
            </span>
          </div>
          <div class="server-name">Server Utama (Malang)</div>
          <div class="server-meta">Jaringan Utama Lokal</div>
        </div>

        <!-- Server Cloud -->
        <div class="server-item" :class="{ 'active-cloud': statusData?.currentOrigin === 'TENCENT' }">
          <div class="server-top">
            <div class="server-icon">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <path d="M17.5 19H9a7 7 0 1 1 6.71-9h1.79a4.5 4.5 0 1 1 0 9Z"/>
              </svg>
            </div>
            <span
              class="server-badge"
              :class="{
                'badge-blue': statusData?.cvm?.status === 'RUNNING',
                'badge-muted': statusData?.cvm?.status === 'STOPPED' || !statusData?.cvm,
                'badge-amber': statusData?.cvm?.status === 'STARTING' || statusData?.cvm?.status === 'STOPPING'
              }"
            >
              {{
                statusData?.cvm?.status === 'RUNNING'
                  ? 'Mesin Menyala'
                  : statusData?.cvm?.status === 'STOPPED'
                  ? 'Mode Hemat (Mati)'
                  : statusData?.cvm?.status || 'Memeriksa'
              }}
            </span>
          </div>
          <div class="server-name">Server Cadangan (Cloud)</div>
          <div class="server-meta">
            {{
              statusData?.cvm?.status === 'STOPPED'
                ? 'Bebas biaya saat tidak digunakan'
                : statusData?.cvm?.publicIp
                ? `Cloud Singapore • ${statusData.cvm.publicIp}`
                : 'Tencent Cloud Singapore'
            }}
          </div>
        </div>
      </div>

      <!-- Contextual Notice Banner -->
      <div
        v-if="statusData?.recommendation"
        class="notice-bar"
        :class="{
          optimal: statusData?.systemState === 'STANDBY_OPTIMAL',
          active: statusData?.systemState === 'FAILOVER_ACTIVE',
          warning: statusData?.systemState === 'COST_WARNING',
          danger: statusData?.systemState === 'CRITICAL_MISMATCH',
          transition: statusData?.systemState === 'TRANSITIONING'
        }"
      >
        <div class="notice-content">
          <span class="notice-dot"></span>
          <span>{{ statusData.recommendation }}</span>
        </div>

        <button
          v-if="statusData?.systemState === 'COST_WARNING'"
          class="btn-notice-action"
          @click="emit('compute', 'stop')"
        >
          Matikan Cloud
        </button>
        <button
          v-else-if="statusData?.systemState === 'CRITICAL_MISMATCH'"
          class="btn-notice-action"
          @click="emit('compute', 'start')"
        >
          Nyalakan Cloud
        </button>
      </div>
    </div>
  </section>
</template>

<style lang="scss" scoped>
@use '~/assets/scss/variables' as *;

.last-refresh {
  font-size: 12px;
  color: var(--text-subtle);
}

.hero-main {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.status-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  flex-wrap: wrap;
  gap: 10px;
}

.status-pill {
  display: inline-flex;
  align-items: center;
  gap: 9px;
  padding: 7px 14px;
  border-radius: 9999px;
  font-size: 13.5px;
  font-weight: 600;

  &.homelab {
    background: rgba(16, 185, 129, 0.12);
    color: #10b981;
    border: 1px solid rgba(16, 185, 129, 0.3);
  }

  &.tencent {
    background: rgba(37, 99, 235, 0.14);
    color: #60a5fa;
    border: 1px solid rgba(59, 130, 246, 0.35);
  }

  &.unknown {
    background: var(--badge-bg);
    color: var(--text-muted);
    border: 1px solid var(--badge-border);
  }
}

.hero-summary {
  font-size: 14px;
  line-height: 1.5;
  color: var(--text-muted);

  strong {
    color: var(--text);
    font-weight: 600;
  }
}

.servers-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px;

  @media (max-width: 560px) {
    grid-template-columns: 1fr;
  }
}

.server-item {
  padding: 15px 16px;
  border-radius: 12px;
  background: var(--card-inner-bg);
  border: 1px solid var(--card-border);
  display: flex;
  flex-direction: column;
  gap: 6px;
  transition: $transition-base;

  &.active {
    border-color: rgba(16, 185, 129, 0.4);
    background: rgba(16, 185, 129, 0.04);
  }

  &.active-cloud {
    border-color: rgba(59, 130, 246, 0.45);
    background: rgba(59, 130, 246, 0.05);
  }
}

.server-top {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 2px;
}

.server-icon {
  color: var(--text-muted);
  display: flex;
  align-items: center;
}

.server-badge {
  font-size: 11px;
  font-weight: 600;
  padding: 3px 9px;
  border-radius: 999px;

  &.badge-green {
    background: rgba(16, 185, 129, 0.14);
    color: #10b981;
  }

  &.badge-blue {
    background: rgba(59, 130, 246, 0.15);
    color: #60a5fa;
  }

  &.badge-amber {
    background: rgba(245, 158, 11, 0.16);
    color: #fbbf24;
  }

  &.badge-muted {
    background: var(--badge-bg);
    color: var(--text-subtle);
  }
}

.server-name {
  font-size: 14px;
  font-weight: 600;
  color: var(--text);
}

.server-meta {
  font-size: 12px;
  color: var(--text-subtle);
}

.notice-bar {
  border-radius: 11px;
  padding: 11px 14px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  font-size: 12.5px;
  line-height: 1.45;
  background: var(--card-inner-bg);
  border: 1px solid var(--card-border);
  color: var(--text-muted);

  .notice-content {
    display: flex;
    align-items: center;
    gap: 10px;
  }

  .notice-dot {
    width: 7px;
    height: 7px;
    border-radius: 50%;
    flex-shrink: 0;
    background: var(--text-subtle);
  }

  &.optimal .notice-dot {
    background: #10b981;
  }

  &.active .notice-dot {
    background: #3b82f6;
  }

  &.warning {
    background: rgba(245, 158, 11, 0.08);
    border-color: rgba(245, 158, 11, 0.28);
    color: var(--text);

    .notice-dot {
      background: #f59e0b;
    }
  }

  &.danger {
    background: rgba(239, 68, 68, 0.09);
    border-color: rgba(239, 68, 68, 0.3);
    color: var(--text);

    .notice-dot {
      background: #ef4444;
    }
  }
}

.btn-notice-action {
  background: var(--text);
  color: var(--bg);
  border: none;
  padding: 6px 12px;
  border-radius: 8px;
  font-size: 12px;
  font-weight: 600;
  cursor: pointer;
  white-space: nowrap;
  transition: $transition-base;

  &:hover {
    opacity: 0.9;
  }
}
</style>
