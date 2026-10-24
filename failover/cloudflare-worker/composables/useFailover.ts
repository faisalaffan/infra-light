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
  timestamp: string
}

export interface ToastItem {
  id: number
  message: string
}

export function useFailover() {
  const currentPin = ref('')
  const authRequired = ref(false)
  const isLoading = ref(false)
  const isRefreshing = ref(false)
  const lastUpdated = ref('')
  const statusData = ref<StatusResponse | null>(null)
  const logHistory = ref<LogItem[]>([])
  const toasts = ref<ToastItem[]>([])

  // Modal State
  const confirmModal = ref({
    visible: false,
    type: 'switch' as 'switch' | 'compute',
    target: '',
    title: '',
    description: '',
    confirmText: '',
    confirmColor: ''
  })

  onMounted(() => {
    currentPin.value = localStorage.getItem('dr_admin_pin') || ''
    if (!currentPin.value) {
      authRequired.value = true
    }
    addLog('SYS', 'Pusat Kendali Failover siap beroperasi.', 'status')
    fetchStatus()
  })

  function showToast(message: string) {
    const id = Date.now()
    toasts.value.push({ id, message })
    setTimeout(() => {
      toasts.value = toasts.value.filter(t => t.id !== id)
    }, 3500)
  }

  function addLog(tag: LogItem['tag'], message: string, category: LogItem['category'] = 'status') {
    const time = new Date().toLocaleTimeString()
    logHistory.value.push({ time, tag, message, category })
  }

  function setPin(pin: string) {
    currentPin.value = pin.trim()
    localStorage.setItem('dr_admin_pin', currentPin.value)
    authRequired.value = !currentPin.value
    showToast('🔒 PIN Berhasil Disimpan')
    addLog('OK', 'Kunci akses PIN administrator tersimpan.', 'status')
    fetchStatus()
  }

  async function fetchStatus() {
    isRefreshing.value = true
    try {
      const res = await $fetch<StatusResponse>('/api/status', {
        headers: { 'X-Admin-Pin': currentPin.value }
      })
      statusData.value = res
      lastUpdated.value = new Date().toLocaleTimeString()
      addLog('STATUS', `Routing: ${res.currentOrigin} | CVM: ${res.cvm?.status || 'N/A'}`, 'status')
      authRequired.value = false
    } catch (err: any) {
      if (err.statusCode === 401) {
        authRequired.value = true
        addLog('ERR', 'PIN otorisasi diperlukan atau salah.', 'error')
      } else {
        addLog('ERR', err.statusMessage || err.message, 'error')
        showToast('❌ Error: ' + (err.statusMessage || err.message))
      }
    } finally {
      isRefreshing.value = false
    }
  }

  function openConfirmSwitch(target: 'homelab' | 'tencent') {
    const isTencent = target === 'tencent'
    confirmModal.value = {
      visible: true,
      type: 'switch',
      target,
      title: isTencent ? 'Alihkan Traffic ke Cloud Standby?' : 'Kembalikan Traffic ke Server Malang?',
      description: isTencent
        ? 'Anda akan mengalihkan <b>SEMUA 29 subdomain</b> website & API menuju <b>Tencent Cloud Standby (Singapore)</b>.<br><br>Gunakan langkah ini jika Server Malang mati lampu atau internet padam. Perubahan efektif di Cloudflare dalam 5-15 detik.'
        : 'Anda akan mengembalikan <b>SEMUA subdomain</b> menuju <b>Server Utama Malang (Homelab)</b>.<br><br>Gunakan langkah ini setelah Server Malang sudah online normal kembali.',
      confirmText: isTencent ? 'Ya, Alihkan ke Cloud Standby' : 'Ya, Kembalikan ke Malang',
      confirmColor: isTencent ? 'linear-gradient(135deg, #0284c7 0%, #0369a1 100%)' : 'linear-gradient(135deg, #059669 0%, #047857 100%)'
    }
  }

  function openConfirmCompute(action: 'start' | 'stop') {
    const isStart = action === 'start'
    confirmModal.value = {
      visible: true,
      type: 'compute',
      target: action,
      title: isStart ? 'Nyalakan Server Cloud Standby?' : 'Matikan Server Cloud Standby ($0)?',
      description: isStart
        ? 'Server Cloud Standby (Tencent CVM) akan dinyalakan. Butuh waktu sekitar <b>30 detik</b> sampai K3s dan seluruh service siap melayani traffic.'
        : 'Server Cloud Standby akan dimatikan dengan mode <b>STOP_CHARGING</b>. Komputasi dihentikan dan <b>biaya tagihan menjadi $0</b>.',
      confirmText: isStart ? 'Ya, Nyalakan Server' : 'Ya, Matikan Server ($0)',
      confirmColor: isStart ? '#3b82f6' : '#ef4444'
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
        addLog('SWITCH', `Mengalihkan seluruh traffic menuju ${target.toUpperCase()}...`, 'switch')
        const res = await $fetch<{ success: boolean; message: string }>('/api/switch', {
          method: 'POST',
          headers: { 'X-Admin-Pin': currentPin.value },
          body: { target }
        })
        if (res.success) {
          addLog('OK', `Berhasil switch ke ${target.toUpperCase()}!`, 'switch')
          showToast(`✅ Sukses! Seluruh traffic dialihkan ke ${target.toUpperCase()}.`)
        }
      } else if (type === 'compute') {
        addLog('COMPUTE', `Mengirim perintah ${target.toUpperCase()} CVM ke Tencent Cloud...`, 'compute')
        const res = await $fetch<{ success: boolean; message: string }>('/api/compute', {
          method: 'POST',
          headers: { 'X-Admin-Pin': currentPin.value },
          body: { action: target }
        })
        if (res.success) {
          addLog('OK', res.message, 'compute')
          showToast(`✔ Perintah ${target.toUpperCase()} CVM terkirim!`)
        }
      }
    } catch (err: any) {
      addLog('ERR', err.statusMessage || err.message, 'error')
      showToast('❌ Gagal: ' + (err.statusMessage || err.message))
    } finally {
      isLoading.value = false
      closeConfirm()
      setTimeout(fetchStatus, 2500)
    }
  }

  function clearLogs() {
    logHistory.value = []
    addLog('SYS', 'Tampilan log dibersihkan.', 'status')
    showToast('Tampilan log dibersihkan')
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
