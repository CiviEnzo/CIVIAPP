import { createHash } from 'node:crypto';

import { ReportsCache } from './cache';
import {
  incrementReportCacheHit,
  incrementReportCacheMiss,
  incrementReportError,
  observeReportRequestDuration,
  setCacheStaleness,
} from './metrics';

export type ReportScope = 'summary' | 'operational' | 'economic' | 'packages' | string;

export interface ReportFilters {
  readonly dateFrom: string;
  readonly dateTo: string;
  readonly storeId?: string | null;
  readonly operatorIds?: readonly string[];
  readonly serviceIds?: readonly string[];
  readonly categoryIds?: readonly string[];
  readonly channel?: string | null;
}

export interface AppliedFilter {
  readonly id: string;
  readonly label: string;
  readonly value: string;
  readonly type: string;
  readonly metadata?: Record<string, unknown>;
}

export interface PaginationState {
  readonly cursor: string | null;
  readonly hasNextPage: boolean;
}

export interface ReportResponse {
  readonly meta: {
    readonly scope: ReportScope;
    readonly generatedAt: string;
    readonly filtersHash: string;
    readonly cacheTtlSeconds: number;
  };
  readonly data: Record<string, unknown>;
  readonly appliedFilters: readonly AppliedFilter[];
  readonly pagination: PaginationState;
}

export interface ReportComputationResult {
  readonly data: Record<string, unknown>;
  readonly appliedFilters?: readonly AppliedFilter[];
  readonly pagination?: PaginationState;
}

type ReportComputeFn = (scope: ReportScope, filters: ReportFilters) => Promise<ReportComputationResult>;

export interface ReportsServiceOptions {
  readonly cache?: ReportsCache<ReportResponse>;
  readonly ttlMs?: number;
  readonly compute?: ReportComputeFn;
}

export class ReportsError extends Error {
  readonly code: string;
  readonly status: number;

  constructor(code: string, message: string, status = 400) {
    super(message);
    this.code = code;
    this.status = status;
    this.name = 'ReportsError';
  }
}

export class ReportsService {
  private readonly cache: ReportsCache<ReportResponse>;
  private readonly ttlMs: number;
  private readonly computeFn: ReportComputeFn;

  constructor(options: ReportsServiceOptions = {}) {
    this.ttlMs = options.ttlMs ?? 10 * 60 * 1000;
    this.cache = options.cache ?? new ReportsCache<ReportResponse>(this.ttlMs);
    this.computeFn = options.compute ?? (scope => this.defaultCompute(scope));
  }

  async getReport(scope: ReportScope, filters: ReportFilters): Promise<ReportResponse> {
    const normalizedScope = scope || 'summary';
    const normalizedStore = filters.storeId && filters.storeId.length ? filters.storeId : 'global';
    const cacheKey = this.buildCacheKey(normalizedScope, filters);
    const recordDuration = this.createDurationRecorder(normalizedScope, normalizedStore);

    const cached = this.cache.get(cacheKey);
    if (cached) {
      incrementReportCacheHit({ scope: normalizedScope, storeId: normalizedStore });
      setCacheStaleness({ scope: normalizedScope, storeId: normalizedStore }, cached.stalenessSeconds);
      recordDuration('success');
      return cached.value;
    }

    incrementReportCacheMiss({ scope: normalizedScope, storeId: normalizedStore });

    try {
      const response = await this.computeReport(normalizedScope, normalizedStore, filters, cacheKey);
      setCacheStaleness({ scope: normalizedScope, storeId: normalizedStore }, 0);
      recordDuration('success');
      return response;
    } catch (error) {
      recordDuration('error');
      incrementReportError({
        scope: normalizedScope,
        storeId: normalizedStore,
        status: this.resolveErrorCode(error),
      });
      throw error;
    }
  }

  async getSummary(filters: ReportFilters): Promise<ReportResponse> {
    return this.getReport('summary', filters);
  }

  private async computeReport(
    scope: ReportScope,
    storeId: string,
    filters: ReportFilters,
    cacheKey: string,
  ): Promise<ReportResponse> {
    const result = await this.computeFn(scope, filters);
    const appliedFilters = result.appliedFilters ?? this.buildAppliedFilters(filters);
    const pagination = result.pagination ?? { cursor: null, hasNextPage: false };
    const response: ReportResponse = {
      meta: {
        scope,
        generatedAt: new Date().toISOString(),
        filtersHash: this.buildFiltersHash(scope, filters),
        cacheTtlSeconds: Math.floor(this.ttlMs / 1000),
      },
      data: result.data,
      appliedFilters,
      pagination,
    };
    this.cache.set(cacheKey, response, this.ttlMs);
    return response;
  }

  private createDurationRecorder(scope: ReportScope, storeId: string) {
    const start = process.hrtime.bigint();
    return (status: 'success' | 'error'): void => {
      const durationMs = Number(process.hrtime.bigint() - start) / 1_000_000;
      observeReportRequestDuration({ scope, storeId, status }, durationMs);
    };
  }

  private buildAppliedFilters(filters: ReportFilters): AppliedFilter[] {
    const entries: AppliedFilter[] = [
      {
        id: 'date_range',
        label: 'Periodo',
        value: `${filters.dateFrom} → ${filters.dateTo}`,
        type: 'date_range',
      },
    ];

    if (filters.storeId && filters.storeId.length) {
      entries.push({
        id: 'store',
        label: 'Salone',
        value: filters.storeId,
        type: 'entity',
      });
    }

    if (filters.operatorIds?.length) {
      entries.push({
        id: 'operator',
        label: 'Operatori',
        value: filters.operatorIds.join(', '),
        type: 'entity',
      });
    }

    if (filters.serviceIds?.length) {
      entries.push({
        id: 'service',
        label: 'Servizi',
        value: filters.serviceIds.join(', '),
        type: 'entity',
      });
    }

    if (filters.categoryIds?.length) {
      entries.push({
        id: 'category',
        label: 'Categorie',
        value: filters.categoryIds.join(', '),
        type: 'entity',
      });
    }

    if (filters.channel && filters.channel.length) {
      entries.push({
        id: 'channel',
        label: 'Canale',
        value: filters.channel,
        type: 'enum',
      });
    }

    return entries;
  }

  private buildFiltersHash(scope: ReportScope, filters: ReportFilters): string {
    const normalized = {
      scope,
      dateFrom: filters.dateFrom,
      dateTo: filters.dateTo,
      storeId: filters.storeId ?? null,
      operatorIds: this.normalizeArray(filters.operatorIds),
      serviceIds: this.normalizeArray(filters.serviceIds),
      categoryIds: this.normalizeArray(filters.categoryIds),
      channel: filters.channel ?? null,
    };
    return createHash('sha256').update(JSON.stringify(normalized)).digest('hex');
  }

  private buildCacheKey(scope: ReportScope, filters: ReportFilters): string {
    return `report:${scope}:${this.buildFiltersHash(scope, filters)}`;
  }

  private normalizeArray(input?: readonly string[]): readonly string[] {
    if (!input?.length) {
      return [];
    }
    return [...input].map(item => item.trim()).filter(Boolean).sort();
  }

  private resolveErrorCode(error: unknown): string {
    if (error instanceof ReportsError) {
      return error.code;
    }
    if (error && typeof error === 'object' && 'code' in error && typeof (error as { code?: unknown }).code === 'string') {
      return (error as { code: string }).code;
    }
    return 'unknown';
  }

  private async defaultCompute(scope: ReportScope): Promise<ReportComputationResult> {
    return {
      data: {
        scope,
        message: 'Report computation not yet implemented for this scope.',
      },
      pagination: { cursor: null, hasNextPage: false },
    };
  }
}
