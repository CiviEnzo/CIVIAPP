import { SecretManagerServiceClient } from '@google-cloud/secret-manager';
import * as logger from 'firebase-functions/logger';

const client = new SecretManagerServiceClient();

const secretCache = new Map<string, string>();

function normalizeSecretName(secretId: string): string {
  if (secretId.includes('/versions/')) {
    return secretId;
  }
  return `${secretId}/versions/latest`;
}

export async function readSecret(secretId: string): Promise<string> {
  if (!secretId) {
    throw new Error('Secret id is required');
  }

  if (secretCache.has(secretId)) {
    return secretCache.get(secretId)!;
  }

  const name = normalizeSecretName(secretId);
  logger.debug('Accessing secret version', { secretId, name });

  try {
    const accessSecretVersion = client.accessSecretVersion.bind(
      client,
    ) as unknown as (
      request: { name: string },
    ) => Promise<
      [
        {
          payload?: {
            data?: Buffer | Uint8Array | string;
          };
        },
      ]
    >;

    const [version] = await accessSecretVersion({ name });
    const payload = version.payload?.data?.toString('utf8');
    if (!payload) {
      throw new Error(`Secret ${secretId} has no payload`);
    }
    secretCache.set(secretId, payload);
    return payload;
  } catch (error) {
    logger.error('Failed to read secret', error instanceof Error ? error : new Error(String(error)), {
      secretId,
    });
    throw error instanceof Error ? error : new Error(String(error));
  }
}

export function clearSecretCache(): void {
  secretCache.clear();
}

async function ensureSecret(projectId: string, secretId: string): Promise<string> {
  const parent = `projects/${projectId}`;
  const name = `${parent}/secrets/${secretId}`;

  try {
    await client.getSecret({ name });
    return name;
  } catch (error) {
    const code = (error as { code?: number } | undefined)?.code;
    if (code !== 5) {
      throw error instanceof Error ? error : new Error(String(error));
    }
  }

  try {
    await client.createSecret({
      parent: `projects/${projectId}`,
      secretId,
      secret: {
        replication: {
          automatic: {},
        },
      },
    });
  } catch (error) {
    const code = (error as { code?: number } | undefined)?.code;
    if (code !== 6) {
      throw error instanceof Error ? error : new Error(String(error));
    }
  }

  return `${parent}/secrets/${secretId}`;
}

export async function upsertSecret(
  secretId: string,
  value: string,
): Promise<string> {
  if (!secretId) {
    throw new Error('Secret id is required');
  }

  const projectId = await client.getProjectId();
  const name = await ensureSecret(projectId, secretId);

  await client.addSecretVersion({
    parent: name,
    payload: {
      data: Buffer.from(value, 'utf8'),
    },
  });

  const cacheKey = name;
  secretCache.set(cacheKey, value);
  secretCache.set(`${cacheKey}/versions/latest`, value);

  return name;
}
