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
  FieldValue,
  Timestamp as AdminTimestamp,
} from '../utils/firestore';
import { formatReminderOffsetLabel } from '../messaging/reminder_settings';
import { DEFAULT_TIMEZONE } from '../utils/time';
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
  offsetMinutes?: number;
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

const TIME_FORMATTER = new Intl.DateTimeFormat('it-IT', {
  timeStyle: 'short',
  timeZone: DEFAULT_TIMEZONE,
});
const DATE_DISPLAY_FORMATTER = new Intl.DateTimeFormat('it-IT', {
  dateStyle: 'long',
  timeZone: DEFAULT_TIMEZONE,
});
const DATE_COMPARE_FORMATTER = new Intl.DateTimeFormat('it-IT', {
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
  timeZone: DEFAULT_TIMEZONE,
});

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

function normalizeToken(value: unknown): string | null {
  if (typeof value !== 'string') {
    return null;
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function collectCandidateClientIds(appt: DocumentData): string[] {
  const ids = new Set<string>();
  const maybeAdd = (value: unknown) => {
    if (typeof value === 'string') {
      const trimmed = value.trim();
      if (trimmed.length > 0) {
        ids.add(trimmed);
      }
    }
  };
  maybeAdd(appt.clientId);
  maybeAdd(appt.clientUid);
  maybeAdd(appt.customerId);
  maybeAdd(appt.customerUid);
  maybeAdd(
    typeof appt.client === 'object' && appt.client
      ? (appt.client as Record<string, unknown>)['id']
      : null,
  );
  return Array.from(ids);
}

async function resolveClientTokens(
  appt: DocumentData,
): Promise<{
  tokens: string[];
  clientRef: DocumentReference<DocumentData> | null;
  clientId: string | null;
}> {
  const candidateIds = collectCandidateClientIds(appt);
  for (const candidate of candidateIds) {
    const clientRef = db.collection('clients').doc(candidate);
    const snapshot = await clientRef.get();
    if (!snapshot.exists) {
      continue;
    }
    const rawTokens = snapshot.get('fcmTokens');
    if (!Array.isArray(rawTokens)) {
      continue;
    }
    const tokens = rawTokens
      .map((token) => normalizeToken(token))
      .filter((token): token is string => Boolean(token));
    if (!tokens.length) {
      continue;
    }
    return {
      tokens,
      clientRef,
      clientId: snapshot.id,
    };
  }

  return {
    tokens: [],
    clientRef: null,
    clientId: null,
  };
}

function resolvePrimaryClientId(
  appt: DocumentData,
  resolvedClientId: string | null,
): string | null {
  if (resolvedClientId) {
    return resolvedClientId;
  }
  const candidates = collectCandidateClientIds(appt);
  return candidates.length > 0 ? candidates[0] : null;
}

function buildReminderNotificationCopy(
  appt: DocumentData,
  startTimestamp: Timestamp | null,
  configuredOffsetMinutes?: number | null,
): {
  title: string;
  body: string;
  minutesUntil: number | null;
  relativeLabel: string | null;
} {
  const defaultTitle = 'Promemoria appuntamento';
  const baseLabel =
    typeof appt.title === 'string' && appt.title.trim().length > 0
      ? appt.title.trim()
      : 'Il tuo appuntamento';
  if (!startTimestamp) {
    const relativeLabel =
      configuredOffsetMinutes != null
        ? formatReminderOffsetLabel(Math.max(0, Math.round(configuredOffsetMinutes)))
        : null;
    return {
      title: defaultTitle,
      body: `${baseLabel} sta per iniziare.`,
      minutesUntil:
        configuredOffsetMinutes != null
          ? Math.max(0, Math.round(configuredOffsetMinutes))
          : null,
      relativeLabel,
    };
  }
  const startDate = startTimestamp.toDate();
  const nowMs = Date.now();
  const offsetForCopy =
    configuredOffsetMinutes != null
      ? Math.max(0, Math.round(configuredOffsetMinutes))
      : Math.max(0, Math.round((startDate.getTime() - nowMs) / 60000));
  const relativeLabel = formatReminderOffsetLabel(offsetForCopy);
  const timeLabel = TIME_FORMATTER.format(startDate);
  const sameDay =
    DATE_COMPARE_FORMATTER.format(startDate) ===
    DATE_COMPARE_FORMATTER.format(new Date(nowMs));
  const whenLabel = sameDay
    ? `alle ${timeLabel}`
    : `il ${DATE_DISPLAY_FORMATTER.format(startDate)} alle ${timeLabel}`;

  return {
    title: defaultTitle,
    body: `${baseLabel} è ${whenLabel} (${relativeLabel}).`,
    minutesUntil: offsetForCopy,
    relativeLabel,
  };
}

async function storeReminderOutboxEntry({
  salonId,
  clientId,
  appointmentId,
  offsetId,
  offsetMinutes,
  startTimestamp,
  notificationTitle,
  notificationBody,
  relativeLabel,
  successCount,
  failureCount,
  invalidTokenCount,
}: {
  salonId: string;
  clientId: string | null;
  appointmentId: string;
  offsetId: string;
  offsetMinutes: number | null;
  startTimestamp: Timestamp | null;
  notificationTitle: string;
  notificationBody: string;
  relativeLabel: string | null;
  successCount: number;
  failureCount: number;
  invalidTokenCount: number;
}): Promise<void> {
  if (!clientId) {
    return;
  }

  const offsetSlug = normalizeSlug(offsetId, 'OFFSET');
  const docId = `reminder_${salonId}_${clientId}_${appointmentId}_${offsetSlug}`;
  const docRef = db.collection('message_outbox').doc(docId);

  const payload: Record<string, unknown> = {
    type: 'appointment_reminder',
    appointmentId,
    offsetId,
    title: notificationTitle,
    body: notificationBody,
    sentAt: new Date().toISOString(),
  };
  if (offsetMinutes != null) {
    payload.offsetMinutes = offsetMinutes;
  }
  if (startTimestamp) {
    payload.appointmentStart = startTimestamp.toDate().toISOString();
  }
  if (relativeLabel) {
    payload.relativeLabel = relativeLabel;
  }

  const metadata: Record<string, unknown> = {
    source: 'appointment_reminder_task',
    offsetId,
    successCount,
    failureCount,
    invalidTokenCount,
  };
  if (offsetMinutes != null) {
    metadata.offsetMinutes = offsetMinutes;
  }
  if (relativeLabel) {
    metadata.relativeLabel = relativeLabel;
  }

  const baseData = {
    salonId,
    clientId,
    channel: 'push',
    status: successCount > 0 ? 'sent' : 'failed',
    type: 'appointment_reminder',
    title: notificationTitle,
    body: notificationBody,
    payload,
    metadata,
    appointmentId,
    appointmentStart: startTimestamp ?? null,
    updatedAt: serverTimestamp(),
    sentAt: successCount > 0 ? serverTimestamp() : null,
  };

  try {
    const snapshot = await docRef.get();
    if (!snapshot.exists) {
      await docRef.set({
        ...baseData,
        scheduledAt: serverTimestamp(),
        createdAt: serverTimestamp(),
        traces: [],
      });
    } else {
      await docRef.update(baseData);
    }
  } catch (error) {
    logger.error(
      'Failed to persist reminder outbox entry',
      error instanceof Error ? error : new Error(String(error)),
      {
        salonId,
        appointmentId,
        offsetId,
        clientId,
      },
    );
  }
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
  offsetMinutes?: number | null,
): Promise<void> {
  const tokens = new Set<string>();
  const appointmentToken = normalizeToken(appt.deviceToken);
  if (appointmentToken) {
    tokens.add(appointmentToken);
  }
  if (Array.isArray(appt.deviceTokens)) {
    for (const token of appt.deviceTokens) {
      const normalized = normalizeToken(token);
      if (normalized) {
        tokens.add(normalized);
      }
    }
  }

  const {
    tokens: clientTokens,
    clientRef,
    clientId: resolvedClientId,
  } = await resolveClientTokens(appt);
  for (const token of clientTokens) {
    tokens.add(token);
  }
  if (!tokens.size) {
    logger.debug('Skipping reminder notification: no push tokens', {
      salonId,
      appointmentId,
      offsetId,
    });
    return;
  }

  const targetTokens = Array.from(tokens);
  const clientTokenSet = new Set(clientTokens);
  const messaging = getMessaging();
  const startTimestamp = getStartTimestamp(appt);
  const copy = buildReminderNotificationCopy(
    appt,
    startTimestamp,
    offsetMinutes,
  );
  const {
    title: notificationTitle,
    body: notificationBody,
    minutesUntil: copyMinutes,
    relativeLabel,
  } = copy;
  const effectiveOffsetMinutes =
    typeof offsetMinutes === 'number'
      ? Math.max(0, Math.round(offsetMinutes))
      : copyMinutes;
  try {
    const response = await messaging.sendEachForMulticast({
      tokens: targetTokens,
      notification: {
        title: notificationTitle,
        body: notificationBody,
      },
      data: {
        salonId,
        appointmentId,
        offsetId,
      },
    });
    const invalidTokenErrors = new Set([
      'messaging/registration-token-not-registered',
      'messaging/invalid-registration-token',
      'messaging/invalid-argument',
    ]);
    const invalidFromClient: string[] = [];
    let totalInvalidTokens = 0;
    response.responses.forEach((res, index) => {
      if (res.success) {
        return;
      }
      const code = res.error?.code;
      if (code && invalidTokenErrors.has(code)) {
        totalInvalidTokens += 1;
        const failingToken = targetTokens[index];
        if (failingToken && clientTokenSet.has(failingToken)) {
          invalidFromClient.push(failingToken);
        }
      }
    });
    if (clientRef && clientTokenSet.size) {
      if (invalidFromClient.length) {
        await clientRef.update({
          fcmTokens: FieldValue.arrayRemove(...invalidFromClient),
        });
        logger.debug('Removed invalid reminder tokens from client profile', {
          salonId,
          appointmentId,
          offsetId,
          clientId: resolvedClientId,
          removed: invalidFromClient.length,
        });
      }
    }
    if (response.successCount === 0) {
      const errors = response.responses
        .map((res) => res.error?.message)
        .filter((msg): msg is string => Boolean(msg));
      logger.warn('Reminder notification failed for all tokens', {
        salonId,
        appointmentId,
        offsetId,
        clientId: resolvedClientId,
        errors,
      });
    }
    await storeReminderOutboxEntry({
      salonId,
      clientId: resolvePrimaryClientId(appt, resolvedClientId),
      appointmentId,
      offsetId,
      offsetMinutes: effectiveOffsetMinutes ?? null,
      startTimestamp,
      notificationTitle,
      notificationBody,
      relativeLabel,
      successCount: response.successCount,
      failureCount: response.failureCount,
      invalidTokenCount: totalInvalidTokens,
    });
  } catch (error) {
    logger.error('Failed to send reminder notification', error, {
      salonId,
      appointmentId,
      offsetId,
      clientId: resolvedClientId ?? undefined,
    });
    await storeReminderOutboxEntry({
      salonId,
      clientId: resolvePrimaryClientId(appt, resolvedClientId),
      appointmentId,
      offsetId,
      offsetMinutes: effectiveOffsetMinutes ?? null,
      startTimestamp,
      notificationTitle,
      notificationBody,
      relativeLabel,
      successCount: 0,
      failureCount: targetTokens.length,
      invalidTokenCount: 0,
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
      {
        salonId,
        appointmentId,
        docPath,
        offsetId: offset.id,
        offsetMinutes: offset.minutesBefore,
      },
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
    const { salonId, appointmentId, offsetId, docPath, offsetMinutes } = payload;
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

    await sendNotification(
      appt,
      salonId,
      appointmentId,
      offsetId,
      typeof offsetMinutes === 'number' ? offsetMinutes : null,
    );
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
