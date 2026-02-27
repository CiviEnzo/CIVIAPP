import { getAuth } from 'firebase-admin/auth';
import type { Request, Response } from 'express';
import * as logger from 'firebase-functions/logger';

import { db } from '../utils/firestore';

export type WaRequestUserContext = {
  uid: string;
  email?: string;
  role?: string;
  salonIds: string[];
};

function normalizeString(value: unknown): string | null {
  if (typeof value !== 'string') {
    return null;
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function normalizeRole(value: unknown): string | undefined {
  return normalizeString(value)?.toLowerCase();
}

function collectSalonIds(...sources: unknown[]): string[] {
  const values = new Set<string>();
  for (const source of sources) {
    if (Array.isArray(source)) {
      for (const item of source) {
        const candidate = normalizeString(item);
        if (candidate) {
          values.add(candidate);
        }
      }
      continue;
    }

    const candidate = normalizeString(source);
    if (candidate) {
      values.add(candidate);
    }
  }
  return [...values];
}

function extractBearerToken(request: Request): string | null {
  const authorization =
    request.header('authorization') ?? request.header('Authorization');
  if (!authorization) {
    return null;
  }
  const match = authorization.match(/^Bearer\s+(.+)$/i);
  return match?.[1]?.trim() || null;
}

export async function loadWaRequestUser(
  request: Request,
): Promise<WaRequestUserContext> {
  const token = extractBearerToken(request);
  if (!token) {
    throw new Error('Missing Authorization bearer token');
  }

  const decoded = await getAuth().verifyIdToken(token);
  const claimsRole = normalizeRole(decoded.role);
  const claimsSalonIds = collectSalonIds(decoded.salonIds);

  let profileRole: string | undefined;
  let profileSalonIds: string[] = [];

  try {
    const userDoc = await db.collection('users').doc(decoded.uid).get();
    if (userDoc.exists) {
      const userData = userDoc.data() ?? {};
      profileRole = normalizeRole(userData.role);
      profileSalonIds = collectSalonIds(
        userData.salonIds,
        userData.managedSalonIds,
        userData.joinedSalonIds,
        userData.primarySalonId,
        userData.salonId,
      );
    }
  } catch (error) {
    logger.warn('WhatsApp authz: unable to load user profile', {
      uid: decoded.uid,
      error: error instanceof Error ? error.message : String(error),
    });
  }

  return {
    uid: decoded.uid,
    email: typeof decoded.email === 'string' ? decoded.email : undefined,
    role: profileRole ?? claimsRole,
    salonIds: profileSalonIds.length > 0 ? profileSalonIds : claimsSalonIds,
  };
}

export async function requireWaSalonAdmin(
  request: Request,
  response: Response,
  salonId: string,
): Promise<WaRequestUserContext | null> {
  try {
    const user = await loadWaRequestUser(request);
    if ((user.role ?? '').toLowerCase() !== 'admin') {
      response.status(403).json({
        success: false,
        error: 'Only salon admins can access this WhatsApp endpoint',
      });
      return null;
    }
    if (!user.salonIds.includes(salonId)) {
      response.status(403).json({
        success: false,
        error: 'User is not authorized for the requested salon',
      });
      return null;
    }
    return user;
  } catch (error) {
    const message =
      error instanceof Error ? error.message : 'Invalid authentication token';
    response.status(401).json({ success: false, error: message });
    return null;
  }
}

