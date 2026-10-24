/**
 * Tencent Cloud TC3-HMAC-SHA256 Helper (Web Crypto API)
 */
async function sha256Hex(str: string): Promise<string> {
  const enc = new TextEncoder()
  const hash = await crypto.subtle.digest('SHA-256', enc.encode(str))
  return Array.from(new Uint8Array(hash))
    .map(b => b.toString(16).padStart(2, '0'))
    .join('')
}

async function hmacRaw(keyBufferOrCryptoKey: string | CryptoKey | ArrayBuffer, dataStr: string): Promise<ArrayBuffer> {
  const enc = new TextEncoder()
  let cryptoKey: CryptoKey
  if (keyBufferOrCryptoKey instanceof CryptoKey) {
    cryptoKey = keyBufferOrCryptoKey
  } else {
    cryptoKey = await crypto.subtle.importKey(
      'raw',
      typeof keyBufferOrCryptoKey === 'string' ? enc.encode(keyBufferOrCryptoKey) : keyBufferOrCryptoKey,
      { name: 'HMAC', hash: 'SHA-256' },
      false,
      ['sign']
    )
  }
  return await crypto.subtle.sign('HMAC', cryptoKey, enc.encode(dataStr))
}

async function getTencentSigningKey(secretKey: string, date: string, service: string): Promise<ArrayBuffer> {
  const kDate = await hmacRaw('TC3' + secretKey, date)
  const kService = await hmacRaw(kDate, service)
  const kSigning = await hmacRaw(kService, 'tc3_request')
  return kSigning
}

async function hmacHex(keyBuffer: ArrayBuffer, dataStr: string): Promise<string> {
  const sigBuffer = await hmacRaw(keyBuffer, dataStr)
  return Array.from(new Uint8Array(sigBuffer))
    .map(b => b.toString(16).padStart(2, '0'))
    .join('')
}

export async function callTencentCvmApi(
  action: string,
  payload: Record<string, any> = {}
): Promise<any> {
  const secretId = process.env.TENCENTCLOUD_SECRET_ID
  const secretKey = process.env.TENCENTCLOUD_SECRET_KEY
  const region = process.env.TENCENTCLOUD_REGION || 'ap-singapore'

  if (!secretId || !secretKey) {
    throw new Error('TENCENTCLOUD_SECRET_ID and TENCENTCLOUD_SECRET_KEY must be configured in secrets')
  }

  const service = 'cvm'
  const host = 'cvm.tencentcloudapi.com'
  const version = '2017-03-12'
  const algorithm = 'TC3-HMAC-SHA256'
  const payloadStr = JSON.stringify(payload)

  const timestamp = Math.floor(Date.now() / 1000)
  const date = new Date(timestamp * 1000).toISOString().slice(0, 10)

  const httpRequestMethod = 'POST'
  const canonicalUri = '/'
  const canonicalQuerystring = ''
  const canonicalHeaders = `content-type:application/json; charset=utf-8\nhost:${host}\nx-tc-action:${action.toLowerCase()}\n`
  const signedHeaders = 'content-type;host;x-tc-action'
  const hashedRequestPayload = await sha256Hex(payloadStr)

  const canonicalRequest = `${httpRequestMethod}\n${canonicalUri}\n${canonicalQuerystring}\n${canonicalHeaders}\n${signedHeaders}\n${hashedRequestPayload}`
  const credentialScope = `${date}/${service}/tc3_request`
  const hashedCanonicalRequest = await sha256Hex(canonicalRequest)
  const stringToSign = `${algorithm}\n${timestamp}\n${credentialScope}\n${hashedCanonicalRequest}`

  const secretSigning = await getTencentSigningKey(secretKey, date, service)
  const signature = await hmacHex(secretSigning, stringToSign)

  const authorization = `${algorithm} Credential=${secretId}/${credentialScope}, SignedHeaders=${signedHeaders}, Signature=${signature}`

  const headers = {
    'Authorization': authorization,
    'Content-Type': 'application/json; charset=utf-8',
    'Host': host,
    'X-TC-Action': action,
    'X-TC-Timestamp': String(timestamp),
    'X-TC-Version': version,
    'X-TC-Region': region
  }

  const resp = await fetch(`https://${host}`, {
    method: 'POST',
    headers,
    body: payloadStr
  })

  return await resp.json()
}
