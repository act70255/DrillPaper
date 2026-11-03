import assert from 'node:assert/strict';
import test from 'node:test';
import { spawnSync } from 'node:child_process';
import { copyFileSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const script = path.join(repo, 'scripts', 'check-pe-imports.mjs');
const { readImports, readDelayImports, forbiddenImports } = await import(new URL('../scripts/check-pe-imports.mjs', import.meta.url));

test('從含空白與繁中的路徑執行仍會檢查並對無效檔案失敗，不得靜默放行', () => {
  // 工作目錄放在 repo 的 artifacts（gitignore），不使用 %TEMP%。
  const root = path.join(repo, 'artifacts', `pe-import-tests-${process.pid}`, '含 空白 繁中');
  mkdirSync(root, { recursive: true });
  try {
    const copied = path.join(root, 'check-pe-imports.mjs');
    copyFileSync(script, copied);
    const notPe = path.join(root, '不是執行檔.exe');
    writeFileSync(notPe, '不是 PE 檔');
    const result = spawnSync(process.execPath, [copied, notPe], { encoding: 'utf8', windowsHide: true });
    assert.equal(result.status, 1, `應以 1 結束：stdout=${result.stdout} stderr=${result.stderr}`);
    assert.match(result.stderr, /不是有效的 PE 檔/);
  } finally {
    rmSync(path.dirname(root), { recursive: true, force: true });
  }
});

test('讀取一般與 delay-load 匯入表', () => {
  const shell32 = readFileSync(path.join(process.env.SystemRoot, 'System32', 'shell32.dll'));
  assert.ok(readImports(shell32).some((name) => /^kernel32\.dll$/i.test(name) || /^api-ms-win-/i.test(name)));
  assert.ok(readDelayImports(shell32).length > 0, 'shell32.dll 應有 delay-load 匯入');
});

test('VC++ 平行／OpenMP 執行環境 DLL 也視為禁止依賴', () => {
  assert.deepEqual(forbiddenImports(['KERNEL32.dll', 'concrt140.dll', 'VCOMP140.DLL', 'user32.dll']), ['concrt140.dll', 'VCOMP140.DLL']);
});
