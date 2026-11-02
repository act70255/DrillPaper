import { copyFileSync, statSync } from 'node:fs';
import { resolve } from 'node:path';

try {
  const sdk = process.argv[2];
  if (!sdk) throw new Error('請提供解壓 SDK 的 sdk/javascript 完整目錄。');
  const files = ['desktop-monitor-sdk.d.ts', 'mock-host.d.ts'];
  for (const file of files) {
    if (!statSync(resolve(sdk, file)).isFile()) throw new Error(`缺少 SDK 宣告：${file}`);
  }
  for (const file of files) copyFileSync(resolve(sdk, file), resolve('src', file));
  console.log('已準備作者端型別宣告；不會加入 dist。');
} catch (error) {
  console.error('SDK 宣告準備失敗：', error.message);
  process.exitCode = 1;
}
