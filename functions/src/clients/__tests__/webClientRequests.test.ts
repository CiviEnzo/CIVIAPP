import assert from 'node:assert/strict';
import test from 'node:test';

import { webClientRequestTestHelpers } from '../webClientRequests';

test('normalizes public request contacts', () => {
  assert.equal(
    webClientRequestTestHelpers.normalizeEmail('  Laura@Example.COM  '),
    'laura@example.com',
  );
  assert.deepEqual(
    webClientRequestTestHelpers.normalizePhone(' +39 333-123 4567 '),
    { display: '+39 333-123 4567', normalized: '393331234567' },
  );
});

test('keeps only configured extra fields and enforces text limits', () => {
  const configured = webClientRequestTestHelpers.configuredExtraFields([
    'profession',
    'notes',
    'unexpected',
  ]);
  const result = webClientRequestTestHelpers.sanitizeExtraData(
    {
      profession: '  Estetista  ',
      notes: 'Richiamare nel pomeriggio',
      address: 'Roma',
      unexpected: 'ignored',
    },
    configured,
  );

  assert.deepEqual(result, {
    profession: 'Estetista',
    notes: 'Richiamare nel pomeriggio',
  });
});

test('rejects malformed email and phone values', () => {
  assert.throws(() => webClientRequestTestHelpers.normalizeEmail('not-an-email'));
  assert.throws(() => webClientRequestTestHelpers.normalizePhone('123'));
});
