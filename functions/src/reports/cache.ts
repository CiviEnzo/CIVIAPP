export interface CacheEntry<T> {
  readonly value: T;
  readonly createdAt: number;
  readonly expiresAt: number;
}

export interface CacheHit<T> {
  readonly value: T;
  readonly stalenessSeconds: number;
}

export class ReportsCache<T> {
  private readonly defaultTtlMs: number;
  private readonly store = new Map<string, CacheEntry<T>>();

  constructor(defaultTtlMs = 10 * 60 * 1000) {
    this.defaultTtlMs = defaultTtlMs;
  }

  get(key: string): CacheHit<T> | null {
    const entry = this.store.get(key);
    if (!entry) {
      return null;
    }
    if (entry.expiresAt <= Date.now()) {
      this.store.delete(key);
      return null;
    }
    const stalenessMs = Date.now() - entry.createdAt;
    return {
      value: entry.value,
      stalenessSeconds: Math.max(0, Math.floor(stalenessMs / 1000)),
    };
  }

  set(key: string, value: T, ttlOverrideMs?: number): void {
    const now = Date.now();
    const ttl = ttlOverrideMs ?? this.defaultTtlMs;
    this.store.set(key, {
      value,
      createdAt: now,
      expiresAt: now + ttl,
    });
  }

  invalidate(key?: string): void {
    if (key) {
      this.store.delete(key);
      return;
    }
    this.store.clear();
  }

  size(): number {
    return this.store.size;
  }
}
