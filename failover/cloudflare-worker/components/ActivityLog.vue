<script setup lang="ts">
import type { LogItem } from '~/composables/useFailover'

defineProps<{
  logs: LogItem[]
}>()

const emit = defineEmits<{
  (e: 'clear'): void
  (e: 'copy'): void
}>()

function getTagLabel(tag: LogItem['tag']) {
  switch (tag) {
    case 'SWITCH': return 'Akses'
    case 'COMPUTE': return 'Mesin'
    case 'OK': return 'Berhasil'
    case 'ERR': return ' kendala'
    default: return 'Info'
  }
}

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
  <section class="card">
    <div class="card-title-row">
      <span class="card-title">Riwayat Aktivitas</span>
      <div class="log-actions">
        <button type="button" class="btn-mini" @click="emit('copy')">Salin</button>
        <button type="button" class="btn-mini" @click="emit('clear')">Bersihkan</button>
      </div>
    </div>

    <div class="log-list">
      <div v-if="logs.length === 0" class="empty-log">
        Belum ada catatan aktivitas baru.
      </div>
      <div v-for="(item, idx) in logs" :key="idx" class="log-row">
        <span class="log-time">{{ item.time }}</span>
        <span class="log-tag" :class="getTagClass(item.tag)">{{ getTagLabel(item.tag) }}</span>
        <span class="log-msg">{{ item.message }}</span>
      </div>
    </div>
  </section>
</template>

<style lang="scss" scoped>
@use '~/assets/scss/variables' as *;

.log-actions {
  display: flex;
  gap: 6px;
}

.btn-mini {
  background: var(--badge-bg);
  border: 1px solid var(--badge-border);
  color: var(--text-muted);
  padding: 4px 10px;
  border-radius: 7px;
  font-size: 11.5px;
  font-weight: 500;
  cursor: pointer;
  transition: $transition-base;

  &:hover {
    color: var(--text);
    border-color: var(--card-border-hover);
  }
}

.log-list {
  background: var(--card-inner-bg);
  border: 1px solid var(--card-border);
  border-radius: 11px;
  padding: 12px 14px;
  max-height: 220px;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.empty-log {
  font-size: 12.5px;
  color: var(--text-subtle);
  text-align: center;
  padding: 12px 0;
}

.log-row {
  display: flex;
  align-items: baseline;
  gap: 10px;
  font-size: 12.5px;
  line-height: 1.45;
}

.log-time {
  font-family: $font-mono;
  font-size: 11px;
  color: var(--text-subtle);
  flex-shrink: 0;
}

.log-tag {
  font-size: 10.5px;
  padding: 1px 7px;
  border-radius: 99px;
  font-weight: 600;
  flex-shrink: 0;

  &.switch { background: rgba(59, 130, 246, 0.16); color: #60a5fa; }
  &.compute { background: rgba(245, 158, 11, 0.16); color: #fbbf24; }
  &.status { background: var(--badge-bg); color: var(--text-muted); }
  &.success { background: rgba(16, 185, 129, 0.16); color: #10b981; }
  &.error { background: rgba(239, 68, 68, 0.16); color: #f87171; }
}

.log-msg {
  color: var(--text-muted);
  word-break: break-word;
}
</style>
