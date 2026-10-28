export type MetricQuality = 'available' | 'unavailable' | 'stale' | 'error';
export type MetricUnit = 'percent' | 'bytes' | 'bytes_per_second' | 'celsius';
export type HostState = 'active' | 'obscured' | 'locked' | 'display-off' | 'recovering';

export interface MetricValue {
  value: number | null;
  unit: MetricUnit;
  quality: MetricQuality;
}

export interface MetricsSnapshot {
  timestamp: string;
  cpu?: { usage: MetricValue };
  gpu?: { usage: MetricValue };
  memory?: { usedBytes: number | null; totalBytes: number | null };
  disk?: { activityPercent: MetricValue };
  network?: { rxBytesPerSec: MetricValue; txBytesPerSec: MetricValue };
}

export interface HostReady {
  hostVersion: string;
  capabilities: string[];
  state: HostState;
  limits: { maxHistory: number; minUpdateIntervalMs: number };
}

export interface SubscribeOptions {
  metrics?: string[];
  intervalMs?: number;
}

export interface HistoryOptions {
  limit?: number;
}

export interface HostError {
  code: string;
  message: string;
  recoverable?: boolean;
}

export declare class DrillPaperClient {
  constructor(transport?: WebViewTransport, options?: { timeoutMs?: number });
  ready(): Promise<HostReady>;
  getSnapshot(): Promise<MetricsSnapshot>;
  getHistory(options?: HistoryOptions): Promise<MetricsSnapshot[]>;
  subscribe(options?: SubscribeOptions): Promise<void>;
  unsubscribe(): Promise<void>;
  on(eventName: 'metrics' | 'metrics.snapshot' | 'metrics.changed', listener: (snapshot: MetricsSnapshot) => void): () => void;
  on(eventName: 'ready', listener: (host: HostReady) => void): () => void;
  on(eventName: 'host.stateChanged', listener: (state: { state: HostState }) => void): () => void;
  on(eventName: 'host.error', listener: (error: HostError) => void): () => void;
  dispose(): void;
}

export { DrillPaperClient as DesktopMonitorClient };

export interface WebViewTransport {
  postMessage(message: unknown): void;
  addEventListener(type: 'message', listener: (event: { data: unknown }) => void): void;
  removeEventListener?(type: 'message', listener: (event: { data: unknown }) => void): void;
}

export declare const API_VERSION: '1';
export declare const SDK_VERSION: '1.0.0-rc3';
export declare const MAX_HISTORY_LENGTH: 120;
export declare const MIN_UPDATE_INTERVAL_MS: 1000;
export declare const MAX_UPDATE_INTERVAL_MS: 60000;
export declare const MAX_PENDING_REQUESTS: 32;
export declare const DrillPaper: Pick<DrillPaperClient,
  'ready' | 'getSnapshot' | 'getHistory' | 'subscribe' | 'unsubscribe' | 'on'>;
export { DrillPaper as DesktopMonitor };
