import {
  Timestamp,
  DocumentData,
  DocumentReference,
} from 'firebase-admin/firestore';
import * as logger from 'firebase-functions/logger';
import { onSchedule } from 'firebase-functions/v2/scheduler';

import { db, serverTimestamp, FieldValue } from '../utils/firestore';
import { buildWhatsappTemplateComponents } from './whatsapp_templates';
import { DEFAULT_TIMEZONE, now as nowInTimeZone } from '../utils/time';
import {
  formatReminderOffsetLabel,
  parseReminderSettingsDoc,
  type ReminderSettingsData,
} from './reminder_settings';


const messageOutboxCollection = db.collection('message_outbox');
const REGION = 'europe-west1';

type ReminderSettingsDoc = ReminderSettingsData;

interface ClientPreferences {
  id: string;
  firstName?: string;
  lastName?: string;
  clientName?: string;
  phone?: string | null;
  salonId?: string;
  channelPreferences?: {
    push?: boolean;
    whatsapp?: boolean;
  };
}

interface BirthdayWhatsappTemplateRecord {
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

interface BirthdayTemplateContext {
  firstName?: string;
  lastName?: string;
  clientName?: string;
  date?: string;
  salonName?: string;
}

const REMINDERS_ENABLED =
  process.env.MESSAGING_REMINDERS_ENABLED === 'true';
const BIRTHDAYS_ENABLED = process.env.MESSAGING_BIRTHDAYS_ENABLED !== 'false';
const REMINDER_WINDOW_MINUTES = Number.parseInt(
  process.env.MESSAGING_REMINDER_WINDOW ?? '30',
  10,
);

const VALID_APPOINTMENT_STATUSES = ['scheduled'];

const appointmentDateFormatter = new Intl.DateTimeFormat('it-IT', {
  dateStyle: 'full',
  timeStyle: 'short',
  timeZone: DEFAULT_TIMEZONE,
});

const birthdayDateFormatter = new Intl.DateTimeFormat('it-IT', {
  month: 'long',
  day: 'numeric',
  timeZone: DEFAULT_TIMEZONE,
});

function normalizeString(value: unknown): string | undefined {
  if (typeof value !== 'string') {
    return undefined;
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : undefined;
}

function normalizeWhatsappRecipient(value: unknown): string | null {
  if (typeof value !== 'string') {
    return null;
  }
  const compact = value.replace(/[\s().-]/g, '');
  if (!compact.length) {
    return null;
  }
  return /^\+?\d+$/.test(compact) ? compact : null;
}

function mapClientPreferences(
  clientId: string,
  data: DocumentData,
): ClientPreferences {
  const firstName = normalizeString(data.firstName);
  const lastName = normalizeString(data.lastName);
  const fallbackClientName = [firstName, lastName]
    .filter((part): part is string => Boolean(part))
    .join(' ');
  return {
    id: clientId,
    firstName,
    lastName,
    clientName:
      normalizeString(data.fullName) ||
      normalizeString(data.clientName) ||
      (fallbackClientName.length > 0 ? fallbackClientName : undefined),
    phone:
      normalizeWhatsappRecipient(data.phone) ??
      normalizeWhatsappRecipient(data.mobile) ??
      normalizeWhatsappRecipient(data.whatsappPhone) ??
      normalizeWhatsappRecipient(data.phoneNumber) ??
      null,
    salonId: normalizeString(data.salonId),
    channelPreferences: data.channelPreferences as ClientPreferences['channelPreferences'],
  };
}

async function fetchReminderSettings(): Promise<ReminderSettingsDoc[]> {
  const snapshot = await db.collection('reminder_settings').get();
  if (snapshot.empty) {
    return [];
  }
  return snapshot.docs.map((doc) =>
    parseReminderSettingsDoc(doc.id, doc.data()),
  );
}

function isAlreadyExistsError(error: unknown): boolean {
  return Boolean(
    error &&
      typeof error === 'object' &&
      'code' in error &&
      (error as { code?: number }).code === 6,
  );
}

function asDate(value: unknown): Date | null {
  if (!value) {
    return null;
  }
  if (value instanceof Date) {
    return value;
  }
  if (value instanceof Timestamp) {
    return value.toDate();
  }
  if (typeof value === 'string') {
    const parsed = Date.parse(value);
    return Number.isNaN(parsed) ? null : new Date(parsed);
  }
  return null;
}

type ReconcileReminderParams = {
  docRef: DocumentReference<DocumentData>;
  scheduledAt: Date;
  appointmentStart: Date;
  title: string;
  body: string;
  payload: Record<string, unknown>;
  salonId: string;
  clientId: string;
  appointmentId: string;
  offsetMinutes: number;
};

async function reconcileExistingReminder({
  docRef,
  scheduledAt,
  appointmentStart,
  title,
  body,
  payload,
  salonId,
  clientId,
  appointmentId,
  offsetMinutes,
}: ReconcileReminderParams): Promise<void> {
  const snapshot = await docRef.get();
  if (!snapshot.exists) {
    logger.debug('Existing reminder missing during reconciliation', {
      salonId,
      appointmentId,
      offsetMinutes,
    });
    return;
  }
  const data = snapshot.data() as DocumentData;
  const status = (data.status as string) ?? 'pending';
  if (status !== 'pending') {
    logger.debug('Reminder already processed, skipping update', {
      docId: docRef.id,
      status,
    });
    return;
  }

  const payloadMap =
    data.payload && typeof data.payload === 'object'
      ? (data.payload as Record<string, unknown>)
      : undefined;
  const storedStart =
    asDate(data.appointmentStart) ??
    asDate(payloadMap?.['appointmentStart']);
  const storedScheduledAt = asDate(data.scheduledAt);

  const startChanged =
    !storedStart || storedStart.getTime() !== appointmentStart.getTime();
  const scheduleChanged =
    !storedScheduledAt || storedScheduledAt.getTime() !== scheduledAt.getTime();

  if (!startChanged && !scheduleChanged) {
    logger.debug('Reminder already up to date', {
      docId: docRef.id,
      salonId,
      appointmentId,
      offsetMinutes,
    });
    return;
  }

  await docRef.update({
    appointmentStart,
    scheduledAt,
    title,
    body,
    payload,
    status: 'pending',
    updatedAt: serverTimestamp(),
    traces: FieldValue.arrayUnion({
      at: new Date(),
      event: 'rescheduled',
      info: {
        startChanged,
        scheduleChanged,
        previousScheduledAt: storedScheduledAt ?? null,
        newScheduledAt: scheduledAt,
      },
    }),
  });

  logger.info('Rescheduled reminder message', {
    salonId,
    appointmentId,
    offsetMinutes,
    clientId,
  });
}

const salonNameCache = new Map<string, string>();
async function getSalonName(salonId: string): Promise<string> {
  if (salonNameCache.has(salonId)) {
    return salonNameCache.get(salonId)!;
  }
  const doc = await db.collection('salons').doc(salonId).get();
  const name = doc.exists ? String(doc.get('name') ?? 'Il tuo salone') : 'Il tuo salone';
  salonNameCache.set(salonId, name);
  return name;
}

const clientCache = new Map<string, ClientPreferences | null>();
async function getClientPreferences(clientId: string): Promise<ClientPreferences | null> {
  if (clientCache.has(clientId)) {
    return clientCache.get(clientId) ?? null;
  }
  const doc = await db.collection('clients').doc(clientId).get();
  if (!doc.exists) {
    clientCache.set(clientId, null);
    return null;
  }
  const data = (doc.data() as DocumentData | undefined) ?? {};
  const preferences = mapClientPreferences(doc.id, data);
  clientCache.set(clientId, preferences);
  return preferences;
}

async function loadBirthdayWhatsappTemplate(
  templateId: string,
): Promise<BirthdayWhatsappTemplateRecord | null> {
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
  const headerFormatRaw = normalizeString(rawWhatsappConfig?.headerFormat);

  return {
    id: snapshot.id,
    salonId: normalizeString(data.salonId) ?? '',
    title: normalizeString(data.title),
    body: normalizeString(data.body) ?? '',
    isActive: data.isActive !== false,
    channel: normalizeString(data.channel) ?? '',
    usage: normalizeString(data.usage) ?? '',
    metaTemplateName: normalizeString(data.metaTemplateName),
    metaTemplateLanguage: normalizeString(data.metaTemplateLanguage),
    whatsappConfig:
      (bodyBindings && bodyBindings.length) ||
      (headerBindings && headerBindings.length) ||
      headerFormatRaw
        ? {
            headerFormat: headerFormatRaw,
            bindings: {
              body: bodyBindings,
              header: headerBindings,
            },
          }
        : undefined,
  };
}

const BIRTHDAY_PLACEHOLDER_ALIASES: Record<
  string,
  keyof BirthdayTemplateContext
> = {
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
  data: 'date',
  date: 'date',
  giorno: 'date',
  compleanno: 'date',
  birthday: 'date',
};

function normalizePlaceholderKey(raw: string): string {
  return raw.trim().toLowerCase().replace(/\s+/g, '_');
}

function resolveBirthdayPlaceholderValue(
  rawKey: string,
  context: BirthdayTemplateContext,
): string {
  const normalized = normalizePlaceholderKey(rawKey);
  const mappedKey =
    BIRTHDAY_PLACEHOLDER_ALIASES[normalized] ??
    BIRTHDAY_PLACEHOLDER_ALIASES[normalized.replace(/[_-]/g, '')];
  if (!mappedKey) {
    return '';
  }
  return (context[mappedKey] ?? '').trim();
}

function buildReminderBody(
  appointmentDate: Date,
  salonName: string,
  minutes: number,
): { title: string; body: string } {
  const whenLabel = formatReminderOffsetLabel(minutes);
  const appointmentLabel = appointmentDateFormatter.format(appointmentDate);
  return {
    title: `Promemoria appuntamento (${whenLabel})`,
    body: `Ti ricordiamo il tuo appuntamento presso ${salonName} il ${appointmentLabel}.`,
  };
}

async function enqueueReminder(
  salonId: string,
  clientId: string,
  templateId: string,
  appointmentId: string,
  appointmentStart: Date,
  offsetMinutes: number,
  salonName: string,
) {
  const scheduledAt = new Date(appointmentStart.getTime() - offsetMinutes * 60_000);
  const now = new Date();
  if (scheduledAt.getTime() < now.getTime() - 15 * 60_000) {
    // Skip late reminders to avoid duplicates.
    return;
  }

  const outboxId = `reminder_${salonId}_${appointmentId}_m${offsetMinutes}`;
  const { title, body } = buildReminderBody(appointmentStart, salonName, offsetMinutes);

  const payload: Record<string, unknown> = {
    type: 'appointment_reminder',
    offsetMinutes,
    appointmentId,
    appointmentStart: appointmentStart.toISOString(),
    title,
    body,
  };

  const docRef = messageOutboxCollection.doc(outboxId);
  const docData = {
    salonId,
    clientId,
    templateId,
    channel: 'push',
    status: 'pending',
    type: 'appointment_reminder',
    scheduledAt,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    title,
    body,
    payload,
    metadata: {
      offsetMinutes,
      type: 'appointment_reminder',
    },
    appointmentStart,
    traces: [],
  };

  try {
    await docRef.create(docData);
    logger.info('Created reminder message', {
      outboxId,
      salonId,
      clientId,
      offsetMinutes,
    });
  } catch (error) {
    if (isAlreadyExistsError(error)) {
      await reconcileExistingReminder({
        docRef,
        scheduledAt,
        appointmentStart,
        title,
        body,
        payload,
        salonId,
        clientId,
        appointmentId,
        offsetMinutes,
      });
      return;
    }
    logger.error(
      'Failed to create reminder message',
      error instanceof Error ? error : new Error(String(error)),
      { outboxId },
    );
  }
}

async function processReminderOffsets(settings: ReminderSettingsDoc) {
  const nowZoned = nowInTimeZone(DEFAULT_TIMEZONE);
  const windowMillis = REMINDER_WINDOW_MINUTES * 60_000;

  if (!settings.appointmentOffsetsMinutes.length) {
    return;
  }

  for (const minutes of settings.appointmentOffsetsMinutes) {
    const lookAheadStart = new Date(nowZoned.getTime() + minutes * 60_000);
    const lookAheadEnd = new Date(lookAheadStart.getTime() + windowMillis);

    const snapshot = await db
      .collection('appointments')
      .where('salonId', '==', settings.salonId)
      .where('status', 'in', VALID_APPOINTMENT_STATUSES)
      .where('start', '>=', Timestamp.fromDate(lookAheadStart))
      .where('start', '<', Timestamp.fromDate(lookAheadEnd))
      .get();

    if (snapshot.empty) {
      continue;
    }

    const salonName = await getSalonName(settings.salonId);

    for (const doc of snapshot.docs) {
      const data = doc.data() ?? {};
      const clientId = data.clientId as string | undefined;
      const appointmentId = doc.id;
      const startRaw = data.start;

      if (!clientId || !(startRaw instanceof Timestamp)) {
        continue;
      }

      const appointmentStart = startRaw.toDate();

      const clientPreferences = await getClientPreferences(clientId);
      if (!clientPreferences || clientPreferences.salonId !== settings.salonId) {
        continue;
      }

      const pushEnabled = clientPreferences.channelPreferences?.push ?? true;
      if (!pushEnabled) {
        continue;
      }

      await enqueueReminder(
        settings.salonId,
        clientId,
        'auto_reminder_push',
        appointmentId,
        appointmentStart,
        minutes,
        salonName,
      );
    }
  }
}

async function enqueueBirthdayPushGreeting(
  settings: ReminderSettingsDoc,
  client: ClientPreferences,
  targetDate: Date,
  salonName: string,
  birthdayLabel: string,
) {
  const dateKey = `${targetDate.getFullYear()}${String(targetDate.getMonth() + 1).padStart(2, '0')}${String(
    targetDate.getDate(),
  ).padStart(2, '0')}`;
  const outboxId = `birthday_${settings.salonId}_${client.id}_${dateKey}`;
  const title = 'Tanti auguri!';
  const body =
    `Buon compleanno${client.firstName != null ? ` ${client.firstName}` : ''}! Passa da ${salonName} entro 14 giorni per un regalo speciale.`;

  const scheduledAt = new Date();

  try {
    await messageOutboxCollection.doc(outboxId).create({
      salonId: settings.salonId,
      clientId: client.id,
      templateId: 'auto_birthday_push',
      channel: 'push',
      status: 'pending',
      type: 'birthday_greeting',
      scheduledAt,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
      title,
      body,
      payload: {
        type: 'birthday_greeting',
        title,
        body,
        birthday: birthdayLabel,
      },
      metadata: {
        type: 'birthday_greeting',
      },
      traces: [],
    });
    logger.info('Created birthday greeting', { outboxId, salonId: settings.salonId, clientId: client.id });
  } catch (error) {
    if (error && typeof error === 'object' && 'code' in error && (error as { code?: number }).code === 6) {
      logger.debug('Birthday message already exists', { outboxId });
      return;
    }
    logger.error(
      'Failed to create birthday greeting',
      error instanceof Error ? error : new Error(String(error)),
      { outboxId },
    );
  }
}

async function enqueueBirthdayWhatsappGreeting(
  settings: ReminderSettingsDoc,
  client: ClientPreferences,
  targetDate: Date,
  salonName: string,
  birthdayLabel: string,
) {
  const templateId = normalizeString(settings.birthdayWhatsappTemplateId);
  if (!templateId) {
    logger.warn('Skipping birthday WhatsApp: missing template id', {
      salonId: settings.salonId,
      clientId: client.id,
    });
    return;
  }

  const recipient = client.phone;
  if (!recipient) {
    logger.warn('Skipping birthday WhatsApp: missing client phone', {
      salonId: settings.salonId,
      clientId: client.id,
    });
    return;
  }

  const template = await loadBirthdayWhatsappTemplate(templateId);
  if (
    template == null ||
    template.salonId !== settings.salonId ||
    template.channel !== 'whatsapp' ||
    template.usage !== 'birthday' ||
    !template.isActive
  ) {
    logger.warn('Skipping birthday WhatsApp: invalid or unavailable template', {
      salonId: settings.salonId,
      clientId: client.id,
      templateId,
    });
    return;
  }

  const templateName = template.metaTemplateName?.trim();
  if (!templateName) {
    logger.warn('Skipping birthday WhatsApp: missing Meta template name', {
      salonId: settings.salonId,
      clientId: client.id,
      templateId,
    });
    return;
  }

  const context: BirthdayTemplateContext = {
    firstName: client.firstName,
    lastName: client.lastName,
    clientName: client.clientName,
    date: birthdayLabel,
    salonName,
  };
  const { components, unresolvedPlaceholders } =
    buildWhatsappTemplateComponents({
      body: template.body,
      bodyPlaceholderOrder: template.whatsappConfig?.bindings?.body,
      headerBindings: template.whatsappConfig?.bindings?.header,
      headerFormat: template.whatsappConfig?.headerFormat,
      resolveValue: (placeholder) =>
        resolveBirthdayPlaceholderValue(placeholder, context),
    });
  if (unresolvedPlaceholders.length > 0) {
    logger.warn('Skipping birthday WhatsApp: unresolved placeholders', {
      salonId: settings.salonId,
      clientId: client.id,
      templateId,
      unresolvedPlaceholders,
    });
    return;
  }

  const dateKey = `${targetDate.getFullYear()}${String(targetDate.getMonth() + 1).padStart(2, '0')}${String(
    targetDate.getDate(),
  ).padStart(2, '0')}`;
  const outboxId = `birthday_${settings.salonId}_${client.id}_${dateKey}_wa`;
  const scheduledAt = new Date();

  try {
    await messageOutboxCollection.doc(outboxId).create({
      salonId: settings.salonId,
      clientId: client.id,
      templateId: template.id,
      channel: 'whatsapp',
      status: 'pending',
      type: 'birthday_greeting',
      scheduledAt,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
      payload: {
        type: 'birthday_greeting',
        to: recipient,
        templateName,
        lang: template.metaTemplateLanguage ?? 'it',
        birthday: birthdayLabel,
        components,
      },
      metadata: {
        type: 'birthday_greeting',
        templateId: template.id,
        templateName,
      },
      traces: [],
    });
    logger.info('Created birthday WhatsApp greeting', {
      outboxId,
      salonId: settings.salonId,
      clientId: client.id,
      templateId: template.id,
    });
  } catch (error) {
    if (isAlreadyExistsError(error)) {
      logger.debug('Birthday WhatsApp message already exists', { outboxId });
      return;
    }
    logger.error(
      'Failed to create birthday WhatsApp greeting',
      error instanceof Error ? error : new Error(String(error)),
      { outboxId },
    );
  }
}

async function processBirthdays(settings: ReminderSettingsDoc) {
  const todayZoned = nowInTimeZone(DEFAULT_TIMEZONE);
  const month = todayZoned.getMonth();
  const day = todayZoned.getDate();
  const shouldSendPush =
    settings.birthdayDeliveryMode === 'push' ||
    settings.birthdayDeliveryMode === 'both';
  const shouldSendWhatsapp =
    settings.birthdayDeliveryMode === 'whatsapp' ||
    settings.birthdayDeliveryMode === 'both';

  if (!shouldSendPush && !shouldSendWhatsapp) {
    return;
  }

  const snapshot = await db
    .collection('clients')
    .where('salonId', '==', settings.salonId)
    .get();

  if (snapshot.empty) {
    return;
  }

  const salonName = await getSalonName(settings.salonId);
  const birthdayLabel = birthdayDateFormatter.format(todayZoned);

  for (const doc of snapshot.docs) {
    const data = doc.data() ?? {};
    const dobRaw = data.dateOfBirth;
    if (!(dobRaw instanceof Timestamp)) {
      continue;
    }
    const dob = dobRaw.toDate();
    if (dob.getMonth() !== month || dob.getDate() !== day) {
      continue;
    }

    const clientPreferences = mapClientPreferences(doc.id, data);

    if (shouldSendPush) {
      const pushEnabled = clientPreferences.channelPreferences?.push ?? true;
      if (pushEnabled) {
        await enqueueBirthdayPushGreeting(
          settings,
          clientPreferences,
          todayZoned,
          salonName,
          birthdayLabel,
        );
      }
    }

    if (shouldSendWhatsapp) {
      const whatsappEnabled =
        clientPreferences.channelPreferences?.whatsapp ?? false;
      if (whatsappEnabled) {
        await enqueueBirthdayWhatsappGreeting(
          settings,
          clientPreferences,
          todayZoned,
          salonName,
          birthdayLabel,
        );
      }
    }
  }
}

export const createReminders = onSchedule(
  {
    schedule: '*/15 * * * *',
    timeZone: DEFAULT_TIMEZONE,
    region: REGION,
  },
  async () => {
    if (!REMINDERS_ENABLED) {
      logger.debug('Reminder generation disabled via configuration');
      return;
    }

    const settingsList = await fetchReminderSettings();
    if (!settingsList.length) {
      logger.debug('No reminder settings configured');
      return;
    }

    for (const settings of settingsList) {
      try {
        await processReminderOffsets(settings);
      } catch (error) {
        logger.error(
          'Failed to process reminder offsets',
          error instanceof Error ? error : new Error(String(error)),
          { salonId: settings.salonId },
        );
      }
    }
  },
);

export const birthdayGreetings = onSchedule(
  {
    schedule: '0 7 * * *',
    timeZone: DEFAULT_TIMEZONE,
    region: REGION,
  },
  async () => {
    if (!BIRTHDAYS_ENABLED) {
      logger.debug('Birthday greetings disabled via configuration');
      return;
    }

    const settingsList = await fetchReminderSettings();
    if (!settingsList.length) {
      return;
    }

    for (const settings of settingsList) {
      if (!settings.birthdayEnabled) {
        continue;
      }
      try {
        await processBirthdays(settings);
      } catch (error) {
        logger.error(
          'Failed to process birthday greetings',
          error instanceof Error ? error : new Error(String(error)),
          { salonId: settings.salonId },
        );
      }
    }
  },
);

export const runCampaigns = onSchedule(
  {
    schedule: '0 9 * * MON',
    timeZone: DEFAULT_TIMEZONE,
    region: REGION,
  },
  async () => {
    logger.debug('runCampaigns scheduled - no automation implemented yet');
  },
);
