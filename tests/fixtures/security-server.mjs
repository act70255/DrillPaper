import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import net from 'node:net';
import dgram from 'node:dgram';

const directory = process.argv[2];
/** 記錄測試伺服器實際收到的請求。
 * Args:
 *     event: 請求種類與路徑。
 */
function record(event) {
  fs.appendFileSync(path.join(directory, 'requests.jsonl'), `${JSON.stringify(event)}\n`);
}
// 以 TCP 接收端觀察 WSS 是否進入 TLS 連線，避免把憑證拒絕誤當 CSP 封鎖。
const secureProbe = net.createServer(socket => {
  fs.appendFileSync(path.join(directory, 'secure-connections.jsonl'), '{"connection":true}\n');
  socket.destroy();
});
await new Promise(resolve => secureProbe.listen(0, '127.0.0.1', resolve));
const stunProbe = dgram.createSocket('udp4');
stunProbe.on('message', packet => {
  fs.appendFileSync(path.join(directory, 'stun-packets.jsonl'), `${JSON.stringify({
    control: packet.toString() === 'drillpaper-udp-control',
    stun: packet.length >= 20 && packet.readUInt32BE(4) === 0x2112a442,
    bytes: packet.length,
  })}\n`);
});
await new Promise(resolve => stunProbe.bind(0, '127.0.0.1', resolve));
const server = http.createServer((request, response) => {
  record({ method: request.method, url: request.url });
  response.setHeader('Access-Control-Allow-Origin', '*');
  response.setHeader('Cache-Control', 'no-store');
  if (request.url.startsWith('/script')) {
    response.setHeader('Content-Type', 'text/javascript');
    response.end('globalThis.remoteScript = true;');
  } else if (request.url.startsWith('/image')) {
    response.setHeader('Content-Type', 'image/svg+xml');
    response.end('<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"/>');
  } else if (request.url.startsWith('/redirect-file')) {
    response.writeHead(302, { Location: 'file:///C:/Windows/win.ini' });
    response.end();
  } else if (request.url.startsWith('/redirect')) {
    response.writeHead(302, { Location: '/target' });
    response.end();
  } else response.end('fixture-ok');
});
server.on('upgrade', (request, socket) => {
  record({ method: 'WEBSOCKET', url: request.url });
  socket.destroy();
});
server.listen(0, '127.0.0.1', () => {
  fs.writeFileSync(path.join(directory, 'server.json'), JSON.stringify({ port: server.address().port, securePort: secureProbe.address().port, stunPort: stunProbe.address().port }));
});
