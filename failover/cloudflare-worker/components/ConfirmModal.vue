<script setup lang="ts">
defineProps<{
  visible: boolean
  type: 'switch' | 'compute'
  title: string
  description: string
  confirmText: string
  confirmColor: string
  isLoading: boolean
}>()

const emit = defineEmits<{
  (e: 'confirm'): void
  (e: 'cancel'): void
}>()
</script>

<template>
  <Teleport to="body">
    <div v-if="visible" class="confirm-modal-overlay">
      <div class="confirm-modal-box">
        <div
          class="modal-icon-badge"
          :class="{
            tencent: type === 'switch',
            compute: type === 'compute'
          }"
        >
          {{ type === 'switch' ? '🚀' : '⚡' }}
        </div>
        <h2 class="modal-title">{{ title }}</h2>
        <p class="modal-desc" v-html="description"></p>

        <div class="confirm-buttons-row">
          <button class="btn-modal btn-modal-cancel" :disabled="isLoading" @click="emit('cancel')">
            Batal
          </button>
          <button
            class="btn-modal btn-modal-confirm"
            :style="{ background: confirmColor }"
            :disabled="isLoading"
            @click="emit('confirm')"
          >
            <span v-if="isLoading" class="spinner"></span>
            <span>{{ isLoading ? 'Memproses...' : confirmText }}</span>
          </button>
        </div>
      </div>
    </div>
  </Teleport>
</template>

<style lang="scss" scoped>
@use '~/assets/scss/variables' as *;

.confirm-modal-overlay {
  position: fixed;
  top: 0; left: 0; right: 0; bottom: 0;
  background: var(--modal-overlay);
  backdrop-filter: blur(8px);
  z-index: 2000;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 20px;
}

.confirm-modal-box {
  background: var(--modal-bg);
  border: 1px solid var(--card-border);
  border-radius: 20px;
  width: 100%;
  max-width: 480px;
  padding: 26px;
  display: flex;
  flex-direction: column;
  gap: 16px;
  box-shadow: 0 20px 40px rgba(0, 0, 0, 0.5);
  animation: modalPop 0.2s cubic-bezier(0.16, 1, 0.3, 1);
}

@keyframes modalPop {
  from { opacity: 0; transform: scale(0.95); }
  to { opacity: 1; transform: scale(1); }
}

.modal-icon-badge {
  width: 52px;
  height: 52px;
  border-radius: 14px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 26px;
  margin-bottom: 4px;

  &.tencent { background: rgba(14, 165, 233, 0.15); color: #0ea5e9; }
  &.compute { background: rgba(245, 158, 11, 0.15); color: #f59e0b; }
}

.modal-title {
  font-size: 18px;
  font-weight: 800;
}

.modal-desc {
  font-size: 14px;
  color: var(--text-muted);
  line-height: 1.5;
}

.confirm-buttons-row {
  display: grid;
  grid-template-columns: 1fr 1.3fr;
  gap: 12px;
  margin-top: 8px;
}

.btn-modal {
  padding: 12px 18px;
  border-radius: 12px;
  font-size: 14px;
  font-weight: 700;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  transition: $transition-base;
  border: 1px solid transparent;

  &:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }
}

.btn-modal-cancel {
  background: var(--badge-bg);
  border-color: var(--badge-border);
  color: var(--text-muted);

  &:hover:not(:disabled) {
    background: var(--card-border-hover);
    color: var(--text);
  }
}

.btn-modal-confirm {
  color: white;
}

.spinner {
  width: 14px;
  height: 14px;
  border: 2px solid rgba(255, 255, 255, 0.3);
  border-top-color: white;
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}
</style>
