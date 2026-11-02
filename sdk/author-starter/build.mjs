import { copyFileSync, mkdirSync } from 'node:fs';

try {
  mkdirSync('dist', { recursive: true });
  for (const file of ['theme.json', 'index.html', 'style.css']) copyFileSync(`static/${file}`, `dist/${file}`);
  console.log('已產生 dist 靜態主題；請用 SDK 正式工具封裝，SDK JS 由封裝器加入。');
} catch (error) {
  console.error('靜態資產建置失敗：', error.message);
  process.exitCode = 1;
}
