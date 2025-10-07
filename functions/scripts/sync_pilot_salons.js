#!/usr/bin/env node
/**
 * Sync pilot salons with feature flags, promotions and last-minute slots.
 *
 * Usage:
 *   node functions/scripts/sync_pilot_salons.js --config=./functions/scripts/pilot_salons.example.json [--dryRun]
 *
 * Requirements:
 * - Set GOOGLE_APPLICATION_CREDENTIALS to a service account JSON with Firestore access, or login via `gcloud auth application-default login`.
 * - Run from the project root (same level as `functions/`).
 */

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

function parseArgs() {
  const args = process.argv.slice(2);
  const params = {};
  for (const arg of args) {
    if (arg.startsWith('--')) {
      const [key, value] = arg.split('=');
      const normalizedKey = key.replace(/^--/, '');
      if (value === undefined) {
        params[normalizedKey] = true;
      } else {
        params[normalizedKey] = value;
      }
    }
  }
  return params;
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
      `Unable to initialize Firebase Admin SDK. Make sure GOOGLE_APPLICATION_CREDENTIALS is set or ADC is configured. Original error: ${error.message}`,
    );
  }
  return admin.app();
}

function toTimestamp(value, fieldName) {
  if (value == null) {
    return null;
  }
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) {
    throw new Error(`Invalid date value for ${fieldName}: ${value}`);
  }
  return admin.firestore.Timestamp.fromDate(date);
}

async function upsertSalonFeatureFlags(db, salonId, featureFlags, dryRun) {
  if (!featureFlags) {
    return;
  }
  const docRef = db.collection('salons').doc(salonId);
  if (dryRun) {
    console.log(`[dryRun] Would update salons/${salonId} featureFlags`, featureFlags);
    return;
  }
  await docRef.set({ featureFlags }, { merge: true });
  console.log(`Updated salons/${salonId} featureFlags`);
}

async function replaceCollection(db, collectionName, salonId, documents, dryRun) {
  if (!Array.isArray(documents)) {
    return;
  }

  const collectionRef = db.collection(collectionName);
  if (!dryRun) {
    const snapshot = await collectionRef.where('salonId', '==', salonId).get();
    const batch = db.batch();
    snapshot.forEach((doc) => batch.delete(doc.ref));
    if (!snapshot.empty) {
      await batch.commit();
      console.log(`Removed ${snapshot.size} existing ${collectionName} for ${salonId}`);
    }
  } else {
    console.log(`[dryRun] Would delete existing ${collectionName} for ${salonId}`);
  }

  for (const document of documents) {
    if (!document.id) {
      throw new Error(`Missing id for document in ${collectionName} (salon ${salonId}).`);
    }
    const docRef = collectionRef.doc(document.id);
    const payload = { ...document, salonId };

    if (collectionName === 'promotions') {
      payload.startsAt = toTimestamp(document.startsAt, 'promotion.startsAt');
      payload.endsAt = toTimestamp(document.endsAt, 'promotion.endsAt');
    }

    if (collectionName === 'last_minute_slots') {
      payload.startAt = toTimestamp(document.startAt ?? document.start, 'slot.startAt');
      payload.createdAt = toTimestamp(document.createdAt, 'slot.createdAt');
      payload.updatedAt = toTimestamp(document.updatedAt, 'slot.updatedAt');
      payload.windowStart = toTimestamp(document.windowStart, 'slot.windowStart');
      payload.windowEnd = toTimestamp(document.windowEnd, 'slot.windowEnd');
      if (typeof payload.durationMinutes !== 'number') {
        throw new Error(`Missing durationMinutes for last-minute slot ${document.id}`);
      }
    }

    if (dryRun) {
      console.log(`[dryRun] Would upsert ${collectionName}/${document.id}`, payload);
    } else {
      await docRef.set(payload, { merge: true });
      console.log(`Upserted ${collectionName}/${document.id}`);
    }
  }
}

async function syncPilotSalons(config, dryRun = false) {
  const app = ensureInitialized();
  const db = app.firestore();

  if (!Array.isArray(config.salons) || config.salons.length === 0) {
    console.log('No salons defined in config. Nothing to do.');
    return;
  }

  for (const salon of config.salons) {
    if (!salon.id) {
      throw new Error('Each salon entry must include an "id".');
    }
    console.log(`\n=== Syncing salon ${salon.id} ===`);
    await upsertSalonFeatureFlags(db, salon.id, salon.featureFlags, dryRun);
    if (Array.isArray(salon.promotions)) {
      await replaceCollection(db, 'promotions', salon.id, salon.promotions, dryRun);
    }
    if (Array.isArray(salon.lastMinuteSlots)) {
      await replaceCollection(
        db,
        'last_minute_slots',
        salon.id,
        salon.lastMinuteSlots,
        dryRun,
      );
    }
  }
}

(async function run() {
  try {
    const params = parseArgs();
    const configPath = params.config;
    const dryRun = Boolean(params.dryRun);
    if (!configPath) {
      throw new Error('Missing required --config path to JSON file.');
    }
    const config = loadConfig(configPath);
    await syncPilotSalons(config, dryRun);
    console.log('\nSync completed.');
    process.exit(0);
  } catch (error) {
    console.error(`\nSync failed: ${error.message}`);
    process.exit(1);
  }
})();
