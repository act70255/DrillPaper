import assert from 'node:assert/strict';
import test from 'node:test';
import { spawnSync } from 'node:child_process';
import path from 'node:path';
import { mkdirSync, mkdtempSync, readFileSync, writeFileSync } from 'node:fs';

test('公開測試入口以非 Temp 使用者繁中空白目錄建立隔離資料', () => {
  const result = spawnSync('powershell.exe', ['-NoProfile', '-Command',
    '. ./scripts/test-workspace.ps1; $root = New-DrillPaperTestWorkspace -Name contract; if (-not (Test-Path -LiteralPath $root -PathType Container)) { exit 2 }; [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false); Write-Output $root; Remove-Item -LiteralPath $root -Force;'],
  { encoding: 'utf8', windowsHide: true });
  assert.equal(result.status, 0, result.stderr);
  const root = result.stdout.trim();
  assert.ok(root.startsWith(path.join(process.env.USERPROFILE, 'DrillPaperTests') + path.sep), root);
  assert.match(root, /回歸 含空白/);
  assert.ok(!root.toLowerCase().startsWith(path.resolve(process.env.TEMP).toLowerCase() + path.sep));
});

test('主題 CLI 缺少 USERPROFILE 時記錄詳細日誌並顯示繁中友善提示', () => {
  const command = '[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false); $env:USERPROFILE = ""; & ./scripts/test-theme-cli.ps1 -ApplicationPath $env:DRILLPAPER_TEST_APPLICATION';
  const result = spawnSync('powershell.exe', ['-NoProfile', '-Command', command], {
    encoding: 'utf8', windowsHide: true,
    env: { ...process.env, DRILLPAPER_TEST_APPLICATION: process.execPath },
  });
  assert.equal(result.status, 1);
  assert.match(result.stderr, /錯誤：無法完成主題 CLI 驗證/);
  assert.match(result.stderr, /詳細日誌：/);
  assert.doesNotMatch(result.stderr, /CategoryInfo|FullyQualifiedErrorId|ScriptStackTrace/);
  const diagnostic = result.stderr.match(/詳細日誌：([^\r\n]+)/)[1].trim();
  assert.match(readFileSync(diagnostic, 'utf8'), /缺少 USERPROFILE/);
});

test('安全整合入口拒絕既有證據目錄並保留其中資料', () => {
  const prefix = path.join(process.env.USERPROFILE, 'DrillPaperTests', '回歸 含空白');
  mkdirSync(prefix, { recursive: true });
  const evidence = mkdtempSync(path.join(prefix, 'existing-evidence-'));
  const sentinel = path.join(evidence, 'source');
  writeFileSync(sentinel, '既有證據不可覆寫', 'utf8');
  const result = spawnSync('pwsh', ['-NoProfile', '-File', 'scripts/test-webview2-security.ps1',
    '-ApplicationPath', process.execPath, '-EvidenceDirectory', evidence],
  { encoding: 'utf8', windowsHide: true, timeout: 10000 });
  assert.equal(result.status, 1);
  assert.match(result.stderr, /證據目錄已存在，拒絕覆寫/);
  assert.equal(readFileSync(sentinel, 'utf8'), '既有證據不可覆寫');
});
