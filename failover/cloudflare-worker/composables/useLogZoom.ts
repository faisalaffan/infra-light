export function useLogZoom() {
  const fontSize = ref(12)
  const isFullscreen = ref(false)

  onMounted(() => {
    const saved = localStorage.getItem('dr_log_font_size')
    if (saved) {
      fontSize.value = parseInt(saved, 10) || 12
    }
  })

  function zoom(delta: number) {
    fontSize.value = Math.max(10, Math.min(22, fontSize.value + delta))
    localStorage.setItem('dr_log_font_size', String(fontSize.value))
  }

  function toggleFullscreen() {
    isFullscreen.value = !isFullscreen.value
  }

  return {
    fontSize,
    isFullscreen,
    zoom,
    toggleFullscreen
  }
}
