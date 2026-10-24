export default defineEventHandler(async (event) => {
  verifyAdminPin(event)

  const cfHeaders = getCloudflareHeaders()
  const zoneId = getCloudflareZoneId()
  const masterRecord = getMasterRecord()
  const homelabUuid = process.env.CLOUDFLARE_HOMELAB_TUNNEL_UUID
  const tencentUuid = process.env.CLOUDFLARE_TENCENT_TUNNEL_UUID

  // 1. Query Cloudflare DNS
  let currentOrigin = 'UNKNOWN'
  let targetContent = 'Record Not Found'
  let proxied = false
  let recordId: string | null = null

  try {
    const cfResp = await fetch(`https://api.cloudflare.com/client/v4/zones/${zoneId}/dns_records?name=${masterRecord}&type=CNAME`, {
      headers: cfHeaders
    })
    const cfData: any = await cfResp.json()

    if (cfData.success && cfData.result && cfData.result[0]) {
      const rec = cfData.result[0]
      recordId = rec.id
      targetContent = rec.content
      proxied = rec.proxied
      if (homelabUuid && targetContent.includes(homelabUuid)) {
        currentOrigin = 'HOMELAB'
      } else if (tencentUuid && targetContent.includes(tencentUuid)) {
        currentOrigin = 'TENCENT'
      }
    }
  } catch (err: any) {
    throw createError({ statusCode: 502, statusMessage: 'Gagal menghubungi Cloudflare API: ' + err.message })
  }

  // 2. Query Tencent CVM Live Status
  let cvm: any = {
    configured: false,
    status: 'UNKNOWN',
    instanceId: process.env.TENCENT_INSTANCE_ID || null,
    region: process.env.TENCENTCLOUD_REGION || 'ap-singapore'
  }

  if (process.env.TENCENTCLOUD_SECRET_ID && process.env.TENCENTCLOUD_SECRET_KEY) {
    cvm.configured = true
    try {
      const queryPayload = process.env.TENCENT_INSTANCE_ID ? { InstanceIds: [process.env.TENCENT_INSTANCE_ID] } : { Limit: 5 }
      const cvmData = await callTencentCvmApi('DescribeInstances', queryPayload)
      const instances = cvmData.Response?.InstanceSet || []
      if (instances.length > 0) {
        const inst = instances[0]
        cvm.status = inst.InstanceState // RUNNING, STOPPED, STARTING, STOPPING
        cvm.instanceId = inst.InstanceId
        cvm.instanceName = inst.InstanceName
        cvm.publicIp = inst.PublicIpAddresses?.[0] || null
        cvm.zone = inst.Placement?.Zone || null
      } else {
        cvm.status = 'NOT_FOUND'
      }
    } catch (e: any) {
      cvm.error = e.message
    }
  }

  // 3. Compute System Health Scenario & Recommendation
  let systemState: 'STANDBY_OPTIMAL' | 'FAILOVER_ACTIVE' | 'COST_WARNING' | 'CRITICAL_MISMATCH' | 'TRANSITIONING' | 'UNKNOWN' = 'UNKNOWN'
  let recommendation = ''

  if (cvm.status === 'STARTING' || cvm.status === 'STOPPING') {
    systemState = 'TRANSITIONING'
    recommendation = cvm.status === 'STARTING'
      ? 'Server cadangan sedang dinyalakan dan menyiapkan data terbaru (sekitar 30 detik)...'
      : 'Server cadangan sedang dimatikan ke mode hemat biaya...'
  } else if (currentOrigin === 'HOMELAB' && cvm.status === 'STOPPED') {
    systemState = 'STANDBY_OPTIMAL'
    recommendation = 'Semua layanan berjalan normal di Server Malang. Server cadangan dalam posisi istirahat (Rp 0).'
  } else if (currentOrigin === 'TENCENT' && cvm.status === 'RUNNING') {
    systemState = 'FAILOVER_ACTIVE'
    recommendation = 'Website saat ini dilayani oleh Server Cadangan Cloud. Kembalikan ke Malang jika kondisi sudah normal.'
  } else if (currentOrigin === 'HOMELAB' && cvm.status === 'RUNNING') {
    systemState = 'COST_WARNING'
    recommendation = 'Website sudah berjalan di Malang, namun Server Cadangan Cloud masih menyala. Matikan agar tidak terkena biaya sewa.'
  } else if (currentOrigin === 'TENCENT' && cvm.status === 'STOPPED') {
    systemState = 'CRITICAL_MISMATCH'
    recommendation = 'Akses mengarah ke Cloud tetapi server cadangan masih mati. Nyalakan server Cloud atau pindahkan kembali ke Malang.'
  }

  return {
    masterRecord,
    currentOrigin,
    targetContent,
    proxied,
    recordId,
    homelabUuid: homelabUuid ? `${homelabUuid.substring(0, 8)}...` : null,
    tencentUuid: tencentUuid ? `${tencentUuid.substring(0, 8)}...` : null,
    cvm,
    systemState,
    recommendation,
    timestamp: new Date().toISOString()
  }
})
