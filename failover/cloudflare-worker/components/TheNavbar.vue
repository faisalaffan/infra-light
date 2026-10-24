<script setup lang="ts">
const { currentTheme, toggleTheme } = useTheme()
const { isRefreshing, fetchStatus, setPin, currentPin } = useFailover()

function promptChangePin() {
  const newPin = prompt('Masukkan PIN Baru Administrator (atau kosongkan untuk logout):', currentPin.value)
  if (newPin !== null) {
    setPin(newPin)
  }
}
</script>

<template>
  <header class="navbar">
    <div class="brand-group">
      <div class="brand-icon">🛡️</div>
      <div class="brand-titles">
        <h1>Pusat Kendali Failover</h1>
        <p>Disaster Recovery Orchestrator • Homelab Malang ⇄ Tencent Cloud</p>
      </div>
    </div>
    <div class="nav-actions">
      <button class="btn-nav" @click="toggleTheme" :title="currentTheme === 'dark' ? 'Ganti ke Mode Terang' : 'Ganti ke Mode Gelap'">
        <span>{{ currentTheme === 'dark' ? '☀️' : '🌙' }}</span>
        <span>{{ currentTheme === 'dark' ? 'Light' : 'Dark' }}</span>
      </button>
      <button class="btn-nav" @click="promptChangePin" title="Kelola Kunci Akses PIN">
        🔒 PIN
      </button>
      <button class="btn-nav" @click="fetchStatus" :disabled="isRefreshing" title="Segarkan Status">
        <span :class="{ 'spin-icon': isRefreshing }">↻</span>
        <span>Segarkan</span>
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
  padding-bottom: 12px;
  border-bottom: 1px solid var(--card-border);
}

.brand-group {
  display: flex;
  align-items: center;
  gap: 14px;
}

.brand-icon {
  width: 44px;
  height: 44px;
  border-radius: 12px;
  background: linear-gradient(135deg, $primary 0%, $success 100%);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 24px;
  box-shadow: 0 4px 14px rgba(59, 130, 246, 0.3);
}

.brand-titles {
  h1 {
    font-size: 20px;
    font-weight: 800;
    letter-spacing: -0.01em;
  }
  p {
    font-size: 13px;
    color: var(--text-muted);
  }
}

.nav-actions {
  display: flex;
  align-items: center;
  gap: 10px;
}

.btn-nav {
  background: var(--badge-bg);
  border: 1px solid var(--badge-border);
  color: var(--text);
  padding: 8px 14px;
  border-radius: 10px;
  font-size: 13px;
  font-weight: 600;
  cursor: pointer;
  display: inline-flex;
  align-items: center;
  gap: 6px;
  transition: $transition-base;

  &:hover {
    background: var(--card-border-hover);
    transform: translateY(-1px);
  }

  &:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }
}

.spin-icon {
  display: inline-block;
  animation: spin 1s infinite linear;
}

@keyframes spin {
  from { transform: rotate(0deg); }
  to { transform: rotate(360deg); }
}
</style>
