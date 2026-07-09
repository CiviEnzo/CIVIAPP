#!/usr/bin/env node
/**
 * Provision a test client account with Firebase Auth, `/users/{uid}` and
 * `/clients/{clientId}` data.
 *
 * Usage:
 *   node functions/scripts/provision_test_client.js --salonId=salon-001 --email=test@example.com --password=test2026 --dryRun
 *   node functions/scripts/provision_test_client.js --salonId=salon-001 --email=test@example.com --password=test2026 --forcePassword
 *
 * Requirements:
 * - Set GOOGLE_APPLICATION_CREDENTIALS to a service account JSON, or run
 *   `gcloud auth application-default login`.
 * - Run from the project root.
 */

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

function parseArgs() {
  const args = process.argv.slice(2);
  const params = {};

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (!arg.startsWith('--')) {
      continue;
    }

    const [rawKey, inlineValue] = arg.split('=');
    const key = rawKey.replace(/^--/, '');
    if (inlineValue !== undefined) {
      params[key] = inlineValue;
      continue;
    }

    const next = args[index + 1];
    if (next && !next.startsWith('--')) {
      params[key] = next;
      index += 1;
    } else {
      params[key] = true;
    }
  }

  return params;
}

function printHelp() {
  console.log(`
Provision test client

Usage:
  node functions/scripts/provision_test_client.js --salonId=<id> --email=<email> --password=<password> [--projectId=civiapp-38b51] [--dryRun]

Flags:
  --salonId=<id>       Required salon document id.
  --email=<email>      Required client login email.
  --password=<value>   Required password for new Auth users. Existing users need --forcePassword to update it.
  --clientId=<id>      Optional existing/new clients document id.
  --firstName=<value>  Defaults to "Test".
  --lastName=<value>   Defaults to "Cliente".
  --phone=<value>      Defaults to "+390000000000".
  --projectId=<id>     Firebase project id. Defaults to env/.firebaserc/firebase.json.
  --dryRun             Print planned operations without writing Auth/Firestore.
  --forcePassword      Update password when the Auth user already exists.
  --forceRole          Allow rewriting an existing users/{uid} role to client.
  --forceClient        Allow linking/updating an existing clients/{clientId} from a different salon.
  --skipClaims         Do not set custom claims directly. Firestore trigger can still sync them later.
  --skipSalonCheck     Do not require salons/{salonId} to exist.
  --help               Show this help.
`);
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

  const appOptions = {
    credential: admin.credential.applicationDefault(),
  };
  if (projectId) {
    appOptions.projectId = projectId;
  }
  admin.initializeApp(appOptions);
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

function buildClientId(email) {
  const base = slugify(email.split('@')[0]) || 'test_client';
  return `test_client_${base}_${formatDateSuffix()}`;
}

function resolveEntry(params) {
  const email = requireString(params.email, 'email').toLowerCase();
  const firstName = optionalString(params.firstName) || 'Test';
  const lastName = optionalString(params.lastName) || 'Cliente';

  return {
    salonId: requireString(params.salonId, 'salonId'),
    email,
    password: requireString(params.password, 'password'),
    clientId: optionalString(params.clientId) || buildClientId(email),
    firstName,
    lastName,
    displayName:
      optionalString(params.displayName) || `${firstName} ${lastName}`.trim(),
    phone: optionalString(params.phone) || '+390000000000',
    notes:
      optionalString(params.notes) ||
      'Cliente test creato da provision_test_client.',
  };
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

async function ensureSalonExists(db, salonId, options) {
  if (options.skipSalonCheck) {
    return;
  }

  const snap = await db.collection('salons').doc(salonId).get();
  if (!snap.exists) {
    throw new Error(
      `salons/${salonId} does not exist. Pass a valid --salonId or use --skipSalonCheck.`,
    );
  }
}

async function ensureAuthUser(auth, entry, options) {
  const existing = await findAuthUserByEmail(auth, entry.email);

  if (existing) {
    const update = {};
    if (existing.displayName !== entry.displayName) {
      update.displayName = entry.displayName;
    }
    if (existing.emailVerified !== true) {
      update.emailVerified = true;
    }
    if (existing.disabled === true) {
      update.disabled = false;
    }
    if (options.forcePassword) {
      update.password = entry.password;
    }

    if (options.dryRun) {
      console.log(`[dryRun] Auth user exists: ${entry.email} (${existing.uid}).`);
      if (Object.keys(update).length > 0) {
        console.log('[dryRun] Would update Auth user fields:', {
          ...update,
          password: update.password ? '<redacted>' : undefined,
        });
      }
      if (!options.forcePassword) {
        console.log(
          '[dryRun] Existing password would be left unchanged. Add --forcePassword to replace it.',
        );
      }
      return existing;
    }

    if (Object.keys(update).length > 0) {
      await auth.updateUser(existing.uid, update);
      console.log(`Updated Auth user ${entry.email} (${existing.uid})`);
      return await auth.getUser(existing.uid);
    }

    console.log(`Auth user already exists: ${entry.email} (${existing.uid})`);
    if (!options.forcePassword) {
      console.log('Password left unchanged. Add --forcePassword to replace it.');
    }
    return existing;
  }

  if (options.dryRun) {
    console.log(`[dryRun] Would create Auth user ${entry.email}.`);
    return null;
  }

  const created = await auth.createUser({
    email: entry.email,
    password: entry.password,
    displayName: entry.displayName,
    emailVerified: true,
    disabled: false,
  });
  console.log(`Created Auth user ${entry.email} (${created.uid})`);
  return created;
}

function assertRoleCanBeClient(userSnap, options) {
  if (!userSnap.exists) {
    return;
  }
  const role = userSnap.data()?.role;
  if (
    typeof role === 'string' &&
    role.trim().toLowerCase() !== 'client' &&
    !options.forceRole
  ) {
    throw new Error(
      `users/${userSnap.id} already has role "${role}". Pass --forceRole to rewrite it to client.`,
    );
  }
}

function assertClaimsCanBeClient(userRecord, options) {
  if (!userRecord) {
    return;
  }
  const role = userRecord.customClaims?.role;
  if (
    typeof role === 'string' &&
    role.trim().toLowerCase() !== 'client' &&
    !options.forceRole
  ) {
    throw new Error(
      `Auth user ${userRecord.uid} already has custom claim role "${role}". Pass --forceRole to rewrite it to client.`,
    );
  }
}

function buildClientPayload(entry, clientSnap) {
  const now = admin.firestore.FieldValue.serverTimestamp();
  const payload = {
    salonId: entry.salonId,
    firstName: entry.firstName,
    lastName: entry.lastName,
    phone: entry.phone,
    email: entry.email,
    notes: entry.notes,
    loyaltyInitialPoints: 0,
    loyaltyPoints: 0,
    fcmTokens: [],
    consents: [],
    channelPreferences: {
      push: true,
      email: true,
      whatsapp: false,
      sms: false,
      updatedAt: now,
    },
    invitationStatus: 'onboardingCompleted',
    firstLoginAt: now,
    onboardingCompletedAt: now,
    updatedAt: now,
    isTest: true,
    provisionedBy: 'provision_test_client',
  };

  if (!clientSnap.exists || !clientSnap.data()?.createdAt) {
    payload.createdAt = now;
  }

  return payload;
}

function formatFirestorePayloadForLog(payload) {
  const result = {};
  for (const [key, value] of Object.entries(payload)) {
    if (value && value.constructor?.name === 'FieldValue') {
      result[key] = '<serverTimestamp>';
    } else if (value && typeof value === 'object' && !Array.isArray(value)) {
      result[key] = formatFirestorePayloadForLog(value);
    } else {
      result[key] = value;
    }
  }
  return result;
}

async function syncClaims(auth, userRecord, entry, options) {
  if (!userRecord || options.skipClaims) {
    if (options.skipClaims) {
      console.log('Skipped direct custom claims sync.');
    }
    return;
  }

  const currentClaims = userRecord.customClaims || {};
  const salonIds = new Set(
    Array.isArray(currentClaims.salonIds)
      ? currentClaims.salonIds.filter((value) => typeof value === 'string')
      : [],
  );
  salonIds.add(entry.salonId);

  const nextClaims = {
    ...currentClaims,
    role: 'client',
    salonIds: Array.from(salonIds),
    clientId: entry.clientId,
  };

  if (options.dryRun) {
    console.log('[dryRun] Would set custom claims:', nextClaims);
    return;
  }

  await auth.setCustomUserClaims(userRecord.uid, nextClaims);
  console.log(`Synced custom claims for ${entry.email}`);
}

async function ensureFirestoreData(db, auth, userRecord, entry, options) {
  const clientRef = db.collection('clients').doc(entry.clientId);
  const clientSnap = await clientRef.get();
  if (clientSnap.exists) {
    const existingSalonId = clientSnap.data()?.salonId;
    if (
      typeof existingSalonId === 'string' &&
      existingSalonId &&
      existingSalonId !== entry.salonId &&
      !options.forceClient
    ) {
      throw new Error(
        `clients/${entry.clientId} already belongs to salon "${existingSalonId}". Pass --forceClient to relink it.`,
      );
    }
  }

  const clientPayload = buildClientPayload(entry, clientSnap);

  if (!userRecord) {
    console.log(
      `[dryRun] Would ${clientSnap.exists ? 'merge update' : 'create'} clients/${entry.clientId}:`,
      formatFirestorePayloadForLog(clientPayload),
    );
    console.log('[dryRun] Would create users/<generated-uid> with role client.');
    return;
  }

  const userRef = db.collection('users').doc(userRecord.uid);
  const userSnap = await userRef.get();
  assertRoleCanBeClient(userSnap, options);

  const userPayload = {
    email: entry.email,
    displayName: entry.displayName,
    firstName: entry.firstName,
    lastName: entry.lastName,
    role: 'client',
    roles: admin.firestore.FieldValue.arrayUnion('client'),
    availableRoles: admin.firestore.FieldValue.arrayUnion('client'),
    salonId: entry.salonId,
    salonIds: admin.firestore.FieldValue.arrayUnion(entry.salonId),
    clientId: entry.clientId,
    enabled: true,
    emailVerified: true,
    mustChangePassword: false,
    pendingSalonId: admin.firestore.FieldValue.delete(),
    pendingFirstName: admin.firestore.FieldValue.delete(),
    pendingLastName: admin.firestore.FieldValue.delete(),
    pendingPhone: admin.firestore.FieldValue.delete(),
    pendingDateOfBirth: admin.firestore.FieldValue.delete(),
    pendingExtraData: admin.firestore.FieldValue.delete(),
    pendingUpdatedAt: admin.firestore.FieldValue.delete(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    isTest: true,
    provisionedBy: 'provision_test_client',
  };

  if (!userSnap.exists) {
    userPayload.createdAt = admin.firestore.FieldValue.serverTimestamp();
  }

  if (options.dryRun) {
    console.log(
      `[dryRun] Would ${clientSnap.exists ? 'merge update' : 'create'} clients/${entry.clientId}:`,
      formatFirestorePayloadForLog(clientPayload),
    );
    console.log(
      `[dryRun] Would ${userSnap.exists ? 'merge update' : 'create'} users/${userRecord.uid}:`,
      {
        ...formatFirestorePayloadForLog(userPayload),
        roles: ['<arrayUnion:client>'],
        availableRoles: ['<arrayUnion:client>'],
        salonIds: [`<arrayUnion:${entry.salonId}>`],
        pendingSalonId: '<delete>',
        pendingFirstName: '<delete>',
        pendingLastName: '<delete>',
        pendingPhone: '<delete>',
        pendingDateOfBirth: '<delete>',
        pendingExtraData: '<delete>',
        pendingUpdatedAt: '<delete>',
      },
    );
    await syncClaims(auth, userRecord, entry, options);
    return;
  }

  const batch = db.batch();
  batch.set(clientRef, clientPayload, { merge: true });
  batch.set(userRef, userPayload, { merge: true });
  await batch.commit();

  console.log(`${clientSnap.exists ? 'Updated' : 'Created'} clients/${entry.clientId}`);
  console.log(`${userSnap.exists ? 'Updated' : 'Created'} users/${userRecord.uid}`);

  await syncClaims(auth, userRecord, entry, options);
}

async function run() {
  const params = parseArgs();
  if (params.help) {
    printHelp();
    return;
  }

  const entry = resolveEntry(params);
  const projectId = resolveProjectId(params);
  const app = ensureInitialized(projectId);
  const db = app.firestore();
  const auth = admin.auth(app);
  const options = {
    dryRun: Boolean(params.dryRun),
    forcePassword: Boolean(params.forcePassword),
    forceRole: Boolean(params.forceRole),
    forceClient: Boolean(params.forceClient),
    skipClaims: Boolean(params.skipClaims),
    skipSalonCheck: Boolean(params.skipSalonCheck),
  };

  console.log(`Using Firebase project: ${projectId || '<application default>'}`);
  await ensureSalonExists(db, entry.salonId, options);
  const userRecord = await ensureAuthUser(auth, entry, options);
  assertClaimsCanBeClient(userRecord, options);
  await ensureFirestoreData(db, auth, userRecord, entry, options);

  console.log('Provisioning summary:', {
    uid: userRecord?.uid || '<generated-uid>',
    email: entry.email,
    password: '<redacted>',
    salonId: entry.salonId,
    clientId: entry.clientId,
  });
}

run().catch((error) => {
  console.error(error);
  process.exit(1);
});
