// 僅供驗收：保留作者 main.js，通過全部斷言後才讓其訂閱送達原生宿主。
const transport = window.chrome.webview;
const send = transport.postMessage.bind(transport);
let subscription;
let config;
transport.postMessage = (message) => {
  if (message.type === 'metrics.subscribe') subscription = message;
  else send(message);
};
const messages = [];
transport.addEventListener('message', ({ data }) => messages.push(data));

/** 斷言瀏覽器內可觀察的契約。
 * Args:
 *     value: 必須成立的條件。
 *     message: 不成立時的診斷。
 */
function check(value, message) { if (!value) throw new Error(message); }

/** 等待實際協定回覆，拒絕逾時冒充成功。
 * Args:
 *     predicate: 符合回覆的條件。
 * Returns:
 *     符合條件的訊息。
 */
async function waitMessage(predicate) {
  for (let index = 0; index < 100; index++) {
    const found = messages.find(predicate);
    if (found) return found;
    await new Promise((resolve) => setTimeout(resolve, 50));
  }
  throw new Error('作者探針等待協定回覆逾時');
}

/** 發送測試用版本化封包，不透過任何管理端旁路。
 * Args:
 *     type: 待測命令。
 *     requestId: 回覆識別。
 *     apiVersion: 測試版本。
 */
function post(type, requestId, apiVersion = '1') {
  send({ apiVersion, type, requestId, timestamp: new Date().toISOString(), payload: {} });
}

try {
  config = await fetch('./probe.json').then((response) => response.json());
  post('theme.hello', 'bad-version', '2');
  check((await waitMessage((m) => m.requestId === 'bad-version')).payload.code === 'unsupported-api-version', '未拒絕 API v2');
  await import('./main.js');
  check(subscription, '作者沒有完成正常初始化與訂閱');
  const ready = messages.find((m) => m.type === 'host.ready');
  check(ready?.apiVersion === '1' && ready.payload.limits.history === 120 && ready.payload.limits.messageBytes === 65536, 'host.ready 契約不符');
  const first = document.getElementById('timestamp').textContent;
  // 真實 collector 首筆是 warm-up；等待可用值，不以任意固定延遲判產品失敗。
  for (let index = 0; index < 10; index++) {
    await new Promise((resolve) => setTimeout(resolve, 1000));
    const request = `author-update-${index}`;
    post('metrics.getSnapshot', request);
    await waitMessage((m) => m.requestId === request);
    if (document.getElementById('cpu').textContent.includes('percent') &&
        document.getElementById('network').textContent.includes('bytes_per_second')) break;
  }
  check(document.getElementById('timestamp').textContent !== first, 'DOM 更新時間沒有前進');
  check(document.getElementById('cpu').textContent.includes('percent'), 'CPU 未顯示單位／有效值');
  check(document.getElementById('memory').textContent.includes('bytes'), 'RAM 未顯示 bytes');
  check(document.getElementById('network').textContent.includes('bytes_per_second'), '網路未顯示速率單位');
  check(document.getElementById('gpu').textContent.includes('unavailable'), '本機無 NVIDIA 卻未顯示 unavailable');
  const main = document.querySelector('main').getBoundingClientRect();
  check(innerWidth > 0 && innerHeight > 0 && main.width <= innerWidth + 1, '主內容寬度超出 viewport');
  for (const type of ['settings.apply', 'theme.remove', 'app.exit']) {
    post(type, type);
    check((await waitMessage((m) => m.requestId === type)).payload.code === 'unsupported-message', `未拒絕 ${type}`);
  }
  let reached = false;
  try {
    reached = (await fetch(config.url, { signal: AbortSignal.timeout(2500) }).then((response) => response.text())) === 'fixture-ok';
  } catch {}
  check(reached === config.allowNetwork, 'HTTP 行為與原生網路偏好不符');
  transport.postMessage = send;
  send(subscription);
  if (config.allowNetwork) {
    const firstPush = await waitMessage((m) => m.type === 'metrics.changed');
    const nextPush = await waitMessage((m) => m.type === 'metrics.changed' && m.timestamp !== firstPush.timestamp);
    check(document.getElementById('timestamp').textContent === nextPush.timestamp, '訂閱推送未更新 DOM');
    await fetch(config.url + '&report=' + encodeURIComponent(JSON.stringify({
      origin: location.origin, width: innerWidth, height: innerHeight, dpr: devicePixelRatio,
      pushUpdatedDom: true,
      ready, timestamp: document.getElementById('timestamp').textContent,
      cpu: document.getElementById('cpu').textContent, gpu: document.getElementById('gpu').textContent,
      memory: document.getElementById('memory').textContent, network: document.getElementById('network').textContent,
    })));
  }
} catch (error) {
  console.error('作者驗收失敗：', error);
  document.getElementById('status').textContent = `驗收失敗：${error.message}`;
  if (config?.allowNetwork) {
    await fetch(config.url + '&error=' + encodeURIComponent(error.message)).catch(() => {});
  }
}
