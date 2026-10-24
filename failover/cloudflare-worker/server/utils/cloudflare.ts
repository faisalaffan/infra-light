export function getCloudflareHeaders(): Record<string, string> {
  const email = process.env.CLOUDFLARE_EMAIL || process.env.GIT_EMAIL || 'faisallionel@gmail.com'
  const apiKey = process.env.CLOUDFLARE_API_KEY
  const apiToken = process.env.CLOUDFLARE_API_TOKEN

  const headers: Record<string, string> = {
    'Content-Type': 'application/json'
  }

  if (apiKey && email) {
    headers['X-Auth-Key'] = apiKey
    headers['X-Auth-Email'] = email
  } else if (apiToken) {
    headers['Authorization'] = `Bearer ${apiToken}`
  }

  return headers
}

export function getCloudflareZoneId(): string {
  return process.env.CLOUDFLARE_ZONE_ID || '6e31dd491d4cdeab97e4e3ec76b61a28'
}

export function getMasterRecord(): string {
  return process.env.CLOUDFLARE_MASTER_ORIGIN_RECORD || `origin.${process.env.FAILOVER_DOMAIN || 'homelab.faisalaffan.com'}`
}
