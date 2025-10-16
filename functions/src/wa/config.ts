import * as logger from 'firebase-functions/logger';

import { db } from '../utils/firestore';

export interface SalonWhatsAppConfig {
  salonId: string;
  mode: 'own' | 'shared';
  businessId: string;
  wabaId: string;
  phoneNumberId: string;
  tokenSecretId: string;
  verifyTokenSecretId?: string;
  displayPhoneNumber?: string;
  defaultLanguage?: string;
}

interface SalonDocument {
  whatsapp?: Partial<SalonWhatsAppConfig>;
}

const salonsCollection = db.collection('salons');

function mapSalonConfig(
  salonId: string,
  data: SalonDocument,
): SalonWhatsAppConfig | null {
  const wa = data.whatsapp;
  if (!wa) {
    return null;
  }

  const mode = (wa.mode ?? 'own') as SalonWhatsAppConfig['mode'];
  const businessId = String(wa.businessId ?? '');
  const wabaId = String(wa.wabaId ?? '');
  const phoneNumberId = String(wa.phoneNumberId ?? '');
  const tokenSecretId = String(wa.tokenSecretId ?? '');

  if (!businessId || !wabaId || !phoneNumberId || !tokenSecretId) {
    logger.warn('Incomplete WhatsApp configuration for salon', {
      salonId,
      businessId,
      wabaId,
      phoneNumberId,
      tokenSecretIdPresent: Boolean(tokenSecretId),
    });
    return null;
  }

  return {
    salonId,
    mode,
    businessId,
    wabaId,
    phoneNumberId,
    tokenSecretId,
    verifyTokenSecretId: wa.verifyTokenSecretId
      ? String(wa.verifyTokenSecretId)
      : undefined,
    displayPhoneNumber: wa.displayPhoneNumber
      ? String(wa.displayPhoneNumber)
      : undefined,
    defaultLanguage: wa.defaultLanguage
      ? String(wa.defaultLanguage)
      : undefined,
  };
}

const configCache = new Map<string, SalonWhatsAppConfig>();
const phoneNumberCache = new Map<string, SalonWhatsAppConfig>();

export async function getSalonWaConfig(
  salonId: string,
  options: { forceRefresh?: boolean } = {},
): Promise<SalonWhatsAppConfig> {
  const forceRefresh = options.forceRefresh ?? false;
  if (!forceRefresh && configCache.has(salonId)) {
    return configCache.get(salonId)!;
  }

  const snapshot = await salonsCollection.doc(salonId).get();
  if (!snapshot.exists) {
    throw new Error(`Salon ${salonId} not found`);
  }

  const mapped = mapSalonConfig(salonId, snapshot.data() as SalonDocument);
  if (!mapped) {
    throw new Error(`Salon ${salonId} has no WhatsApp configuration`);
  }

  configCache.set(salonId, mapped);
  phoneNumberCache.set(mapped.phoneNumberId, mapped);
  return mapped;
}

export async function getSalonWaConfigByPhoneNumberId(
  phoneNumberId: string,
): Promise<SalonWhatsAppConfig | null> {
  if (phoneNumberCache.has(phoneNumberId)) {
    return phoneNumberCache.get(phoneNumberId)!;
  }

  const querySnapshot = await salonsCollection
    .where('whatsapp.phoneNumberId', '==', phoneNumberId)
    .limit(1)
    .get();

  if (querySnapshot.empty) {
    logger.warn('No salon configured for phone number id', { phoneNumberId });
    return null;
  }

  const doc = querySnapshot.docs[0];
  const mapped = mapSalonConfig(doc.id, doc.data() as SalonDocument);
  if (!mapped) {
    return null;
  }

  configCache.set(doc.id, mapped);
  phoneNumberCache.set(phoneNumberId, mapped);
  return mapped;
}

export function clearWaConfigCache(): void {
  configCache.clear();
  phoneNumberCache.clear();
}
