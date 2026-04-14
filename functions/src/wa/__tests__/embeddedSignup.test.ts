import assert from 'node:assert/strict'
import { before, test } from 'node:test'
import { getApps, initializeApp } from 'firebase-admin/app'

let helpers: typeof import('../embeddedSignup').__test__

before(async () => {
  if (getApps().length === 0) {
    initializeApp({ projectId: 'demo-test' })
  }
  const embeddedSignup = await import('../embeddedSignup')
  helpers = embeddedSignup.__test__
})

test('parseCodeMethod normalizes SMS and VOICE values', () => {
  assert.equal(helpers.parseCodeMethod('sms'), 'SMS')
  assert.equal(helpers.parseCodeMethod('VOICE'), 'VOICE')
  assert.equal(helpers.parseCodeMethod(null), 'SMS')
})

test('parseSessionState falls back to session_created for unknown values', () => {
  assert.equal(helpers.parseSessionState('ready'), 'ready')
  assert.equal(helpers.parseSessionState('unknown-value'), 'session_created')
})
