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
      <span class="card-title">🔐 Masukkan Kunci Akses Administrator</span>
    </div>
    <p class="auth-desc">
      Masukkan PIN Disaster Recovery untuk mengaktifkan kontrol pengalihan traffic dan server standby.
    </p>
    <div class="auth-input-group">
      <input
        v-model="pinInput"
        type="password"
        placeholder="Masukkan PIN (Default: 2026)"
        maxlength="12"
        class="pin-field"
        @keyup.enter="submit"
      >
      <button class="btn-unlock" @click="submit">
        Buka Kunci
      </button>
    </div>
  </div>
</template>

<style lang="scss" scoped>
@use '~/assets/scss/variables' as *;

.auth-card {
  border-color: rgba(245, 158, 11, 0.4);
}

.auth-desc {
  font-size: 13px;
  color: var(--text-muted);
  margin-bottom: 12px;
}

.auth-input-group {
  display: flex;
  gap: 10px;
  max-width: 380px;
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
  font-weight: 700;
  cursor: pointer;
  transition: $transition-base;

  &:hover {
    background: $primary-hover;
  }
}
</style>
