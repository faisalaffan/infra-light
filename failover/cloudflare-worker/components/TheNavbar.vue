<script setup lang="ts">
const { currentTheme, toggleTheme } = useTheme()
const { isRefreshing, fetchStatus, setPin, currentPin } = useFailover()

function promptChangePin() {
  const newPin = prompt('Masukkan Kode Akses (PIN) Administrator:', currentPin.value)
  if (newPin !== null) {
    setPin(newPin)
  }
}
</script>

<template>
  <header class="navbar">
    <div class="brand-group">
      <div class="brand-icon">
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
          <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/>
          <path d="m9 12 2 2 4-4"/>
        </svg>
      </div>
      <div class="brand-titles">
        <h1>Panel Kendali Server</h1>
        <p>Pengalihan Akses Server Malang & Cloud</p>
      </div>
    </div>

    <div class="nav-actions">
      <button class="btn-nav" @click="toggleTheme" :title="currentTheme === 'dark' ? 'Mode Terang' : 'Mode Gelap'">
        <svg v-if="currentTheme === 'dark'" width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <circle cx="12" cy="12" r="5"/><line x1="12" y1="1" x2="12" y2="3"/><line x1="12" y1="21" x2="12" y2="23"/><line x1="4.22" y1="4.22" x2="5.64" y2="5.64"/><line x1="18.36" y1="18.36" x2="19.78" y2="19.78"/><line x1="1" y1="12" x2="3" y2="12"/><line x1="21" y1="12" x2="23" y2="12"/><line x1="4.22" y1="19.78" x2="5.64" y2="18.36"/><line x1="18.36" y1="5.64" x2="19.78" y2="4.22"/>
        </svg>
        <svg v-else width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/>
        </svg>
      </button>

      <button class="btn-nav" @click="promptChangePin" title="Kode Akses PIN">
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <rect x="3" y="11" width="18" height="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/>
        </svg>
        <span>PIN</span>
      </button>

      <button class="btn-nav" @click="fetchStatus" :disabled="isRefreshing" title="Perbarui Status">
        <svg :class="{ 'spin-icon': isRefreshing }" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
          <path d="M21 12a9 9 0 0 0-9-9 9.75 9.75 0 0 0-6.74 2.74L3 8"/><path d="M3 3v5h5"/><path d="M3 12a9 9 0 0 0 9 9 9.75 9.75 0 0 0 6.74-2.74L21 16"/><path d="M16 16h5v5"/>
        </svg>
        <span>Perbarui</span>
      </button>
    </div>
  </header>
</template>

<style lang="scss" scoped>
@use '~/assets/scss/variables' as *;

.navbar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  flex-wrap: wrap;
  gap: 12px;
  padding: 4px 0 14px;
  border-bottom: 1px solid var(--card-border);
}

.brand-group {
  display: flex;
  align-items: center;
  gap: 12px;
}

.brand-icon {
  width: 38px;
  height: 38px;
  border-radius: 10px;
  background: rgba(37, 99, 235, 0.14);
  border: 1px solid rgba(59, 130, 246, 0.3);
  color: #3b82f6;
  display: flex;
  align-items: center;
  justify-content: center;
}

.brand-titles {
  h1 {
    font-size: 17px;
    font-weight: 700;
    letter-spacing: -0.01em;
  }
  p {
    font-size: 12px;
    color: var(--text-muted);
    margin-top: 1px;
  }
}

.nav-actions {
  display: flex;
  align-items: center;
  gap: 8px;
}

.btn-nav {
  background: var(--badge-bg);
  border: 1px solid var(--badge-border);
  color: var(--text-muted);
  padding: 7px 12px;
  border-radius: 9px;
  font-size: 12.5px;
  font-weight: 600;
  cursor: pointer;
  display: inline-flex;
  align-items: center;
  gap: 6px;
  transition: $transition-base;

  &:hover:not(:disabled) {
    background: var(--card-inner-bg);
    border-color: var(--card-border-hover);
    color: var(--text);
  }

  &:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }
}

.spin-icon {
  animation: spin 0.9s infinite linear;
}

@keyframes spin {
  from { transform: rotate(0deg); }
  to { transform: rotate(360deg); }
}
</style>
