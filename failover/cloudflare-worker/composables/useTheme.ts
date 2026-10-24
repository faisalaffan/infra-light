export function useTheme() {
  const currentTheme = ref<'light' | 'dark'>('dark')

  onMounted(() => {
    const saved = localStorage.getItem('dr_theme') as 'light' | 'dark' | null
    if (saved) {
      currentTheme.value = saved
    } else if (window.matchMedia && window.matchMedia('(prefers-color-scheme: light)').matches) {
      currentTheme.value = 'light'
    }
    document.documentElement.setAttribute('data-theme', currentTheme.value)
  })

  function toggleTheme() {
    currentTheme.value = currentTheme.value === 'dark' ? 'light' : 'dark'
    document.documentElement.setAttribute('data-theme', currentTheme.value)
    localStorage.setItem('dr_theme', currentTheme.value)
  }

  return {
    currentTheme,
    toggleTheme
  }
}
