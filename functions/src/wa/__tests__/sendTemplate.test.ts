import assert from 'node:assert/strict'
import { before, test } from 'node:test'
import { getApps, initializeApp } from 'firebase-admin/app'

let helpers: typeof import('../sendTemplate').__test__

before(async () => {
  if (getApps().length === 0) {
    initializeApp({ projectId: 'demo-test' })
  }
  const sendTemplate = await import('../sendTemplate')
  helpers = sendTemplate.__test__
})

test('mapSendTemplateError explains account-not-registered failures', () => {
  const error = {
    isAxiosError: true,
    response: {
      status: 400,
      data: {
        error: {
          code: 133010,
          message: '(#133010) Account not registered',
          type: 'OAuthException',
        },
      },
    },
  }

  const mapped = helpers.mapSendTemplateError({
    salonId: 'salon-1',
    phoneNumberId: '1097976850056204',
    error,
  })

  assert.equal(mapped instanceof Error, true)
  assert.match(mapped?.message ?? '', /1097976850056204/)
  assert.match(mapped?.message ?? '', /Account not registered/)
  assert.match(mapped?.message ?? '', /old\/unregistered phone number ID/)
})
