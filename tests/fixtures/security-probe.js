import { DrillPaperClient } from './desktop-monitor-sdk.js';
const base = '__BASE__';
const enabled = __ENABLED__;
const client = new DrillPaperClient(window.chrome.webview);
await client.ready();
const local = await fetch('./download.json').then(r => r.json());
if (local.download !== '必須拒絕') throw new Error('離線主題不能讀取自己的 JSON 資產');
/** 斷言真實瀏覽器可觀察行為。
 * Args:
 *     value: 必須成立的條件。
 *     message: 失敗原因。
 */
function check(value, message) { if (!value) throw new Error(message); }
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
// 外部導覽必須維持原本頁面，否則後續訂閱不會成立。
location.href = base + '/navigate';
await new Promise(resolve => setTimeout(resolve, 500));
// 不訂閱即代表測試未通過；宿主既有 ReadyEpoch 只在真正訂閱後前進。
await client.subscribe({ metrics: ['cpu'], intervalMs: 1000 });
