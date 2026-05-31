import axios from 'axios';
import { getFirestore } from 'firebase-admin/firestore';
import { defineSecret } from 'firebase-functions/params';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

const REGION = 'europe-west3';
const googleGeocodingApiKey = defineSecret('GOOGLE_GEOCODING_API_KEY');

type GeocodeSalonAddressPayload = {
  salonId?: unknown;
  address?: unknown;
  city?: unknown;
  postalCode?: unknown;
  country?: unknown;
};

type GoogleGeocodeResult = {
  formatted_address?: string;
  place_id?: string;
  geometry?: {
    location?: {
      lat?: number;
      lng?: number;
    };
    location_type?: string;
  };
  types?: string[];
};

function normalizeString(value: unknown): string {
  return typeof value === 'string' ? value.trim() : '';
}

function normalizeStringArray(value: unknown): string[] {
  if (!Array.isArray(value)) {
    return [];
  }
  return value
    .map((entry) => normalizeString(entry))
    .filter((entry) => entry.length > 0);
}

async function assertCanUseGeocoding(
  uid: string,
  salonId: string,
): Promise<void> {
  const db = getFirestore();
  const userSnapshot = await db.collection('users').doc(uid).get();
  if (!userSnapshot.exists) {
    throw new HttpsError('permission-denied', 'User profile not found.');
  }

  const data = userSnapshot.data() ?? {};
  const role = normalizeString(data.role).toLowerCase();
  const roles = normalizeStringArray(data.roles ?? data.availableRoles).map(
    (entry) => entry.toLowerCase(),
  );
  const hasAdminAccess = role === 'admin' || roles.includes('admin');
  const hasStaffAccess = role === 'staff' || roles.includes('staff');
  if (!hasAdminAccess && !hasStaffAccess) {
    throw new HttpsError(
      'permission-denied',
      'Only salon admins or staff can geocode salon addresses.',
    );
  }

  if (!salonId) {
    return;
  }

  const salonIds = normalizeStringArray(data.salonIds);
  if (!salonIds.includes(salonId)) {
    throw new HttpsError(
      'permission-denied',
      'User is not linked to the requested salon.',
    );
  }
}

function buildAddressQuery(payload: GeocodeSalonAddressPayload): string {
  const parts = [
    normalizeString(payload.address),
    normalizeString(payload.postalCode),
    normalizeString(payload.city),
    normalizeString(payload.country) || 'Italia',
  ].filter((part) => part.length > 0);
  return parts.join(', ');
}

function mapGoogleResult(result: GoogleGeocodeResult) {
  const location = result.geometry?.location;
  const latitude = location?.lat;
  const longitude = location?.lng;
  if (typeof latitude !== 'number' || typeof longitude !== 'number') {
    return null;
  }
  return {
    formattedAddress: result.formatted_address ?? '',
    placeId: result.place_id ?? '',
    latitude,
    longitude,
    locationType: result.geometry?.location_type ?? '',
    types: result.types ?? [],
  };
}

export const geocodeSalonAddress = onCall(
  { region: REGION, secrets: [googleGeocodingApiKey] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Authentication is required.');
    }

    const payload = (request.data ?? {}) as GeocodeSalonAddressPayload;
    const salonId = normalizeString(payload.salonId);
    await assertCanUseGeocoding(request.auth.uid, salonId);

    const address = buildAddressQuery(payload);
    if (!address) {
      throw new HttpsError('invalid-argument', 'Address is required.');
    }

    const apiKey = googleGeocodingApiKey.value();
    if (!apiKey) {
      throw new HttpsError(
        'failed-precondition',
        'Google geocoding API key is not configured.',
      );
    }

    const response = await axios.get(
      'https://maps.googleapis.com/maps/api/geocode/json',
      {
        params: {
          address,
          components: 'country:IT',
          region: 'it',
          language: 'it',
          key: apiKey,
        },
        timeout: 8000,
      },
    );

    const data = response.data as {
      status?: string;
      error_message?: string;
      results?: GoogleGeocodeResult[];
    };

    if (data.status === 'ZERO_RESULTS') {
      return { candidates: [] };
    }
    if (data.status !== 'OK') {
      throw new HttpsError(
        'unavailable',
        data.error_message || `Geocoding failed with status ${data.status}`,
      );
    }

    const candidates: Array<NonNullable<ReturnType<typeof mapGoogleResult>>> = [];
    for (const result of data.results ?? []) {
      const mapped = mapGoogleResult(result);
      if (!mapped) {
        continue;
      }
      candidates.push(mapped);
      if (candidates.length >= 5) {
        break;
      }
    }

    return { candidates };
  },
);
