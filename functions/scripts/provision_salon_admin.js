#!/usr/bin/env node
/**
 * Provision a salon admin with Firebase Auth, Firestore user metadata and salon data.
 *
 * Usage:
 *   node functions/scripts/provision_salon_admin.js --config=functions/scripts/provision_salon_admin.example.json --dryRun
 *   node functions/scripts/provision_salon_admin.js --config=functions/scripts/provision_salon_admin.example.json
 *
 * Requirements:
 * - Set GOOGLE_APPLICATION_CREDENTIALS to a service account JSON, or run
 *   `gcloud auth application-default login`.
 * - The script reads the project ID from --projectId, GOOGLE_CLOUD_PROJECT,
 *   GCLOUD_PROJECT, .firebaserc or firebase.json.
 * - Run from the project root (same level as `functions/`).
 */

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

const CHECKLIST_KEYS = [
  'profile',
  'operations',
  'equipment',
  'rooms',
  'loyalty',
  'social',
];

const DEFAULT_FEATURE_FLAGS = {
  clientOnlinePayments: true,
  clientPromotions: false,
  clientLastMinute: false,
};

const DEFAULT_STAFF_ROLES = [
  { id: 'manager', name: 'Manager', sortPriority: 10 },
  { id: 'receptionist', name: 'Receptionist', sortPriority: 20 },
  { id: 'estetista', name: 'Estetista', sortPriority: 30 },
  { id: 'massaggiatore', name: 'Massaggiatore', sortPriority: 40 },
  { id: 'nail_artist', name: 'Nail Artist', sortPriority: 50 },
  { id: 'staff-role-unknown', name: 'Ruolo non assegnato', sortPriority: 1000 },
];

function parseArgs() {
  const args = process.argv.slice(2);
  const params = {};
  for (const arg of args) {
    if (!arg.startsWith('--')) {
      continue;
    }
    const [key, value] = arg.split('=');
    const normalizedKey = key.replace(/^--/, '');
    params[normalizedKey] = value === undefined ? true : value;
  }
  return params;
}

function printHelp() {
  console.log(`
Provision salon admin

Usage:
  node functions/scripts/provision_salon_admin.js --config=path/to/config.json [--projectId=civiapp-38b51] [--dryRun] [--forcePassword]

Flags:
  --config=path       Required JSON config path.
  --projectId=id      Firebase project ID. Defaults to env/.firebaserc/firebase.json.
  --dryRun           Print planned operations without writing Auth/Firestore.
  --forcePassword    If the Auth user already exists, replace the password with temporaryPassword.
  --skipClaims       Do not set custom claims directly. Firestore trigger can still sync them later.
  --help             Show this help.
`);
}

function loadConfig(configPath) {
  const resolved = path.resolve(configPath);
  if (!fs.existsSync(resolved)) {
    throw new Error(`Config file not found: ${resolved}`);
  }
  const content = fs.readFileSync(resolved, 'utf8');
  try {
    return JSON.parse(content);
  } catch (error) {
    throw new Error(`Failed to parse JSON config: ${error.message}`);
  }
}

function readJsonIfExists(filePath) {
  const resolved = path.resolve(filePath);
  if (!fs.existsSync(resolved)) {
    return null;
  }
  try {
    return JSON.parse(fs.readFileSync(resolved, 'utf8'));
  } catch (error) {
    throw new Error(`Failed to parse ${resolved}: ${error.message}`);
  }
}

function resolveProjectId(params) {
  if (typeof params.projectId === 'string' && params.projectId.trim()) {
    return params.projectId.trim();
  }
  if (process.env.GOOGLE_CLOUD_PROJECT) {
    return process.env.GOOGLE_CLOUD_PROJECT;
  }
  if (process.env.GCLOUD_PROJECT) {
    return process.env.GCLOUD_PROJECT;
  }

  const firebaserc = readJsonIfExists('.firebaserc');
  const defaultProject = firebaserc?.projects?.default;
  if (typeof defaultProject === 'string' && defaultProject.trim()) {
    return defaultProject.trim();
  }

  const firebaseJson = readJsonIfExists('firebase.json');
  const flutterPlatforms = firebaseJson?.flutter?.platforms;
  if (flutterPlatforms && typeof flutterPlatforms === 'object') {
    for (const platform of Object.values(flutterPlatforms)) {
      const candidate = platform?.default?.projectId;
      if (typeof candidate === 'string' && candidate.trim()) {
        return candidate.trim();
      }
    }
  }

  return undefined;
}

function ensureInitialized(projectId) {
  if (admin.apps.length) {
    return admin.app();
  }
  try {
    const appOptions = {
      credential: admin.credential.applicationDefault(),
    };
    if (projectId) {
      appOptions.projectId = projectId;
    }
    admin.initializeApp(appOptions);
  } catch (error) {
    throw new Error(
      `Unable to initialize Firebase Admin SDK. Configure ADC/service account and project ID. ${error.message}`,
    );
  }
  return admin.app();
}

function requireString(value, fieldName) {
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw new Error(`Missing required string field: ${fieldName}`);
  }
  return value.trim();
}

function optionalString(value) {
  if (typeof value !== 'string') {
    return undefined;
  }
  const trimmed = value.trim();
  return trimmed.length ? trimmed : undefined;
}

function optionalNumber(value, fieldName) {
  if (value == null || value === '') {
    return undefined;
  }
  if (typeof value === 'number' && !Number.isNaN(value)) {
    return value;
  }
  if (typeof value === 'string') {
    const parsed = Number.parseFloat(value);
    if (!Number.isNaN(parsed)) {
      return parsed;
    }
  }
  throw new Error(`Invalid number field: ${fieldName}`);
}

function slugify(value) {
  return value
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .replace(/_{2,}/g, '_');
}

function formatDateSuffix(date = new Date()) {
  const pad = (value) => String(value).padStart(2, '0');
  return [
    date.getFullYear(),
    pad(date.getMonth() + 1),
    pad(date.getDate()),
    '_',
    pad(date.getHours()),
    pad(date.getMinutes()),
    pad(date.getSeconds()),
  ].join('');
}

function buildSalonId(salonConfig, salonName) {
  const base =
    optionalString(salonConfig.idBase) ||
    optionalString(salonConfig.id) ||
    `salon_${slugify(salonName)}`;
  const slugBase = slugify(base);
  if (!slugBase) {
    throw new Error(`Invalid salon id generated from name: ${salonName}`);
  }
  const suffix =
    optionalString(salonConfig.idDateSuffix) || formatDateSuffix();
  const slugSuffix = slugify(suffix);
  if (!slugSuffix) {
    throw new Error(`Invalid salon id date suffix: ${suffix}`);
  }
  return `${slugBase}_${slugSuffix}`;
}

function uniqueStrings(values) {
  const result = [];
  const seen = new Set();
  for (const value of values) {
    if (typeof value !== 'string') {
      continue;
    }
    const trimmed = value.trim();
    if (!trimmed || seen.has(trimmed)) {
      continue;
    }
    seen.add(trimmed);
    result.push(trimmed);
  }
  return result;
}

function normalizeEntries(config) {
  if (Array.isArray(config.admins)) {
    return config.admins;
  }
  if (config.admin || config.adminEmail || config.salon) {
    return [config];
  }
  throw new Error(
    'Config must contain either an "admins" array or a single admin/salon object.',
  );
}

function resolveEntry(rawEntry) {
  const adminConfig = rawEntry.admin || {};
  const salonConfig = rawEntry.salon || {};

  const adminEmail = requireString(
    adminConfig.email || rawEntry.adminEmail,
    'admin.email',
  ).toLowerCase();
  const adminName = optionalString(
    adminConfig.displayName || adminConfig.name || rawEntry.adminName,
  );
  const temporaryPassword = optionalString(
    adminConfig.temporaryPassword || rawEntry.temporaryPassword,
  );

  const salonName = requireString(salonConfig.name, 'salon.name');
  const salonId = buildSalonId(salonConfig, salonName);

  return {
    admin: {
      email: adminEmail,
      displayName: adminName,
      temporaryPassword,
      emailVerified: adminConfig.emailVerified !== false,
      disabled: Boolean(adminConfig.disabled),
    },
    salon: {
      id: salonId,
      name: salonName,
      address: requireString(salonConfig.address, 'salon.address'),
      city: requireString(salonConfig.city, 'salon.city'),
      phone: requireString(salonConfig.phone, 'salon.phone'),
      email: optionalString(salonConfig.email) || adminEmail,
      postalCode: optionalString(salonConfig.postalCode),
      bookingLink: optionalString(salonConfig.bookingLink),
      googlePlaceId: optionalString(salonConfig.googlePlaceId),
      latitude: optionalNumber(salonConfig.latitude, 'salon.latitude'),
      longitude: optionalNumber(salonConfig.longitude, 'salon.longitude'),
      description: optionalString(salonConfig.description),
      status: optionalString(salonConfig.status) || 'active',
      isPublished: Boolean(salonConfig.isPublished),
      socialLinks:
        salonConfig.socialLinks && typeof salonConfig.socialLinks === 'object'
          ? salonConfig.socialLinks
          : {},
      rooms: Array.isArray(salonConfig.rooms) ? salonConfig.rooms : [],
      equipment: Array.isArray(salonConfig.equipment)
        ? salonConfig.equipment
        : [],
      closures: Array.isArray(salonConfig.closures)
        ? salonConfig.closures
        : [],
      schedule: Array.isArray(salonConfig.schedule)
        ? salonConfig.schedule
        : [],
      featureFlags: {
        ...DEFAULT_FEATURE_FLAGS,
        ...(salonConfig.featureFlags || {}),
      },
      clientRegistration: {
        accessMode: 'approval',
        extraFields: [],
        ...(salonConfig.clientRegistration || {}),
      },
    },
    options: {
      enabled: rawEntry.enabled !== false,
      mustChangePassword: rawEntry.mustChangePassword !== false,
      status: optionalString(rawEntry.status) || 'active',
    },
  };
}

function buildSalonPayload(salon, exists) {
  const payload = {
    name: salon.name,
    address: salon.address,
    city: salon.city,
    phone: salon.phone,
    email: salon.email,
    postalCode: salon.postalCode,
    bookingLink: salon.bookingLink,
    googlePlaceId: salon.googlePlaceId,
    latitude: salon.latitude,
    longitude: salon.longitude,
    socialLinks: salon.socialLinks,
    description: salon.description,
    status: salon.status,
    isPublished: salon.isPublished,
    rooms: salon.rooms,
    equipment: salon.equipment,
    closures: salon.closures,
    schedule: salon.schedule,
    featureFlags: salon.featureFlags,
    clientRegistration: salon.clientRegistration,
    setupChecklist: Object.fromEntries(
      CHECKLIST_KEYS.map((key) => [key, 'notStarted']),
    ),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    provisionedBy: 'provision_salon_admin',
  };

  if (!exists) {
    payload.createdAt = admin.firestore.FieldValue.serverTimestamp();
  }

  Object.keys(payload).forEach((key) => {
    if (payload[key] === undefined) {
      delete payload[key];
    }
  });

  return payload;
}

function buildSetupProgressPayload(salonId, adminUid, exists) {
  const serverNow = admin.firestore.FieldValue.serverTimestamp();
  const itemNow = admin.firestore.Timestamp.now();
  const payload = {
    salonId,
    pendingReminder: true,
    requiredCompleted: false,
    updatedAt: serverNow,
    updatedBy: adminUid,
    items: CHECKLIST_KEYS.map((key) => ({
      key,
      status: 'notStarted',
      metadata: {},
      updatedAt: itemNow,
      updatedBy: adminUid,
    })),
  };

  if (!exists) {
    payload.createdAt = serverNow;
    payload.createdBy = adminUid;
  }

  return payload;
}

function buildReminderSettingsPayload(salonId, adminUid) {
  return {
    salonId,
    offsets: [],
    appointmentOffsetsMinutes: [],
    birthdayEnabled: true,
    lastMinuteNotificationAudience: 'none',
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedBy: adminUid,
    provisionedBy: 'provision_salon_admin',
  };
}

async function ensureDefaultStaffRoles(db, options) {
  for (const role of DEFAULT_STAFF_ROLES) {
    const roleRef = db.collection('staff_roles').doc(role.id);
    const roleSnap = await roleRef.get();
    const payload = {
      name: role.name,
      salonId: null,
      description: null,
      color: null,
      isDefault: true,
      sortPriority: role.sortPriority,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      provisionedBy: 'provision_salon_admin',
    };

    if (options.dryRun) {
      console.log(
        `[dryRun] Would ${roleSnap.exists ? 'merge update' : 'create'} staff_roles/${role.id}`,
      );
      continue;
    }

    await roleRef.set(payload, { merge: true });
    console.log(`${roleSnap.exists ? 'Updated' : 'Created'} staff_roles/${role.id}`);
  }
}

async function findAuthUserByEmail(auth, email) {
  try {
    return await auth.getUserByEmail(email);
  } catch (error) {
    if (error.code === 'auth/user-not-found') {
      return null;
    }
    throw error;
  }
}

async function ensureAuthUser(auth, entry, options) {
  const existing = await findAuthUserByEmail(auth, entry.admin.email);
  const password = entry.admin.temporaryPassword;

  if (existing) {
    const update = {};
    if (
      entry.admin.displayName &&
      existing.displayName !== entry.admin.displayName
    ) {
      update.displayName = entry.admin.displayName;
    }
    if (existing.emailVerified !== entry.admin.emailVerified) {
      update.emailVerified = entry.admin.emailVerified;
    }
    if (existing.disabled !== entry.admin.disabled) {
      update.disabled = entry.admin.disabled;
    }
    if (options.forcePassword) {
      if (!password) {
        throw new Error(
          `Auth user ${entry.admin.email} exists and --forcePassword was passed, but temporaryPassword is missing.`,
        );
      }
      update.password = password;
    }

    if (options.dryRun) {
      console.log(
        `[dryRun] Auth user exists: ${entry.admin.email} (${existing.uid}).`,
      );
      if (Object.keys(update).length) {
        console.log('[dryRun] Would update Auth user fields:', {
          ...update,
          password: update.password ? '<redacted>' : undefined,
        });
      }
      return existing;
    }

    if (Object.keys(update).length) {
      await auth.updateUser(existing.uid, update);
      console.log(`Updated Auth user ${entry.admin.email} (${existing.uid})`);
      return await auth.getUser(existing.uid);
    }

    console.log(`Auth user already exists: ${entry.admin.email} (${existing.uid})`);
    return existing;
  }

  if (!password) {
    throw new Error(
      `Auth user ${entry.admin.email} does not exist: temporaryPassword is required.`,
    );
  }

  if (options.dryRun) {
    console.log(
      `[dryRun] Would create Auth user ${entry.admin.email} with temporary password.`,
    );
    return null;
  }

  const created = await auth.createUser({
    email: entry.admin.email,
    password,
    displayName: entry.admin.displayName,
    emailVerified: entry.admin.emailVerified,
    disabled: entry.admin.disabled,
  });
  console.log(`Created Auth user ${entry.admin.email} (${created.uid})`);
  return created;
}

async function syncClaims(auth, userRecord, salonId, options) {
  if (!userRecord || options.skipClaims) {
    if (options.skipClaims) {
      console.log('Skipped direct custom claims sync.');
    }
    return;
  }

  const currentClaims = userRecord.customClaims || {};
  const salonIds = uniqueStrings([
    ...(Array.isArray(currentClaims.salonIds) ? currentClaims.salonIds : []),
    salonId,
  ]);
  const nextClaims = {
    ...currentClaims,
    role: 'admin',
    salonIds,
  };
  delete nextClaims.staffId;
  delete nextClaims.clientId;

  if (options.dryRun) {
    console.log('[dryRun] Would set custom claims:', nextClaims);
    return;
  }

  await auth.setCustomUserClaims(userRecord.uid, nextClaims);
  console.log(`Synced custom claims for ${userRecord.uid}`);
}

async function provisionEntry(db, auth, rawEntry, options) {
  const entry = resolveEntry(rawEntry);
  console.log(`\n=== Provisioning ${entry.admin.email} -> ${entry.salon.id} ===`);

  const userRecord = await ensureAuthUser(auth, entry, options);
  const salonRef = db.collection('salons').doc(entry.salon.id);
  const salonSnap = await salonRef.get();
  const salonPayload = buildSalonPayload(entry.salon, salonSnap.exists);

  if (options.dryRun) {
    console.log(
      `[dryRun] Would ${salonSnap.exists ? 'merge update' : 'create'} salons/${entry.salon.id}:`,
      {
        ...salonPayload,
        createdAt: salonPayload.createdAt ? '<serverTimestamp>' : undefined,
        updatedAt: '<serverTimestamp>',
      },
    );
  } else {
    await salonRef.set(salonPayload, { merge: true });
    console.log(
      `${salonSnap.exists ? 'Updated' : 'Created'} salons/${entry.salon.id}`,
    );
  }

  if (!userRecord) {
    console.log(
      '[dryRun] Firestore user document and claims require the generated Auth UID, so they were only described.',
    );
    console.log('[dryRun] Would create users/<generated-uid> with role admin.');
    return;
  }

  const userRef = db.collection('users').doc(userRecord.uid);
  const userSnap = await userRef.get();
  const userPayload = {
    email: entry.admin.email,
    displayName: entry.admin.displayName || userRecord.displayName || null,
    role: 'admin',
    roles: admin.firestore.FieldValue.arrayUnion('admin'),
    availableRoles: admin.firestore.FieldValue.arrayUnion('admin'),
    salonId: entry.salon.id,
    salonIds: admin.firestore.FieldValue.arrayUnion(entry.salon.id),
    enabled: entry.options.enabled,
    status: entry.options.status,
    mustChangePassword: entry.options.mustChangePassword,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    provisionedBy: 'provision_salon_admin',
  };
  if (!userSnap.exists) {
    userPayload.createdAt = admin.firestore.FieldValue.serverTimestamp();
  }

  const setupRef = db.collection('salon_setup_progress').doc(entry.salon.id);
  const setupSnap = await setupRef.get();
  const setupPayload = buildSetupProgressPayload(
    entry.salon.id,
    userRecord.uid,
    setupSnap.exists,
  );
  const remindersRef = db
    .collection('salons')
    .doc(entry.salon.id)
    .collection('settings')
    .doc('reminders');
  const remindersSnap = await remindersRef.get();
  const remindersPayload = buildReminderSettingsPayload(
    entry.salon.id,
    userRecord.uid,
  );

  if (options.dryRun) {
    console.log(
      `[dryRun] Would ${userSnap.exists ? 'merge update' : 'create'} users/${userRecord.uid}:`,
      {
        ...userPayload,
        roles: ['<arrayUnion:admin>'],
        availableRoles: ['<arrayUnion:admin>'],
        salonIds: [`<arrayUnion:${entry.salon.id}>`],
        createdAt: userPayload.createdAt ? '<serverTimestamp>' : undefined,
        updatedAt: '<serverTimestamp>',
      },
    );
    console.log(
      `[dryRun] Would ${setupSnap.exists ? 'merge update' : 'create'} salon_setup_progress/${entry.salon.id}.`,
    );
    console.log(
      `[dryRun] Would ${remindersSnap.exists ? 'keep existing' : 'create'} salons/${entry.salon.id}/settings/reminders.`,
    );
    await ensureDefaultStaffRoles(db, options);
    await syncClaims(auth, userRecord, entry.salon.id, options);
    return;
  }

  const batch = db.batch();
  batch.set(userRef, userPayload, { merge: true });
  if (!setupSnap.exists) {
    batch.set(setupRef, setupPayload, { merge: true });
  }
  if (!remindersSnap.exists) {
    batch.set(remindersRef, remindersPayload, { merge: true });
  }
  await batch.commit();

  console.log(`${userSnap.exists ? 'Updated' : 'Created'} users/${userRecord.uid}`);
  if (!setupSnap.exists) {
    console.log(`Created salon_setup_progress/${entry.salon.id}`);
  } else {
    console.log(`salon_setup_progress/${entry.salon.id} already exists`);
  }
  if (!remindersSnap.exists) {
    console.log(`Created salons/${entry.salon.id}/settings/reminders`);
  } else {
    console.log(`salons/${entry.salon.id}/settings/reminders already exists`);
  }

  await ensureDefaultStaffRoles(db, options);

  await syncClaims(auth, userRecord, entry.salon.id, options);

  console.log('Provisioning summary:', {
    uid: userRecord.uid,
    adminEmail: entry.admin.email,
    salonId: entry.salon.id,
    mustChangePassword: entry.options.mustChangePassword,
  });
}

async function run() {
  const params = parseArgs();
  if (params.help) {
    printHelp();
    return false;
  }
  if (!params.config) {
    throw new Error('Missing required --config path.');
  }

  const config = loadConfig(params.config);
  const entries = normalizeEntries(config);
  const projectId = resolveProjectId(params);
  const app = ensureInitialized(projectId);
  const db = app.firestore();
  const auth = admin.auth(app);
  const options = {
    dryRun: Boolean(params.dryRun),
    forcePassword: Boolean(params.forcePassword),
    skipClaims: Boolean(params.skipClaims),
  };
  console.log(`Using Firebase project: ${projectId || '<application default>'}`);

  for (const entry of entries) {
    await provisionEntry(db, auth, entry, options);
  }
  return true;
}

(async function main() {
  try {
    const completed = await run();
    if (completed !== false) {
      console.log('\nProvisioning completed.');
    }
    process.exit(0);
  } catch (error) {
    console.error(`\nProvisioning failed: ${error.message}`);
    process.exit(1);
  }
})();
