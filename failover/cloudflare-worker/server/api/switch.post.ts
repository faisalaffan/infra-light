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
  if (target === 'homelab') {
    if (!homelabUuid) throw createError({ statusCode: 400, statusMessage: 'CLOUDFLARE_HOMELAB_TUNNEL_UUID belum dikonfigurasi' })
    newContent = `${homelabUuid}.cfargotunnel.com`
  } else if (target === 'tencent') {
    if (!tencentUuid) throw createError({ statusCode: 400, statusMessage: 'CLOUDFLARE_TENCENT_TUNNEL_UUID belum dikonfigurasi' })
    newContent = `${tencentUuid}.cfargotunnel.com`
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
    message: `Lalu lintas berhasil dialihkan ke ${target.toUpperCase()}`,
    targetOrigin: target.toUpperCase(),
    newContent,
    timestamp: new Date().toISOString()
  }
})
