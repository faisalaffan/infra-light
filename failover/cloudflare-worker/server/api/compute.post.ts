export default defineEventHandler(async (event) => {
  verifyAdminPin(event)

  const body = await readBody(event).catch(() => ({}))
  const action = ((body?.action || getQuery(event).action || '') as string).toLowerCase()

  if (!['start', 'stop'].includes(action)) {
    throw createError({ statusCode: 400, statusMessage: "Aksi tidak valid. Gunakan 'start' atau 'stop'" })
  }

  // Priority 1: Direct Tencent Cloud API ($0 compute stopped mode guaranteed)
  if (process.env.TENCENTCLOUD_SECRET_ID && process.env.TENCENTCLOUD_SECRET_KEY) {
    let instanceId = process.env.TENCENT_INSTANCE_ID

    if (!instanceId) {
      const listRes = await callTencentCvmApi('DescribeInstances', { Limit: 5 })
      const insts = listRes.Response?.InstanceSet || []
      if (insts.length === 0) {
        throw createError({ statusCode: 404, statusMessage: 'Instance Tencent CVM tidak ditemukan' })
      }
      instanceId = insts[0].InstanceId
    }

    if (action === 'start') {
      const startRes = await callTencentCvmApi('StartInstances', { InstanceIds: [instanceId] })
      if (startRes.Response?.Error) {
        throw createError({ statusCode: 502, statusMessage: startRes.Response.Error.Message })
      }
      return {
        success: true,
        method: 'direct_api',
        message: `Tencent CVM ${instanceId} sedang dinyalakan (~30s hingga k3s siap)...`,
        instanceId,
        action: 'START',
        timestamp: new Date().toISOString()
      }
    } else if (action === 'stop') {
      const stopRes = await callTencentCvmApi('StopInstances', {
        InstanceIds: [instanceId],
        StopType: 'SOFT_FIRST',
        StoppedMode: 'STOP_CHARGING'
      })
      if (stopRes.Response?.Error) {
        throw createError({ statusCode: 502, statusMessage: stopRes.Response.Error.Message })
      }
      return {
        success: true,
        method: 'direct_api',
        message: `Tencent CVM ${instanceId} dimatikan dengan STOP_CHARGING ($0 biaya komputasi)...`,
        instanceId,
        action: 'STOP',
        timestamp: new Date().toISOString()
      }
    }
  }

  // Priority 2: GitHub Actions Workflow Dispatch fallback
  const githubPat = process.env.GITHUB_PAT
  const githubRepo = process.env.GITHUB_REPO || 'faisalaffan/infra-light'

  if (githubPat) {
    const ghResp = await fetch(`https://api.github.com/repos/${githubRepo}/actions/workflows/dr-failover.yml/dispatches`, {
      method: 'POST',
      headers: {
        'Accept': 'application/vnd.github.v3+json',
        'Authorization': `Bearer ${githubPat}`,
        'User-Agent': 'DR-Failover-Nuxt-Controller'
      },
      body: JSON.stringify({
        ref: process.env.GIT_BRANCH || 'dev',
        inputs: {
          action: action,
          environment: 'prod',
          provider: 'tencent'
        }
      })
    })

    if (ghResp.status === 204) {
      return {
        success: true,
        method: 'github_actions',
        message: `GitHub Action workflow_dispatch terkirim: ${action.toUpperCase()} Tencent CVM`,
        action,
        repo: githubRepo,
        timestamp: new Date().toISOString()
      }
    } else {
      const errDetail = await ghResp.text()
      throw createError({ statusCode: 502, statusMessage: 'Gagal memicu GitHub Action: ' + errDetail })
    }
  }

  throw createError({
    statusCode: 500,
    statusMessage: 'Kredensial Tencent Cloud API (TENCENTCLOUD_SECRET_ID/KEY) maupun GITHUB_PAT belum dikonfigurasi di secrets'
  })
})
