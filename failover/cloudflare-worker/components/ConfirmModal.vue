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
    <div v-if="visible" class="confirm-modal-overlay" @click.self="emit('cancel')">
      <div class="confirm-modal-box">
        <div
          class="modal-icon-badge"
          :class="{
            tencent: type === 'switch',
            compute: type === 'compute'
          }"
        >
          <svg v-if="type === 'switch'" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="m16 3 4 4-4 4"/><path d="M20 7H4"/><path d="m8 21-4-4 4-4"/><path d="M4 17h16"/>
          </svg>
          <svg v-else width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M18.36 6.64a9 9 0 1 1-12.73 0"/><line x1="12" y1="2" x2="12" y2="12"/>
          </svg>
        </div>

        <h2 class="modal-title">{{ title }}</h2>
        <p class="modal-desc" v-html="description"></p>

        <div class="confirm-buttons-row">
          <button type="button" class="btn-modal btn-modal-cancel" :disabled="isLoading" @click="emit('cancel')">
            Batal
          </button>
          <button
            type="button"
            class="btn-modal btn-modal-confirm"
            :style="{ background: confirmColor }"
            :disabled="isLoading"
            @click="emit('confirm')"
          >
            <span v-if="isLoading" class="spinner"></span>
            <span>{{ isLoading ? 'Sedang Memproses...' : confirmText }}</span>
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
  backdrop-filter: blur(6px);
  z-index: 2000;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 20px;
}

.confirm-modal-box {
  background: var(--modal-bg);
  border: 1px solid var(--card-border);
  border-radius: 18px;
  width: 100%;
  max-width: 440px;
  padding: 24px;
  display: flex;
  flex-direction: column;
  gap: 14px;
  box-shadow: 0 20px 40px rgba(0, 0, 0, 0.45);
  animation: modalPop 0.18s cubic-bezier(0.16, 1, 0.3, 1);
}

@keyframes modalPop {
  from { opacity: 0; transform: scale(0.96); }
  to { opacity: 1; transform: scale(1); }
}

.modal-icon-badge {
  width: 44px;
  height: 44px;
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;

  &.tencent { background: rgba(59, 130, 246, 0.14); color: #3b82f6; }
  &.compute { background: rgba(245, 158, 11, 0.14); color: #f59e0b; }
}

.modal-title {
  font-size: 17px;
  font-weight: 700;
  color: var(--text);
}

.modal-desc {
  font-size: 13.5px;
  color: var(--text-muted);
  line-height: 1.55;
}

.confirm-buttons-row {
  display: grid;
  grid-template-columns: 1fr 1.35fr;
  gap: 10px;
  margin-top: 6px;
}

.btn-modal {
  padding: 11px 16px;
  border-radius: 10px;
  font-size: 13.5px;
  font-weight: 600;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  transition: $transition-base;
  border: 1px solid transparent;
  font-family: inherit;

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
    border-color: var(--card-border-hover);
    color: var(--text);
  }
}

.btn-modal-confirm {
  color: white;

  &:hover:not(:disabled) {
    filter: brightness(1.08);
  }
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
