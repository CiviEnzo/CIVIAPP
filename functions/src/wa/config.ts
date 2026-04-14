import * as logger from 'firebase-functions/logger';

import { db } from '../utils/firestore';

import {
  ConnectionMethod,
  WhatsAppHttpError,
  WhatsAppOnboardingStatus,
  WhatsAppRegistrationStatus,
  inferConnectionMethod,
  inferOnboardingStatus,
  inferRegistrationStatus,
  inferRequiresReconnect,
  normalizeString,
} from './runtime';

export interface SalonWhatsAppConfig {
  salonId: string;
  mode: 'own' | 'shared';
  businessId: string;
  wabaId: string;
  phoneNumberId: string;
  displayPhoneNumber?: string;
  defaultLanguage?: string;
  tokenSecretId?: string;
  verifyTokenSecretId?: string;
  connectionMethod: ConnectionMethod;
  onboardingStatus: WhatsAppOnboardingStatus;
  registrationStatus: WhatsAppRegistrationStatus;
  requiresReconnect: boolean;
}

export interface SalonWhatsAppRoutingConfig {
  salonId: string;
  phoneNumberId: string;
  connectionMethod: ConnectionMethod;
  onboardingStatus: WhatsAppOnboardingStatus;
  registrationStatus: WhatsAppRegistrationStatus;
  requiresReconnect: boolean;
}

interface SalonDocument {
  whatsapp?: Record<string, unknown>;
}

const salonsCollection = db.collection('salons');

const configCache = new Map<string, SalonWhatsAppConfig>();
const phoneNumberCache = new Map<string, SalonWhatsAppRoutingConfig>();

function buildRoutingConfig(
  salonId: string,
  whatsapp: Record<string, unknown> | undefined,
): SalonWhatsAppRoutingConfig | null {
  const phoneNumberId = normalizeString(whatsapp?.phoneNumberId);
  if (!phoneNumberId) {
    return null;
  }

  return {
    salonId,
    phoneNumberId,
    connectionMethod: inferConnectionMethod(whatsapp),
    onboardingStatus: inferOnboardingStatus(whatsapp),
    registrationStatus: inferRegistrationStatus(whatsapp),
    requiresReconnect: inferRequiresReconnect(whatsapp),
  };
}

function buildRuntimeConfig(
  salonId: string,
  whatsapp: Record<string, unknown> | undefined,
): SalonWhatsAppConfig | null {
  const routing = buildRoutingConfig(salonId, whatsapp);
  if (!routing) {
    return null;
  }

  const businessId = normalizeString(whatsapp?.businessId);
  const wabaId = normalizeString(whatsapp?.wabaId);
  const modeRaw = normalizeString(whatsapp?.mode);
  const mode = modeRaw === 'shared' ? 'shared' : 'own';

  if (!businessId || !wabaId) {
    logger.warn('Incomplete WhatsApp runtime configuration for salon', {
      salonId,
      businessIdPresent: Boolean(businessId),
      wabaIdPresent: Boolean(wabaId),
      phoneNumberId: routing.phoneNumberId,
    });
    return null;
  }

  return {
    ...routing,
    mode,
    businessId,
    wabaId,
    displayPhoneNumber: normalizeString(whatsapp?.displayPhoneNumber) ?? undefined,
    defaultLanguage: normalizeString(whatsapp?.defaultLanguage) ?? undefined,
    tokenSecretId: normalizeString(whatsapp?.tokenSecretId) ?? undefined,
    verifyTokenSecretId:
      normalizeString(whatsapp?.verifyTokenSecretId) ?? undefined,
  };
}

function assertRuntimeReady(config: SalonWhatsAppConfig): SalonWhatsAppConfig {
  if (config.requiresReconnect || config.connectionMethod === 'legacy_oauth') {
    throw new WhatsAppHttpError(
      'WhatsApp deve essere riconfigurato manualmente prima di poter inviare messaggi.',
      409,
      'reconnect_required',
      {
        salonId: config.salonId,
        connectionMethod: config.connectionMethod,
      },
    );
  }

  if (config.registrationStatus !== 'registered') {
    throw new WhatsAppHttpError(
      'Il numero WhatsApp del salone non e ancora registrato. Completa la verifica del numero e riprova.',
      409,
      'number_not_registered',
      {
        salonId: config.salonId,
        registrationStatus: config.registrationStatus,
        onboardingStatus: config.onboardingStatus,
      },
    );
  }

  return config;
}

export async function getSalonWaConfig(
  salonId: string,
  options: { forceRefresh?: boolean } = {},
): Promise<SalonWhatsAppConfig> {
  const forceRefresh = options.forceRefresh ?? false;
  if (!forceRefresh && configCache.has(salonId)) {
    return assertRuntimeReady(configCache.get(salonId)!);
  }

  const snapshot = await salonsCollection.doc(salonId).get();
  if (!snapshot.exists) {
    throw new WhatsAppHttpError(`Salon ${salonId} not found`, 404, 'salon_not_found');
  }

  const data = snapshot.data() as SalonDocument;
  const mapped = buildRuntimeConfig(salonId, data.whatsapp);
  if (!mapped) {
    throw new WhatsAppHttpError(
      `Salon ${salonId} has no WhatsApp configuration`,
      400,
      'whatsapp_not_configured',
    );
  }

  configCache.set(salonId, mapped);
  phoneNumberCache.set(mapped.phoneNumberId, {
    salonId,
    phoneNumberId: mapped.phoneNumberId,
    connectionMethod: mapped.connectionMethod,
    onboardingStatus: mapped.onboardingStatus,
    registrationStatus: mapped.registrationStatus,
    requiresReconnect: mapped.requiresReconnect,
  });
  return assertRuntimeReady(mapped);
}

export async function getSalonWaRoutingByPhoneNumberId(
  phoneNumberId: string,
): Promise<SalonWhatsAppRoutingConfig | null> {
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
  const data = doc.data() as SalonDocument;
  const mapped = buildRoutingConfig(doc.id, data.whatsapp);
  if (!mapped) {
    return null;
  }

  phoneNumberCache.set(phoneNumberId, mapped);
  return mapped;
}

export const __test__ = {
  buildRuntimeConfig,
  buildRoutingConfig,
  assertRuntimeReady,
};

export function clearWaConfigCache(): void {
  configCache.clear();
  phoneNumberCache.clear();
}
