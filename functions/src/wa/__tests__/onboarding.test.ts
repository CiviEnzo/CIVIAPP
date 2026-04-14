import assert from 'node:assert/strict'
import { before, test } from 'node:test'
import { getApps, initializeApp } from 'firebase-admin/app'

let helpers: typeof import('../onboarding').__test__

before(async () => {
  if (getApps().length === 0) {
    initializeApp({ projectId: 'demo-test' })
  }
  const onboarding = await import('../onboarding')
  helpers = onboarding.__test__
})

test('buildLegacyReconnectPayload marks salons for forced manual reconnect', () => {
  const payload = helpers.buildLegacyReconnectPayload()

  assert.equal(payload.connectionMethod, 'legacy_oauth')
  assert.equal(payload.requiresReconnect, true)
  assert.equal(payload.onboardingStatus, 'reconnect_required')
  assert.equal(payload.registrationStatus, 'error')
  assert.match(String(payload.lastOnboardingErrorMessage), /setup manuale/)
})
