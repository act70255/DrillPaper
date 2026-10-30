import type { HostState, MetricsSnapshot } from './desktop-monitor-sdk.js';

export type MockSnapshot = Omit<MetricsSnapshot, 'timestamp'> & { timestamp?: string };

export declare const DEFAULT_SNAPSHOT: MockSnapshot;

export declare class MockHost {
  constructor(options?: { window?: object; snapshot?: MockSnapshot; updateEveryMs?: number });
  setSnapshot(snapshot: MockSnapshot): void;
  setState(state: HostState): void;
  dispose(): void;
}
