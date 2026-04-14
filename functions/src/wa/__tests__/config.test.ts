import assert from 'node:assert/strict'
import { before, test } from 'node:test'
import { getApps, initializeApp } from 'firebase-admin/app'

let helpers: typeof import('../config').__test__

before(async () => {
  if (getApps().length === 0) {
    initializeApp({ projectId: 'demo-test' })
  }
  const config = await import('../config')
  helpers = config.__test__
})

test('buildRuntimeConfig infers legacy salons as reconnect required', () => {
  const config = helpers.buildRuntimeConfig('salon-1', {
    tokenSecretId: 'projects/demo/secrets/legacy-token',
    businessId: 'business-1',
    wabaId: 'waba-1',
    phoneNumberId: 'phone-1',
  })

  assert.equal(config?.connectionMethod, 'legacy_oauth')
  assert.equal(config?.requiresReconnect, true)
  assert.equal(config?.registrationStatus, 'error')
})

test('assertRuntimeReady rejects salons that still require reconnect', () => {
  assert.throws(() => {
    helpers.assertRuntimeReady({
      salonId: 'salon-1',
      mode: 'own',
      businessId: 'business-1',
      wabaId: 'waba-1',
      phoneNumberId: 'phone-1',
      connectionMethod: 'legacy_oauth',
      onboardingStatus: 'reconnect_required',
      registrationStatus: 'error',
      requiresReconnect: true,
    })
  }, /riconfigurato manualmente/)
})
