<script setup lang="ts">
import type { LogItem } from '~/composables/useFailover'

const props = defineProps<{
  logs: LogItem[]
}>()

const emit = defineEmits<{
  (e: 'clear'): void
  (e: 'copy'): void
}>()

const { fontSize, isFullscreen, zoom, toggleFullscreen } = useLogZoom()
const activeFilter = ref<'all' | 'switch' | 'compute' | 'error'>('all')

const filteredLogs = computed(() => {
  if (activeFilter.value === 'all') return props.logs
  return props.logs.filter(l => l.category === activeFilter.value)
})

function getTagClass(tag: LogItem['tag']) {
  switch (tag) {
    case 'SWITCH': return 'switch'
    case 'COMPUTE': return 'compute'
    case 'OK': return 'success'
    case 'ERR': return 'error'
    default: return 'status'
  }
}
</script>

<template>
  <section class="card log-terminal-card">
    <div class="log-toolbar">
      <div class="card-title" style="margin-bottom: 0;">
        📜 Log Aktivitas Sistem
      </div>
      <div class="log-tools-group">
        <!-- Zoom Controls -->
        <span class="zoom-label">Zoom:</span>
        <button class="btn-tool" @click="zoom(-1)" title="Perkecil Font">A-</button>
        <span class="zoom-val">{{ fontSize }}px</span>
        <button class="btn-tool" @click="zoom(1)" title="Perbesar Font">A+</button>

        <!-- Fullscreen Button -->
        <button class="btn-tool" @click="toggleFullscreen" title="Tampilan Layar Penuh">
          ⛶ Layar Penuh
        </button>
        <!-- Copy and Clear -->
        <button class="btn-tool" @click="emit('copy')" title="Salin Log ke Clipboard">📋</button>
        <button class="btn-tool" @click="emit('clear')" title="Bersihkan Tampilan Log">🗑️</button>
      </div>
    </div>

    <!-- Filter tabs -->
    <div class="filter-tabs">
      <button class="btn-tool" :class="{ active: activeFilter === 'all' }" @click="activeFilter = 'all'">Semua</button>
      <button class="btn-tool" :class="{ active: activeFilter === 'switch' }" @click="activeFilter = 'switch'">Traffic</button>
      <button class="btn-tool" :class="{ active: activeFilter === 'compute' }" @click="activeFilter = 'compute'">Server</button>
      <button class="btn-tool" :class="{ active: activeFilter === 'error' }" @click="activeFilter = 'error'">Error</button>
    </div>

    <!-- Terminal Container -->
    <div class="terminal-container" :style="{ fontSize: `${fontSize}px` }">
      <div v-for="(item, idx) in filteredLogs" :key="idx" class="log-row">
        <span class="log-time">[{{ item.time }}]</span>
        <span class="log-tag" :class="getTagClass(item.tag)">{{ item.tag }}</span>
        <span class="log-msg">{{ item.message }}</span>
      </div>
    </div>

    <!-- Fullscreen Modal Log Overlay -->
    <Teleport to="body">
      <div v-if="isFullscreen" class="fullscreen-overlay">
        <div class="fullscreen-modal">
          <div class="fullscreen-header">
            <h2>📜 Log Aktivitas Sistem (Layar Penuh)</h2>
            <div class="log-tools-group">
              <button class="btn-tool" @click="zoom(-1)">A-</button>
              <span class="zoom-val">{{ fontSize }}px</span>
              <button class="btn-tool" @click="zoom(1)">A+</button>
              <button class="btn-tool" @click="emit('copy')">📋 Salin Log</button>
              <button class="btn-close" @click="toggleFullscreen">✕ Tutup</button>
            </div>
          </div>
          <div class="terminal-container fullscreen-body" :style="{ fontSize: `${fontSize}px` }">
            <div v-for="(item, idx) in filteredLogs" :key="idx" class="log-row">
              <span class="log-time">[{{ item.time }}]</span>
              <span class="log-tag" :class="getTagClass(item.tag)">{{ item.tag }}</span>
              <span class="log-msg">{{ item.message }}</span>
            </div>
          </div>
        </div>
      </div>
    </Teleport>
  </section>
</template>

<style lang="scss" scoped>
@use '~/assets/scss/variables' as *;

.log-terminal-card {
  display: flex;
  flex-direction: column;
  height: 100%;
  min-height: 520px;
}

.log-toolbar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  flex-wrap: wrap;
  gap: 8px;
  margin-bottom: 12px;
  padding-bottom: 10px;
  border-bottom: 1px solid var(--card-border);
}

.log-tools-group {
  display: flex;
  align-items: center;
  gap: 6px;
}

.zoom-label {
  font-size: 11px;
  color: var(--text-subtle);
}

.zoom-val {
  font-size: 11px;
  font-weight: 700;
  min-width: 32px;
  text-align: center;
}

.filter-tabs {
  display: flex;
  gap: 6px;
  margin-bottom: 10px;
  overflow-x: auto;
  padding-bottom: 4px;
}

.btn-tool {
  background: var(--badge-bg);
  border: 1px solid var(--badge-border);
  color: var(--text-muted);
  padding: 6px 11px;
  border-radius: 8px;
  font-size: 12px;
  font-weight: 600;
  cursor: pointer;
  transition: $transition-base;
  display: inline-flex;
  align-items: center;
  gap: 4px;

  &:hover {
    background: var(--card-border-hover);
    color: var(--text);
  }

  &.active {
    background: $primary;
    color: white;
    border-color: $primary;
  }
}

.terminal-container {
  flex: 1;
  background: var(--log-bg);
  border: 1px solid var(--card-border);
  border-radius: 14px;
  padding: 14px;
  font-family: $font-mono;
  color: #cbd5e1;
  overflow-y: auto;
  max-height: 520px;
  display: flex;
  flex-direction: column;
  gap: 6px;
  position: relative;
  box-shadow: inset 0 2px 8px rgba(0, 0, 0, 0.4);
}

.log-row {
  display: flex;
  align-items: flex-start;
  gap: 8px;
  line-height: 1.5;
  word-break: break-word;
  animation: fadeIn 0.2s ease;
}

@keyframes fadeIn {
  from { opacity: 0; transform: translateY(-4px); }
  to { opacity: 1; transform: translateY(0); }
}

.log-time {
  color: var(--text-subtle);
  font-size: 0.9em;
  flex-shrink: 0;
}

.log-tag {
  font-size: 0.8em;
  padding: 1px 6px;
  border-radius: 4px;
  font-weight: 700;
  flex-shrink: 0;
  text-transform: uppercase;

  &.switch { background: rgba(59, 130, 246, 0.25); color: #60a5fa; }
  &.compute { background: rgba(245, 158, 11, 0.25); color: #fbbf24; }
  &.status { background: rgba(100, 116, 139, 0.25); color: #94a3b8; }
  &.success { background: rgba(16, 185, 129, 0.25); color: #34d399; }
  &.error { background: rgba(239, 68, 68, 0.25); color: #f87171; }
}

.fullscreen-overlay {
  position: fixed;
  top: 0; left: 0; right: 0; bottom: 0;
  background: var(--modal-overlay);
  backdrop-filter: blur(12px);
  z-index: 1000;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 24px;
}

.fullscreen-modal {
  background: var(--modal-bg);
  border: 1px solid var(--card-border);
  border-radius: 20px;
  width: 100%;
  max-width: 1100px;
  height: 90vh;
  display: flex;
  flex-direction: column;
  box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.6);
  padding: 24px;
  gap: 16px;
}

.fullscreen-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  border-bottom: 1px solid var(--card-border);
  padding-bottom: 12px;

  h2 {
    font-size: 18px;
    display: flex;
    align-items: center;
    gap: 8px;
  }
}

.fullscreen-body {
  max-height: none;
  flex: 1;
}

.btn-close {
  background: var(--badge-bg);
  border: 1px solid var(--badge-border);
  color: var(--text);
  padding: 6px 14px;
  border-radius: 8px;
  font-weight: 700;
  cursor: pointer;
}
</style>
