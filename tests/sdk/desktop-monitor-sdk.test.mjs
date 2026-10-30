import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  DesktopMonitor,
  DesktopMonitorClient,
  DrillPaper,
  DrillPaperClient,
  SDK_VERSION,
} from '../../sdk/javascript/desktop-monitor-sdk.js';
import { MockHost } from '../../sdk/javascript/mock-host.js';

class FakeTransport {
  listeners = new Set();
  sent = [];

  addEventListener(type, listener) {
    if (type === 'message') this.listeners.add(listener);
  }

  removeEventListener(type, listener) {
    if (type === 'message') this.listeners.delete(listener);
  }

  postMessage(message) {
    this.sent.push(message);
  }

  emit(message) {
    for (const listener of this.listeners) listener({ data: message });
  }
}

const hostReady = {
  apiVersion: '1',
  type: 'host.ready',
  requestId: null,
  timestamp: '2026-10-27T00:00:00.000Z',
  payload: { capabilities: ['cpu', 'memory'], state: 'active' },
};

async function connect(client, transport) {
  const ready = client.ready();
  transport.emit(hostReady);
  return ready;
}

test('ready sends one protocol hello and resolves on host.ready', async () => {
  const transport = new FakeTransport();
  const client = new DrillPaperClient(transport, { timeoutMs: 100 });
  let readyEvent;
  client.on('ready', (payload) => { readyEvent = payload; });

  const firstReady = client.ready();
  const secondReady = client.ready();
  assert.equal(transport.sent.length, 1);
  assert.equal(transport.sent[0].type, 'theme.hello');
  assert.equal(transport.sent[0].apiVersion, '1');
  transport.emit(hostReady);

  assert.deepEqual(await firstReady, hostReady.payload);
  assert.deepEqual(await secondReady, hostReady.payload);
  assert.deepEqual(readyEvent, hostReady.payload);
  client.dispose();
});

test('DrillPaper is the primary SDK name and DesktopMonitor remains a compatibility alias', () => {
  assert.equal(DesktopMonitorClient, DrillPaperClient);
  assert.equal(DesktopMonitor, DrillPaper);
});

test('Theme SDK reports the current release candidate version', () => {
  assert.equal(SDK_VERSION, '1.0.0-rc3');
});

test('getSnapshot resolves only from the matching requestId response', async () => {
  const transport = new FakeTransport();
  const client = new DrillPaperClient(transport, { timeoutMs: 100 });
  await connect(client, transport);

  const request = client.getSnapshot();
  const command = transport.sent.at(-1);
  assert.equal(command.type, 'metrics.getSnapshot');
  assert.equal(typeof command.requestId, 'string');

  const snapshot = { cpu: { usage: { value: 42, unit: 'percent', quality: 'available' } } };
  transport.emit({ ...hostReady, type: 'metrics.snapshot', requestId: 'unrelated', payload: snapshot });
  transport.emit({ ...hostReady, type: 'metrics.snapshot', requestId: command.requestId, payload: snapshot });
  assert.deepEqual(await request, { ...snapshot, timestamp: hostReady.timestamp });
  client.dispose();
});

test('metrics listeners receive push updates and unsubscribe cleanly', async () => {
  const transport = new FakeTransport();
  const client = new DrillPaperClient(transport, { timeoutMs: 100 });
  await connect(client, transport);
  const received = [];
  const off = client.on('metrics', (payload) => received.push(payload));

  const update = { cpu: { usage: { value: 0, unit: 'percent', quality: 'available' } } };
  transport.emit({ ...hostReady, type: 'metrics.changed', payload: update });
  off();
  transport.emit({ ...hostReady, type: 'metrics.snapshot', payload: { ignored: true } });

  assert.deepEqual(received, [{ ...update, timestamp: hostReady.timestamp }]);
  client.dispose();
});

test('getHistory clamps the request and returns the snapshot list', async () => {
  const transport = new FakeTransport();
  const client = new DrillPaperClient(transport, { timeoutMs: 100 });
  await connect(client, transport);

  const request = client.getHistory({ limit: 500 });
  const command = transport.sent.at(-1);
  assert.equal(command.type, 'metrics.getHistory');
  assert.deepEqual(command.payload, { limit: 120 });
  const snapshots = [{ timestamp: hostReady.timestamp, cpu: { usage: { value: 0 } } }];
  transport.emit({ ...hostReady, type: 'metrics.history', requestId: command.requestId,
    payload: { snapshots } });
  assert.deepEqual(await request, snapshots);
  client.dispose();
});

test('subscribe and unsubscribe use bounded protocol messages', async () => {
  const transport = new FakeTransport();
  const client = new DrillPaperClient(transport, { timeoutMs: 100 });
  await connect(client, transport);

  await client.subscribe({ metrics: ['cpu', 'memory'], intervalMs: 500 });
  await client.unsubscribe();
  const subscribe = transport.sent.at(-2);
  const unsubscribe = transport.sent.at(-1);
  assert.equal(subscribe.type, 'metrics.subscribe');
  assert.deepEqual(subscribe.payload, { metrics: ['cpu', 'memory'], intervalMs: 1000 });
  assert.equal(unsubscribe.type, 'metrics.unsubscribe');
  client.dispose();
});

test('subscribe drops unapproved metric names and clamps the update interval', async () => {
  const transport = new FakeTransport();
  const client = new DrillPaperClient(transport, { timeoutMs: 100 });
  await connect(client, transport);

  await client.subscribe({ metrics: ['cpu', 'shell', 'cpu', 'network'], intervalMs: 999999 });
  assert.deepEqual(transport.sent.at(-1).payload, {
    metrics: ['cpu', 'network'],
    intervalMs: 60000,
  });
  client.dispose();
});

test('a host with another protocol version cannot complete the handshake', async () => {
  const transport = new FakeTransport();
  const client = new DrillPaperClient(transport, { timeoutMs: 10 });
  const ready = client.ready();
  transport.emit({ ...hostReady, apiVersion: '2' });

  await assert.rejects(ready, /timed out/i);
  client.dispose();
});

test('a host with an invalid timestamp cannot complete the handshake', async () => {
  const transport = new FakeTransport();
  const client = new DrillPaperClient(transport, { timeoutMs: 10 });
  const ready = client.ready();
  transport.emit({ ...hostReady, timestamp: 'yesterday' });

  await assert.rejects(ready, /timed out/i);
  client.dispose();
});

test('pending requests time out instead of hanging forever', async () => {
  const transport = new FakeTransport();
  const client = new DrillPaperClient(transport, { timeoutMs: 10 });
  await connect(client, transport);

  await assert.rejects(client.getSnapshot(), /timed out/i);
  client.dispose();
});

test('pending requests are bounded', async () => {
  const transport = new FakeTransport();
  const client = new DrillPaperClient(transport, { timeoutMs: 20 });
  await connect(client, transport);

  const settled = await Promise.allSettled(Array.from({ length: 33 }, () => client.getSnapshot()));
  assert.equal(settled.filter((result) => result.status === 'rejected').length, 33);
  assert.match(settled[32].reason.message, /at most 32 pending requests/i);
  assert.equal(transport.sent.filter((message) => message.type === 'metrics.getSnapshot').length, 32);
  client.dispose();
});

test('MockHost supports SDK handshake, snapshot, and history in a browser-like window', async () => {
  const window = {};
  const mock = new MockHost({ window });
  const client = new DrillPaperClient(window.chrome.webview, { timeoutMs: 100 });

  const host = await client.ready();
  const snapshot = await client.getSnapshot();
  const history = await client.getHistory({ limit: 1 });
  assert.equal(host.state, 'active');
  assert.deepEqual(host.limits, { history: 120, messageBytes: 65536 });
  assert.equal(snapshot.cpu.usage.quality, 'available');
  assert.equal(history.length, 1);
  assert.equal(typeof history[0].timestamp, 'string');

  client.dispose();
  mock.dispose();
});

test('MockHost rejects a malformed subscription payload with a protocol error', async () => {
  const window = {};
  const mock = new MockHost({ window });
  const client = new DrillPaperClient(window.chrome.webview, { timeoutMs: 100 });
  await client.ready();
  let receivedError;
  client.on('host.error', (error) => { receivedError = error; });

  window.chrome.webview.postMessage({
    apiVersion: '1', type: 'metrics.subscribe', requestId: null,
    timestamp: new Date().toISOString(), payload: { metrics: ['shell'], intervalMs: 1000 },
  });
  assert.equal(receivedError.code, 'invalid-payload');

  client.dispose();
  mock.dispose();
});
