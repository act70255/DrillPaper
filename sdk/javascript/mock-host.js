import {
  API_VERSION,
  MAX_UPDATE_INTERVAL_MS,
  MIN_UPDATE_INTERVAL_MS,
} from './desktop-monitor-sdk.js';

const DEFAULT_SNAPSHOT = {
  cpu: { usage: { value: 24.5, unit: 'percent', quality: 'available' } },
  gpu: { usage: { value: null, unit: 'percent', quality: 'unavailable' } },
  memory: { usedBytes: 33751040000, totalBytes: 103079215104 },
  disk: { activityPercent: { value: 0, unit: 'percent', quality: 'available' } },
  network: {
    rxBytesPerSec: { value: 123456, unit: 'bytes_per_second', quality: 'available' },
    txBytesPerSec: { value: 23456, unit: 'bytes_per_second', quality: 'available' },
  },
};

function withTimestamp(snapshot) {
  return { ...structuredClone(snapshot), timestamp: new Date().toISOString() };
}

export class MockHost {
  constructor({ window = globalThis.window, snapshot = DEFAULT_SNAPSHOT, updateEveryMs = 1000 } = {}) {
    if (!window) throw new Error('MockHost requires a browser window.');
    this._window = window;
    this._snapshot = withTimestamp(snapshot);
    this._history = [structuredClone(this._snapshot)];
    this._listeners = new Set();
    this._updateEveryMs = updateEveryMs;
    this._timer = null;
    this._state = 'active';
    this._webview = {
      addEventListener: (type, listener) => {
        if (type === 'message') this._listeners.add(listener);
      },
      removeEventListener: (type, listener) => {
        if (type === 'message') this._listeners.delete(listener);
      },
      postMessage: (message) => this._receive(message),
    };
    window.chrome ??= {};
    this._previousWebView = window.chrome.webview;
    window.chrome.webview = this._webview;
  }

  setSnapshot(snapshot) {
    this._snapshot = withTimestamp(snapshot);
    this._history.push(structuredClone(this._snapshot));
    if (this._history.length > 120) this._history.shift();
    this._emit('metrics.changed', this._snapshot);
  }

  setState(state) {
    this._state = state;
    this._emit('host.stateChanged', { state });
  }

  dispose() {
    clearInterval(this._timer);
    this._listeners.clear();
    if (this._window.chrome.webview === this._webview) {
      if (this._previousWebView === undefined) delete this._window.chrome.webview;
      else this._window.chrome.webview = this._previousWebView;
    }
  }

  _receive(message) {
    if (message?.apiVersion !== API_VERSION || typeof message.type !== 'string') return;
    switch (message.type) {
      case 'theme.hello':
        this._emit('host.ready', {
          hostVersion: 'mock',
          capabilities: ['cpu', 'gpu', 'memory', 'disk', 'network', 'clock'],
          state: this._state,
          limits: { maxHistory: 120, minUpdateIntervalMs: 1000 },
        });
        break;
      case 'metrics.getSnapshot':
        this._emit('metrics.snapshot', this._snapshot, message.requestId);
        break;
      case 'metrics.getHistory':
        {
          const requestedLimit = Number.isInteger(message.payload?.limit) ? message.payload.limit : 120;
          const limit = Math.min(120, Math.max(1, requestedLimit));
          this._emit('metrics.history', { snapshots: this._history.slice(-limit) }, message.requestId);
        }
        break;
      case 'metrics.subscribe':
        if (!Array.isArray(message.payload?.metrics) ||
            !message.payload.metrics.every((metric) => ['cpu', 'gpu', 'memory', 'disk', 'network', 'clock'].includes(metric)) ||
            new Set(message.payload.metrics).size !== message.payload.metrics.length ||
            !Number.isInteger(message.payload.intervalMs)) {
          this._emit('host.error', {
            code: 'invalid-payload',
            message: 'metrics.subscribe payload does not match Protocol v1.',
          }, message.requestId);
          break;
        }
        this._startUpdates(message.payload?.intervalMs);
        break;
      case 'metrics.unsubscribe':
        clearInterval(this._timer);
        this._timer = null;
        break;
      default:
        this._emit('host.error', { code: 'unsupported-message', message: 'Unsupported mock command.' }, message.requestId);
    }
  }

  _startUpdates(intervalMs) {
    clearInterval(this._timer);
    const requestedInterval = Number.isInteger(intervalMs) ? intervalMs : this._updateEveryMs;
    const safeInterval = Math.max(MIN_UPDATE_INTERVAL_MS,
      Math.min(MAX_UPDATE_INTERVAL_MS, requestedInterval));
    this._timer = setInterval(() => {
      this._snapshot = withTimestamp({
        ...this._snapshot,
        cpu: { usage: { value: (Date.now() / 100) % 100, unit: 'percent', quality: 'available' } },
      });
      this._history.push(structuredClone(this._snapshot));
      if (this._history.length > 120) this._history.shift();
      this._emit('metrics.changed', this._snapshot);
    }, safeInterval);
  }

  _emit(type, payload, requestId = null) {
    const envelope = {
      apiVersion: API_VERSION,
      type,
      requestId,
      timestamp: typeof payload?.timestamp === 'string' ? payload.timestamp : new Date().toISOString(),
      payload,
    };
    for (const listener of this._listeners) listener({ data: envelope });
  }
}

export { DEFAULT_SNAPSHOT };
