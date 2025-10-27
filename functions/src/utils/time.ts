import { utcToZonedTime } from 'date-fns-tz';

export interface QuietHours {
  /** Hour in 24h format when quiet period starts (inclusive). */
  start: number;
  /** Hour in 24h format when quiet period ends (exclusive). */
  end: number;
}

export const DEFAULT_TIMEZONE = 'Europe/Rome';
export const DEFAULT_QUIET_HOURS: QuietHours = { start: 0, end: 0 };

export function now(timeZone: string = DEFAULT_TIMEZONE): Date {
  return utcToZonedTime(new Date(), timeZone);
}

export function isWithinQuietHours(date: Date, quietHours: QuietHours): boolean {
  const hour = date.getHours();
  if (quietHours.start === quietHours.end) {
    return false;
  }
  if (quietHours.start < quietHours.end) {
    return hour >= quietHours.start && hour < quietHours.end;
  }
  return hour >= quietHours.start || hour < quietHours.end;
}
