#!/usr/bin/env node
/**
 * Delete a salon and salon-scoped data from Firestore and Storage.
 *
 * Dry-run is the default. Real deletion requires --confirm=<salonId>.
 *
 * Usage:
 *   node functions/scripts/delete_salon.js --salonId=salon-001
 *   node functions/scripts/delete_salon.js --salonId=salon-001 --confirm=salon-001
 *
 * Requirements:
 * - Set GOOGLE_APPLICATION_CREDENTIALS to a service account JSON, or run
 *   `gcloud auth application-default login`.
 * - Run from the project root.
 */

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

const MAX_BATCH_SIZE = 450;
const WHERE_IN_LIMIT = 10;

const ROOT_DOCUMENT_COLLECTIONS = [
  'salons',
  'public_salons',
  'salon_setup_progress',
  'salon_sequences',
  'reminder_settings',
];

const COLLECTIONS_BY_SALON_ID = [
  'staff',
  'clients',
  'client_notes',
  'client_photos',
  'client_photo_collages',
  'client_questionnaire_templates',
  'client_questionnaires',
  'service_categories',
  'services',
  'packages',
  'appointments',
  'public_appointments',
  'appointment_day_checklists',
  'inventory',
  'sales',
  'payment_tickets',
  'quotes',
  'cash_flows',
  'staff_roles',
  'message_templates',
  'message_outbox',
  'shifts',
  'staff_absences',
  'public_staff_absences',
  'staff_absence_requests',
  'salon_access_requests',
  'client_app_movements',
  'promotions',
  'last_minute_slots',
  'carts',
  'orders',
];

const RECURSIVE_DELETE_COLLECTIONS = new Set(['clients']);

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
Delete salon data

Usage:
  node functions/scripts/delete_salon.js --salonId=<id> [--projectId=<id>]
  node functions/scripts/delete_salon.js --salonId=<id> --confirm=<id> [--projectId=<id>]

Flags:
  --salonId=<id>     Required salon document id.
  --confirm=<id>     Required for real deletion. Must match --salonId.
  --projectId=<id>   Firebase project id. Defaults to env/.firebaserc/firebase.json.
  --bucket=<name>    Storage bucket. Defaults to lib/firebase_options.dart.
  --skipStorage      Do not delete files under salon_media/<salonId>/.
  --skipClaims       Do not update Firebase Auth custom claims for affected users.
  --dryRun           Force dry-run mode.
  --help             Show this help.

Dry-run is the default. Without --confirm=<salonId>, no writes are made.
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

function resolveStorageBucket(params) {
  if (typeof params.bucket === 'string' && params.bucket.trim()) {
    return params.bucket.trim();
  }
  if (process.env.FIREBASE_STORAGE_BUCKET) {
    return process.env.FIREBASE_STORAGE_BUCKET;
  }

  const firebaseOptionsPath = path.resolve('lib/firebase_options.dart');
  if (!fs.existsSync(firebaseOptionsPath)) {
    return undefined;
  }

  const content = fs.readFileSync(firebaseOptionsPath, 'utf8');
  const match = content.match(/storageBucket:\s*'([^']+)'/);
  return match?.[1];
}

function ensureInitialized({ projectId, storageBucket }) {
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
    if (storageBucket) {
      appOptions.storageBucket = storageBucket;
    }
    admin.initializeApp(appOptions);
  } catch (error) {
    throw new Error(
      `Unable to initialize Firebase Admin SDK. Configure ADC/service account and project ID. ${error.message}`,
    );
  }

  return admin.app();
}

function normalizeString(value) {
  return typeof value === 'string' ? value.trim() : '';
}

function normalizeStringArray(value) {
  if (!Array.isArray(value)) {
    return [];
  }
  const ids = new Set();
  for (const entry of value) {
    const normalized = normalizeString(entry);
    if (normalized) {
      ids.add(normalized);
    }
  }
  return Array.from(ids);
}

function splitIntoChunks(items, size) {
  const chunks = [];
  for (let index = 0; index < items.length; index += size) {
    chunks.push(items.slice(index, index + size));
  }
  return chunks;
}

function hasUpdates(updates) {
  return Object.keys(updates).length > 0;
}

function formatCount(count) {
  return String(count).padStart(5, ' ');
}

async function countQuery(query) {
  const snapshot = await query.select().get();
  return snapshot.size;
}

async function countRecursiveDocument(ref) {
  const snapshot = await ref.get();
  let count = snapshot.exists ? 1 : 0;
  const subcollections = await ref.listCollections();

  for (const collectionRef of subcollections) {
    const documents = await collectionRef.listDocuments();
    for (const documentRef of documents) {
      count += await countRecursiveDocument(documentRef);
    }
  }

  return count;
}

async function collectIdsBySalonId(db, collectionName, salonId) {
  const snapshot = await db
    .collection(collectionName)
    .where('salonId', '==', salonId)
    .select()
    .get();
  return snapshot.docs.map((doc) => doc.id);
}

async function collectAffectedUsers(db, salonId, staffIds, clientIds) {
  const usersCollection = db.collection('users');
  const users = new Map();

  async function addQuery(query) {
    const snapshot = await query.get();
    for (const doc of snapshot.docs) {
      users.set(doc.id, doc);
    }
  }

  await addQuery(usersCollection.where('salonIds', 'array-contains', salonId));
  await addQuery(usersCollection.where('salonId', '==', salonId));
  await addQuery(usersCollection.where('pendingSalonId', '==', salonId));

  for (const chunk of splitIntoChunks(staffIds, WHERE_IN_LIMIT)) {
    if (chunk.length > 0) {
      await addQuery(usersCollection.where('staffId', 'in', chunk));
    }
  }

  for (const chunk of splitIntoChunks(clientIds, WHERE_IN_LIMIT)) {
    if (chunk.length > 0) {
      await addQuery(usersCollection.where('clientId', 'in', chunk));
    }
  }

  return Array.from(users.values());
}

function buildUserUpdates(userData, salonId, staffIds, clientIds) {
  const FieldValue = admin.firestore.FieldValue;
  const updates = {};

  const currentSalonIds = normalizeStringArray(userData.salonIds);
  const nextSalonIds = currentSalonIds.filter((id) => id !== salonId);
  const currentSalonId = normalizeString(userData.salonId);
  const currentPendingSalonId = normalizeString(userData.pendingSalonId);
  const currentStaffId = normalizeString(userData.staffId);
  const currentClientId = normalizeString(userData.clientId);

  if (currentSalonIds.includes(salonId)) {
    updates.salonIds = nextSalonIds.length ? nextSalonIds : FieldValue.delete();
  }
  if (currentSalonId === salonId) {
    updates.salonId = FieldValue.delete();
  }
  if (currentPendingSalonId === salonId) {
    updates.pendingSalonId = FieldValue.delete();
  }
  if (staffIds.has(currentStaffId)) {
    updates.staffId = FieldValue.delete();
  }
  if (clientIds.has(currentClientId)) {
    updates.clientId = FieldValue.delete();
  }

  const remainingSalonId = currentSalonId && currentSalonId !== salonId ? currentSalonId : '';
  const remainingStaffId = currentStaffId && !staffIds.has(currentStaffId) ? currentStaffId : '';
  const remainingClientId = currentClientId && !clientIds.has(currentClientId) ? currentClientId : '';
  const keepsAnyIdentity =
    nextSalonIds.length > 0 || remainingSalonId || remainingStaffId || remainingClientId;

  if (!keepsAnyIdentity && normalizeString(userData.role)) {
    updates.role = FieldValue.delete();
  }

  return updates;
}

function buildClaimsUpdate(customClaims, salonId, staffIds, clientIds) {
  const nextClaims = { ...(customClaims ?? {}) };

  if (Array.isArray(nextClaims.salonIds)) {
    const nextSalonIds = normalizeStringArray(nextClaims.salonIds).filter(
      (id) => id !== salonId,
    );
    if (nextSalonIds.length) {
      nextClaims.salonIds = nextSalonIds;
    } else {
      delete nextClaims.salonIds;
    }
  }

  if (normalizeString(nextClaims.salonId) === salonId) {
    delete nextClaims.salonId;
  }
  if (staffIds.has(normalizeString(nextClaims.staffId))) {
    delete nextClaims.staffId;
  }
  if (clientIds.has(normalizeString(nextClaims.clientId))) {
    delete nextClaims.clientId;
  }

  const hasSalon =
    normalizeString(nextClaims.salonId) ||
    (Array.isArray(nextClaims.salonIds) && nextClaims.salonIds.length > 0);
  const hasIdentity =
    hasSalon || normalizeString(nextClaims.staffId) || normalizeString(nextClaims.clientId);
  if (!hasIdentity && normalizeString(nextClaims.role)) {
    delete nextClaims.role;
  }

  return nextClaims;
}

function stableJson(value) {
  return JSON.stringify(value, Object.keys(value ?? {}).sort());
}

async function updateAuthClaimsForUsers(auth, users, salonId, staffIds, clientIds, dryRun) {
  let updated = 0;
  let missing = 0;

  for (const userDoc of users) {
    const uid = userDoc.id;
    try {
      const userRecord = await auth.getUser(uid);
      const currentClaims = userRecord.customClaims ?? {};
      const nextClaims = buildClaimsUpdate(currentClaims, salonId, staffIds, clientIds);
      if (stableJson(currentClaims) === stableJson(nextClaims)) {
        continue;
      }

      updated += 1;
      if (!dryRun) {
        await auth.setCustomUserClaims(
          uid,
          Object.keys(nextClaims).length > 0 ? nextClaims : null,
        );
      }
    } catch (error) {
      if (error?.code === 'auth/user-not-found') {
        missing += 1;
        continue;
      }
      throw error;
    }
  }

  return { updated, missing };
}

async function updateAffectedUsers(db, users, salonId, staffIds, clientIds, dryRun) {
  let updated = 0;
  let batch = db.batch();
  let operations = 0;

  async function commitIfNeeded(force = false) {
    if (operations === 0 || (!force && operations < MAX_BATCH_SIZE)) {
      return;
    }
    if (!dryRun) {
      await batch.commit();
    }
    batch = db.batch();
    operations = 0;
  }

  for (const userDoc of users) {
    const updates = buildUserUpdates(
      userDoc.data() ?? {},
      salonId,
      staffIds,
      clientIds,
    );
    if (!hasUpdates(updates)) {
      continue;
    }
    updated += 1;
    batch.update(userDoc.ref, updates);
    operations += 1;
    await commitIfNeeded();
  }

  await commitIfNeeded(true);
  return updated;
}

async function deleteQueryResults(db, query, recursive = false) {
  let deleted = 0;

  while (true) {
    const snapshot = await query.limit(MAX_BATCH_SIZE).get();
    if (snapshot.empty) {
      return deleted;
    }

    if (recursive) {
      for (const doc of snapshot.docs) {
        await db.recursiveDelete(doc.ref);
      }
    } else {
      const batch = db.batch();
      for (const doc of snapshot.docs) {
        batch.delete(doc.ref);
      }
      await batch.commit();
    }

    deleted += snapshot.size;
    if (snapshot.size < MAX_BATCH_SIZE) {
      return deleted;
    }
  }
}

async function countStorageFiles(bucket, prefix) {
  const [files] = await bucket.getFiles({ prefix });
  return files.length;
}

async function deleteStorageFiles(bucket, prefix) {
  const count = await countStorageFiles(bucket, prefix);
  if (count === 0) {
    return 0;
  }
  await bucket.deleteFiles({ prefix, force: true });
  return count;
}

async function buildPlan(db, bucket, salonId, skipStorage) {
  const rootDocuments = [];
  for (const collectionName of ROOT_DOCUMENT_COLLECTIONS) {
    const ref = db.collection(collectionName).doc(salonId);
    const count =
      collectionName === 'salons'
        ? await countRecursiveDocument(ref)
        : (await ref.get()).exists
          ? 1
          : 0;
    rootDocuments.push({ collectionName, count });
  }

  const queryCollections = [];
  for (const collectionName of COLLECTIONS_BY_SALON_ID) {
    const count = await countQuery(
      db.collection(collectionName).where('salonId', '==', salonId),
    );
    queryCollections.push({ collectionName, count });
  }

  const staffIds = await collectIdsBySalonId(db, 'staff', salonId);
  const clientIds = await collectIdsBySalonId(db, 'clients', salonId);
  const affectedUsers = await collectAffectedUsers(db, salonId, staffIds, clientIds);

  const storagePrefix = `salon_media/${salonId}/`;
  let storageFiles = 0;
  let storageError = null;
  if (!skipStorage && bucket) {
    try {
      storageFiles = await countStorageFiles(bucket, storagePrefix);
    } catch (error) {
      storageError = error.message;
    }
  }

  return {
    rootDocuments,
    queryCollections,
    staffIds,
    clientIds,
    affectedUsers,
    storagePrefix,
    storageFiles,
    storageError,
  };
}

function printPlan(plan, salonId, dryRun, skipStorage, skipClaims, projectId, storageBucket) {
  console.log(`Salon: ${salonId}`);
  console.log(`Project: ${projectId ?? '(default ADC project)'}`);
  console.log(`Mode: ${dryRun ? 'dry-run' : 'DELETE'}`);
  console.log(`Storage: ${skipStorage ? 'skipped' : storageBucket ?? '(default bucket)'}`);
  console.log(`Claims: ${skipClaims ? 'skipped' : 'update affected users'}`);
  console.log('');

  console.log('Root documents:');
  for (const entry of plan.rootDocuments) {
    console.log(`  ${formatCount(entry.count)}  ${entry.collectionName}/${salonId}`);
  }

  console.log('');
  console.log('Collections with salonId:');
  for (const entry of plan.queryCollections) {
    if (entry.count > 0) {
      console.log(`  ${formatCount(entry.count)}  ${entry.collectionName}`);
    }
  }

  console.log('');
  console.log(`Staff ids found: ${plan.staffIds.length}`);
  console.log(`Client ids found: ${plan.clientIds.length}`);
  console.log(`Affected user docs: ${plan.affectedUsers.length}`);

  if (!skipStorage) {
    if (plan.storageError) {
      console.log(`Storage files: unable to count (${plan.storageError})`);
    } else {
      console.log(`Storage files under ${plan.storagePrefix}: ${plan.storageFiles}`);
    }
  }

  if (dryRun) {
    console.log('');
    console.log(`Dry-run only. To delete, rerun with --confirm=${salonId}`);
  }
}

async function executeDeletion(db, auth, bucket, plan, salonId, skipStorage, skipClaims) {
  if (plan.storageError && !skipStorage) {
    throw new Error(`Storage check failed. Rerun with --skipStorage to ignore it. ${plan.storageError}`);
  }

  let deletedStorageFiles = 0;
  if (!skipStorage && bucket) {
    deletedStorageFiles = await deleteStorageFiles(bucket, plan.storagePrefix);
    console.log(`Deleted ${deletedStorageFiles} Storage files under ${plan.storagePrefix}`);
  }

  const staffIdSet = new Set(plan.staffIds);
  const clientIdSet = new Set(plan.clientIds);
  const updatedUsers = await updateAffectedUsers(
    db,
    plan.affectedUsers,
    salonId,
    staffIdSet,
    clientIdSet,
    false,
  );
  console.log(`Updated ${updatedUsers} user documents`);

  if (!skipClaims) {
    const claimsResult = await updateAuthClaimsForUsers(
      auth,
      plan.affectedUsers,
      salonId,
      staffIdSet,
      clientIdSet,
      false,
    );
    console.log(
      `Updated ${claimsResult.updated} Auth claim sets (${claimsResult.missing} missing Auth users)`,
    );
  }

  for (const collectionName of COLLECTIONS_BY_SALON_ID) {
    const deleted = await deleteQueryResults(
      db,
      db.collection(collectionName).where('salonId', '==', salonId),
      RECURSIVE_DELETE_COLLECTIONS.has(collectionName),
    );
    if (deleted > 0) {
      console.log(`Deleted ${deleted} docs from ${collectionName}`);
    }
  }

  for (const collectionName of ROOT_DOCUMENT_COLLECTIONS) {
    const ref = db.collection(collectionName).doc(salonId);
    await db.recursiveDelete(ref);
    console.log(`Deleted ${collectionName}/${salonId}`);
  }

  return { deletedStorageFiles, updatedUsers };
}

async function main() {
  const params = parseArgs();
  if (params.help) {
    printHelp();
    return;
  }

  const salonId = normalizeString(params.salonId);
  if (!salonId) {
    printHelp();
    throw new Error('Missing required --salonId=<id>');
  }

  if (params.confirm && normalizeString(params.confirm) !== salonId) {
    throw new Error('--confirm must exactly match --salonId');
  }

  const dryRun = Boolean(params.dryRun) || normalizeString(params.confirm) !== salonId;
  const skipStorage = Boolean(params.skipStorage);
  const skipClaims = Boolean(params.skipClaims);
  const projectId = resolveProjectId(params);
  const storageBucket = skipStorage ? undefined : resolveStorageBucket(params);

  const app = ensureInitialized({ projectId, storageBucket });
  const db = app.firestore();
  const auth = app.auth();
  const bucket = skipStorage ? null : app.storage().bucket();

  const plan = await buildPlan(db, bucket, salonId, skipStorage);
  printPlan(plan, salonId, dryRun, skipStorage, skipClaims, projectId, storageBucket);

  if (dryRun) {
    return;
  }

  console.log('');
  console.log('Deleting...');
  await executeDeletion(db, auth, bucket, plan, salonId, skipStorage, skipClaims);
  console.log('Deletion completed.');
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
