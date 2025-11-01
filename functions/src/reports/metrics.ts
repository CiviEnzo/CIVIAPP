type MetricLabels = Record<string, string>;

type CounterStore = Map<string, CounterEntry>;
type HistogramStore = Map<string, HistogramEntry>;
type GaugeStore = Map<string, GaugeEntry>;

type MetricType = 'counter' | 'histogram' | 'gauge';

interface MetricDefinition {
  readonly name: string;
  readonly help: string;
  readonly type: MetricType;
}

interface CounterEntry {
  readonly labels: MetricLabels;
  value: number;
}

interface HistogramEntry {
  readonly labels: MetricLabels;
  readonly buckets: number[];
  sum: number;
  count: number;
}

interface GaugeEntry {
  readonly labels: MetricLabels;
  value: number;
}

export interface CounterSnapshot {
  readonly name: string;
  readonly labels: MetricLabels;
  readonly value: number;
}

export interface HistogramBucketSnapshot {
  readonly upperBound: number | 'Inf';
  readonly value: number;
}

export interface HistogramSnapshot {
  readonly name: string;
  readonly labels: MetricLabels;
  readonly buckets: HistogramBucketSnapshot[];
  readonly sum: number;
  readonly count: number;
}

export interface GaugeSnapshot {
  readonly name: string;
  readonly labels: MetricLabels;
  readonly value: number;
}

export interface MetricsSnapshot {
  readonly counters: CounterSnapshot[];
  readonly histograms: HistogramSnapshot[];
  readonly gauges: GaugeSnapshot[];
}

type ObserveStatus = 'success' | 'error';

const metricDefinitions: Record<string, MetricDefinition> = {
  reports_cache_hit_total: {
    name: 'reports_cache_hit_total',
    help: 'Number of report cache hits served to clients.',
    type: 'counter',
  },
  reports_cache_miss_total: {
    name: 'reports_cache_miss_total',
    help: 'Number of report cache misses requiring recomputation.',
    type: 'counter',
  },
  reports_request_duration_ms: {
    name: 'reports_request_duration_ms',
    help: 'Latency of report requests in milliseconds.',
    type: 'histogram',
  },
  reports_request_errors_total: {
    name: 'reports_request_errors_total',
    help: 'Total number of report requests that ended in error.',
    type: 'counter',
  },
  reports_cache_staleness_seconds: {
    name: 'reports_cache_staleness_seconds',
    help: 'Age of the cached report payload served to the client.',
    type: 'gauge',
  },
};

const counters = new Map<string, CounterStore>();
const histograms = new Map<string, HistogramStore>();
const gauges = new Map<string, GaugeStore>();

const DURATION_BUCKETS = [50, 100, 250, 500, 1000, 2000, 5000, 10000, Infinity];

const ensureCounterEntry = (metricName: string, labels: MetricLabels): CounterEntry => {
  const metric = getOrCreateMetricStore(counters, metricName);
  const key = makeLabelKey(labels);
  let entry = metric.get(key);
  if (!entry) {
    entry = { labels: cloneLabels(labels), value: 0 };
    metric.set(key, entry);
  }
  return entry;
};

const ensureHistogramEntry = (metricName: string, labels: MetricLabels): HistogramEntry => {
  const metric = getOrCreateMetricStore(histograms, metricName);
  const key = makeLabelKey(labels);
  let entry = metric.get(key);
  if (!entry) {
    entry = {
      labels: cloneLabels(labels),
      buckets: Array<number>(DURATION_BUCKETS.length).fill(0),
      sum: 0,
      count: 0,
    };
    metric.set(key, entry);
  }
  return entry;
};

const ensureGaugeEntry = (metricName: string, labels: MetricLabels): GaugeEntry => {
  const metric = getOrCreateMetricStore(gauges, metricName);
  const key = makeLabelKey(labels);
  let entry = metric.get(key);
  if (!entry) {
    entry = { labels: cloneLabels(labels), value: 0 };
    metric.set(key, entry);
  }
  return entry;
};

const getOrCreateMetricStore = <T>(
  map: Map<string, Map<string, T>>,
  metricName: string,
): Map<string, T> => {
  let metricStore = map.get(metricName);
  if (!metricStore) {
    metricStore = new Map<string, T>();
    map.set(metricName, metricStore);
  }
  return metricStore;
};

const normalizeLabels = (labels: Record<string, string | number | boolean | null | undefined>): MetricLabels => {
  const normalized: MetricLabels = {};
  for (const [key, value] of Object.entries(labels)) {
    if (value === undefined || value === null) {
      continue;
    }
    normalized[key] = String(value);
  }
  return normalized;
};

const cloneLabels = (labels: MetricLabels): MetricLabels => ({ ...labels });

const makeLabelKey = (labels: MetricLabels): string => {
  const entries = Object.entries(labels).sort(([a], [b]) => a.localeCompare(b));
  return entries.map(([key, value]) => `${key}=${value}`).join(',');
};

const formatLabelPairs = (labels: MetricLabels): string[] => {
  return Object.entries(labels).map(([key, value]) => `${key}="${escapeLabelValue(value)}"`);
};

const formatLabelBlock = (labels: MetricLabels): string => {
  const pairs = formatLabelPairs(labels);
  if (!pairs.length) {
    return '';
  }
  return `{${pairs.join(',')}}`;
};

const escapeLabelValue = (value: string): string => {
  return value.replace(/\\/g, '\\\\').replace(/"/g, '\\"');
};

const ensureMetricDefined = (metricName: string): void => {
  if (!metricDefinitions[metricName]) {
    throw new Error(`Metric "${metricName}" is not defined in metricDefinitions`);
  }
};

const recordDuration = (labels: MetricLabels, durationMs: number): void => {
  if (Number.isNaN(durationMs) || durationMs < 0) {
    return;
  }
  ensureMetricDefined('reports_request_duration_ms');
  const entry = ensureHistogramEntry('reports_request_duration_ms', labels);
  entry.count += 1;
  entry.sum += durationMs;
  for (let index = 0; index < DURATION_BUCKETS.length; index += 1) {
    if (durationMs <= DURATION_BUCKETS[index]) {
      entry.buckets[index] += 1;
    }
  }
};

const recordCounter = (metricName: string, labels: MetricLabels, value = 1): void => {
  ensureMetricDefined(metricName);
  const entry = ensureCounterEntry(metricName, labels);
  entry.value += value;
};

const recordGauge = (metricName: string, labels: MetricLabels, value: number): void => {
  ensureMetricDefined(metricName);
  const entry = ensureGaugeEntry(metricName, labels);
  entry.value = value;
};

export const observeReportRequestDuration = (
  labels: { scope: string; storeId: string; status: ObserveStatus },
  durationMs: number,
): void => {
  const normalized = normalizeLabels(labels);
  recordDuration(normalized, durationMs);
};

export const incrementReportCacheHit = (labels: { scope: string; storeId: string }): void => {
  const normalized = normalizeLabels(labels);
  recordCounter('reports_cache_hit_total', normalized, 1);
};

export const incrementReportCacheMiss = (labels: { scope: string; storeId: string }): void => {
  const normalized = normalizeLabels(labels);
  recordCounter('reports_cache_miss_total', normalized, 1);
};

export const incrementReportError = (labels: { scope: string; storeId: string; status?: string }): void => {
  const normalized = normalizeLabels({
    ...labels,
    status: labels.status ?? 'unknown',
  });
  recordCounter('reports_request_errors_total', normalized, 1);
};

export const setCacheStaleness = (labels: { scope: string; storeId: string }, seconds: number): void => {
  const normalized = normalizeLabels(labels);
  recordGauge('reports_cache_staleness_seconds', normalized, Math.max(0, seconds));
};

export const getMetricsSnapshot = (): MetricsSnapshot => {
  const counterSnapshots: CounterSnapshot[] = [];
  for (const [metricName, store] of counters.entries()) {
    for (const entry of store.values()) {
      counterSnapshots.push({
        name: metricName,
        labels: cloneLabels(entry.labels),
        value: entry.value,
      });
    }
  }

  const histogramSnapshots: HistogramSnapshot[] = [];
  for (const [metricName, store] of histograms.entries()) {
    for (const entry of store.values()) {
      histogramSnapshots.push({
        name: metricName,
        labels: cloneLabels(entry.labels),
        buckets: entry.buckets.map((value, index) => ({
          upperBound: Number.isFinite(DURATION_BUCKETS[index])
            ? DURATION_BUCKETS[index]
            : 'Inf',
          value,
        })),
        sum: entry.sum,
        count: entry.count,
      });
    }
  }

  const gaugeSnapshots: GaugeSnapshot[] = [];
  for (const [metricName, store] of gauges.entries()) {
    for (const entry of store.values()) {
      gaugeSnapshots.push({
        name: metricName,
        labels: cloneLabels(entry.labels),
        value: entry.value,
      });
    }
  }

  return {
    counters: counterSnapshots,
    histograms: histogramSnapshots,
    gauges: gaugeSnapshots,
  };
};

export const getPrometheusMetrics = (): string => {
  const lines: string[] = [];

  const emitHeader = (definition: MetricDefinition): void => {
    lines.push(`# HELP ${definition.name} ${definition.help}`);
    lines.push(`# TYPE ${definition.name} ${definition.type}`);
  };

  for (const [metricName, store] of counters.entries()) {
    if (!store.size) {
      continue;
    }
    emitHeader(metricDefinitions[metricName]);
    for (const entry of store.values()) {
      lines.push(`${metricName}${formatLabelBlock(entry.labels)} ${entry.value}`);
    }
  }

  for (const [metricName, store] of histograms.entries()) {
    if (!store.size) {
      continue;
    }
    emitHeader(metricDefinitions[metricName]);
    for (const entry of store.values()) {
      const labelPairs = formatLabelPairs(entry.labels);
      const baseLabel = labelPairs.length ? `{${labelPairs.join(',')}}` : '';
      for (let index = 0; index < DURATION_BUCKETS.length; index += 1) {
        const le = Number.isFinite(DURATION_BUCKETS[index])
          ? DURATION_BUCKETS[index].toString()
          : '+Inf';
        const bucketLabels = labelPairs.length
          ? `{${[...labelPairs, `le="${le}"`].join(',')}}`
          : `{le="${le}"}`;
        lines.push(`${metricName}_bucket${bucketLabels} ${entry.buckets[index]}`);
      }
      lines.push(`${metricName}_sum${baseLabel} ${entry.sum}`);
      lines.push(`${metricName}_count${baseLabel} ${entry.count}`);
    }
  }

  for (const [metricName, store] of gauges.entries()) {
    if (!store.size) {
      continue;
    }
    emitHeader(metricDefinitions[metricName]);
    for (const entry of store.values()) {
      lines.push(`${metricName}${formatLabelBlock(entry.labels)} ${entry.value}`);
    }
  }

  return lines.join('\n');
};

export const resetMetricsForTest = (): void => {
  counters.clear();
  histograms.clear();
  gauges.clear();
};

export type { ObserveStatus as ReportObserveStatus };
