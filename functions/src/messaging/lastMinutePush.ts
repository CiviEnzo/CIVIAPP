import { getMessaging } from "firebase-admin/messaging";
import type { DocumentSnapshot } from "firebase-admin/firestore";
import * as functions from "firebase-functions";
import * as logger from "firebase-functions/logger";

import { db, FieldValue } from "../utils/firestore";

type CallableAudience = "none" | "everyone" | "ownerSelection";

type CallableData = {
  slotId?: unknown;
  salonId?: unknown;
  audience?: unknown;
  clientIds?: unknown;
};

interface Recipient {
  clientId: string;
  tokens: string[];
}

interface UserContext {
  role: string | null;
  salonIds: string[];
  raw: Record<string, unknown>;
}

const functionsEU = functions.region("europe-west1");

const INVALID_TOKEN_ERRORS = new Set([
  "messaging/registration-token-not-registered",
  "messaging/invalid-registration-token",
  "messaging/invalid-argument",
]);

const normalizeString = (value: unknown): string => {
  if (typeof value !== "string") {
    return "";
  }
  return value.trim();
};

const normalizeRole = (value: unknown): string | null => {
  const normalized = normalizeString(value);
  return normalized ? normalized.toLowerCase() : null;
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
    const snapshot = await db.collection("users").doc(userId).get();
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
        normalizeSalonIds(
          joinedSalonIds,
          normalizeSalonIds(primarySalonId, salonId),
        ),
      ),
    );
    return {
      role: normalizeRole(data.role),
      salonIds: aggregatedSalonIds,
      raw: data,
    };
  } catch (error) {
    logger.error("Unable to load user context", { userId, error });
    return null;
  }
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

const coerceAudience = (value: unknown): CallableAudience => {
  const normalized = normalizeString(value).toLowerCase();
  if (normalized === "ownerselection") {
    return "ownerSelection";
  }
  if (normalized === "everyone") {
    return "everyone";
  }
  if (normalized === "none") {
    return "none";
  }
  return "everyone";
};

const coerceClientIds = (value: unknown): string[] => {
  if (!Array.isArray(value)) {
    return [];
  }
  const ids = new Set<string>();
  value.forEach((item) => {
    const normalized = normalizeString(item);
    if (normalized) {
      ids.add(normalized);
    }
  });
  return Array.from(ids);
};

const parseTimestamp = (value: unknown): Date | null => {
  if (!value) {
    return null;
  }
  if (typeof value === "string") {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }
  if (value instanceof Date) {
    return value;
  }
  if (typeof value === "object" && value !== null) {
    const maybeTimestamp = value as { toDate?: () => Date };
    if (typeof maybeTimestamp.toDate === "function") {
      const parsed = maybeTimestamp.toDate();
      return parsed instanceof Date ? parsed : null;
    }
  }
  return null;
};

const formatPrice = (value: unknown): string => {
  const price =
    typeof value === "number" ? value : Number.parseFloat(String(value ?? "0"));
  if (!Number.isFinite(price)) {
    return "0,00";
  }
  return price.toFixed(2).replace(".", ",");
};

const formatTimeLabel = (date: Date): { day: string; time: string } => {
  const day = date.toLocaleDateString("it-IT", {
    weekday: "short",
    day: "2-digit",
    month: "2-digit",
  });
  const time = date.toLocaleTimeString("it-IT", {
    hour: "2-digit",
    minute: "2-digit",
  });
  return { day, time };
};

const collectRecipients = async (
  salonId: string,
  audience: CallableAudience,
  candidateIds: string[],
): Promise<{ recipients: Recipient[]; skipped: string[] }> => {
  if (audience === "ownerSelection") {
    const docs = await Promise.all(
      candidateIds.map((clientId) =>
        db.collection("clients").doc(clientId).get(),
      ),
    );
    return buildRecipientsFromDocs(salonId, docs, candidateIds);
  }
  const snapshot = await db
    .collection("clients")
    .where("salonId", "==", salonId)
    .get();
  return buildRecipientsFromDocs(
    salonId,
    snapshot.docs,
    snapshot.docs.map((doc) => doc.id),
  );
};

const buildRecipientsFromDocs = (
  salonId: string,
  docs: Array<DocumentSnapshot<Record<string, unknown>>>,
  clientIds: string[],
): { recipients: Recipient[]; skipped: string[] } => {
  const recipients: Recipient[] = [];
  const skipped: string[] = [];
  docs.forEach((doc, index) => {
    const clientId = doc.id ?? clientIds[index];
    if (!doc.exists) {
      if (clientId) {
        skipped.push(clientId);
      }
      return;
    }
    const data = doc.data() ?? {};
    const clientSalon = normalizeString(data.salonId);
    if (clientSalon && clientSalon !== salonId) {
      skipped.push(clientId);
      return;
    }
    const channelPreferences = (data.channelPreferences ?? {}) as {
      push?: boolean;
    };
    if (channelPreferences.push === false) {
      skipped.push(clientId);
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
      skipped.push(clientId);
      return;
    }
    recipients.push({ clientId, tokens });
  });
  return { recipients, skipped };
};

export const notifyLastMinuteSlot = functionsEU.https.onCall(
  async (data: CallableData, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "È richiesta l'autenticazione.",
      );
    }

    const slotId = normalizeString(data?.slotId);
    if (!slotId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Devi indicare uno slotId valido.",
      );
    }

    const requestedSalonId = normalizeString(data?.salonId);
    const audience = coerceAudience(data?.audience);
    const clientIds = coerceClientIds(data?.clientIds);

    if (audience === "ownerSelection" && clientIds.length === 0) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Specifica almeno un destinatario per l'invio manuale.",
      );
    }

    if (audience === "none") {
      return {
        successCount: 0,
        failureCount: 0,
        skippedCount: 0,
        skippedClients: [],
        audience,
      };
    }

    const userId = context.auth.uid;
    const claimsRole = normalizeRole(context.auth.token?.role);
    const claimsSalonIds = extractSalonIds(context.auth.token?.salonIds);
    const userContext = await loadUserContext(userId);

    if (!userContext) {
      logger.warn("User context not found for notifyLastMinuteSlot", {
        userId,
        claimsRole,
        claimsSalonIds,
      });
      throw new functions.https.HttpsError(
        "permission-denied",
        "Solo admin o staff possono inviare notifiche last-minute.",
      );
    }

    const resolvedRole = userContext.role ?? claimsRole;
    if (resolvedRole !== "admin" && resolvedRole !== "staff") {
      logger.warn("User not allowed to send last-minute notifications", {
        userId,
        resolvedRole,
      });
      throw new functions.https.HttpsError(
        "permission-denied",
        "Solo admin o staff possono inviare notifiche last-minute.",
      );
    }

    const slotSnapshot = await db
      .collection("last_minute_slots")
      .doc(slotId)
      .get();
    if (!slotSnapshot.exists) {
      throw new functions.https.HttpsError(
        "not-found",
        "Slot last-minute non trovato.",
      );
    }

    const slotData = slotSnapshot.data() ?? {};
    const slotSalonId = normalizeString(slotData.salonId) || requestedSalonId;
    if (!slotSalonId) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Lo slot non specifica un salonId. Impossibile inviare la notifica.",
      );
    }

    let allowedSalonIds = userContext.salonIds;
    if (!allowedSalonIds.length) {
      allowedSalonIds = claimsSalonIds;
    }
    if (allowedSalonIds.length > 0 && !allowedSalonIds.includes(slotSalonId)) {
      logger.warn("Salon permission denied for last-minute notification", {
        userId,
        salonId: slotSalonId,
        allowedSalonIds,
      });
      throw new functions.https.HttpsError(
        "permission-denied",
        "Non hai i permessi per questo salone.",
      );
    }

    const startDate =
      parseTimestamp(slotData.startAt ?? slotData.start) ?? new Date();
    const serviceName =
      normalizeString(slotData.serviceName) || "Slot last-minute";
    const discountPct = Number.parseFloat(
      String(slotData.discountPct ?? slotData.discountPercentage ?? 0),
    );
    const priceNow = slotData.priceNow ?? slotData.price ?? 0;
    const availableSeats = Number(
      slotData.availableSeats ?? slotData.seats ?? 1,
    );

    const { day, time } = formatTimeLabel(startDate);
    const priceLabel = formatPrice(priceNow);
    const discountLabel =
      Number.isFinite(discountPct) && discountPct > 0
        ? ` • -${discountPct}%`
        : "";
    const seatsLabel = availableSeats > 1 ? ` • ${availableSeats} posti` : "";

    const title = `Last-minute: ${serviceName}`;
    const body = `${day} ${time} • ${priceLabel}€${discountLabel}${seatsLabel}`;

    const { recipients, skipped } = await collectRecipients(
      slotSalonId,
      audience,
      clientIds,
    );

    if (!recipients.length) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Nessun cliente con notifiche push abilitate o token valido.",
        { skippedClients: skipped },
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
      const messageId = `lastminute_${slotId}_${recipient.clientId}_${Date.now()}`;
      const payload: Record<string, string> = {
        type: "last_minute_slot",
        slotId,
        salonId: slotSalonId,
        startAt: startDate.toISOString(),
        serviceName,
        priceNow: String(priceNow ?? ""),
        discountPct: String(Number.isFinite(discountPct) ? discountPct : 0),
        availableSeats: String(availableSeats),
        title,
        body,
        messageId,
      };

      const tokenChunks = chunkArray(recipient.tokens, 500);
      let recipientSuccess = 0;
      let recipientFailure = 0;
      let recipientInvalid = 0;

      for (const chunk of tokenChunks) {
        try {
          const response = await getMessaging().sendEachForMulticast({
            tokens: chunk,
            notification: { title, body },
            data: payload,
            android: {
              priority: "high",
              notification: {
                sound: "default",
                channelId: "civiapp_push",
              },
            },
            apns: {
              headers: {
                "apns-push-type": "alert",
                "apns-priority": "10",
              },
              payload: {
                aps: {
                  sound: "default",
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
            tokensToRemove.push({
              clientId: recipient.clientId,
              tokens: invalidTokens,
            });
            invalidTokenCount += invalidTokens.length;
            recipientInvalid += invalidTokens.length;
          }
        } catch (error) {
          failureCount += chunk.length;
          recipientFailure += chunk.length;
          logger.error(
            "Errore durante l'invio della notifica last-minute",
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
          .collection("clients")
          .doc(entry.clientId)
          .update({ fcmTokens: FieldValue.arrayRemove(...entry.tokens) })
          .catch((error) => {
            logger.warn("Impossibile rimuovere token invalidi", {
              clientId: entry.clientId,
              error,
            });
          }),
      ),
    );

    const outboxCollection = db.collection("message_outbox");
    await Promise.all(
      outboxEntries.map((entry) =>
        outboxCollection.add({
          salonId: slotSalonId,
          clientId: entry.clientId,
          channel: "push",
          status: entry.success > 0 ? "sent" : "failed",
          type: "last_minute_slot",
          title,
          body,
          payload: entry.payload,
          metadata: {
            source: "notify_last_minute_slot",
            slotId,
            messageId: entry.messageId,
            audience,
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

    logger.info("Notifica last-minute inviata", {
      slotId,
      salonId: slotSalonId,
      recipients: recipients.length,
      successCount,
      failureCount,
      invalidTokenCount,
      skippedCount: skipped.length,
    });

    return {
      successCount,
      failureCount,
      invalidTokenCount,
      skippedCount: skipped.length,
      skippedClients: skipped,
      recipients: recipients.length,
      audience,
    };
  },
);
