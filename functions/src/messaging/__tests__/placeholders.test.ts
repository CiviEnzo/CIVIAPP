import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { renderTemplate } from '../placeholders';

describe('renderTemplate', () => {
  it('replaces placeholders with provided context', () => {
    const result = renderTemplate(
      'Ciao {{nome}} {{cognome}}, il tuo appuntamento per {{servizio}} è il {{data}} alle {{ora}}.',
      {
        firstName: 'Marta',
        lastName: 'Verdi',
        serviceName: 'Taglio capelli',
        date: '12 ottobre',
        time: '15:00',
      },
    );

    assert.equal(
      result,
      'Ciao Marta Verdi, il tuo appuntamento per Taglio capelli è il 12 ottobre alle 15:00.',
    );
  });

  it('supports alias placeholders and removes missing values', () => {
    const result = renderTemplate(
      'Reminder {{promemoria}} per {{client}} alle {{time}} in {{salon}}',
      {
        reminderOffsetLabel: 'tra 3 ore',
        clientName: 'Giulia',
        time: '18:30',
      },
    );

    assert.equal(result, 'Reminder tra 3 ore per Giulia alle 18:30 in ');
  });
});

