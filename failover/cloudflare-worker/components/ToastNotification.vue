<script setup lang="ts">
import type { ToastItem } from '~/composables/useFailover'

defineProps<{
  toasts: ToastItem[]
}>()
</script>

<template>
  <div class="toast-container">
    <div v-for="t in toasts" :key="t.id" class="toast">
      {{ t.message }}
    </div>
  </div>
</template>

<style lang="scss" scoped>
@use '~/assets/scss/variables' as *;

.toast-container {
  position: fixed;
  bottom: 24px;
  right: 24px;
  z-index: 3000;
  display: flex;
  flex-direction: column;
  gap: 10px;
  pointer-events: none;
}

.toast {
  background: var(--modal-bg);
  border: 1px solid var(--card-border);
  color: var(--text);
  padding: 12px 20px;
  border-radius: 12px;
  box-shadow: 0 10px 25px rgba(0, 0, 0, 0.3);
  font-size: 13px;
  font-weight: 600;
  display: flex;
  align-items: center;
  gap: 10px;
  pointer-events: auto;
  animation: toastIn 0.3s cubic-bezier(0.16, 1, 0.3, 1);
}

@keyframes toastIn {
  from { opacity: 0; transform: translateY(12px); }
  to { opacity: 1; transform: translateY(0); }
}
</style>
