import { beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';

import {
  getMetricsSnapshot,
  getPrometheusMetrics,
  incrementReportCacheHit,
  incrementReportCacheMiss,
  incrementReportError,
  observeReportRequestDuration,
  resetMetricsForTest,
  setCacheStaleness,
} from '../metrics';

beforeEach(() => {
  resetMetricsForTest();
});

test('records request durations in histogram buckets', () => {
  observeReportRequestDuration({ scope: 'summary', storeId: 'salon-1', status: 'success' }, 120);
  observeReportRequestDuration({ scope: 'summary', storeId: 'salon-1', status: 'success' }, 600);
  observeReportRequestDuration({ scope: 'summary', storeId: 'salon-1', status: 'error' }, 2200);

  const snapshot = getMetricsSnapshot();
  const entry = snapshot.histograms.find(
    item =>
      item.name === 'reports_request_duration_ms' &&
      item.labels.scope === 'summary' &&
      item.labels.storeId === 'salon-1' &&
      item.labels.status === 'success',
  );

  assert(entry, 'Histogram entry for success status is missing');
  assert.equal(entry.count, 2);
  assert.equal(entry.sum, 720);

  const bucket250 = entry.buckets.find(bucket => bucket.upperBound === 250);
  assert(bucket250, 'Bucket 250ms missing');
  assert.equal(bucket250.value, 1);

  const bucket1000 = entry.buckets.find(bucket => bucket.upperBound === 1000);
  assert(bucket1000, 'Bucket 1000ms missing');
  assert.equal(bucket1000.value, 2);

  const errorEntry = snapshot.histograms.find(
    item =>
      item.name === 'reports_request_duration_ms' &&
      item.labels.status === 'error',
  );
  assert(errorEntry, 'Histogram entry for error status missing');
  assert.equal(errorEntry.count, 1);
});

test('tracks cache hit/miss, errors and staleness gauges', () => {
  incrementReportCacheMiss({ scope: 'summary', storeId: 'salon-1' });
  incrementReportCacheHit({ scope: 'summary', storeId: 'salon-1' });
  incrementReportError({ scope: 'summary', storeId: 'salon-1', status: 'REPORTS_INVALID_FILTER' });
  setCacheStaleness({ scope: 'summary', storeId: 'salon-1' }, 42);

  const snapshot = getMetricsSnapshot();

  const hitCounter = snapshot.counters.find(
    item =>
      item.name === 'reports_cache_hit_total' &&
      item.labels.scope === 'summary' &&
      item.labels.storeId === 'salon-1',
  );
  assert(hitCounter, 'Cache hit counter missing');
  assert.equal(hitCounter.value, 1);

  const missCounter = snapshot.counters.find(item => item.name === 'reports_cache_miss_total');
  assert(missCounter, 'Cache miss counter missing');
  assert.equal(missCounter.value, 1);

  const errorsCounter = snapshot.counters.find(item => item.name === 'reports_request_errors_total');
  assert(errorsCounter, 'Error counter missing');
  assert.equal(errorsCounter.labels.status, 'REPORTS_INVALID_FILTER');
  assert.equal(errorsCounter.value, 1);

  const stalenessGauge = snapshot.gauges.find(item => item.name === 'reports_cache_staleness_seconds');
  assert(stalenessGauge, 'Staleness gauge missing');
  assert.equal(stalenessGauge.value, 42);
});

test('renders prometheus output for populated metrics', () => {
  incrementReportCacheHit({ scope: 'summary', storeId: 'salon-1' });
  observeReportRequestDuration({ scope: 'summary', storeId: 'salon-1', status: 'success' }, 180);

  const text = getPrometheusMetrics();
  assert(
    text.includes('reports_cache_hit_total{scope="summary",storeId="salon-1"} 1'),
    'Prometheus output should include cache hit metric',
  );
  assert(
    text.includes('reports_request_duration_ms_bucket{scope="summary",storeId="salon-1",status="success",le="250"}'),
    'Prometheus output should include histogram buckets',
  );
});
