import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { buildWhatsappTemplateComponents } from '../whatsapp_templates';

describe('buildWhatsappTemplateComponents', () => {
  it('builds body and header components from ordered bindings', () => {
    const result = buildWhatsappTemplateComponents({
      body: 'Buon compleanno {{firstName}} da {{salonName}}',
      bodyPlaceholderOrder: ['firstName', 'salonName'],
      headerBindings: ['salonName'],
      headerFormat: 'TEXT',
      resolveValue: (placeholder) => {
        switch (placeholder) {
          case 'firstName':
            return 'Giulia';
          case 'salonName':
            return 'You Book';
          default:
            return '';
        }
      },
    });

    assert.deepEqual(result.unresolvedPlaceholders, []);
    assert.deepEqual(result.components, [
      {
        type: 'header',
        parameters: [{ type: 'text', text: 'You Book' }],
      },
      {
        type: 'body',
        parameters: [
          { type: 'text', text: 'Giulia' },
          { type: 'text', text: 'You Book' },
        ],
      },
    ]);
  });

  it('reports unresolved placeholders and invalid image headers', () => {
    const result = buildWhatsappTemplateComponents({
      body: 'Buon compleanno {{firstName}}',
      headerBindings: ['headerImage'],
      headerFormat: 'IMAGE',
      resolveValue: (placeholder) =>
        placeholder == 'headerImage' ? 'not-a-url' : '',
    });

    assert.deepEqual(result.components, [
      {
        type: 'body',
        parameters: [{ type: 'text', text: '' }],
      },
    ]);
    assert.deepEqual(result.unresolvedPlaceholders, ['headerImage', 'firstName']);
  });
});
