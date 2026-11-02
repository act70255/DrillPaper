import assert from 'node:assert/strict';
import path from 'node:path';
import os from 'node:os';
import { spawnSync } from 'node:child_process';
import test from 'node:test';

for (const script of ['test-default-startup.ps1', 'test-multi-monitor.ps1']) {
  test(`${script} 缺少必要 EXE 時顯示繁中友善訊息`, () => {
    const result = spawnSync('pwsh', ['-NoProfile', '-File', `scripts/${script}`,
      '-ApplicationPath', path.join(os.homedir(), 'DrillPaperTests', '不存在的 RC05 工具測試', 'missing.exe'),
      '-EvidenceDirectory', path.join(os.homedir(), 'DrillPaperTests', '不可建立的證據')],
    { encoding: 'utf8', timeout: 20000 });
    assert.equal(result.status, 1);
    assert.match(result.stderr, /^錯誤：/);
    assert.doesNotMatch(result.stderr, /Resolve-Path:|\nLine\s*\||\n\s*At /);
  });
}
