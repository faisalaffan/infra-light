<script setup lang="ts">
defineProps<{
  visible: boolean
}>()

const emit = defineEmits<{
  (e: 'save', pin: string): void
}>()

const pinInput = ref('')

function submit() {
  if (pinInput.value.trim()) {
    emit('save', pinInput.value.trim())
    pinInput.value = ''
  }
}
</script>

<template>
  <div v-if="visible" class="card auth-card">
    <div class="card-title-row">
      <span class="card-title">Verifikasi Kode Akses (PIN)</span>
    </div>
    <p class="auth-desc">
      Masukkan PIN keamanan untuk melihat status dan mengelola perpindahan server.
    </p>
    <div class="auth-input-group">
      <input
        v-model="pinInput"
        type="password"
        placeholder="Masukkan PIN"
        maxlength="12"
        class="pin-field"
        @keyup.enter="submit"
      >
      <button type="button" class="btn-unlock" @click="submit">
        Masuk
      </button>
    </div>
  </div>
</template>

<style lang="scss" scoped>
@use '~/assets/scss/variables' as *;

.auth-card {
  border-color: rgba(59, 130, 246, 0.35);
}

.auth-desc {
  font-size: 13.5px;
  color: var(--text-muted);
  margin-bottom: 14px;
}

.auth-input-group {
  display: flex;
  gap: 10px;
  max-width: 360px;
}

.pin-field {
  flex: 1;
  background: var(--input-bg);
  border: 1px solid var(--card-border);
  border-radius: 10px;
  padding: 10px 14px;
  font-family: $font-mono;
  font-size: 14px;
  color: var(--text);

  &:focus {
    outline: none;
    border-color: $primary;
  }
}

.btn-unlock {
  background: $primary;
  color: white;
  border: 1px solid $primary;
  padding: 10px 18px;
  border-radius: 10px;
  font-size: 13.5px;
  font-weight: 600;
  cursor: pointer;
  transition: $transition-base;

  &:hover {
    background: $primary-hover;
  }
}
</style>
