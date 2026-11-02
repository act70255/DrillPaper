import fs from 'node:fs';
import { spawn } from 'node:child_process';

// JSON 傳遞路徑與參數，避免 shell 插值；只用於隔離測試，不隨產品封裝。
const requestPath = process.argv[2];
const request = JSON.parse(fs.readFileSync(requestPath, 'utf8').replace(/^\uFEFF/, ''));
const started = new Date().toISOString();
const child = spawn(request.file, request.args, { windowsHide: true, stdio: 'ignore' });
child.on('spawn', () => fs.writeFileSync(requestPath + '.started.json', JSON.stringify({
  pid: child.pid, parent: process.pid, file: request.file, started,
})));
child.on('error', error => {
  fs.writeFileSync(requestPath + '.exit.json', JSON.stringify({ started, ended: new Date().toISOString(), error: error.message }));
  process.exitCode = 1;
});
child.on('exit', (code, signal) => {
  fs.writeFileSync(requestPath + '.exit.json', JSON.stringify({ started, ended: new Date().toISOString(), code, signal }));
  process.exitCode = code ?? 1;
});
