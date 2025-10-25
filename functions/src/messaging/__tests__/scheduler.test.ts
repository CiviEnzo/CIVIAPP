import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import type { DocumentData } from 'firebase-admin/firestore';

import {
  formatReminderOffsetLabel,
  normalizeReminderOffsets,
  parseReminderSettingsDoc,
} from '../reminder_settings';

describe('parseReminderSettingsDoc', () => {
  it('uses explicit offsets when provided', () => {
    const doc = parseReminderSettingsDoc('salon-explicit', {
      salonId: 'salon-explicit',
      appointmentOffsetsMinutes: [180, 60, 180, 1440],
      birthdayEnabled: false,
    } as DocumentData);

    assert.deepEqual(doc.appointmentOffsetsMinutes, [60, 180, 1440]);
    assert.equal(doc.birthdayEnabled, false);
  });

  it('falls back to legacy toggles when explicit offsets are missing', () => {
    const doc = parseReminderSettingsDoc('salon-legacy', {
      salonId: 'salon-legacy',
      dayBeforeEnabled: true,
      threeHoursEnabled: false,
      oneHourEnabled: true,
    } as DocumentData);

    assert.deepEqual(doc.appointmentOffsetsMinutes, [60, 1440]);
    assert.equal(doc.birthdayEnabled, true);
  });

  it('returns an empty list when all legacy toggles are disabled', () => {
    const doc = parseReminderSettingsDoc('salon-empty', {
      salonId: 'salon-empty',
      dayBeforeEnabled: false,
      threeHoursEnabled: false,
      oneHourEnabled: false,
    } as DocumentData);

    assert.deepEqual(doc.appointmentOffsetsMinutes, []);
  });

  it('uses the document id when salonId is missing or invalid', () => {
    const doc = parseReminderSettingsDoc('salon-fallback', undefined);

    assert.equal(doc.salonId, 'salon-fallback');
    assert.deepEqual(doc.appointmentOffsetsMinutes, []);
  });
});

describe('normalizeReminderOffsets', () => {
  it('filters invalid values and sorts ascending', () => {
    const result = normalizeReminderOffsets([1440, 15, 5, 720, 1440, 20000]);

    assert.deepEqual(result, [15, 720, 1440]);
  });
});

describe('formatReminderOffsetLabel', () => {
  it('formats hour-based offsets', () => {
    assert.equal(formatReminderOffsetLabel(60), 'tra 1 ora');
    assert.equal(formatReminderOffsetLabel(180), 'tra 3 ore');
  });

  it('formats mixed durations', () => {
    assert.equal(
      formatReminderOffsetLabel(90),
      'tra 1 ora e 30 minuti',
    );
    assert.equal(
      formatReminderOffsetLabel(3 * 1440 + 120),
      'tra 3 giorni e 2 ore',
    );
  });

  it('handles minute-only durations', () => {
    assert.equal(formatReminderOffsetLabel(45), 'tra 45 minuti');
  });
});
