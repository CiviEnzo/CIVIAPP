#!/usr/bin/env node
/**
 * Backfill helper to ensure every client document has a populated `createdAt`
 * timestamp and a normalized `city` field.
 *
 * Usage:
 *   node functions/scripts/backfill_clients_created_at_city.js [--salonIds=salon-001,salon-002] [--clientIds=client-1,client-2] [--batchSize=500] [--dryRun]
 *
 * Requirements:
 * - Configure Application Default Credentials (ADC) via GOOGLE_APPLICATION_CREDENTIALS
 *   or `gcloud auth application-default login`.
 * - Run from the project root (same level as the `functions/` folder).
 */

const admin = require('firebase-admin');

const DEFAULT_BATCH_SIZE = 500;

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

function parseList(value) {
  if (!value || typeof value !== 'string') {
    return new Set();
  }
  return new Set(
    value
      .split(',')
      .map((item) => item.trim())
      .filter((item) => item.length > 0),
  );
}

function ensureInitialized() {
  if (admin.apps.length) {
    return admin.app();
  }
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
  });
  return admin.app();
}

function sanitizeString(value) {
  if (typeof value !== 'string') {
    return '';
  }
  return value.trim();
}

function buildClientUpdate(doc) {
  const data = doc.data() ?? {};
  const updates = {};

  const hasCreatedAt =
    data.createdAt instanceof admin.firestore.Timestamp ||
    data.createdAt instanceof Date;
  if (!hasCreatedAt) {
    const fallbackTimestamp = doc.createTime || doc.updateTime;
    if (fallbackTimestamp) {
      updates.createdAt =
        fallbackTimestamp instanceof admin.firestore.Timestamp
          ? fallbackTimestamp
          : admin.firestore.Timestamp.fromDate(fallbackTimestamp);
    } else {
      updates.createdAt = admin.firestore.FieldValue.serverTimestamp();
    }
  }

  const rawCity = sanitizeString(data.city);
  const rawAddress = sanitizeString(data.address);
  if (rawCity) {
    if (rawCity !== data.city) {
      updates.city = rawCity;
    }
  } else if (rawAddress) {
    updates.city = rawAddress;
  }

  if (rawAddress && rawAddress !== data.address) {
    updates.address = rawAddress;
  }

  return updates;
}

async function processClientDocs({
  db,
  dryRun,
  salonFilter,
  batchSize,
  startAfter,
}) {
  let query = db
    .collection('clients')
    .orderBy(admin.firestore.FieldPath.documentId())
    .limit(batchSize);
  if (startAfter) {
    query = query.startAfter(startAfter);
  }

  const snapshot = await query.get();
  if (snapshot.empty) {
    return { lastDoc: null, processed: 0, updated: 0 };
  }

  const batch = db.batch();
  let processed = 0;
  let updated = 0;

  for (const doc of snapshot.docs) {
    processed += 1;
    const data = doc.data() ?? {};
    if (salonFilter.size > 0 && !salonFilter.has(data.salonId)) {
      continue;
    }
    const updates = buildClientUpdate(doc);
    if (Object.keys(updates).length === 0) {
      continue;
    }
    updated += 1;
    if (dryRun) {
      console.log(
        `[DRY RUN] Would update client ${doc.id}: ${JSON.stringify(updates)}`,
      );
    } else {
      batch.update(doc.ref, updates);
    }
  }

  if (!dryRun && updated > 0) {
    await batch.commit();
  }

  const lastDoc = snapshot.docs[snapshot.docs.length - 1];
  return { lastDoc, processed, updated };
}

async function processSpecificClientIds({ db, dryRun, clientIds, salonFilter }) {
  let processed = 0;
  let updated = 0;
  const batch = db.batch();

  for (const clientId of clientIds) {
    const doc = await db.collection('clients').doc(clientId).get();
    processed += 1;
    if (!doc.exists) {
      console.warn(`Client ${clientId} not found, skipping.`);
      continue;
    }
    const data = doc.data() ?? {};
    if (salonFilter.size > 0 && !salonFilter.has(data.salonId)) {
      continue;
    }
    const updates = buildClientUpdate(doc);
    if (Object.keys(updates).length === 0) {
      continue;
    }
    updated += 1;
    if (dryRun) {
      console.log(
        `[DRY RUN] Would update client ${doc.id}: ${JSON.stringify(updates)}`,
      );
    } else {
      batch.update(doc.ref, updates);
      if (updated % DEFAULT_BATCH_SIZE === 0) {
        await batch.commit();
      }
    }
  }

  if (!dryRun && updated > 0) {
    await batch.commit();
  }

  return { processed, updated };
}

async function main() {
  const params = parseArgs();
  const dryRun = Boolean(params.dryRun);
  const batchSize =
    Number.parseInt(params.batchSize, 10) > 0
      ? Number.parseInt(params.batchSize, 10)
      : DEFAULT_BATCH_SIZE;
  const salonFilter = parseList(params.salonIds);
  const clientFilter = parseList(params.clientIds);

  ensureInitialized();
  const db = admin.firestore();

  let totalProcessed = 0;
  let totalUpdated = 0;

  if (clientFilter.size > 0) {
    console.log(
      `Processing explicit clientIds (${clientFilter.size}) with batch size ${batchSize}${dryRun ? ' [DRY RUN]' : ''}...`,
    );
    const { processed, updated } = await processSpecificClientIds({
      db,
      dryRun,
      clientIds: clientFilter,
      salonFilter,
    });
    totalProcessed += processed;
    totalUpdated += updated;
  } else {
    console.log(
      `Scanning clients collection in batches of ${batchSize}${dryRun ? ' [DRY RUN]' : ''}...`,
    );
    let cursor = null;
    // eslint-disable-next-line no-constant-condition
    while (true) {
      const { lastDoc, processed, updated } = await processClientDocs({
        db,
        dryRun,
        salonFilter,
        batchSize,
        startAfter: cursor,
      });
      totalProcessed += processed;
      totalUpdated += updated;
      if (!lastDoc || processed < batchSize) {
        break;
      }
      cursor = lastDoc;
    }
  }

  console.log(
    `Completed. Processed ${totalProcessed} clients, updated ${totalUpdated}.`,
  );

  if (dryRun) {
    console.log('No changes were written (dry run).');
  }

  process.exit(0);
}

main().catch((error) => {
  console.error('Backfill failed:', error);
  process.exit(1);
});
