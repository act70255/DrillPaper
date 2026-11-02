import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

for (const script of ['check-security-netlog.mjs', 'summarize-security-netlog.mjs']) {
  test(script + ' 缺少必填目錄時顯示繁中提示並隱藏原始堆疊', () => {
    const result = spawnSync(process.execPath, [path.resolve('scripts', script)], { encoding: 'utf8' });
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /無法|失敗/);
    assert.doesNotMatch(result.stderr, /\n\s+at |file:\/\/\/|Node\.js v/);
  });
}

test('管理或獨立重啟缺少任一 NetLog 時不得通過', () => {
  fs.mkdirSync('artifacts', { recursive: true });
  const directory = fs.mkdtempSync(path.resolve('artifacts/security-netlog-test-'));
  fs.writeFileSync(path.join(directory, 'launch-one.json'), JSON.stringify({ captureNetwork: true }));
  fs.writeFileSync(path.join(directory, 'launch-two.json'), JSON.stringify({ captureNetwork: true }));
  fs.writeFileSync(path.join(directory, 'launch-one.json.netlog.json'), JSON.stringify({
    constants: { timeTickOffset: '0', logEventTypes: { URL_REQUEST_START_JOB: 1 } },
    events: [{ type: 1, time: '1000', source: { id: 1 },
      params: { method: 'GET', url: 'https://example.com/' } }],
  }));
  const result = spawnSync(process.execPath, [path.resolve('scripts/check-security-netlog.mjs'), directory], { encoding: 'utf8' });
  assert.notEqual(result.status, 0, '缺少第二輪 NetLog 時必須拒絕');
});
