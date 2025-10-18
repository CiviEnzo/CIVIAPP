#!/usr/bin/env node
/**
 * Backfill AdminSetupProgress documents and setupChecklist map for existing salons.
 *
 * Usage:
 *   node functions/scripts/backfill_salon_setup_progress.js [--salonIds=id1,id2] [--force] [--dryRun]
 *
 * Requirements:
 * - Set GOOGLE_APPLICATION_CREDENTIALS or login via `gcloud auth application-default login`.
 * - Run from the project root (same level as `functions/`).
 */

const admin = require('firebase-admin');

const CHECKLIST_KEYS = {
  PROFILE: 'profile',
  OPERATIONS: 'operations',
  EQUIPMENT: 'equipment',
  ROOMS: 'rooms',
  LOYALTY: 'loyalty',
  SOCIAL: 'social',
  INTEGRATIONS: 'integrations',
};

const DEFAULT_KEYS = [
  CHECKLIST_KEYS.PROFILE,
  CHECKLIST_KEYS.OPERATIONS,
  CHECKLIST_KEYS.EQUIPMENT,
  CHECKLIST_KEYS.ROOMS,
  CHECKLIST_KEYS.LOYALTY,
  CHECKLIST_KEYS.SOCIAL,
  CHECKLIST_KEYS.INTEGRATIONS,
];

const STATUS = {
  NOT_STARTED: 'notStarted',
  IN_PROGRESS: 'inProgress',
  COMPLETED: 'completed',
  POSTPONED: 'postponed',
};

function parseArgs() {
  const args = process.argv.slice(2);
  const params = {};
  for (const arg of args) {
    if (!arg.startsWith('--')) continue;
    const [key, value] = arg.split('=');
    const normalizedKey = key.replace(/^--/, '');
    params[normalizedKey] = value === undefined ? true : value;
  }
  return params;
}

function ensureInitialized() {
  if (admin.apps.length) {
    return admin.app();
  }
  try {
    admin.initializeApp({
      credential: admin.credential.applicationDefault(),
    });
  } catch (error) {
    throw new Error(
      `Unable to initialize Firebase Admin SDK. Configure ADC or set GOOGLE_APPLICATION_CREDENTIALS. ${error.message}`,
    );
  }
  return admin.app();
}

function coerceArray(value) {
  if (!Array.isArray(value)) {
    return [];
  }
  return value;
}

function sanitizeString(value) {
  if (typeof value !== 'string') {
    return '';
  }
  return value.trim();
}

function extractSalonChecklistSnapshot(salon) {
  const snapshot = {};
  const existing = salon.setupChecklist;
  if (existing && typeof existing === 'object') {
    for (const [key, raw] of Object.entries(existing)) {
      if (typeof raw === 'string' && DEFAULT_KEYS.includes(key)) {
        snapshot[key] = raw;
      }
    }
  }
  return snapshot;
}

function computeStatus({ condition, fallback }) {
  return condition ? STATUS.COMPLETED : fallback ?? STATUS.NOT_STARTED;
}

function mapStatusToString(status) {
  switch (status) {
    case STATUS.COMPLETED:
    case STATUS.IN_PROGRESS:
    case STATUS.POSTPONED:
    case STATUS.NOT_STARTED:
      return status;
    default:
      return STATUS.NOT_STARTED;
  }
}

function evaluateChecklistForSalon(salon) {
  const now = admin.firestore.Timestamp.now();
  const actor = 'setup-migration';

  const address = sanitizeString(salon.address);
  const city = sanitizeString(salon.city);
  const description = sanitizeString(salon.description);
  const socialLinks = salon.socialLinks && typeof salon.socialLinks === 'object'
    ? Object.entries(salon.socialLinks).filter(
        ([label, url]) => sanitizeString(label) && sanitizeString(url),
      )
    : [];

  const schedule = coerceArray(salon.schedule);
  const closures = coerceArray(salon.closures);
  const rooms = coerceArray(salon.rooms);
  const equipment = coerceArray(salon.equipment);

  const loyaltySettings = salon.loyaltySettings || {};
  const loyaltyEnabled = Boolean(loyaltySettings.enabled);

  const stripeAccountId = sanitizeString(salon.stripeAccountId);
  const hasStripe = Boolean(stripeAccountId);

  const snapshot = extractSalonChecklistSnapshot(salon);

  const items = [];

  function pushItem(key, status, metadata) {
    const safeStatus = mapStatusToString(status);
    items.push({
      key,
      status: safeStatus,
      metadata: metadata && Object.keys(metadata).length > 0 ? metadata : undefined,
      updatedAt: now,
      updatedBy: actor,
    });
    snapshot[key] = safeStatus;
  }

  pushItem(
    CHECKLIST_KEYS.PROFILE,
    snapshot[CHECKLIST_KEYS.PROFILE] ||
      computeStatus({
        condition: Boolean(address || city),
      }),
    {
      hasAddress: Boolean(address),
      hasDescription: Boolean(description),
    },
  );

  const hasSchedule = schedule.some((entry) => Boolean(entry && entry.isOpen));
  pushItem(
    CHECKLIST_KEYS.OPERATIONS,
    snapshot[CHECKLIST_KEYS.OPERATIONS] ||
      computeStatus({
        condition: hasSchedule || closures.length > 0,
      }),
    {
      hasSchedule,
      closureCount: closures.length,
      status: salon.status,
    },
  );

  pushItem(
    CHECKLIST_KEYS.EQUIPMENT,
    snapshot[CHECKLIST_KEYS.EQUIPMENT] ||
      computeStatus({
        condition: equipment.length > 0,
      }),
    { count: equipment.length },
  );

  pushItem(
    CHECKLIST_KEYS.ROOMS,
    snapshot[CHECKLIST_KEYS.ROOMS] ||
      computeStatus({
        condition: rooms.length > 0,
      }),
    { count: rooms.length },
  );

  pushItem(
    CHECKLIST_KEYS.LOYALTY,
    snapshot[CHECKLIST_KEYS.LOYALTY] ||
      (loyaltyEnabled ? STATUS.COMPLETED : STATUS.NOT_STARTED),
    { enabled: loyaltyEnabled },
  );

  pushItem(
    CHECKLIST_KEYS.SOCIAL,
    snapshot[CHECKLIST_KEYS.SOCIAL] ||
      computeStatus({
        condition: socialLinks.length > 0,
      }),
    { count: socialLinks.length },
  );

  pushItem(
    CHECKLIST_KEYS.INTEGRATIONS,
    snapshot[CHECKLIST_KEYS.INTEGRATIONS] ||
      (hasStripe ? STATUS.COMPLETED : STATUS.NOT_STARTED),
    { hasStripe },
  );

  const pendingReminder = items.some(
    (item) =>
      item.status === STATUS.NOT_STARTED || item.status === STATUS.IN_PROGRESS,
  ) ||
    items.find((item) => item.key === CHECKLIST_KEYS.OPERATIONS)?.status !==
      STATUS.COMPLETED;

  const requiredCompleted =
    items.find((item) => item.key === CHECKLIST_KEYS.OPERATIONS)?.status ===
    STATUS.COMPLETED;

  return {
    items,
    snapshot,
    pendingReminder,
    requiredCompleted,
    actor,
    now,
  };
}

async function backfillSalon(db, salonDoc, options) {
  const salonId = salonDoc.id;
  const salonData = salonDoc.data();
  const checklistField = salonData.setupChecklist;

  const progressRef = db.collection('salon_setup_progress').doc(salonId);
  const progressSnap = await progressRef.get();

  const shouldUpdateProgress = options.force || !progressSnap.exists;
  const shouldUpdateChecklist = options.force || !checklistField;

  if (!shouldUpdateProgress && !shouldUpdateChecklist) {
    console.log(`Skipping ${salonId}: already configured`);
    return;
  }

  const { items, snapshot, pendingReminder, requiredCompleted, actor, now } =
    evaluateChecklistForSalon(salonData);

  if (options.dryRun) {
    console.log(`[dryRun] Salon ${salonId}`);
    if (shouldUpdateChecklist) {
      console.log('  Would set setupChecklist:', snapshot);
    }
    if (shouldUpdateProgress) {
      console.log('  Would write salon_setup_progress document with:', {
        items,
        pendingReminder,
        requiredCompleted,
      });
    }
    return;
  }

  if (shouldUpdateChecklist) {
    await db
      .collection('salons')
      .doc(salonId)
      .set({ setupChecklist: snapshot }, { merge: true });
    console.log(`Updated salons/${salonId} setupChecklist`);
  }

  if (shouldUpdateProgress) {
    const payload = {
      salonId,
      pendingReminder,
      requiredCompleted,
      createdAt: progressSnap.exists
        ? progressSnap.get('createdAt') || now
        : now,
      createdBy: progressSnap.exists
        ? progressSnap.get('createdBy') || actor
        : actor,
      updatedAt: now,
      updatedBy: actor,
      items,
    };
    await progressRef.set(payload, { merge: true });
    console.log(`Upserted salon_setup_progress/${salonId}`);
  }
}

async function runBackfill(options) {
  const app = ensureInitialized();
  const db = app.firestore();

  const targetIds = options.salonIds && options.salonIds.length > 0
    ? options.salonIds
    : null;

  const chunks = [];
  if (targetIds) {
    const size = 10;
    for (let index = 0; index < targetIds.length; index += size) {
      chunks.push(targetIds.slice(index, index + size));
    }
  } else {
    chunks.push(null);
  }

  let processed = 0;
  for (const chunk of chunks) {
    let query = db.collection('salons');
    if (chunk) {
      query = query.where(admin.firestore.FieldPath.documentId(), 'in', chunk);
    }
    const snapshot = await query.get();
    if (snapshot.empty) {
      console.log(
        chunk
          ? `No salons found for chunk: ${chunk.join(', ')}`
          : 'No salons found.',
      );
      continue;
    }
    console.log(`Processing ${snapshot.size} salon(s)...`);
    for (const doc of snapshot.docs) {
      await backfillSalon(db, doc, options);
      processed += 1;
    }
  }

  console.log(`Finished. Processed ${processed} salon(s).`);
}

(async function main() {
  try {
    const params = parseArgs();
    const salonIds =
      typeof params.salonIds === 'string' && params.salonIds.length > 0
        ? params.salonIds.split(',').map((id) => id.trim()).filter(Boolean)
        : undefined;
    const options = {
      salonIds,
      dryRun: Boolean(params.dryRun),
      force: Boolean(params.force),
    };
    await runBackfill(options);
    process.exit(0);
  } catch (error) {
    console.error(`\nBackfill failed: ${error.message}`);
    process.exit(1);
  }
})();
