import { DrillPaper, type MetricValue } from '../src/desktop-monitor-sdk.js';
import { MockHost } from '../src/mock-host.js';

DrillPaper.subscribe({ intervalMs: '1000' });
DrillPaper.on('app.exit', () => {});
const value: MetricValue = { value: 0, unit: 'MB', quality: 'available' };
new MockHost().setState('sleeping');
void value;
