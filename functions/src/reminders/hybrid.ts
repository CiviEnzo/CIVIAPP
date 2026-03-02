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
import {
  sendTemplateMessage,
  type WhatsAppTemplateComponent,
} from '../wa/sendTemplate';
const REGION = 'europe-west1';
const MAX_AHEAD_MS = 30 * 24 * 60 * 60 * 1000;
const MAX_AHEAD_MINUTES = MAX_AHEAD_MS / 60000;
const CACHE_TTL_MS = 5 * 60 * 1000;

type ReminderKind = string;
type ReminderDeliveryMode = 'push' | 'whatsapp' | 'both';

interface ReminderOffsetConfig {
  id: ReminderKind;
  minutesBefore: number;
  active: boolean;
  title?: string;
  bodyTemplate?: string;
  deliveryMode: ReminderDeliveryMode;
  whatsappTemplateId?: string;
  whatsappTemplateName?: string;
}

interface ReminderPayload {
  salonId: string;
  appointmentId: string;
  docPath: string;
  offsetId: ReminderKind | 'CHECKPOINT';
  offsetMinutes?: number;
}

interface ReminderClientContact {
  clientId: string | null;
  clientRef: DocumentReference<DocumentData> | null;
  phone: string | null;
  firstName?: string;
  lastName?: string;
  clientName?: string;
}

interface ReminderWhatsappTemplateRecord {
  id: string;
  salonId: string;
  title?: string;
  body: string;
  isActive: boolean;
  channel: string;
  usage: string;
  metaTemplateName?: string;
  metaTemplateLanguage?: string;
  whatsappConfig?: {
    headerFormat?: string;
    bindings?: {
      body?: string[];
      header?: string[];
    };
  };
}

interface ReminderTemplateContext {
  firstName?: string;
  lastName?: string;
  clientName?: string;
  salonName?: string;
  serviceName?: string;
  staffName?: string;
  dateTimeFull?: string;
  date?: string;
  time?: string;
  appointmentLabel?: string;
  reminderOffsetLabel?: string;
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
const DATE_DAY_MONTH_FORMATTER = new Intl.DateTimeFormat('it-IT', {
  day: 'numeric',
  month: 'long',
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

function normalizeString(value: unknown): string | null {
  if (typeof value !== 'string') {
    return null;
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function parseReminderDeliveryMode(value: unknown): ReminderDeliveryMode {
  if (typeof value !== 'string') {
    return 'push';
  }
  const normalized = value.trim().toLowerCase();
  if (normalized === 'whatsapp') {
    return 'whatsapp';
  }
  if (normalized === 'both') {
    return 'both';
  }
  return 'push';
}

function offsetSendsPush(offset: ReminderOffsetConfig): boolean {
  return offset.deliveryMode === 'push' || offset.deliveryMode === 'both';
}

function offsetSendsWhatsapp(offset: ReminderOffsetConfig): boolean {
  return offset.deliveryMode === 'whatsapp' || offset.deliveryMode === 'both';
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
        const deliveryMode = parseReminderDeliveryMode(
          raw.deliveryMode ?? raw.deliveryChannel,
        );
        const whatsappTemplateId = normalizeString(raw.whatsappTemplateId) ?? undefined;
        const whatsappTemplateName =
          normalizeString(raw.whatsappTemplateName) ?? undefined;
        sanitized.push({
          id,
          minutesBefore: minutes,
          active,
          title,
          bodyTemplate,
          deliveryMode,
          whatsappTemplateId,
          whatsappTemplateName,
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
            deliveryMode: 'push',
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
            deliveryMode: 'push',
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

function pickString(
  source: Record<string, unknown> | null | undefined,
  ...keys: string[]
): string | undefined {
  if (!source) {
    return undefined;
  }
  for (const key of keys) {
    const value = normalizeString(source[key]);
    if (value) {
      return value;
    }
  }
  return undefined;
}

function normalizeWhatsappRecipient(value: unknown): string | null {
  if (typeof value !== 'string') {
    return null;
  }
  const compact = value.replace(/[\s().-]/g, '');
  if (!compact) {
    return null;
  }
  if (/^\+?\d+$/.test(compact)) {
    return compact;
  }
  return null;
}

function extractAppointmentPhone(appt: DocumentData): string | null {
  const direct = [
    appt.phone,
    appt.clientPhone,
    appt.customerPhone,
    appt.phoneNumber,
    appt.mobile,
  ]
    .map((value) => normalizeWhatsappRecipient(value))
    .find((value): value is string => Boolean(value));
  if (direct) {
    return direct;
  }
  const clientObj =
    typeof appt.client === 'object' && appt.client
      ? (appt.client as Record<string, unknown>)
      : null;
  return (
    normalizeWhatsappRecipient(clientObj?.phone) ??
    normalizeWhatsappRecipient(clientObj?.mobile) ??
    normalizeWhatsappRecipient(clientObj?.whatsappPhone) ??
    null
  );
}

async function resolveClientContact(
  appt: DocumentData,
): Promise<ReminderClientContact> {
  const candidateIds = collectCandidateClientIds(appt);
  for (const candidate of candidateIds) {
    const clientRef = db.collection('clients').doc(candidate);
    const snapshot = await clientRef.get();
    if (!snapshot.exists) {
      continue;
    }
    const data = (snapshot.data() ?? {}) as Record<string, unknown>;
    const firstName = normalizeString(data.firstName) ?? undefined;
    const lastName = normalizeString(data.lastName) ?? undefined;
    const fallbackClientName = [firstName, lastName]
      .filter((part): part is string => Boolean(part))
      .join(' ');
    const clientName =
      normalizeString(data.fullName) ??
      (fallbackClientName.length > 0 ? fallbackClientName : undefined);
    const phone =
      normalizeWhatsappRecipient(data.phone) ??
      normalizeWhatsappRecipient(data.mobile) ??
      normalizeWhatsappRecipient(data.whatsappPhone) ??
      normalizeWhatsappRecipient(data.phoneNumber) ??
      extractAppointmentPhone(appt);
    return {
      clientId: snapshot.id,
      clientRef,
      phone,
      firstName,
      lastName,
      clientName,
    };
  }

  const apptClient =
    typeof appt.client === 'object' && appt.client
      ? (appt.client as Record<string, unknown>)
      : null;
  const firstName =
    normalizeString(appt.firstName) ??
    normalizeString(appt.clientFirstName) ??
    pickString(apptClient, 'firstName', 'name');
  const lastName =
    normalizeString(appt.lastName) ??
    normalizeString(appt.clientLastName) ??
    pickString(apptClient, 'lastName', 'surname');
  const fallbackClientName = [firstName, lastName]
    .filter((part): part is string => Boolean(part))
    .join(' ');
  const clientName =
    normalizeString(appt.clientName) ??
    normalizeString(appt.customerName) ??
    pickString(apptClient, 'fullName', 'displayName') ??
    (fallbackClientName.length > 0 ? fallbackClientName : undefined);

  return {
    clientId: resolvePrimaryClientId(appt, null),
    clientRef: null,
    phone: extractAppointmentPhone(appt),
    firstName: firstName ?? undefined,
    lastName: lastName ?? undefined,
    clientName,
  };
}

function extractServiceId(appt: DocumentData): string | null {
  const direct =
    normalizeString(appt.serviceId) ??
    (Array.isArray(appt.serviceIds)
      ? normalizeString(appt.serviceIds[0])
      : null);
  if (direct) {
    return direct;
  }
  if (Array.isArray(appt.serviceAllocations) && appt.serviceAllocations.length > 0) {
    const first = appt.serviceAllocations[0];
    if (first && typeof first === 'object') {
      return normalizeString((first as Record<string, unknown>).serviceId);
    }
  }
  return null;
}

async function resolveServiceName(appt: DocumentData): Promise<string | null> {
  const apptService =
    typeof appt.service === 'object' && appt.service
      ? (appt.service as Record<string, unknown>)
      : null;
  const direct =
    normalizeString(appt.serviceName) ??
    normalizeString(appt.serviceLabel) ??
    pickString(apptService, 'name', 'title');
  if (direct) {
    return direct;
  }
  const serviceId = extractServiceId(appt);
  if (!serviceId) {
    return normalizeString(appt.title);
  }
  try {
    const snapshot = await db.collection('services').doc(serviceId).get();
    if (snapshot.exists) {
      const data = (snapshot.data() ?? {}) as Record<string, unknown>;
      const name = normalizeString(data.name);
      if (name) {
        return name;
      }
    }
  } catch (error) {
    logger.warn('Unable to resolve reminder service name', {
      serviceId,
      error: error instanceof Error ? error.message : String(error),
    });
  }
  return normalizeString(appt.title);
}

async function resolveStaffName(appt: DocumentData): Promise<string | null> {
  const apptStaff =
    typeof appt.staff === 'object' && appt.staff
      ? (appt.staff as Record<string, unknown>)
      : null;
  const direct =
    normalizeString(appt.staffName) ??
    pickString(apptStaff, 'displayName', 'fullName', 'name');
  if (direct) {
    return direct;
  }
  const staffId =
    normalizeString(appt.staffId) ??
    pickString(apptStaff, 'id');
  if (!staffId) {
    return null;
  }
  try {
    const snapshot = await db.collection('staff').doc(staffId).get();
    if (snapshot.exists) {
      const data = (snapshot.data() ?? {}) as Record<string, unknown>;
      const firstName = normalizeString(data.firstName);
      const lastName = normalizeString(data.lastName);
      const fullName =
        normalizeString(data.displayName) ??
        normalizeString(data.fullName) ??
        [firstName, lastName]
          .filter((part): part is string => Boolean(part))
          .join(' ');
      return fullName || null;
    }
  } catch (error) {
    logger.warn('Unable to resolve reminder staff name', {
      staffId,
      error: error instanceof Error ? error.message : String(error),
    });
  }
  return null;
}

async function getReminderSalonName(salonId: string): Promise<string> {
  try {
    const snapshot = await db.collection('salons').doc(salonId).get();
    const data = (snapshot.data() ?? {}) as Record<string, unknown>;
    return normalizeString(data.name) ?? 'il salone';
  } catch (error) {
    logger.warn('Unable to resolve reminder salon name', {
      salonId,
      error: error instanceof Error ? error.message : String(error),
    });
    return 'il salone';
  }
}

async function buildAppointmentReminderTemplateContext(
  appt: DocumentData,
  salonId: string,
  startTimestamp: Timestamp | null,
  configuredOffsetMinutes?: number | null,
): Promise<ReminderTemplateContext & { clientId: string | null; phone: string | null }> {
  const [client, serviceName, staffName, salonName] = await Promise.all([
    resolveClientContact(appt),
    resolveServiceName(appt),
    resolveStaffName(appt),
    getReminderSalonName(salonId),
  ]);

  const startDate = startTimestamp?.toDate() ?? null;
  const dateLabel = startDate ? DATE_DAY_MONTH_FORMATTER.format(startDate) : undefined;
  const timeLabel = startDate ? TIME_FORMATTER.format(startDate) : undefined;
  const dateTimeFullLabel =
    dateLabel && timeLabel ? `${dateLabel} alle ore ${timeLabel}` : undefined;
  const appointmentLabel = dateTimeFullLabel;
  const reminderOffsetLabel =
    configuredOffsetMinutes != null
      ? formatReminderOffsetLabel(Math.max(0, Math.round(configuredOffsetMinutes)))
      : undefined;

  return {
    clientId: client.clientId,
    phone: client.phone,
    firstName: client.firstName,
    lastName: client.lastName,
    clientName: client.clientName,
    salonName,
    serviceName: serviceName ?? undefined,
    staffName: staffName ?? undefined,
    dateTimeFull: dateTimeFullLabel,
    date: dateLabel,
    time: timeLabel,
    appointmentLabel,
    reminderOffsetLabel,
  };
}

async function loadReminderWhatsappTemplate(
  templateId: string,
): Promise<ReminderWhatsappTemplateRecord | null> {
  const snapshot = await db.collection('message_templates').doc(templateId).get();
  if (!snapshot.exists) {
    return null;
  }
  const data = (snapshot.data() ?? {}) as Record<string, unknown>;
  const rawWhatsappConfig =
    data.whatsappConfig && typeof data.whatsappConfig === 'object'
      ? (data.whatsappConfig as Record<string, unknown>)
      : undefined;
  const rawBindings =
    rawWhatsappConfig?.bindings && typeof rawWhatsappConfig.bindings === 'object'
      ? (rawWhatsappConfig.bindings as Record<string, unknown>)
      : undefined;
  const bodyBindings =
    rawBindings?.body && Array.isArray(rawBindings.body)
      ? rawBindings.body
          .map((item) => (typeof item === 'string' ? item.trim() : ''))
          .filter((item) => item.length > 0)
      : undefined;
  const headerBindings =
    rawBindings?.header && Array.isArray(rawBindings.header)
      ? rawBindings.header
          .map((item) => (typeof item === 'string' ? item.trim() : ''))
          .filter((item) => item.length > 0)
      : undefined;
  const headerFormatRaw =
    typeof rawWhatsappConfig?.headerFormat === 'string'
      ? rawWhatsappConfig.headerFormat.trim()
      : '';
  const headerFormat = headerFormatRaw.length > 0 ? headerFormatRaw : undefined;
  return {
    id: snapshot.id,
    salonId: normalizeString(data.salonId) ?? '',
    title: normalizeString(data.title) ?? undefined,
    body: normalizeString(data.body) ?? '',
    isActive: data.isActive !== false,
    channel: normalizeString(data.channel) ?? '',
    usage: normalizeString(data.usage) ?? '',
    metaTemplateName: normalizeString(data.metaTemplateName) ?? undefined,
    metaTemplateLanguage: normalizeString(data.metaTemplateLanguage) ?? undefined,
    whatsappConfig:
      (bodyBindings && bodyBindings.length) ||
      (headerBindings && headerBindings.length) ||
      headerFormat
        ? {
            headerFormat,
            bindings: {
              body: bodyBindings,
              header: headerBindings,
            },
          }
        : undefined,
  };
}

const REMINDER_PLACEHOLDER_ALIASES: Record<string, keyof ReminderTemplateContext> = {
  nome: 'firstName',
  firstname: 'firstName',
  first_name: 'firstName',
  cognome: 'lastName',
  lastname: 'lastName',
  last_name: 'lastName',
  cliente: 'clientName',
  client: 'clientName',
  clientname: 'clientName',
  client_name: 'clientName',
  salone: 'salonName',
  salon: 'salonName',
  salonname: 'salonName',
  salon_name: 'salonName',
  servizio: 'serviceName',
  service: 'serviceName',
  servicename: 'serviceName',
  service_name: 'serviceName',
  staff: 'staffName',
  staffname: 'staffName',
  staff_name: 'staffName',
  datacompleta: 'dateTimeFull',
  data_completa: 'dateTimeFull',
  dataora: 'dateTimeFull',
  data_ora: 'dateTimeFull',
  datetime: 'dateTimeFull',
  date_time: 'dateTimeFull',
  fulldate: 'dateTimeFull',
  full_date: 'dateTimeFull',
  fulltime: 'dateTimeFull',
  full_time: 'dateTimeFull',
  datetimefull: 'dateTimeFull',
  datatimefull: 'dateTimeFull',
  date_time_full: 'dateTimeFull',
  datefull: 'dateTimeFull',
  date_full: 'dateTimeFull',
  data: 'date',
  date: 'date',
  giorno: 'date',
  ora: 'time',
  time: 'time',
  orario: 'time',
  appuntamento: 'appointmentLabel',
  appointment: 'appointmentLabel',
  appointmentlabel: 'appointmentLabel',
  appointment_label: 'appointmentLabel',
  promemoria: 'reminderOffsetLabel',
  reminder: 'reminderOffsetLabel',
  reminderoffsetlabel: 'reminderOffsetLabel',
  reminder_offset_label: 'reminderOffsetLabel',
};

function normalizePlaceholderKey(raw: string): string {
  return raw.trim().toLowerCase().replace(/\s+/g, '_');
}

const CUSTOM_BINDING_PREFIX = 'custom:';

function decodeCustomBindingValue(raw: string): string | null {
  const trimmed = raw.trim();
  if (!trimmed.length) {
    return null;
  }
  if (!trimmed.toLowerCase().startsWith(CUSTOM_BINDING_PREFIX)) {
    return null;
  }
  return trimmed.slice(CUSTOM_BINDING_PREFIX.length);
}

function resolveReminderPlaceholderValue(
  rawKey: string,
  context: ReminderTemplateContext,
): string {
  const normalizedKey = normalizePlaceholderKey(rawKey);
  const mappedKey = REMINDER_PLACEHOLDER_ALIASES[normalizedKey];
  if (mappedKey) {
    const rawValue = context[mappedKey];
    const direct = typeof rawValue === 'string' ? rawValue.trim() : '';
    if (direct.length > 0) {
      return direct;
    }
    return fallbackReminderPlaceholderValue(mappedKey, context);
  }
  const compactKey = normalizedKey.replace(/[_-]/g, '');
  const compactMappedKey = REMINDER_PLACEHOLDER_ALIASES[compactKey];
  if (compactMappedKey) {
    const rawValue = context[compactMappedKey];
    const direct = typeof rawValue === 'string' ? rawValue.trim() : '';
    if (direct.length > 0) {
      return direct;
    }
    return fallbackReminderPlaceholderValue(compactMappedKey, context);
  }
  return '';
}

function fallbackReminderPlaceholderValue(
  key: keyof ReminderTemplateContext,
  context: ReminderTemplateContext,
): string {
  switch (key) {
    case 'firstName':
      return (context.firstName ?? context.clientName ?? 'Cliente').trim();
    case 'clientName':
      return (context.clientName ?? context.firstName ?? 'Cliente').trim();
    case 'salonName':
      return (context.salonName ?? 'il salone').trim();
    case 'serviceName':
      return (context.serviceName ?? 'il servizio').trim();
    case 'staffName':
      return (context.staffName ?? 'il team').trim();
    case 'dateTimeFull': {
      const date = context.date?.trim() ?? '';
      const time = context.time?.trim() ?? '';
      if (date.length > 0 && time.length > 0) {
        return `${date} alle ore ${time}`;
      }
      return (context.dateTimeFull ?? date).trim();
    }
    case 'date':
      return (context.date ?? '').trim();
    case 'time':
      return (context.time ?? '').trim();
    case 'appointmentLabel':
      return (
        context.appointmentLabel ??
        context.dateTimeFull ??
        fallbackReminderPlaceholderValue('dateTimeFull', context)
      ).trim();
    case 'lastName':
    case 'reminderOffsetLabel':
    default:
      return '';
  }
}

function extractPlaceholdersInOrder(body: string): string[] {
  if (!body.trim()) {
    return [];
  }
  const matches = body.matchAll(/\{\{\s*([^}]+?)\s*\}\}/g);
  return Array.from(matches)
    .map((match) => (match[1] ?? '').trim())
    .filter((value) => value.length > 0);
}

function buildWhatsappTemplateComponentsFromTemplate(params: {
  body: string;
  context: ReminderTemplateContext;
  bodyPlaceholderOrder?: string[];
  headerBindings?: string[];
  headerFormat?: string;
}): {
  components?: WhatsAppTemplateComponent[];
  unresolvedPlaceholders: string[];
} {
  const {
    body,
    context,
    bodyPlaceholderOrder,
    headerBindings,
    headerFormat,
  } = params;
  const components: WhatsAppTemplateComponent[] = [];
  const unresolvedPlaceholders: string[] = [];
  const normalizedHeaderFormat = (headerFormat ?? '').trim().toUpperCase();
  const hasImageHeader = normalizedHeaderFormat === 'IMAGE';
  const firstHeaderBinding =
    headerBindings && headerBindings.length > 0
      ? headerBindings[0]?.trim() ?? ''
      : '';

  if (hasImageHeader) {
    if (!firstHeaderBinding.length) {
      unresolvedPlaceholders.push('header:image');
    } else {
      const customValue = decodeCustomBindingValue(firstHeaderBinding);
      const resolved = (
        customValue ?? resolveReminderPlaceholderValue(firstHeaderBinding, context)
      ).trim();
      if (!resolved.length || !/^https?:\/\//i.test(resolved)) {
        unresolvedPlaceholders.push(firstHeaderBinding);
      } else {
        components.push({
          type: 'header',
          parameters: [
            {
              type: 'image',
              image: { link: resolved },
            },
          ],
        });
      }
    }
  } else if (firstHeaderBinding.length) {
    const customValue = decodeCustomBindingValue(firstHeaderBinding);
    const resolved = (
      customValue ?? resolveReminderPlaceholderValue(firstHeaderBinding, context)
    ).trim();
    if (!resolved.length) {
      unresolvedPlaceholders.push(firstHeaderBinding);
    } else {
      components.push({
        type: 'header',
        parameters: [
          {
            type: 'text',
            text: resolved,
          },
        ],
      });
    }
  }

  const placeholders =
    bodyPlaceholderOrder && bodyPlaceholderOrder.length
      ? bodyPlaceholderOrder
      : extractPlaceholdersInOrder(body);
  if (placeholders.length) {
    const parameters = placeholders.map((placeholder) => {
      const customValue = decodeCustomBindingValue(placeholder);
      const resolved = (
        customValue ?? resolveReminderPlaceholderValue(placeholder, context)
      ).trim();
      if (!resolved.length) {
        unresolvedPlaceholders.push(placeholder);
      }
      return {
        type: 'text' as const,
        text: resolved,
      };
    });
    components.push({
      type: 'body',
      parameters,
    });
  }

  return {
    components: components.length > 0 ? components : undefined,
    unresolvedPlaceholders,
  };
}

async function storeReminderWhatsappOutboxEntry({
  salonId,
  clientId,
  appointmentId,
  offsetId,
  offsetMinutes,
  startTimestamp,
  to,
  templateId,
  templateName,
  language,
  providerMessageId,
  status,
  errorMessage,
}: {
  salonId: string;
  clientId: string | null;
  appointmentId: string;
  offsetId: string;
  offsetMinutes: number | null;
  startTimestamp: Timestamp | null;
  to: string | null;
  templateId: string | null;
  templateName: string | null;
  language: string | null;
  providerMessageId?: string;
  status: 'sent' | 'failed' | 'skipped';
  errorMessage?: string;
}): Promise<void> {
  const resolvedClientId = clientId ?? 'unknown';
  const offsetSlug = normalizeSlug(offsetId, 'OFFSET');
  const docId = `reminder_wa_${salonId}_${resolvedClientId}_${appointmentId}_${offsetSlug}`;
  const docRef = db.collection('message_outbox').doc(docId);

  const payload: Record<string, unknown> = {
    type: 'appointment_reminder',
    appointmentId,
    offsetId,
    to,
    templateName,
    lang: language,
  };
  if (offsetMinutes != null) {
    payload.offsetMinutes = offsetMinutes;
  }
  if (providerMessageId) {
    payload.providerMessageId = providerMessageId;
  }
  if (startTimestamp) {
    payload.appointmentStart = startTimestamp.toDate().toISOString();
  }

  const metadata: Record<string, unknown> = {
    source: 'appointment_reminder_task',
    offsetId,
  };
  if (offsetMinutes != null) {
    metadata.offsetMinutes = offsetMinutes;
  }
  if (providerMessageId) {
    metadata.providerMessageId = providerMessageId;
  }
  if (errorMessage) {
    metadata.error = errorMessage;
  }

  const baseData: Record<string, unknown> = {
    salonId,
    clientId,
    channel: 'whatsapp',
    status,
    type: 'appointment_reminder',
    templateId: templateId ?? `wa_reminder_${offsetSlug}`,
    payload,
    metadata,
    appointmentId,
    appointmentStart: startTimestamp ?? null,
    updatedAt: serverTimestamp(),
    ...(providerMessageId ? { sentAt: serverTimestamp() } : {}),
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
      'Failed to persist WhatsApp reminder outbox entry',
      error instanceof Error ? error : new Error(String(error)),
      { salonId, appointmentId, offsetId, clientId },
    );
  }
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

async function sendPushReminderNotification(
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

async function sendWhatsappReminderNotification(
  appt: DocumentData,
  salonId: string,
  appointmentId: string,
  offset: ReminderOffsetConfig,
  offsetMinutes?: number | null,
): Promise<void> {
  const startTimestamp = getStartTimestamp(appt);
  const effectiveOffsetMinutes =
    typeof offsetMinutes === 'number'
      ? Math.max(0, Math.round(offsetMinutes))
      : Math.max(0, Math.round(offset.minutesBefore));
  const context = await buildAppointmentReminderTemplateContext(
    appt,
    salonId,
    startTimestamp,
    effectiveOffsetMinutes,
  );
  const clientId = context.clientId ?? resolvePrimaryClientId(appt, null);
  const recipient = context.phone;
  if (!recipient) {
    logger.warn('Skipping WhatsApp reminder: missing client phone', {
      salonId,
      appointmentId,
      offsetId: offset.id,
      clientId,
    });
    await storeReminderWhatsappOutboxEntry({
      salonId,
      clientId,
      appointmentId,
      offsetId: offset.id,
      offsetMinutes: effectiveOffsetMinutes,
      startTimestamp,
      to: null,
      templateId: offset.whatsappTemplateId ?? null,
      templateName: offset.whatsappTemplateName ?? null,
      language: 'it',
      status: 'skipped',
      errorMessage: 'missing-client-phone',
    });
    return;
  }

  const templateId = normalizeString(offset.whatsappTemplateId);
  if (!templateId) {
    logger.warn('Skipping WhatsApp reminder: missing template mapping', {
      salonId,
      appointmentId,
      offsetId: offset.id,
      clientId,
    });
    await storeReminderWhatsappOutboxEntry({
      salonId,
      clientId,
      appointmentId,
      offsetId: offset.id,
      offsetMinutes: effectiveOffsetMinutes,
      startTimestamp,
      to: recipient,
      templateId: null,
      templateName: offset.whatsappTemplateName ?? null,
      language: 'it',
      status: 'failed',
      errorMessage: 'missing-whatsapp-template-id',
    });
    return;
  }

  const template = await loadReminderWhatsappTemplate(templateId);
  if (!template) {
    await storeReminderWhatsappOutboxEntry({
      salonId,
      clientId,
      appointmentId,
      offsetId: offset.id,
      offsetMinutes: effectiveOffsetMinutes,
      startTimestamp,
      to: recipient,
      templateId,
      templateName: offset.whatsappTemplateName ?? null,
      language: 'it',
      status: 'failed',
      errorMessage: 'template-not-found',
    });
    logger.warn('Skipping WhatsApp reminder: template not found', {
      salonId,
      appointmentId,
      offsetId: offset.id,
      templateId,
    });
    return;
  }

  if (
    template.salonId !== salonId ||
    template.channel !== 'whatsapp' ||
    template.usage !== 'reminder' ||
    !template.isActive
  ) {
    await storeReminderWhatsappOutboxEntry({
      salonId,
      clientId,
      appointmentId,
      offsetId: offset.id,
      offsetMinutes: effectiveOffsetMinutes,
      startTimestamp,
      to: recipient,
      templateId: template.id,
      templateName: template.title ?? offset.whatsappTemplateName ?? null,
      language: template.metaTemplateLanguage ?? 'it',
      status: 'failed',
      errorMessage: 'template-invalid-for-reminder',
    });
    logger.warn('Skipping WhatsApp reminder: invalid local template', {
      salonId,
      appointmentId,
      offsetId: offset.id,
      templateId: template.id,
      templateSalonId: template.salonId,
      channel: template.channel,
      usage: template.usage,
      isActive: template.isActive,
    });
    return;
  }

  const metaTemplateName = template.metaTemplateName ?? template.id;
  const language = template.metaTemplateLanguage ?? 'it';
  const { components, unresolvedPlaceholders } =
    buildWhatsappTemplateComponentsFromTemplate({
      body: template.body,
      context,
      bodyPlaceholderOrder: template.whatsappConfig?.bindings?.body,
      headerBindings: template.whatsappConfig?.bindings?.header,
      headerFormat: template.whatsappConfig?.headerFormat,
    });
  if (unresolvedPlaceholders.length > 0) {
    const unresolved = Array.from(
      new Set(
        unresolvedPlaceholders
          .map((item) => item.trim())
          .filter((item) => item.length > 0),
      ),
    );
    const errorMessage = `missing-template-parameter-values:${unresolved.join(',')}`;
    logger.warn('Skipping WhatsApp reminder: unresolved template parameters', {
      salonId,
      appointmentId,
      offsetId: offset.id,
      templateId: template.id,
      unresolvedPlaceholders: unresolved,
      configuredBindings: template.whatsappConfig?.bindings ?? null,
      headerFormat: template.whatsappConfig?.headerFormat ?? null,
    });
    await storeReminderWhatsappOutboxEntry({
      salonId,
      clientId,
      appointmentId,
      offsetId: offset.id,
      offsetMinutes: effectiveOffsetMinutes,
      startTimestamp,
      to: recipient,
      templateId: template.id,
      templateName: metaTemplateName,
      language,
      status: 'failed',
      errorMessage,
    });
    return;
  }

  try {
    const result = await sendTemplateMessage({
      salonId,
      to: recipient,
      templateName: metaTemplateName,
      lang: language,
      components,
      metadata: {
        source: 'appointment_reminder_task',
        type: 'appointment_reminder',
        appointmentId,
        offsetId: offset.id,
      },
    });

    await storeReminderWhatsappOutboxEntry({
      salonId,
      clientId,
      appointmentId,
      offsetId: offset.id,
      offsetMinutes: effectiveOffsetMinutes,
      startTimestamp,
      to: recipient,
      templateId: template.id,
      templateName: metaTemplateName,
      language,
      providerMessageId: result.messageId,
      status: result.success ? 'sent' : 'failed',
      errorMessage: result.success ? undefined : 'whatsapp-send-unsuccessful',
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    logger.error(
      'Failed to send WhatsApp appointment reminder',
      error instanceof Error ? error : new Error(message),
      {
        salonId,
        appointmentId,
        offsetId: offset.id,
        templateId: template.id,
        clientId,
      },
    );
    await storeReminderWhatsappOutboxEntry({
      salonId,
      clientId,
      appointmentId,
      offsetId: offset.id,
      offsetMinutes: effectiveOffsetMinutes,
      startTimestamp,
      to: recipient,
      templateId: template.id,
      templateName: metaTemplateName,
      language,
      status: 'failed',
      errorMessage: message,
    });
  }
}

async function sendNotification(
  appt: DocumentData,
  salonId: string,
  appointmentId: string,
  offsetId: string,
  offsetMinutes?: number | null,
  offsetConfig?: ReminderOffsetConfig | null,
): Promise<void> {
  const resolvedOffset: ReminderOffsetConfig = offsetConfig ?? {
    id: offsetId,
    minutesBefore:
      typeof offsetMinutes === 'number'
        ? Math.max(0, Math.round(offsetMinutes))
        : MIN_OFFSET_MINUTES,
    active: true,
    deliveryMode: 'push',
  };

  if (offsetSendsPush(resolvedOffset)) {
    await sendPushReminderNotification(
      appt,
      salonId,
      appointmentId,
      offsetId,
      offsetMinutes,
    );
  }
  if (offsetSendsWhatsapp(resolvedOffset)) {
    await sendWhatsappReminderNotification(
      appt,
      salonId,
      appointmentId,
      resolvedOffset,
      offsetMinutes,
    );
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

    const currentOffsets = await loadReminderOffsets(salonId);
    const offsetConfig = currentOffsets.find((offset) => offset.id === offsetId);

    await sendNotification(
      appt,
      salonId,
      appointmentId,
      offsetId,
      typeof offsetMinutes === 'number' ? offsetMinutes : null,
      offsetConfig,
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
