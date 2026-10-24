<script setup lang="ts">
import type { StatusResponse } from '~/composables/useFailover'

defineProps<{
  statusData: StatusResponse | null
  lastUpdated: string
}>()
</script>

<template>
  <section class="card">
    <div class="card-title-row">
      <span class="card-title">📡 Status Routing Lalu Lintas (Traffic)</span>
      <span class="last-refresh">Update: {{ lastUpdated || 'Checking...' }}</span>
    </div>

    <div class="hero-routing-box">
      <div class="hero-status-header">
        <div
          class="big-status-pill"
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
                ? '🟢 SERVER UTAMA (HOMELAB MALANG AKTIF)'
                : statusData?.currentOrigin === 'TENCENT'
                ? '🔵 CLOUD STANDBY (TENCENT SINGAPORE AKTIF)'
                : '⚪ MEMERIKSA STATUS ROUTING...'
            }}
          </span>
        </div>
        <span class="edge-badge">
          Cloudflare Edge: <b style="color: #f97316;">🟧 Aktif</b>
        </span>
      </div>

      <p class="hero-description">
        <template v-if="statusData?.currentOrigin === 'HOMELAB'">
          Lalu lintas seluruh 29 subdomain saat ini normal menuju <strong>Server Malang (Homelab Utama)</strong>.
        </template>
        <template v-else-if="statusData?.currentOrigin === 'TENCENT'">
          Status Failover Aktif! Seluruh lalu lintas sedang dilayani oleh <strong>Cloud Standby (Tencent Cloud Singapore)</strong>.
        </template>
        <template v-else>
          Sistem sedang memverifikasi rute DNS global di Cloudflare Edge.
        </template>
      </p>

      <!-- Smart System State Recommendation Banner -->
      <div
        v-if="statusData?.recommendation"
        class="smart-recommendation-banner"
        :class="{
          optimal: statusData?.systemState === 'STANDBY_OPTIMAL',
          active: statusData?.systemState === 'FAILOVER_ACTIVE',
          warning: statusData?.systemState === 'COST_WARNING',
          danger: statusData?.systemState === 'CRITICAL_MISMATCH',
          transition: statusData?.systemState === 'TRANSITIONING'
        }"
      >
        <span class="banner-icon">
          {{
            statusData?.systemState === 'STANDBY_OPTIMAL' ? '🛡️' :
            statusData?.systemState === 'FAILOVER_ACTIVE' ? '🚀' :
            statusData?.systemState === 'COST_WARNING' ? '⚠️' :
            statusData?.systemState === 'CRITICAL_MISMATCH' ? '🚨' : '⏳'
          }}
        </span>
        <div class="banner-text">
          <b>{{
            statusData?.systemState === 'STANDBY_OPTIMAL' ? 'Siaga Ideal ($0 Compute): ' :
            statusData?.systemState === 'FAILOVER_ACTIVE' ? 'Failover Cloud Berjalan: ' :
            statusData?.systemState === 'COST_WARNING' ? 'Peringatan Biaya: ' :
            statusData?.systemState === 'CRITICAL_MISMATCH' ? 'Peringatan Bahaya: ' : 'Status Transisi: '
          }}</b>
          {{ statusData?.recommendation }}
        </div>
      </div>

      <!-- Visual Flow Diagram -->
      <div class="flow-diagram">
        <div class="flow-node">
          <div class="node-icon">👥</div>
          <div class="node-name">Pengunjung</div>
          <div class="node-sub">Web & Mobile</div>
        </div>
        <div class="flow-arrow">➔</div>
        <div class="flow-node">
          <div class="node-icon">☁️</div>
          <div class="node-name">Cloudflare</div>
          <div class="node-sub">Global Edge DNS</div>
        </div>
        <div class="flow-arrow">➔</div>
        <div
          class="flow-node"
          :class="{ active: statusData?.currentOrigin === 'HOMELAB' }"
        >
          <div class="node-icon">🏠</div>
          <div class="node-name">Server Malang</div>
          <div class="node-sub">Homelab Utama</div>
        </div>
        <div class="flow-arrow">/</div>
        <div
          class="flow-node"
          :class="{ 'active-tencent': statusData?.currentOrigin === 'TENCENT' }"
        >
          <div class="node-icon">🚀</div>
          <div class="node-name">Cloud Standby</div>
          <div class="node-sub">Tencent Singapore</div>
        </div>
      </div>

      <!-- Collapsible Technical Specs -->
      <details class="tech-details">
        <summary>🔧 Lihat Parameter Teknis DNS (Cloudflare CNAME)</summary>
        <div class="tech-grid">
          <div class="tech-item">
            <span>Master Pointer Record</span>
            <b>{{ statusData?.masterRecord || '-' }}</b>
          </div>
          <div class="tech-item">
            <span>Target CNAME Aktif</span>
            <code style="color: #38bdf8;">{{ statusData?.targetContent || 'Loading...' }}</code>
          </div>
          <div class="tech-item">
            <span>Homelab Tunnel ID</span>
            <code>{{ statusData?.homelabUuid || '-' }}</code>
          </div>
          <div class="tech-item">
            <span>Tencent Standby ID</span>
            <code>{{ statusData?.tencentUuid || '-' }}</code>
          </div>
        </div>
      </details>
    </div>
  </section>
</template>

<style lang="scss" scoped>
@use '~/assets/scss/variables' as *;

.last-refresh {
  font-size: 11px;
  color: var(--text-subtle);
}

.hero-routing-box {
  border-radius: 16px;
  padding: 20px;
  background: var(--card-inner-bg);
  border: 1px solid var(--card-border);
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.hero-status-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  flex-wrap: wrap;
  gap: 10px;
}

.smart-recommendation-banner {
  border-radius: 12px;
  padding: 12px 16px;
  display: flex;
  align-items: center;
  gap: 12px;
  font-size: 13px;
  line-height: 1.4;

  .banner-icon {
    font-size: 20px;
    flex-shrink: 0;
  }

  &.optimal {
    background: rgba(16, 185, 129, 0.12);
    border: 1px solid rgba(16, 185, 129, 0.3);
    color: #10b981;
  }

  &.active {
    background: rgba(14, 165, 233, 0.12);
    border: 1px solid rgba(14, 165, 233, 0.3);
    color: #38bdf8;
  }

  &.warning {
    background: rgba(245, 158, 11, 0.15);
    border: 1px solid rgba(245, 158, 11, 0.4);
    color: #fbbf24;
  }

  &.danger {
    background: rgba(239, 68, 68, 0.15);
    border: 1px solid rgba(239, 68, 68, 0.4);
    color: #f87171;
  }

  &.transition {
    background: rgba(168, 85, 247, 0.12);
    border: 1px solid rgba(168, 85, 247, 0.3);
    color: #c084fc;
  }
}

.big-status-pill {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  padding: 8px 18px;
  border-radius: 9999px;
  font-size: 14px;
  font-weight: 800;
  letter-spacing: 0.02em;

  &.homelab {
    background: rgba(16, 185, 129, 0.15);
    color: #10b981;
    border: 1.5px solid rgba(16, 185, 129, 0.45);
    box-shadow: 0 0 20px rgba(16, 185, 129, 0.2);
  }

  &.tencent {
    background: rgba(14, 165, 233, 0.15);
    color: #0ea5e9;
    border: 1.5px solid rgba(14, 165, 233, 0.45);
    box-shadow: 0 0 20px rgba(14, 165, 233, 0.2);
  }

  &.unknown {
    background: rgba(156, 163, 175, 0.15);
    color: #94a3b8;
    border: 1.5px solid rgba(156, 163, 175, 0.3);
  }
}

.edge-badge {
  font-size: 12px;
  color: var(--text-muted);
}

.hero-description {
  font-size: 15px;
  line-height: 1.5;
  color: var(--text);

  strong {
    color: $primary;
  }
}

.flow-diagram {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  padding: 14px;
  background: rgba(0, 0, 0, 0.12);
  border-radius: 12px;
  border: 1px dashed var(--card-border);
  flex-wrap: wrap;
}

.flow-node {
  display: flex;
  flex-direction: column;
  align-items: center;
  text-align: center;
  gap: 4px;
  flex: 1;
  min-width: 90px;
  padding: 8px;
  border-radius: 10px;
  transition: $transition-base;

  .node-icon {
    font-size: 22px;
    width: 40px;
    height: 40px;
    border-radius: 10px;
    background: var(--badge-bg);
    border: 1px solid var(--badge-border);
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .node-name {
    font-size: 12px;
    font-weight: 700;
  }

  .node-sub {
    font-size: 11px;
    color: var(--text-muted);
  }

  &.active {
    background: rgba(16, 185, 129, 0.08);
    border: 1px solid rgba(16, 185, 129, 0.3);

    .node-icon {
      border-color: #10b981;
      box-shadow: 0 0 14px rgba(16, 185, 129, 0.35);
      color: #10b981;
    }

    .node-name {
      color: #10b981;
    }
  }

  &.active-tencent {
    background: rgba(14, 165, 233, 0.08);
    border: 1px solid rgba(14, 165, 233, 0.3);

    .node-icon {
      border-color: #0ea5e9;
      box-shadow: 0 0 14px rgba(14, 165, 233, 0.35);
      color: #0ea5e9;
    }

    .node-name {
      color: #0ea5e9;
    }
  }
}

.flow-arrow {
  color: var(--text-subtle);
  font-size: 18px;
  font-weight: bold;
}

details.tech-details {
  background: var(--card-inner-bg);
  border-radius: 10px;
  padding: 10px 14px;
  font-size: 12px;

  summary {
    cursor: pointer;
    color: $primary;
    font-weight: 600;
    user-select: none;
  }
}

.tech-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
  gap: 10px;
  margin-top: 10px;
  font-family: $font-mono;
  font-size: 11px;
}

.tech-item {
  background: rgba(0, 0, 0, 0.15);
  padding: 8px 12px;
  border-radius: 8px;
  display: flex;
  flex-direction: column;
  gap: 3px;

  span {
    color: var(--text-subtle);
    font-size: 10px;
    text-transform: uppercase;
    font-weight: 600;
  }
}
</style>
