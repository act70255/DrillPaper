import assert from 'node:assert/strict';
import test from 'node:test';
import { invokeThemeCli } from './fixtures/theme-cli-launcher.mjs';

test('CLI 啟動器直接保留參數、隔離設定、UTF-8 輸出與非零退出碼', () => {
  const result = invokeThemeCli({
    application: process.execPath,
    args: ['-e', 'console.log(JSON.stringify({args:process.argv.slice(1),local:process.env.LOCALAPPDATA,parent:process.ppid})); console.error("繁中錯誤"); process.exitCode=7;', '含空白 的路徑', '& % ! " 中文'],
    localAppData: 'C:\\Users\\James\\DrillPaperTests\\隔離 含空白',
  });
  assert.equal(result.ExitCode, 7);
  assert.deepEqual(JSON.parse(result.Output), {
    args: ['含空白 的路徑', '& % ! " 中文'],
    local: 'C:\\Users\\James\\DrillPaperTests\\隔離 含空白',
    parent: process.pid,
  });
  assert.equal(result.Error.trim(), '繁中錯誤');
});

test('缺少必要設定的 CLI 情境不會繼承外層 LOCALAPPDATA', () => {
  const result = invokeThemeCli({
    application: process.execPath,
    args: ['-e', 'console.log(JSON.stringify(process.env.LOCALAPPDATA ?? ""));'],
    localAppData: '',
  });
  assert.equal(result.ExitCode, 0);
  assert.equal(JSON.parse(result.Output), '');
});

test('CLI 超過原有 15 秒期限會失敗並終止本次子程序', () => {
  assert.throws(() => invokeThemeCli({
    application: process.execPath,
    args: ['-e', 'setTimeout(() => {}, 60000);'],
    localAppData: '',
  }), /15 秒.*ETIMEDOUT/);
});
