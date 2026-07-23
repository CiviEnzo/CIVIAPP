import assert from 'node:assert/strict';
import test from 'node:test';

import { publicSalonSyncTestHelpers } from '../publicSalonSync';

const approvedTemplates = [
  'editorialBeauty',
  'minimalGlow',
  'studioPop',
  'botanicalRitual',
] as const;

test('keeps every approved promotion landing template', () => {
  for (const templateId of approvedTemplates) {
    const landing = publicSalonSyncTestHelpers.sanitizePromotionLanding(
      { templateId },
      'Rituale luminosita',
    );

    assert.equal(landing.templateId, templateId);
  }
});

test('falls back to Editorial Beauty for unknown templates', () => {
  const landing = publicSalonSyncTestHelpers.sanitizePromotionLanding(
    { templateId: 'unknown-template' },
    'Rituale luminosita',
  );

  assert.equal(landing.templateId, 'editorialBeauty');
});
