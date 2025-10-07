import { Timestamp , DocumentData } from 'firebase-admin/firestore';
import logger from 'firebase-functions/logger';
import { onSchedule } from 'firebase-functions/v2/scheduler';

import { db, serverTimestamp } from '../utils/firestore';
import { DEFAULT_TIMEZONE, now as nowInTimeZone } from '../utils/time';


const messageOutboxCollection = db.collection('message_outbox');
const REGION = 'europe-west1';

interface ReminderSettingsDoc {
  salonId: string;
  dayBeforeEnabled: boolean;
  threeHoursEnabled: boolean;
  oneHourEnabled: boolean;
  birthdayEnabled: boolean;
}

interface ClientPreferences {
  id: string;
  firstName?: string;
  salonId?: string;
  channelPreferences?: {
    push?: boolean;
  };
}

const REMINDERS_ENABLED = process.env.MESSAGING_REMINDERS_ENABLED !== 'false';
const BIRTHDAYS_ENABLED = process.env.MESSAGING_BIRTHDAYS_ENABLED !== 'false';
const REMINDER_WINDOW_MINUTES = Number.parseInt(
  process.env.MESSAGING_REMINDER_WINDOW ?? '30',
  10,
);
const REMINDER_CONFIG = [
  { key: 'dayBeforeEnabled' as const, minutes: 1440, label: '1 giorno prima' },
  { key: 'threeHoursEnabled' as const, minutes: 180, label: '3 ore prima' },
  { key: 'oneHourEnabled' as const, minutes: 60, label: '1 ora prima' },
];

const VALID_APPOINTMENT_STATUSES = ['scheduled', 'confirmed'];

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

async function fetchReminderSettings(): Promise<ReminderSettingsDoc[]> {
  const snapshot = await db.collection('reminder_settings').get();
  if (snapshot.empty) {
    return [];
  }
  return snapshot.docs.map((doc) => {
    const data = doc.data() ?? {};
    return {
      salonId: (data.salonId as string) ?? doc.id,
      dayBeforeEnabled: data.dayBeforeEnabled !== false,
      threeHoursEnabled: data.threeHoursEnabled !== false,
      oneHourEnabled: data.oneHourEnabled !== false,
      birthdayEnabled: data.birthdayEnabled !== false,
    };
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
  const preferences: ClientPreferences = {
    id: doc.id,
    firstName: data.firstName as string | undefined,
    salonId: data.salonId as string | undefined,
    channelPreferences: data.channelPreferences as ClientPreferences['channelPreferences'],
  };
  clientCache.set(clientId, preferences);
  return preferences;
}

function offsetLabel(minutes: number): string {
  switch (minutes) {
    case 1440:
      return 'tra 1 giorno';
    case 180:
      return 'tra 3 ore';
    case 60:
      return 'tra 1 ora';
    default:
      return 'a breve';
  }
}

function buildReminderBody(
  appointmentDate: Date,
  salonName: string,
  minutes: number,
): { title: string; body: string } {
  const whenLabel = offsetLabel(minutes);
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

  const payload = {
    type: 'appointment_reminder',
    offsetMinutes,
    appointmentId,
    appointmentStart: appointmentStart.toISOString(),
    title,
    body,
  };

  try {
    await messageOutboxCollection.doc(outboxId).create({
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
      traces: [],
    });
    logger.info('Created reminder message', { outboxId, salonId, clientId, offsetMinutes });
  } catch (error) {
    if (error && typeof error === 'object' && 'code' in error && (error as { code?: number }).code === 6) {
      logger.debug('Reminder already exists', { outboxId });
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

  for (const config of REMINDER_CONFIG) {
    if (!settings[config.key]) {
      continue;
    }

    const lookAheadStart = new Date(nowZoned.getTime() + config.minutes * 60_000);
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
        config.minutes,
        salonName,
      );
    }
  }
}

async function enqueueBirthdayGreeting(
  settings: ReminderSettingsDoc,
  client: ClientPreferences,
  targetDate: Date,
) {
  const dateKey = `${targetDate.getFullYear()}${String(targetDate.getMonth() + 1).padStart(2, '0')}${String(
    targetDate.getDate(),
  ).padStart(2, '0')}`;
  const outboxId = `birthday_${settings.salonId}_${client.id}_${dateKey}`;
  const salonName = await getSalonName(settings.salonId);
  const birthdayLabel = birthdayDateFormatter.format(targetDate);
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

async function processBirthdays(settings: ReminderSettingsDoc) {
  const todayZoned = nowInTimeZone(DEFAULT_TIMEZONE);
  const month = todayZoned.getMonth();
  const day = todayZoned.getDate();

  const snapshot = await db
    .collection('clients')
    .where('salonId', '==', settings.salonId)
    .get();

  if (snapshot.empty) {
    return;
  }

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

    const clientPreferences: ClientPreferences = {
      id: doc.id,
      firstName: data.firstName as string | undefined,
      salonId: data.salonId as string | undefined,
      channelPreferences: data.channelPreferences as ClientPreferences['channelPreferences'],
    };

    const pushEnabled = clientPreferences.channelPreferences?.push ?? true;
    if (!pushEnabled) {
      continue;
    }

    await enqueueBirthdayGreeting(settings, clientPreferences, todayZoned);
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
