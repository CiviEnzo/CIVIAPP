import { getMessaging } from 'firebase-admin/messaging';
import { getFunctions } from 'firebase-admin/functions';
import type {
  DocumentData,
  DocumentReference,
  DocumentSnapshot,
  Timestamp,
} from 'firebase-admin/firestore';
import * as logger from 'firebase-functions/logger';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import {
  onTaskDispatched,
  type Request as TaskRequest,
} from 'firebase-functions/v2/tasks';
import { onSchedule } from 'firebase-functions/v2/scheduler';

import {
  db,
  serverTimestamp,
  Timestamp as AdminTimestamp,
} from '../utils/firestore';

const REGION = 'europe-west1';
const MAX_AHEAD_MS = 30 * 24 * 60 * 60 * 1000;
const MAX_AHEAD_MINUTES = MAX_AHEAD_MS / 60000;
const CACHE_TTL_MS = 5 * 60 * 1000;

type ReminderKind = string;

interface ReminderOffsetConfig {
  id: ReminderKind;
  minutesBefore: number;
  active: boolean;
  title?: string;
  bodyTemplate?: string;
}

interface ReminderPayload {
  salonId: string;
  appointmentId: string;
  docPath: string;
  offsetId: ReminderKind | 'CHECKPOINT';
}

const MIN_OFFSET_MINUTES = 15;
const MAX_OFFSETS_COUNT = 5;

const offsetsCache = new Map<
  string,
  { expiresAt: number; value: ReminderOffsetConfig[] }
>();

const reminderQueue = getFunctions().taskQueue<ReminderPayload>(
  `locations/${REGION}/functions/processAppointmentReminderTask`,
);

function clampMinutes(value: number): number {
  if (Number.isNaN(value)) {
    return MIN_OFFSET_MINUTES;
  }
  if (value < MIN_OFFSET_MINUTES) {
    return MIN_OFFSET_MINUTES;
  }
  if (value > MAX_AHEAD_MINUTES) {
    return MAX_AHEAD_MINUTES;
  }
  return value;
}

function normalizeSlug(value: unknown, fallback: string): string {
  if (typeof value !== 'string') {
    return fallback;
  }
  const sanitized = value.trim().toUpperCase().replace(/[^A-Z0-9_-]/g, '_');
  return sanitized.length > 0 ? sanitized.replace(/_+/g, '_') : fallback;
}

function parseMinutesList(value: unknown): number[] {
  if (!Array.isArray(value)) {
    return [];
  }
  const result = new Set<number>();
  for (const item of value) {
    if (typeof item === 'number' && Number.isFinite(item)) {
      result.add(clampMinutes(Math.trunc(item)));
    } else if (typeof item === 'string') {
      const parsed = Number.parseInt(item, 10);
      if (Number.isFinite(parsed)) {
        result.add(clampMinutes(parsed));
      }
    }
  }
  return Array.from(result).sort((a, b) => a - b);
}

async function loadReminderOffsets(
  salonId: string,
): Promise<ReminderOffsetConfig[]> {
  const cached = offsetsCache.get(salonId);
  const now = Date.now();
  if (cached && cached.expiresAt > now) {
    return cached.value;
  }

  const docRef = db
    .collection('salons')
    .doc(salonId)
    .collection('settings')
    .doc('reminders');
  const snapshot = await docRef.get();
  let data = (snapshot.data() ?? {}) as Record<string, unknown>;

  function buildOffsets(
    source: Record<string, unknown>,
  ): ReminderOffsetConfig[] {
    const sanitized: ReminderOffsetConfig[] = [];
    const usedIds = new Set<string>();

    function ensureUniqueId(base: string, minutes: number): string {
      let candidate = base.length > 0 ? base : `M${minutes}`;
      let suffix = 1;
      while (usedIds.has(candidate)) {
        candidate = `${base.length > 0 ? base : 'OFFSET'}_${suffix}`;
        suffix += 1;
      }
      usedIds.add(candidate);
      return candidate;
    }

    const offsetsRaw = Array.isArray(source.offsets) ? source.offsets : [];
    if (offsetsRaw.length > 0) {
      for (const entry of offsetsRaw) {
        if (!entry || typeof entry !== 'object') {
          continue;
        }
        const raw = entry as Record<string, unknown>;
        const minutes = clampMinutes(
          typeof raw.minutesBefore === 'number'
            ? raw.minutesBefore
            : typeof raw.minutesBefore === 'string'
              ? Number.parseInt(raw.minutesBefore, 10)
              : typeof raw.minutes === 'number'
                ? raw.minutes
                : 0,
        );
        if (!minutes) {
          continue;
        }
        const slug = normalizeSlug(raw.id, `M${minutes}`);
        const id = ensureUniqueId(slug, minutes);
        const title =
          typeof raw.title === 'string' && raw.title.trim().length > 0
            ? raw.title.trim()
            : undefined;
        const bodyTemplate =
          typeof raw.bodyTemplate === 'string' &&
          raw.bodyTemplate.trim().length > 0
            ? raw.bodyTemplate.trim()
            : undefined;
        const active = raw.active !== false;
        sanitized.push({
          id,
          minutesBefore: minutes,
          active,
          title,
          bodyTemplate,
        });
      }
    }

    if (!sanitized.length) {
      const explicitMinutes = parseMinutesList(
        source.appointmentOffsetsMinutes,
      );
      if (explicitMinutes.length) {
        for (const minutes of explicitMinutes) {
          const id = ensureUniqueId(`M${minutes}`, minutes);
          sanitized.push({
            id,
            minutesBefore: minutes,
            active: true,
          });
        }
      }
    }

    if (!sanitized.length) {
      const legacyMinutes = [
        source.dayBeforeEnabled === true ? 1440 : null,
        source.threeHoursEnabled === true ? 180 : null,
        source.oneHourEnabled === true ? 60 : null,
      ].filter((value): value is number => value !== null);
      if (legacyMinutes.length) {
        for (const minutes of legacyMinutes) {
          const id = ensureUniqueId(`M${minutes}`, minutes);
          sanitized.push({
            id,
            minutesBefore: clampMinutes(minutes),
            active: true,
          });
        }
      }
    }

    return sanitized;
  }

  let sanitized = buildOffsets(data);

  if (!sanitized.length) {
    const fallbackSnapshot = await db
      .collection('reminder_settings')
      .doc(salonId)
      .get();
    if (fallbackSnapshot.exists) {
      data = (fallbackSnapshot.data() ?? {}) as Record<string, unknown>;
      sanitized = buildOffsets(data);
    }
  }

  if (!sanitized.length) {
    const result: ReminderOffsetConfig[] = [];
    offsetsCache.set(salonId, {
      value: result,
      expiresAt: now + CACHE_TTL_MS,
    });
    return result;
  }

  if (sanitized.length > MAX_OFFSETS_COUNT) {
    sanitized.length = MAX_OFFSETS_COUNT;
  }

  sanitized.sort((a, b) => a.minutesBefore - b.minutesBefore);
  offsetsCache.set(salonId, {
    value: sanitized,
    expiresAt: now + CACHE_TTL_MS,
  });
  return sanitized;
}

function getStartTimestamp(appt: DocumentData): Timestamp | null {
  const candidate = appt.startAt ?? appt.start;
  if (candidate instanceof AdminTimestamp) {
    return candidate;
  }
  return null;
}

function buildFlagKey(offsetId: string): string {
  return `reminder_${offsetId}_sent`;
}

function hasSentFlag(appt: DocumentData, offsetId: string): boolean {
  return Boolean(appt[buildFlagKey(offsetId)]);
}

function isCancelled(appt: DocumentData): boolean {
  if (typeof appt.cancelled === 'boolean') {
    return appt.cancelled;
  }
  const status = typeof appt.status === 'string' ? appt.status : '';
  return status.toLowerCase() === 'cancelled';
}

async function markSent(
  ref: DocumentReference<DocumentData>,
  offsetId: string,
): Promise<void> {
  const field = buildFlagKey(offsetId);
  await ref.update({
    [field]: true,
    updatedAt: serverTimestamp(),
  });
}

async function sendNotification(
  appt: DocumentData,
  salonId: string,
  appointmentId: string,
  offsetId: string,
): Promise<void> {
  const token = typeof appt.deviceToken === 'string' ? appt.deviceToken : null;
  if (!token) {
    return;
  }

  const messaging = getMessaging();
  try {
    await messaging.send({
      token,
      notification: {
        title: 'Promemoria appuntamento',
        body:
          typeof appt.title === 'string' && appt.title.trim().length > 0
            ? `${appt.title} in arrivo`
            : 'Hai un appuntamento imminente',
      },
      data: {
        salonId,
        appointmentId,
        offsetId,
      },
    });
  } catch (error) {
    logger.error('Failed to send reminder notification', error, {
      salonId,
      appointmentId,
      offsetId,
    });
  }
}

async function enqueueReminderTask(
  data: ReminderPayload,
  fireAt: Date,
): Promise<void> {
  await reminderQueue.enqueue(data, {
    scheduleTime: fireAt,
    dispatchDeadlineSeconds: 300,
  });
}

async function enqueueForAppointment(
  apptRef: DocumentReference<DocumentData>,
  appt: DocumentData,
  pathSalonId?: string,
): Promise<void> {
  const salonDoc = apptRef.parent.parent;
  let salonId = salonDoc?.id ?? pathSalonId;
  if (!salonId && typeof appt.salonId === 'string') {
    const candidate = appt.salonId.trim();
    if (candidate.length > 0) {
      salonId = candidate;
    }
  }
  if (!salonId) {
    logger.info('Missing salonId on appointment, skipping scheduling', {
      docPath: apptRef.path,
    });
    return;
  }

  const appointmentId = apptRef.id;
  const docPath = apptRef.path;

  const startTimestamp = getStartTimestamp(appt);
  if (!startTimestamp) {
    logger.info('Appointment start missing, skipping reminder scheduling', {
      salonId,
      appointmentId,
    });
    return;
  }
  const startMs = startTimestamp.toMillis();
  const now = Date.now();
  if (startMs <= now) {
    return;
  }

  if (startMs - now > MAX_AHEAD_MS) {
    const checkpointAt = new Date(startMs - MAX_AHEAD_MS);
    await enqueueReminderTask(
      { salonId, appointmentId, docPath, offsetId: 'CHECKPOINT' },
      checkpointAt,
    );
    return;
  }

  const offsets = await loadReminderOffsets(salonId);
  for (const offset of offsets) {
    if (!offset.active) {
      continue;
    }
    const fireAtMs = startMs - offset.minutesBefore * 60 * 1000;
    if (fireAtMs <= now) {
      continue;
    }
    if (hasSentFlag(appt, offset.id)) {
      continue;
    }
    await enqueueReminderTask(
      { salonId, appointmentId, docPath, offsetId: offset.id },
      new Date(fireAtMs),
    );
  }
}

async function handleAppointmentWrite(
  snapshot: DocumentSnapshot<DocumentData> | undefined,
  pathSalonId?: string,
): Promise<void> {
  if (!snapshot?.exists) {
    return;
  }
  const appt = snapshot.data();
  if (!appt) {
    return;
  }
  if (isCancelled(appt)) {
    return;
  }
  await enqueueForAppointment(snapshot.ref, appt, pathSalonId);
}

export const appointmentReminderOnWrite = onDocumentWritten(
  {
    region: REGION,
    document: 'salons/{salonId}/appointments/{appointmentId}',
  },
  async (event) => {
    await handleAppointmentWrite(
      event.data?.after as DocumentSnapshot<DocumentData> | undefined,
      event.params?.salonId as string | undefined,
    );
  },
);

export const appointmentReminderOnRootWrite = onDocumentWritten(
  {
    region: REGION,
    document: 'appointments/{appointmentId}',
  },
  async (event) => {
    await handleAppointmentWrite(
      event.data?.after as DocumentSnapshot<DocumentData> | undefined,
    );
  },
);

export const processAppointmentReminderTask = onTaskDispatched(
  {
    region: REGION,
    retryConfig: { maxAttempts: 5 },
    rateLimits: { maxConcurrentDispatches: 20 },
  },
  async (request: TaskRequest<ReminderPayload>) => {
    const payload = request.data;
    if (!payload) {
      return;
    }
    const { salonId, appointmentId, offsetId, docPath } = payload;
    const apptRef = db.doc(docPath);
    const snapshot = await apptRef.get();
    if (!snapshot.exists) {
      logger.info('Reminder task skipped: appointment not found', {
        docPath,
        offsetId,
      });
      return;
    }
    const appt = snapshot.data() ?? {};
    if (isCancelled(appt)) {
      return;
    }

    if (offsetId === 'CHECKPOINT') {
      offsetsCache.delete(salonId);
      await enqueueForAppointment(apptRef, appt, salonId);
      return;
    }

    if (hasSentFlag(appt, offsetId)) {
      return;
    }

    const startTimestamp = getStartTimestamp(appt);
    if (!startTimestamp || startTimestamp.toMillis() <= Date.now()) {
      return;
    }

    await sendNotification(appt, salonId, appointmentId, offsetId);
    await markSent(apptRef, offsetId);
  },
);

export const appointmentReminderSweeper = onSchedule(
  { region: REGION, schedule: 'every 15 minutes' },
  async () => {
    const now = AdminTimestamp.now();
    const in30d = AdminTimestamp.fromMillis(now.toMillis() + MAX_AHEAD_MS);
    const fields = ['start', 'startAt'] as const;
    const processed = new Set<string>();
    const tasks: Promise<void>[] = [];

    for (const field of fields) {
      const query = db
        .collectionGroup('appointments')
        .where(field, '>=', now)
        .where(field, '<=', in30d)
        .limit(500);
      const snapshot = await query.get();
      for (const doc of snapshot.docs) {
        const path = doc.ref.path;
        if (processed.has(path)) {
          continue;
        }
        processed.add(path);
        const data = doc.data();
        if (isCancelled(data)) {
          continue;
        }
        tasks.push(enqueueForAppointment(doc.ref, data));
      }
    }

    await Promise.all(tasks);
  },
);

// Re-export constants for reuse/tests if necessary.
export const ReminderSettings = {
  minOffsetMinutes: MIN_OFFSET_MINUTES,
  maxOffsetsCount: MAX_OFFSETS_COUNT,
} as const;
