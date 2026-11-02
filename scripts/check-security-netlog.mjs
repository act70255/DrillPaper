import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

try {
  // 只輸出端點、時間與傳輸計數；授權標頭及 POST 內容留在本機原始證據。
  const directory = process.argv[2];
  if (!directory) throw Error('必須指定安全測試證據目錄。');
  const files = fs.readdirSync(directory).filter(file => file.endsWith('.netlog.json'));
  if (!files.length) throw Error('沒有 NetLog，不能判定 SmartScreen 上傳。');
  const requests = fs.readdirSync(directory).filter(file => /^launch-[^.]+\.json$/.test(file));
  const expected = requests.filter(file => {
    const request = JSON.parse(fs.readFileSync(path.join(directory, file), 'utf8').replace(/^\uFEFF/, ''));
    // 接續前的唯讀證據沒有 captureNetwork 欄位，按其管理／Preview 啟動參數辨識。
    return request.captureNetwork === true || (request.captureNetwork === undefined &&
      request.args?.some(argument => argument === '--preview' || argument === '--management'));
  }).map(file => file + '.netlog.json');
  if (!expected.length || expected.some(file => !files.includes(file))) {
    throw Error('缺少預期的 NetLog 啟動紀錄或檔案，不能以部分觀測宣稱通過。');
  }
  const reports = [];
  for (const file of files) {
    const raw = fs.readFileSync(path.join(directory, file));
    const log = JSON.parse(raw.toString('utf8'));
    const names = new Map(Object.entries(log.constants.logEventTypes).map(([name, id]) => [id, name]));
    if (!log.events?.length || !Number.isFinite(Number(log.constants.timeTickOffset))) {
      throw Error('NetLog 缺少事件或時鐘資訊：' + file);
    }
    const attempts = [];
    const streams = [];
    for (const event of log.events) {
      const type = names.get(event.type);
      const params = event.params ?? {};
      if (type === 'URL_REQUEST_START_JOB' && params.method === 'POST' &&
          /^https?:\/\/[^/]*smartscreen\.microsoft\.com(?::\d+)?\//i.test(params.url ?? '')) {
        attempts.push({ time: new Date(Number(log.constants.timeTickOffset) + Number(event.time)).toISOString(),
          endpoint: new URL(params.url).origin + new URL(params.url).pathname });
      }
      if (type === 'HTTP2_SESSION_SEND_HEADERS' &&
          params.headers?.some(header => /^:authority: .*smartscreen\.microsoft\.com(?::\d+)?$/i.test(header)) &&
          params.headers.includes(':method: POST')) {
        const matching = log.events.filter(item => item.source.id === event.source.id &&
          item.params?.stream_id === params.stream_id);
        streams.push({ source: event.source.id, stream: params.stream_id,
          time: new Date(Number(log.constants.timeTickOffset) + Number(event.time)).toISOString(),
          sentBytes: matching.filter(item => names.get(item.type) === 'HTTP2_SESSION_SEND_DATA')
            .reduce((sum, item) => sum + Number(item.params.size ?? 0), 0),
          response: matching.filter(item => names.get(item.type) === 'HTTP2_SESSION_RECV_HEADERS')
            .flatMap(item => item.params.headers.filter(header => header.startsWith(':status: '))) });
      }
    }
    reports.push({ file, sha256: crypto.createHash('sha256').update(raw).digest('hex'),
      events: log.events.length, attempts, streams });
  }
  const failed = reports.some(report => report.attempts.length || report.streams.length);
  fs.writeFileSync(path.join(directory, 'smartscreen-result.json'), JSON.stringify({
    result: failed ? 'FAIL' : 'PASS',
    criterion: 'SmartScreen POST 嘗試即失敗；HTTP/2 source／stream 關聯 SEND_DATA 另證實實際上傳。僅限這些 NetLog 的觀測時段。',
    expectedNetlogs: expected, reports,
  }, null, 2));
  console.log((failed ? 'FAIL' : 'PASS') + '：SmartScreen POST 檢查，NetLog ' + files.length + ' 份；嘗試 ' +
    reports.reduce((sum, report) => sum + report.attempts.length, 0) + '；HTTP/2 送出 ' +
    reports.flatMap(report => report.streams).reduce((sum, stream) => sum + stream.sentBytes, 0) + ' bytes。');
  process.exitCode = failed ? 1 : 0;
} catch (error) {
  try {
    fs.mkdirSync('artifacts', { recursive: true });
    fs.appendFileSync('artifacts/security-netlog-errors.log', new Date().toISOString() + '\n' + error.stack + '\n');
  } catch { console.error('無法寫入本機詳細診斷日誌。'); }
  console.error('安全 NetLog 檢查失敗：請核對必填目錄、每次啟動的日誌與檔案完整性；詳細診斷見 artifacts/security-netlog-errors.log。');
  process.exitCode = 1;
}
