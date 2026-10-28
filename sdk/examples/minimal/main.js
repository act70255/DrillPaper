import { DrillPaperClient } from '../../javascript/desktop-monitor-sdk.js';
import { MockHost } from '../../javascript/mock-host.js';

const mock = window.chrome?.webview ? null : new MockHost({ window });
const monitor = new DrillPaperClient(window.chrome.webview);
const $ = (id) => document.getElementById(id);

function render(snapshot) {
  const cpu = snapshot.cpu?.usage;
  const memory = snapshot.memory;
  const rx = snapshot.network?.rxBytesPerSec;
  $('cpu').textContent = cpu?.quality === 'available' ? `${Math.round(cpu.value)}%` : '--';
  $('memory').textContent = memory?.usedBytes != null && memory.totalBytes
    ? `${(memory.usedBytes / memory.totalBytes * 100).toFixed(0)}%` : '--';
  $('network').textContent = rx?.quality === 'available' ? `${Math.round(rx.value / 1024)} KB/s` : '--';
}

try {
  const host = await monitor.ready();
  $('host-state').textContent = `Host: ${host.state}`;
  render(await monitor.getSnapshot());
  monitor.on('metrics', render);
  monitor.on('host.stateChanged', ({ state }) => { $('host-state').textContent = `Host: ${state}`; });
  await monitor.subscribe({ metrics: ['cpu', 'memory', 'network'], intervalMs: 1000 });
} catch (error) {
  $('host-state').textContent = `Host unavailable: ${error.message}`;
}

const clockTimer = setInterval(() => { $('clock').textContent = new Date().toLocaleTimeString(); }, 1000);
window.addEventListener('pagehide', () => {
  clearInterval(clockTimer);
  void monitor.unsubscribe();
  monitor.dispose();
  mock?.dispose();
}, { once: true });
