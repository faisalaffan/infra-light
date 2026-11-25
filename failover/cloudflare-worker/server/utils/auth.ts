import { timingSafeEqual } from 'node:crypto'
import type { H3Event } from 'h3'

function safeEqual(a: string, b: string): boolean {
  const bufA = Buffer.from(a, 'utf8')
  const bufB = Buffer.from(b, 'utf8')
  if (bufA.length !== bufB.length) {
    return false
  }
  return timingSafeEqual(bufA, bufB)
}

export function verifyAdminPin(event: H3Event): boolean {
  const expectedPin = process.env.ADMIN_PIN
  if (!expectedPin || expectedPin.length < 16) {
    throw createError({
      statusCode: 500,
      statusMessage: 'Server misconfigured: ADMIN_PIN secret is not properly configured'
    })
  }

  // Only accept token from header — never from URL query parameters (prevents log/referrer leakage)
  const reqPin = getHeader(event, 'x-admin-pin')
  if (!reqPin || !safeEqual(reqPin, expectedPin)) {
    throw createError({
      statusCode: 401,
      statusMessage: 'Unauthorized: Token tidak valid atau belum dimasukkan'
    })
  }
  return true
}
