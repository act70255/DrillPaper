import { DrillPaperClient } from '../../javascript/desktop-monitor-sdk.js';
import { MockHost } from '../../javascript/mock-host.js';

const mock = window.chrome?.webview ? null : new MockHost({ window });
const monitor = new DrillPaperClient(window.chrome.webview);
const history = [];
const $ = (id) => document.getElementById(id);

function showMetric(element, metric, suffix = '%') {
  element.textContent = metric?.quality === 'available' && metric.value != null
    ? `${Math.round(metric.value)}${suffix}` : '--';
}

function drawCpuHistory() {
  const canvas = $('cpu-chart');
  const context = canvas.getContext('2d');
  const width = canvas.width;
  const height = canvas.height;
  context.clearRect(0, 0, width, height);
  if (history.length < 2) return;
  context.beginPath();
  history.forEach((value, index) => {
    const x = index / (history.length - 1) * width;
    const y = height - Math.max(0, Math.min(100, value)) / 100 * height;
    if (index === 0) context.moveTo(x, y); else context.lineTo(x, y);
  });
  context.strokeStyle = '#78a9ff';
  context.lineWidth = 3;
  context.stroke();
}

function render(snapshot) {
  const cpu = snapshot.cpu?.usage;
  const memory = snapshot.memory;
  showMetric($('cpu'), cpu);
  showMetric($('gpu'), snapshot.gpu?.usage);
  showMetric($('disk'), snapshot.disk?.activityPercent);
  showMetric($('network'), snapshot.network?.rxBytesPerSec, ' B/s');
  if (memory?.usedBytes != null && memory.totalBytes != null && memory.totalBytes > 0) {
    $('memory').textContent = `${(memory.usedBytes / memory.totalBytes * 100).toFixed(0)}%`;
    $('memory-detail').textContent = `${(memory.usedBytes / 1024 ** 3).toFixed(1)} / ${(memory.totalBytes / 1024 ** 3).toFixed(1)} GiB`;
  } else {
    $('memory').textContent = '--';
    $('memory-detail').textContent = 'Unavailable';
  }
  if (cpu?.quality === 'available' && cpu.value != null) {
    history.push(cpu.value);
    if (history.length > 60) history.shift();
    drawCpuHistory();
  }
}

try {
  const host = await monitor.ready();
  $('host-state').textContent = `Host: ${host.state}`;
  render(await monitor.getSnapshot());
  monitor.on('metrics', render);
  monitor.on('host.stateChanged', ({ state }) => { $('host-state').textContent = `Host: ${state}`; });
  await monitor.subscribe({ metrics: ['cpu', 'gpu', 'memory', 'disk', 'network'], intervalMs: 1000 });
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
