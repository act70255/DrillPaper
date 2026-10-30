import fs from 'node:fs';
import path from 'node:path';

try {
  const directory = process.argv[2];
  if (!directory) throw Error('必須指定安全測試證據目錄。');
  // 同時接受首筆曾採縮排格式的早期證據，不改寫原始檔。
  const phaseText = fs.readFileSync(path.join(directory, 'network-phases.jsonl'), 'utf8').replace(/^\uFEFF/, '').trim();
  const phases = JSON.parse('[' + phaseText.replace(/}\s*\r?\n(?=\{)/g, '},') + ']');
  const dnsHost = phases[0].dnsHost;
  const summaries = [];
  for (const file of fs.readdirSync(directory).filter(name => name.endsWith('.netlog.json'))) {
    const log = JSON.parse(fs.readFileSync(path.join(directory, file), 'utf8'));
    const names = new Map(Object.entries(log.constants.logEventTypes).map(([name, id]) => [id, name]));
    const counts = new Map();
    for (const event of log.events) {
      const type = names.get(event.type) ?? String(event.type);
      if (!/HOST_RESOLVER|DNS_TRANSACTION|TCP_CONNECT|SSL_CONNECT|URL_REQUEST_START_JOB/.test(type)) continue;
      // 僅保留已知探針及背景端點的聚合，原始 NetLog 留本機 artifacts。
      const params = event.params ?? {};
      let endpoint = params.host ?? params.hostname ?? params.url ?? params.address ?? '';
      if (!endpoint) continue;
      // 組態請求的 query 可能包含裝置識別值，不寫入可提交的聚合。
      if (/^https?:\/\//i.test(String(endpoint))) {
        const url = new URL(endpoint);
        endpoint = url.origin + url.pathname;
      }
      const milliseconds = Number(log.constants.timeTickOffset) + Number(event.time);
      const phase = phases.filter(item => Date.parse(item.timestamp) <= milliseconds).at(-1)?.phase ?? 'minimal-baseline';
      const category = String(endpoint).includes(dnsHost) ? 'theme-dns-hint' :
        /127\.0\.0\.1|example\.com|drillpaper-theme-/.test(String(endpoint)) ? 'known-probe-or-local-origin' : 'browser-unattributed';
      const key = JSON.stringify({ phase, type, endpoint, category });
      counts.set(key, (counts.get(key) ?? 0) + 1);
    }
    summaries.push({ file, events: log.events.length, endpoints: [...counts].map(([key, count]) => ({ ...JSON.parse(key), count })) });
  }
  if (!summaries.length) throw Error('沒有 NetLog，不能宣稱 DNS／背景流量已觀測。');
  fs.writeFileSync(path.join(directory, 'netlog-summary.json'), JSON.stringify({
    dnsHost, attribution: '觀測點限 WebView2 NetLog；未歸因背景端點不代表主題或產品遙測。', summaries,
  }, null, 2));
  console.log('已彙整 ' + summaries.length + ' 份 NetLog；完整 DNS 封鎖仍須受控解析器正向控制。');
} catch (error) {
  try {
    fs.mkdirSync('artifacts', { recursive: true });
    fs.appendFileSync('artifacts/security-netlog-errors.log', new Date().toISOString() + '\n' + error.stack + '\n');
  } catch { console.error('無法寫入本機詳細診斷日誌。'); }
  console.error('安全 NetLog 彙整失敗：請核對必填目錄、切換時間紀錄與日誌完整性；詳細診斷見 artifacts/security-netlog-errors.log。');
  process.exitCode = 1;
}
