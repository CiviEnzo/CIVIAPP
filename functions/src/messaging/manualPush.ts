import { getMessaging } from 'firebase-admin/messaging';
import * as functions from 'firebase-functions';
import * as logger from 'firebase-functions/logger';

import { db, FieldValue } from '../utils/firestore';

type CallableData = {
  salonId: unknown;
  clientIds: unknown;
  title: unknown;
  body: unknown;
  data?: Record<string, unknown>;
};

interface Recipient {
  clientId: string;
  tokens: string[];
}

const INVALID_TOKEN_ERRORS = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
  'messaging/invalid-argument',
]);

const normalizeString = (value: unknown): string => {
  if (typeof value !== 'string') {
    return '';
  }
  return value.trim();
};

const sanitizeDataPayload = (input: Record<string, unknown> | undefined): Record<string, string> => {
  const sanitized: Record<string, string> = {};
  if (!input) {
    return sanitized;
  }
  Object.entries(input).forEach(([rawKey, rawValue]) => {
    const key = normalizeString(rawKey);
    if (!key) {
      return;
    }
    if (rawValue === null || rawValue === undefined) {
      return;
    }
    sanitized[key] = typeof rawValue === 'string' ? rawValue : String(rawValue);
  });
  return sanitized;
};

const extractSalonIds = (claims: unknown): string[] => {
  if (!Array.isArray(claims)) {
    return [];
  }
  const ids = new Set<string>();
  claims.forEach((value) => {
    const normalized = normalizeString(value);
    if (normalized) {
      ids.add(normalized);
    }
  });
  return Array.from(ids);
};

const chunkArray = <T>(input: T[], size: number): T[][] => {
  if (size <= 0) {
    return [input];
  }
  const chunks: T[][] = [];
  for (let index = 0; index < input.length; index += size) {
    chunks.push(input.slice(index, index + size));
  }
  return chunks;
};

const functionsEU = functions.region('europe-west1');

const normalizeRole = (value: unknown): string | null => {
  const normalized = normalizeString(value);
  return normalized ? normalized.toLowerCase() : null;
};

interface UserContext {
  role: string | null;
  salonIds: string[];
  raw: Record<string, unknown>;
}

const normalizeSalonIds = (primary: unknown, fallback?: unknown): string[] => {
  const ids = new Set<string>();
  const add = (candidate: unknown) => {
    const normalized = normalizeString(candidate);
    if (normalized) {
      ids.add(normalized);
    }
  };
  if (Array.isArray(primary)) {
    primary.forEach(add);
  } else {
    add(primary);
  }
  if (ids.size === 0) {
    if (Array.isArray(fallback)) {
      fallback.forEach(add);
    } else {
      add(fallback);
    }
  }
  return Array.from(ids);
};

const loadUserContext = async (userId: string): Promise<UserContext | null> => {
  try {
    const snapshot = await db.collection('users').doc(userId).get();
    if (!snapshot.exists) {
      return null;
    }
    const data = snapshot.data() ?? {};
    const {
      salonIds,
      managedSalonIds,
      joinedSalonIds,
      salonId,
      primarySalonId,
    } = data;
    const aggregatedSalonIds = normalizeSalonIds(
      salonIds,
      normalizeSalonIds(
        managedSalonIds,
        normalizeSalonIds(joinedSalonIds, normalizeSalonIds(primarySalonId, salonId)),
      ),
    );
    return {
      role: normalizeRole(data.role),
      salonIds: aggregatedSalonIds,
      raw: data,
    };
  } catch (error) {
    logger.error('Unable to load user context', { userId, error });
    return null;
  }
};

export const sendManualPushNotification = functionsEU.https.onCall(async (data: CallableData, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'È richiesta l\'autenticazione.');
  }

  const userId = context.auth.uid;
  const claimsRole = normalizeRole(context.auth.token?.role);
  const claimsSalonIds = extractSalonIds(context.auth.token?.salonIds);
  const userContext = await loadUserContext(userId);

  if (!userContext) {
    logger.warn('User context not found for manual push', {
      userId,
      claimsRole,
      claimsSalonIds,
    });
    throw new functions.https.HttpsError(
      'permission-denied',
      'Solo admin o staff possono inviare notifiche manuali.',
    );
  }

  const resolvedRole = userContext.role ?? claimsRole;
  if (resolvedRole !== 'admin' && resolvedRole !== 'staff') {
    logger.warn('User not allowed to send manual push', {
      userId,
      resolvedRole,
      claimsRole,
      profileRole: userContext.role,
    });
    throw new functions.https.HttpsError(
      'permission-denied',
      'Solo admin o staff possono inviare notifiche manuali.',
    );
  }

  const salonId = normalizeString(data?.salonId);
  if (!salonId) {
    throw new functions.https.HttpsError('invalid-argument', 'È necessario indicare un salonId valido.');
  }

  let allowedSalonIds = userContext.salonIds;
  if (allowedSalonIds.length === 0) {
    allowedSalonIds = claimsSalonIds;
  }
  if (allowedSalonIds.length > 0 && !allowedSalonIds.includes(salonId)) {
    logger.warn('Salon permission denied for user', {
      userId,
      salonId,
      allowedSalonIds,
      profileSalonIds: userContext.salonIds,
      claimsSalonIds,
    });
    throw new functions.https.HttpsError(
      'permission-denied',
      'Non hai i permessi per inviare notifiche a questo salone.',
    );
  }

  if (!Array.isArray(data?.clientIds) || data.clientIds.length === 0) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'clientIds deve essere una lista con almeno un elemento.',
    );
  }

  const clientIds = data.clientIds
    .map((value) => normalizeString(value))
    .filter((value) => value.length > 0);

  if (!clientIds.length) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'clientIds deve contenere identificativi validi.',
    );
  }

  const title = normalizeString(data?.title);
  const body = normalizeString(data?.body);
  if (!title || !body) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Titolo e corpo della notifica sono obbligatori.',
    );
  }

  const dataPayload = sanitizeDataPayload(data?.data);
  if (!dataPayload.type) {
    dataPayload.type = 'manual_notification';
  }
  dataPayload.salonId = salonId;

  const clientDocs = await Promise.all(
    clientIds.map((clientId) => db.collection('clients').doc(clientId).get()),
  );

  const recipients: Recipient[] = [];
  const skippedClients: string[] = [];

  clientDocs.forEach((doc, index) => {
    const clientId = clientIds[index];
    if (!doc.exists) {
      skippedClients.push(clientId);
      return;
    }
    const data = doc.data() ?? {};
    const clientSalon = normalizeString(data.salonId);
    if (clientSalon && clientSalon !== salonId) {
      skippedClients.push(clientId);
      return;
    }
    const channelPreferences = (data.channelPreferences ?? {}) as { push?: boolean };
    if (channelPreferences.push === false) {
      skippedClients.push(clientId);
      return;
    }
    const tokensRaw = data.fcmTokens;
    const tokens = Array.isArray(tokensRaw)
      ? Array.from(
          new Set(
            tokensRaw
              .map((token) => normalizeString(token))
              .filter((token) => token.length > 0),
          ),
        )
      : [];
    if (!tokens.length) {
      skippedClients.push(clientId);
      return;
    }
    recipients.push({ clientId, tokens });
  });

  if (!recipients.length) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Nessun cliente con notifiche push abilitate o token valido.',
      { skippedClients },
    );
  }

  let successCount = 0;
  let failureCount = 0;
  let invalidTokenCount = 0;
  const tokensToRemove: Array<{ clientId: string; tokens: string[] }> = [];
  const outboxEntries: Array<{
    clientId: string;
    messageId: string;
    payload: Record<string, string>;
    success: number;
    failure: number;
    invalid: number;
  }> = [];

  for (const recipient of recipients) {
    const messageId = `manual_${Date.now()}_${recipient.clientId}_${Math.random()
      .toString(16)
      .slice(2, 8)}`;
    const payload = {
      ...dataPayload,
      clientId: recipient.clientId,
      messageId,
      title,
      body,
      sentAt: new Date().toISOString(),
    };

    const tokenChunks = chunkArray(recipient.tokens, 500);
    let recipientSuccess = 0;
    let recipientFailure = 0;
    let recipientInvalid = 0;

    for (const chunk of tokenChunks) {
      try {
        const response = await getMessaging().sendEachForMulticast({
          tokens: chunk,
          notification: body ? { title, body } : undefined,
          data: payload,
          android: {
            priority: 'high',
            notification: {
              sound: 'default',
              channelId: 'civiapp_push',
            },
          },
          apns: {
            headers: {
              'apns-push-type': 'alert',
              'apns-priority': '10',
            },
            payload: {
              aps: {
                sound: 'default',
              },
            },
          },
        });

        recipientSuccess += response.successCount;
        recipientFailure += response.failureCount;
        successCount += response.successCount;
        failureCount += response.failureCount;

        const invalidTokens: string[] = [];
        response.responses.forEach((res, index) => {
          if (res.success) {
            return;
          }
          const errorCode = res.error?.code;
          if (errorCode && INVALID_TOKEN_ERRORS.has(errorCode)) {
            const token = chunk[index];
            if (token) {
              invalidTokens.push(token);
            }
          }
        });

        if (invalidTokens.length) {
          tokensToRemove.push({ clientId: recipient.clientId, tokens: invalidTokens });
          invalidTokenCount += invalidTokens.length;
          recipientInvalid += invalidTokens.length;
        }
      } catch (error) {
        failureCount += chunk.length;
        recipientFailure += chunk.length;
        logger.error(
          'Errore durante l\'invio manuale della notifica',
          error instanceof Error ? error : new Error(String(error)),
          { clientId: recipient.clientId },
        );
      }
    }
    outboxEntries.push({
      clientId: recipient.clientId,
      messageId,
      payload,
      success: recipientSuccess,
      failure: recipientFailure,
      invalid: recipientInvalid,
    });
  }

  await Promise.all(
    tokensToRemove.map((entry) =>
      db
        .collection('clients')
        .doc(entry.clientId)
        .update({ fcmTokens: FieldValue.arrayRemove(...entry.tokens) })
        .catch((error) => {
          logger.warn('Impossibile rimuovere token invalidi', {
            clientId: entry.clientId,
            error,
          });
        }),
    ),
  );

  const outboxCollection = db.collection('message_outbox');
  await Promise.all(
    outboxEntries.map((entry) =>
      outboxCollection.add({
        salonId,
        clientId: entry.clientId,
        channel: 'push',
        status: entry.success > 0 ? 'sent' : 'failed',
        type: dataPayload.type ?? 'manual_notification',
        title,
        body,
        payload: entry.payload,
        metadata: {
          source: 'manual_push',
          messageId: entry.messageId,
          successCount: entry.success,
          failureCount: entry.failure,
          invalidTokenCount: entry.invalid,
        },
        createdAt: FieldValue.serverTimestamp(),
        scheduledAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        sentAt: entry.success > 0 ? FieldValue.serverTimestamp() : null,
        traces: [],
      }),
    ),
  );

  logger.info('Notifiche manuali inviate', {
    salonId,
    recipients: recipients.length,
    successCount,
    failureCount,
    invalidTokenCount,
    skippedClients,
  });

  return {
    successCount,
    failureCount,
    invalidTokenCount,
    skippedClients,
  };
});
