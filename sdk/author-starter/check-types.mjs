import { spawnSync } from 'node:child_process';
import assert from 'node:assert/strict';

try {
  const compiler = 'node_modules/typescript/bin/tsc';
  const version = spawnSync(process.execPath, [compiler, '--version'], { encoding: 'utf8' });
  assert.equal(version.status, 0, '無法啟動 TypeScript compiler。');
  assert.equal(version.stdout.trim(), 'Version 5.9.3', 'TypeScript 版本必須固定為 5.9.3。');
  console.log(version.stdout.trim());
  for (const [fixture, codes] of [['valid', []], ['invalid', ['2322', '2769', '2322', '2345']]]) {
    const result = spawnSync(process.execPath, [compiler, '--strict', '--noEmit', '--target', 'ES2022',
      '--module', 'ES2022', '--moduleResolution', 'bundler', `contracts/${fixture}.ts`], { encoding: 'utf8' });
    console.log(result.stdout, result.stderr);
    assert.equal(result.status, codes.length ? 2 : 0, `${fixture} 編譯結果不符合預期。`);
    assert.deepEqual([...result.stdout.matchAll(/error TS(\d+):/g)].map((match) => match[1]), codes,
      '必須僅出現預定的型別錯誤，不能以缺檔或語法錯誤冒充。');
  }
  console.log('PASS：SDK／MockHost 正確用法編譯成功，四個錯誤用法均由 compiler 拒絕。');
} catch (error) {
  console.error('型別契約檢查失敗：', error.message);
  process.exitCode = 1;
}
