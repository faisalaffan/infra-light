export interface LogItem {
  time: string
  tag: 'SWITCH' | 'COMPUTE' | 'OK' | 'ERR' | 'SYS' | 'STATUS'
  message: string
  category: 'all' | 'switch' | 'compute' | 'error' | 'status'
}

export interface StatusResponse {
  masterRecord: string
  currentOrigin: 'HOMELAB' | 'TENCENT' | 'UNKNOWN'
  targetContent: string
  proxied: boolean
  recordId: string | null
  homelabUuid: string | null
  tencentUuid: string | null
  cvm?: {
    configured: boolean
    status: string
    instanceId?: string
    instanceName?: string
    publicIp?: string
    zone?: string
    error?: string
  }
  systemState?: 'STANDBY_OPTIMAL' | 'FAILOVER_ACTIVE' | 'COST_WARNING' | 'CRITICAL_MISMATCH' | 'TRANSITIONING' | 'UNKNOWN'
  recommendation?: string
  timestamp: string
}

export interface ToastItem {
  id: number
  message: string
}

export function useFailover() {
  const currentPin = useState<string>('dr_pin', () => '')
  const authRequired = useState<boolean>('dr_auth_required', () => false)
  const isLoading = useState<boolean>('dr_is_loading', () => false)
  const isRefreshing = useState<boolean>('dr_is_refreshing', () => false)
  const lastUpdated = useState<string>('dr_last_updated', () => '')
  const statusData = useState<StatusResponse | null>('dr_status_data', () => null)
  const logHistory = useState<LogItem[]>('dr_log_history', () => [])
  const toasts = useState<ToastItem[]>('dr_toasts', () => [])
  const initialized = useState<boolean>('dr_initialized', () => false)

  // Modal State
  const confirmModal = useState('dr_confirm_modal', () => ({
    visible: false,
    type: 'switch' as 'switch' | 'compute',
    target: '',
    title: '',
    description: '',
    confirmText: '',
    confirmColor: ''
  }))

  onMounted(() => {
    if (initialized.value) return
    initialized.value = true

    currentPin.value = localStorage.getItem('dr_admin_pin') || ''
    if (!currentPin.value) {
      authRequired.value = true
    } else {
      fetchStatus()
    }
    addLog('SYS', 'Panel kendali siap digunakan.', 'status')
  })

  function showToast(message: string) {
    const id = Date.now() + Math.random()
    toasts.value.push({ id, message })
    setTimeout(() => {
      toasts.value = toasts.value.filter(t => t.id !== id)
    }, 3500)
  }

  function addLog(tag: LogItem['tag'], message: string, category: LogItem['category'] = 'status') {
    const time = new Date().toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit', second: '2-digit' })
    logHistory.value.unshift({ time, tag, message, category })
  }

  function setPin(pin: string) {
    currentPin.value = pin.trim()
    localStorage.setItem('dr_admin_pin', currentPin.value)
    authRequired.value = !currentPin.value
    if (currentPin.value) {
      showToast('Kode akses berhasil disimpan')
      addLog('OK', 'Kode akses administrator diverifikasi.', 'status')
      fetchStatus()
    }
  }

  async function fetchStatus() {
    if (!currentPin.value) {
      authRequired.value = true
      return
    }
    isRefreshing.value = true
    try {
      const res = await $fetch<StatusResponse>('/api/status', {
        headers: { 'X-Admin-Pin': currentPin.value }
      })
      statusData.value = res
      lastUpdated.value = new Date().toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit', second: '2-digit' })
      const originLabel = res.currentOrigin === 'HOMELAB' ? 'Server Malang' : res.currentOrigin === 'TENCENT' ? 'Server Cloud' : res.currentOrigin
      const cvmLabel = res.cvm?.status === 'RUNNING' ? 'Menyala' : res.cvm?.status === 'STOPPED' ? 'Istirahat (Rp 0)' : (res.cvm?.status || '-')
      addLog('STATUS', `Akses: ${originLabel} • Server Cloud: ${cvmLabel}`, 'status')
      authRequired.value = false
    } catch (err: any) {
      if (err.statusCode === 401) {
        authRequired.value = true
        addLog('ERR', 'Kode akses belum sesuai.', 'error')
      } else {
        addLog('ERR', err.statusMessage || err.message, 'error')
        showToast('Gagal memuat status: ' + (err.statusMessage || err.message))
      }
    } finally {
      isRefreshing.value = false
    }
  }

  function openConfirmSwitch(target: 'homelab' | 'tencent') {
    const isTencent = target === 'tencent'
    const cvmStatus = statusData.value?.cvm?.status || 'UNKNOWN'

    if (isTencent) {
      const isStopped = cvmStatus === 'STOPPED'
      confirmModal.value = {
        visible: true,
        type: 'switch',
        target,
        title: 'Pindahkan ke Server Cadangan (Cloud)?',
        description: isStopped
          ? 'Gunakan opsi ini saat listrik atau internet di Malang sedang padam.<br><br>Sistem akan otomatis <b>menyalakan Server Cloud</b>, memuat data cadangan terbaru, dan memindahkan akses website dalam waktu sekitar 30 detik.'
          : 'Akses seluruh website akan langsung diarahkan ke <b>Server Cadangan (Cloud)</b>. Karena server Cloud sudah menyala, perpindahan akan selesai dalam 5–15 detik.',
        confirmText: isStopped ? 'Nyalakan & Pindahkan Sekarang' : 'Pindahkan ke Cloud',
        confirmColor: '#2563eb'
      }
    } else {
      const isRunning = cvmStatus === 'RUNNING'
      confirmModal.value = {
        visible: true,
        type: 'switch',
        target,
        title: 'Kembalikan ke Server Utama (Malang)?',
        description: isRunning
          ? 'Gunakan opsi ini jika listrik dan internet di Malang sudah kembali normal.<br><br>Akses website akan dikembalikan ke Malang, dan <b>Server Cadangan Cloud akan otomatis dimatikan</b> agar tidak dikenakan biaya.'
          : 'Akses seluruh website akan dikembalikan menuju <b>Server Utama di Malang</b>.',
        confirmText: 'Kembalikan ke Malang',
        confirmColor: '#059669'
      }
    }
  }

  function openConfirmCompute(action: 'start' | 'stop') {
    const isStart = action === 'start'
    confirmModal.value = {
      visible: true,
      type: 'compute',
      target: action,
      title: isStart ? 'Nyalakan Server Cadangan?' : 'Matikan Server Cadangan?',
      description: isStart
        ? 'Server Cadangan (Cloud) akan dinyalakan dan menyiapkan data terbaru. Proses ini membutuhkan waktu sekitar 30 detik.'
        : 'Server Cadangan (Cloud) akan diistirahatkan ke mode hemat sehingga tidak ada biaya komputasi yang berjalan.',
      confirmText: isStart ? 'Nyalakan Server' : 'Matikan Server',
      confirmColor: isStart ? '#2563eb' : '#dc2626'
    }
  }

  function closeConfirm() {
    confirmModal.value.visible = false
  }

  async function executeConfirm() {
    const { type, target } = confirmModal.value
    isLoading.value = true

    try {
      if (type === 'switch') {
        const label = target === 'homelab' ? 'Server Utama (Malang)' : 'Server Cadangan (Cloud)'
        addLog('SWITCH', `Memindahkan akses menuju ${label}...`, 'switch')
        const res = await $fetch<{ success: boolean; message: string }>('/api/switch', {
          method: 'POST',
          headers: { 'X-Admin-Pin': currentPin.value },
          body: {
            target,
            autoStartCvm: true,
            autoStopCvm: true
          }
        })
        if (res.success) {
          addLog('OK', res.message, 'switch')
          showToast(res.message)
        }
      } else if (type === 'compute') {
        const actLabel = target === 'start' ? 'Menyalakan' : 'Mematikan'
        addLog('COMPUTE', `${actLabel} Server Cadangan (Cloud)...`, 'compute')
        const res = await $fetch<{ success: boolean; message: string }>('/api/compute', {
          method: 'POST',
          headers: { 'X-Admin-Pin': currentPin.value },
          body: { action: target }
        })
        if (res.success) {
          addLog('OK', res.message, 'compute')
          showToast(target === 'start' ? 'Server Cloud sedang dinyalakan' : 'Server Cloud berhasil dimatikan')
        }
      }
    } catch (err: any) {
      addLog('ERR', err.statusMessage || err.message, 'error')
      showToast('Gagal: ' + (err.statusMessage || err.message))
    } finally {
      isLoading.value = false
      closeConfirm()
      setTimeout(fetchStatus, 2200)
    }
  }

  function clearLogs() {
    logHistory.value = []
    addLog('SYS', 'Riwayat aktivitas dibersihkan.', 'status')
    showToast('Riwayat dibersihkan')
  }

  return {
    currentPin,
    authRequired,
    isLoading,
    isRefreshing,
    lastUpdated,
    statusData,
    logHistory,
    toasts,
    confirmModal,
    setPin,
    fetchStatus,
    openConfirmSwitch,
    openConfirmCompute,
    closeConfirm,
    executeConfirm,
    clearLogs,
    showToast
  }
}
