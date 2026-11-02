import fs from 'node:fs';
import { spawnSync } from 'node:child_process';
import { pathToFileURL } from 'node:url';

/** 直接執行單次 CLI，不經 shell 重新解析路徑及參數。
 * Args:
 *     request: application、未加 shell 引號的 args 與隔離 localAppData。
 * Returns:
 *     原始退出碼、UTF-8 標準輸出與錯誤輸出。
 */
export function invokeThemeCli(request) {
  const child = spawnSync(request.application, request.args, {
    shell: false,
    windowsHide: true,
    encoding: 'utf8',
    env: { ...process.env, LOCALAPPDATA: request.localAppData },
    timeout: 15000,
  });
  if (child.error) throw new Error(`主題 CLI 啟動失敗或未於 15 秒內結束：${child.error.message}`);
  if (child.signal || child.status === null) throw new Error('主題 CLI 未正常結束。');
  return { ExitCode: child.status, Output: child.stdout, Error: child.stderr };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const request = JSON.parse(fs.readFileSync(process.argv[2], 'utf8').replace(/^\uFEFF/, ''));
    fs.writeFileSync(process.argv[2] + '.result.json', JSON.stringify(invokeThemeCli(request)), 'utf8');
  } catch (error) {
    console.error(`錯誤：${error.message}`);
    process.exitCode = 1;
  }
}
