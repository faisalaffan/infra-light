export default defineEventHandler(async (event) => {
  verifyAdminPin(event)

  const body = await readBody(event).catch(() => ({}))
  const target = ((body?.target || getQuery(event).target || '') as string).toLowerCase()

  const cfHeaders = getCloudflareHeaders()
  const zoneId = getCloudflareZoneId()
  const masterRecord = getMasterRecord()
  const homelabUuid = process.env.CLOUDFLARE_HOMELAB_TUNNEL_UUID
  const tencentUuid = process.env.CLOUDFLARE_TENCENT_TUNNEL_UUID

  let newContent = ''
  let autoStartMessage = ''

  if (target === 'homelab') {
    if (!homelabUuid) throw createError({ statusCode: 400, statusMessage: 'CLOUDFLARE_HOMELAB_TUNNEL_UUID belum dikonfigurasi' })
    newContent = `${homelabUuid}.cfargotunnel.com`
  } else if (target === 'tencent') {
    if (!tencentUuid) throw createError({ statusCode: 400, statusMessage: 'CLOUDFLARE_TENCENT_TUNNEL_UUID belum dikonfigurasi' })
    newContent = `${tencentUuid}.cfargotunnel.com`

    // Auto-Start CVM if it is currently STOPPED (1-Click Smart Failover)
    const autoStart = body?.autoStartCvm !== false
    if (autoStart && process.env.TENCENTCLOUD_SECRET_ID && process.env.TENCENTCLOUD_SECRET_KEY) {
      try {
        const queryPayload = process.env.TENCENT_INSTANCE_ID ? { InstanceIds: [process.env.TENCENT_INSTANCE_ID] } : { Limit: 5 }
        const cvmData = await callTencentCvmApi('DescribeInstances', queryPayload)
        const instances = cvmData.Response?.InstanceSet || []
        if (instances.length > 0) {
          const inst = instances[0]
          if (inst.InstanceState === 'STOPPED') {
            await callTencentCvmApi('StartInstances', { InstanceIds: [inst.InstanceId] })
            autoStartMessage = ` CVM (${inst.InstanceId}) otomatis dinyalakan dan sedang memicu restore delta dari B2.`
          }
        }
      } catch (err: any) {
        console.error('Failed to auto-start CVM during switch:', err)
      }
    }
  } else {
    throw createError({ statusCode: 400, statusMessage: "Target tidak valid. Tentukan 'homelab' atau 'tencent'" })
  }

  // Check existing DNS record
  const cfGet = await fetch(`https://api.cloudflare.com/client/v4/zones/${zoneId}/dns_records?name=${masterRecord}&type=CNAME`, {
    headers: cfHeaders
  })
  const getJson: any = await cfGet.json()
  const existing = getJson.result && getJson.result[0]

  let updateResp: Response
  if (existing) {
    updateResp = await fetch(`https://api.cloudflare.com/client/v4/zones/${zoneId}/dns_records/${existing.id}`, {
      method: 'PATCH',
      headers: cfHeaders,
      body: JSON.stringify({
        type: 'CNAME',
        name: masterRecord,
        content: newContent,
        proxied: true,
        comment: `Switched via DR Control Center (${target})`
      })
    })
  } else {
    updateResp = await fetch(`https://api.cloudflare.com/client/v4/zones/${zoneId}/dns_records`, {
      method: 'POST',
      headers: cfHeaders,
      body: JSON.stringify({
        type: 'CNAME',
        name: masterRecord,
        content: newContent,
        ttl: 1,
        proxied: true,
        comment: `Created via DR Control Center (${target})`
      })
    })
  }

  const updateJson: any = await updateResp.json()
  if (!updateJson.success) {
    throw createError({
      statusCode: 502,
      statusMessage: 'Gagal memperbarui DNS di Cloudflare: ' + JSON.stringify(updateJson.errors)
    })
  }

  return {
    success: true,
    message: `Lalu lintas berhasil dialihkan ke ${target.toUpperCase()}.${autoStartMessage}`,
    targetOrigin: target.toUpperCase(),
    newContent,
    autoStartTriggered: !!autoStartMessage,
    timestamp: new Date().toISOString()
  }
})
