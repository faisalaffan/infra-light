import type { H3Event } from 'h3'

export function verifyAdminPin(event: H3Event): boolean {
  const reqPin = getHeader(event, 'x-admin-pin') || (getQuery(event).pin as string)
  const expectedPin = process.env.ADMIN_PIN || '2026'

  if (!reqPin || reqPin !== expectedPin) {
    throw createError({
      statusCode: 401,
      statusMessage: 'Unauthorized: PIN tidak valid atau belum dimasukkan'
    })
  }
  return true
}
