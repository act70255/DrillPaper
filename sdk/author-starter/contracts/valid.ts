import {
  DrillPaper, DrillPaperClient, DesktopMonitorClient, API_VERSION,
  type MetricValue, type MetricsSnapshot, type HostReady,
} from '../src/desktop-monitor-sdk.js';
import { MockHost, DEFAULT_SNAPSHOT } from '../src/mock-host.js';

const mock = new MockHost({ window: {}, snapshot: DEFAULT_SNAPSHOT, updateEveryMs: 1000 });
mock.setSnapshot({ gpu: { usage: { value: null, unit: 'percent', quality: 'unavailable' } } });
mock.setState('locked');
mock.dispose();
const version: '1' = API_VERSION;
const host: HostReady = await DrillPaper.ready();
const historyLimit: number = host.limits.history;
const messageLimit: number = host.limits.messageBytes;
const snapshot: MetricsSnapshot = await DrillPaper.getSnapshot();
const history: MetricsSnapshot[] = await DrillPaper.getHistory({ limit: 2 });
const value: MetricValue | undefined = snapshot.gpu?.usage;
const off = DrillPaper.on('metrics', (next) => { const time: string = next.timestamp; void time; });
DrillPaper.on('host.stateChanged', ({ state }) => { const s: string = state; void s; });
DrillPaper.on('host.error', ({ message }) => { const s: string = message; void s; });
await DrillPaper.subscribe({ metrics: ['cpu', 'gpu', 'memory'], intervalMs: 1000 });
await DrillPaper.unsubscribe();
off();
const client: DrillPaperClient = new DesktopMonitorClient();
client.dispose();
void [version, host, history, value, historyLimit, messageLimit];
