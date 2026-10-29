import { DrillPaperClient } from './desktop-monitor-sdk.js';
/** 執行不阻擋文件載入的非同步安全探針。
 * Returns:
 *     全部真實瀏覽器斷言完成時解決的 Promise。
 */
async function runSecurityProbe() {
  const base = '__BASE__';
  const enabled = __ENABLED__;
  const client = new DrillPaperClient(window.chrome.webview);
  await client.ready();
  const preconnect = document.createElement('link');
  preconnect.rel = 'preconnect';
  preconnect.href = '__PRECONNECT__';
  document.head.append(preconnect);
  const local = await fetch('./download.json').then(r => r.json());
  if (local.download !== '必須拒絕') throw new Error('離線主題不能讀取自己的 JSON 資產');
  /** 斷言真實瀏覽器可觀察行為。
   * Args:
   *     value: 必須成立的條件。
   *     message: 失敗原因。
   */
  function check(value, message) { if (!value) throw new Error(message); }
  // 每次載入都必須是獨立來源；同一 profile 亦不能沿用前一來源的資料。
  check(localStorage.getItem('drillpaper-probe') === null, 'localStorage 跨來源重用');
  check(sessionStorage.getItem('drillpaper-probe') === null, 'sessionStorage 跨來源重用');
  check(!document.cookie.includes('drillpaper-probe='), 'Cookie 跨來源重用');
  check(!document.cookie.includes('drillpaper-host='), 'Host-only Cookie 跨來源重用');
  localStorage.setItem('drillpaper-probe', 'private');
  sessionStorage.setItem('drillpaper-probe', 'private');
  document.cookie = 'drillpaper-host=private; Secure; SameSite=Strict; Path=/';
  check(document.cookie.includes('drillpaper-host=private'), '目前來源無法保存自己的 Cookie');
  // 嘗試用共同父網域讓下一個主題來源讀到此值。
  document.cookie = `drillpaper-probe=private; Domain=${location.hostname.split('.').slice(1).join('.')}; Secure; SameSite=Strict; Path=/`;
  const cache = await caches.open('drillpaper-probe');
  check(await cache.match('./cache-marker') === undefined, 'Cache Storage 跨來源重用');
  await cache.put('./cache-marker', new Response('private'));
  check(await (await cache.match('./cache-marker')).text() === 'private', '目前來源 Cache Storage 正向控制失敗');
  /** 等待公開 IndexedDB 請求完成。
   * Args:
   *     request: 瀏覽器提供的 IDBRequest。
   * Returns:
   *     該請求的結果。
   */
  function idbResult(request) {
    return new Promise((resolve, reject) => {
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
  }
  const opening = indexedDB.open('drillpaper-probe', 1);
  opening.onupgradeneeded = () => opening.result.createObjectStore('marker');
  const database = await idbResult(opening);
  try {
    check(await idbResult(database.transaction('marker').objectStore('marker').get('key')) === undefined, 'IndexedDB 跨來源重用');
    const transaction = database.transaction('marker', 'readwrite');
    const committed = new Promise((resolve, reject) => {
      transaction.oncomplete = resolve;
      transaction.onabort = () => reject(transaction.error);
    });
    transaction.objectStore('marker').put('private', 'key');
    await committed;
    check(await idbResult(database.transaction('marker').objectStore('marker').get('key')) === 'private', '目前來源 IndexedDB 正向控制失敗');
  } finally { database.close(); }
  // 不需麥克風／攝影機的 data channel 也必須被宿主連線政策拒絕。
  check(typeof RTCPeerConnection === 'function', '受測 Runtime 缺少 WebRTC，不能驗證連線邊界');
  let peer;
  try {
    peer = new RTCPeerConnection({ iceServers: [{ urls: '__STUN__' },
      { urls: '__TURN__', username: 'probe', credential: 'probe' }] });
    peer.createDataChannel('probe');
    await peer.setLocalDescription(await peer.createOffer());
    await new Promise(resolve => setTimeout(resolve, 1000));
  } catch (error) {
    check(error.name === 'SecurityError', 'WebRTC 探針遇到非政策錯誤：' + error.name);
  } finally { peer?.close(); }
  /** 驗證 worker 不能執行，同時要求明確拒絕而非逾時。
   * Args:
   *     shared: 是否測試 SharedWorker。
   * Returns:
   *     明確遭 CSP 拒絕時為 true。
   */
  async function workerBlocked(shared) {
    let worker;
    let blocked = false;
    try {
      worker = shared ? new SharedWorker('./worker.js') : new Worker('./worker.js');
      return await new Promise(resolve => {
        const timer = setTimeout(() => resolve(false), 2000);
        worker.onerror = event => { event.preventDefault(); clearTimeout(timer); blocked = true; resolve(true); };
        const target = shared ? worker.port : worker;
        target.onmessage = () => { clearTimeout(timer); resolve(false); };
        if (shared) worker.port.start();
      });
    } catch (error) { return error.name === 'SecurityError'; }
    finally { if (!blocked) { worker?.terminate?.(); worker?.port?.close(); } }
  }
  check(await workerBlocked(false), 'Dedicated Worker 未明確拒絕');
  check(await workerBlocked(true), 'SharedWorker 未明確拒絕');
  check(await navigator.serviceWorker.register('./worker.js').then(() => false, error => error.name === 'SecurityError'), 'ServiceWorker 未拒絕');
  for (const name of ['camera', 'microphone']) {
    check((await navigator.permissions.query({ name })).state === 'denied', name + ' 權限未拒絕');
  }
  /** 取得外部資源載入結果。
   * Args:
   *     tag: HTML 元素類型。
   *     endpoint: 測試伺服器路徑。
   * Returns:
   *     載入成功時為 true。
   */
  function load(tag, endpoint) {
    return new Promise(resolve => {
      const element = document.createElement(tag);
      element.onload = () => resolve(true);
      element.onerror = () => resolve(false);
      element.src = base + endpoint;
      document.body.append(element);
      setTimeout(() => resolve(false), 3000);
    });
  }
  const fetched = await fetch(base + '/fetch').then(r => r.text(), () => 'blocked');
  check(fetched === (enabled ? 'fixture-ok' : 'blocked'), 'fetch 政策錯誤');
  const namedPath = await fetch(base + '/.drillpaper.local/resource').then(r => r.text(), () => 'blocked');
  check(namedPath === (enabled ? 'fixture-ok' : 'blocked'), '一般 HTTP 路徑被誤判為保留來源');
  const xhr = await new Promise(resolve => {
    const request = new XMLHttpRequest();
    request.open('GET', base + '/xhr');
    request.onload = () => resolve(request.responseText);
    request.onerror = () => resolve('blocked');
    request.send();
  });
  check(xhr === (enabled ? 'fixture-ok' : 'blocked'), 'XHR 政策錯誤');
  await load('script', '/script');
  check(Boolean(globalThis.remoteScript) === enabled, '外部 script 政策錯誤');
  check(await load('img', '/image') === enabled, '外部圖片政策錯誤');
  const redirected = await fetch(base + '/redirect').then(r => r.text(), () => 'blocked');
  check(redirected === (enabled ? 'fixture-ok' : 'blocked'), 'HTTP redirect 政策錯誤');
  const fileRedirect = await fetch(base + '/redirect-file').then(() => true, () => false);
  check(!fileRedirect, 'redirect 讀取 file scheme');
  for (const endpoint of [base.replace('http:', 'ws:') + '/socket', '__WSS__']) {
    await new Promise(resolve => {
      const socket = new WebSocket(endpoint);
      socket.onopen = () => { socket.close(); resolve(); };
      socket.onerror = resolve;
      setTimeout(resolve, 2000);
    });
  }
  await load('iframe', '/iframe');
  check(window.open(base + '/popup') === null, '彈窗未拒絕');
  check(await Notification.requestPermission() === 'denied', '通知權限未拒絕');
  const geolocation = await new Promise(resolve => navigator.geolocation.getCurrentPosition(
    () => resolve('allowed'), error => resolve(error.code === 1 ? 'denied' : 'other')));
  check(geolocation === 'denied', '定位權限未拒絕');
  for (const scheme of ['file:///C:/Windows/win.ini', 'data:text/plain,test', 'ftp://127.0.0.1/test']) {
    check(await fetch(scheme).then(() => false, () => true), '不支援的 scheme 可讀取');
  }
  const https = await fetch('https://example.com/?drillpaper-security-probe', { mode: 'no-cors' }).then(() => true, () => false);
  check(https === enabled, 'HTTPS 開關行為錯誤');
  const download = document.createElement('a');
  download.href = './download.json';
  download.download = 'drillpaper-security-denied.txt';
  document.body.append(download);
  download.click();
  await client.subscribe({ metrics: ['cpu'], intervalMs: 1000 });
}
// 透過非同步函數執行，不以頂層 await 延後文件的 load。
runSecurityProbe().catch(error => console.error(error));
