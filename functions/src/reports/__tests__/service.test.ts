import { beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';

import { ReportsCache } from '../cache';
import { ReportFilters, ReportResponse, ReportsError, ReportsService } from '../service';
import { getMetricsSnapshot, resetMetricsForTest } from '../metrics';

const baseFilters: ReportFilters = {
  dateFrom: '2024-01-01',
  dateTo: '2024-01-31',
  storeId: 'salon-42',
  operatorIds: [],
  serviceIds: [],
  categoryIds: [],
  channel: null,
};

beforeEach(() => {
  resetMetricsForTest();
});

test('caches report responses and records metrics for hits/misses', async () => {
  let computeCount = 0;
  const cache = new ReportsCache<ReportResponse>(60_000);
  const service = new ReportsService({
    cache,
    ttlMs: 60_000,
    compute: async scope => {
      computeCount += 1;
      return {
        data: {
          scope,
          computeCount,
        },
      };
    },
  });

  const first = await service.getSummary(baseFilters);
  assert.equal(first.data.computeCount, 1);

  let snapshot = getMetricsSnapshot();
  const missCounter = snapshot.counters.find(item => item.name === 'reports_cache_miss_total');
  assert(missCounter, 'Cache miss counter should be populated after first request');
  assert.equal(missCounter.value, 1);

  const second = await service.getSummary(baseFilters);
  assert.equal(second.data.computeCount, 1, 'Cached response should not recompute payload');

  snapshot = getMetricsSnapshot();
  const hitCounter = snapshot.counters.find(
    item =>
      item.name === 'reports_cache_hit_total' &&
      item.labels.scope === 'summary' &&
      item.labels.storeId === 'salon-42',
  );
  assert(hitCounter, 'Cache hit counter missing after second request');
  assert.equal(hitCounter.value, 1);

  const stalenessGauge = snapshot.gauges.find(item => item.name === 'reports_cache_staleness_seconds');
  assert(stalenessGauge, 'Staleness gauge missing');
  assert(stalenessGauge.value >= 0);
});

test('increments error metrics when compute pipeline fails', async () => {
  const service = new ReportsService({
    compute: async () => {
      throw new ReportsError('REPORTS_INVALID_FILTER', 'Invalid filters provided');
    },
  });

  await assert.rejects(() => service.getSummary(baseFilters), ReportsError);

  const snapshot = getMetricsSnapshot();
  const errorsCounter = snapshot.counters.find(item => item.name === 'reports_request_errors_total');
  assert(errorsCounter, 'Error counter missing after failure');
  assert.equal(errorsCounter.labels.status, 'REPORTS_INVALID_FILTER');
  assert.equal(errorsCounter.value, 1);

  const durationHistogram = snapshot.histograms.find(
    item =>
      item.name === 'reports_request_duration_ms' &&
      item.labels.status === 'error' &&
      item.labels.scope === 'summary',
  );
  assert(durationHistogram, 'Duration histogram should capture error case');
  assert.equal(durationHistogram.count, 1);
});
