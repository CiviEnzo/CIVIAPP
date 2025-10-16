import type { DocumentData } from 'firebase-admin/firestore';

export interface ReminderSettingsData {
  salonId: string;
  appointmentOffsetsMinutes: number[];
  birthdayEnabled: boolean;
}

export const MIN_REMINDER_OFFSET_MINUTES = 15;
export const MAX_REMINDER_OFFSET_MINUTES = 10080;
export const DEFAULT_REMINDER_OFFSETS_MINUTES = [1440, 180, 60];

export function normalizeReminderOffsets(value: unknown): number[] {
  if (!Array.isArray(value)) {
    return [];
  }
  const offsets = new Set<number>();
  for (const item of value) {
    const parsed =
      typeof item === 'number'
        ? item
        : typeof item === 'string'
          ? Number.parseInt(item, 10)
          : Number.NaN;
    if (!Number.isFinite(parsed)) {
      continue;
    }
    const minutes = Math.trunc(parsed);
    if (
      minutes < MIN_REMINDER_OFFSET_MINUTES ||
      minutes > MAX_REMINDER_OFFSET_MINUTES
    ) {
      continue;
    }
    offsets.add(minutes);
  }
  return Array.from(offsets).sort((a, b) => a - b);
}

function buildLegacyReminderOffsets(
  data: Record<string, unknown>,
): number[] {
  const offsets = new Set<number>();
  if (data.dayBeforeEnabled !== false) {
    offsets.add(1440);
  }
  if (data.threeHoursEnabled !== false) {
    offsets.add(180);
  }
  if (data.oneHourEnabled !== false) {
    offsets.add(60);
  }
  return Array.from(offsets).sort((a, b) => a - b);
}

export function parseReminderSettingsDoc(
  docId: string,
  rawData: DocumentData | undefined,
): ReminderSettingsData {
  const data = (rawData ?? {}) as Record<string, unknown>;
  const hasExplicitOffsets = Object.prototype.hasOwnProperty.call(
    data,
    'appointmentOffsetsMinutes',
  );
  const explicitOffsets = normalizeReminderOffsets(
    (data as { appointmentOffsetsMinutes?: unknown })
      .appointmentOffsetsMinutes,
  );
  const legacyOffsets = buildLegacyReminderOffsets(data);
  const appointmentOffsetsMinutes = hasExplicitOffsets
    ? explicitOffsets
    : legacyOffsets;
  const salonIdRaw = data.salonId;

  return {
    salonId:
      typeof salonIdRaw === 'string' && salonIdRaw.trim().length > 0
        ? salonIdRaw
        : docId,
    appointmentOffsetsMinutes,
    birthdayEnabled: data.birthdayEnabled !== false,
  };
}

export function formatReminderOffsetLabel(minutes: number): string {
  if (minutes <= 0) {
    return 'tra pochi minuti';
  }
  const days = Math.floor(minutes / 1440);
  const hours = Math.floor((minutes % 1440) / 60);
  const mins = minutes % 60;
  const parts: string[] = [];
  if (days > 0) {
    parts.push(days === 1 ? '1 giorno' : `${days} giorni`);
  }
  if (hours > 0) {
    parts.push(hours === 1 ? '1 ora' : `${hours} ore`);
  }
  if (mins > 0) {
    parts.push(`${mins} minuti`);
  }
  if (parts.length === 0) {
    return 'tra pochi minuti';
  }
  if (parts.length === 1) {
    return `tra ${parts[0]}`;
  }
  const last = parts[parts.length - 1];
  const initial = parts.slice(0, -1);
  return `tra ${initial.join(', ')} e ${last}`;
}
