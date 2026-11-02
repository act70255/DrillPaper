import { API_VERSION, DrillPaper, type MetricValue, type MetricsSnapshot } from './desktop-monitor-sdk.js';

/** 將可用的讀值連同協定單位顯示，不把缺值當成零。
 * Args:
 *     metric: 宿主提供的指標。
 * Returns:
 *     指標文字與品質。
 */
function metricText(metric: MetricValue | undefined): string {
  return metric?.quality === 'available' && metric.value !== null
    ? `${metric.value.toFixed(1)} ${metric.unit}` : `unavailable (${metric?.quality ?? 'missing'})`;
}

/** 更新主題文字，僅在值有變化時改寫 DOM。
 * Args:
 *     id: 範本元素識別。
 *     text: 已格式化文字。
 */
function put(id: string, text: string): void {
  const element = document.getElementById(id);
  if (!element) throw new Error(`主題缺少元素：${id}`);
  if (element.textContent !== text) element.textContent = text;
}

/** 顯示一份快照，各目標依自己的 viewport 排版。
 * Args:
 *     snapshot: SDK 正規化後的快照。
 */
function render(snapshot: MetricsSnapshot): void {
  put('cpu', metricText(snapshot.cpu?.usage));
  put('gpu', metricText(snapshot.gpu?.usage));
  put('disk', metricText(snapshot.disk?.activityPercent));
  const memory = snapshot.memory;
  put('memory', memory?.usedBytes != null && memory.totalBytes != null
    ? `${memory.usedBytes} / ${memory.totalBytes} bytes` : 'unavailable');
  put('network', `${metricText(snapshot.network?.rxBytesPerSec)} / ${metricText(snapshot.network?.txBytesPerSec)}`);
  put('timestamp', snapshot.timestamp);
}

try {
  const host = await DrillPaper.ready();
  put('status', `API ${API_VERSION} · ${host.hostVersion} · ${host.state}`);
  render(await DrillPaper.getSnapshot());
  const off = DrillPaper.on('metrics', render);
  DrillPaper.on('host.error', ({ message }) => put('status', `宿主錯誤：${message}`));
  DrillPaper.on('host.stateChanged', ({ state }) => put('status', `API ${API_VERSION} · ${host.hostVersion} · ${state}`));
  await DrillPaper.subscribe({ metrics: ['cpu', 'gpu', 'memory', 'disk', 'network', 'clock'], intervalMs: 1000 });
  window.addEventListener('pagehide', () => { off(); void DrillPaper.unsubscribe().catch(() => {}); }, { once: true });
} catch (error) {
  put('status', `主題初始化失敗：${error instanceof Error ? error.message : String(error)}`);
}
