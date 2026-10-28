export const API_VERSION = '1';
export const SDK_VERSION = '1.0.0-rc3';
export const MAX_HISTORY_LENGTH = 120;
export const MIN_UPDATE_INTERVAL_MS = 1000;
export const MAX_UPDATE_INTERVAL_MS = 60000;
export const MAX_PENDING_REQUESTS = 32;
const ALLOWED_METRICS = new Set(['cpu', 'gpu', 'memory', 'disk', 'network', 'clock']);

const REQUEST_RESPONSE_TYPES = new Map([
  ['metrics.getSnapshot', 'metrics.snapshot'],
  ['metrics.getHistory', 'metrics.history'],
]);

function findWebViewTransport() {
  const transport = globalThis.window?.chrome?.webview;
  if (!transport?.postMessage || !transport?.addEventListener) {
    throw new Error('DrillPaper is available only inside the DrillPaper WebView host.');
  }
  return transport;
}

function isRecord(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function isUtcTimestamp(value) {
  if (typeof value !== 'string') return false;
  const match = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d{1,9})?Z$/.exec(value);
  if (!match) return false;
  const [, yearText, monthText, dayText, hourText, minuteText, secondText] = match;
  const year = Number(yearText);
  const month = Number(monthText);
  const day = Number(dayText);
  const hour = Number(hourText);
  const minute = Number(minuteText);
  const second = Number(secondText);
  const leapYear = year % 4 === 0 && (year % 100 !== 0 || year % 400 === 0);
  const daysInMonth = [31, leapYear ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  return month >= 1 && month <= 12 && day >= 1 && day <= daysInMonth[month - 1] &&
    hour <= 23 && minute <= 59 && second <= 59;
}

export class DrillPaperClient {
  constructor(transport = findWebViewTransport(), { timeoutMs = 5000 } = {}) {
    if (!transport?.postMessage || !transport?.addEventListener) {
      throw new TypeError('A WebView-compatible message transport is required.');
    }
    this._transport = transport;
    this._timeoutMs = timeoutMs;
    this._listeners = new Map();
    this._requests = new Map();
    this._requestNumber = 0;
    this._readyStatus = 'idle';
    this._readyPayload = null;
    this._readyPromise = null;
    this._readyTimer = null;
    this._disposed = false;
    this._onMessage = (event) => this._receive(event?.data);
    transport.addEventListener('message', this._onMessage);
  }

  ready() {
    if (this._disposed) return Promise.reject(new Error('DrillPaper client is disposed.'));
    if (this._readyStatus === 'ready') return Promise.resolve(this._readyPayload);
    if (this._readyStatus === 'failed') return Promise.reject(this._readyError);
    if (this._readyPromise) return this._readyPromise;

    this._readyStatus = 'connecting';
    this._readyPromise = new Promise((resolve, reject) => {
      this._resolveReady = resolve;
      this._rejectReady = reject;
    });
    this._readyTimer = setTimeout(() => {
      this._failReady(new Error('DrillPaper host handshake timed out.'));
    }, this._timeoutMs);

    try {
      this._post('theme.hello', null, { sdkVersion: SDK_VERSION });
    } catch (error) {
      this._failReady(error);
    }
    return this._readyPromise;
  }

  getSnapshot() {
    return this._request('metrics.getSnapshot', {});
  }

  getHistory({ limit = MAX_HISTORY_LENGTH } = {}) {
    const boundedLimit = Number.isInteger(limit)
      ? Math.min(MAX_HISTORY_LENGTH, Math.max(1, limit))
      : MAX_HISTORY_LENGTH;
    return this._request('metrics.getHistory', { limit: boundedLimit }).then((payload) => {
      if (!Array.isArray(payload.snapshots)) {
        throw new Error('metrics.history response did not contain a snapshots array.');
      }
      return payload.snapshots;
    });
  }

  async subscribe({ metrics = [], intervalMs = 1000 } = {}) {
    await this.ready();
    const uniqueMetrics = [...new Set(Array.isArray(metrics) ? metrics : [])]
      .filter((metric) => typeof metric === 'string' && ALLOWED_METRICS.has(metric));
    const requestedInterval = Number.isInteger(intervalMs) ? intervalMs : MIN_UPDATE_INTERVAL_MS;
    const boundedInterval = Math.max(MIN_UPDATE_INTERVAL_MS,
      Math.min(MAX_UPDATE_INTERVAL_MS, requestedInterval));
    this._post('metrics.subscribe', null, { metrics: uniqueMetrics, intervalMs: boundedInterval });
  }

  async unsubscribe() {
    await this.ready();
    this._post('metrics.unsubscribe', null, {});
  }

  on(eventName, listener) {
    if (typeof eventName !== 'string' || typeof listener !== 'function') {
      throw new TypeError('on(eventName, listener) requires a string name and function listener.');
    }
    let listeners = this._listeners.get(eventName);
    if (!listeners) {
      listeners = new Set();
      this._listeners.set(eventName, listeners);
    }
    listeners.add(listener);
    return () => {
      listeners.delete(listener);
      if (listeners.size === 0) this._listeners.delete(eventName);
    };
  }

  dispose() {
    if (this._disposed) return;
    this._disposed = true;
    clearTimeout(this._readyTimer);
    this._transport.removeEventListener?.('message', this._onMessage);
    const error = new Error('DrillPaper client was disposed.');
    if (this._readyStatus === 'connecting') this._failReady(error);
    for (const request of this._requests.values()) {
      clearTimeout(request.timer);
      request.reject(error);
    }
    this._requests.clear();
    this._listeners.clear();
  }

  _request(type, payload) {
    if (this._readyStatus === 'ready') return this._sendRequest(type, payload);
    return this.ready().then(() => this._sendRequest(type, payload));
  }

  _sendRequest(type, payload) {
    if (this._requests.size >= MAX_PENDING_REQUESTS) {
      return Promise.reject(new Error(`DrillPaper allows at most ${MAX_PENDING_REQUESTS} pending requests.`));
    }
    const requestId = `dm-${++this._requestNumber}`;
    const responseType = REQUEST_RESPONSE_TYPES.get(type);
    if (!responseType) return Promise.reject(new Error(`Unsupported request: ${type}`));

    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        this._requests.delete(requestId);
        reject(new Error(`${type} timed out.`));
      }, this._timeoutMs);
      this._requests.set(requestId, { responseType, resolve, reject, timer });
      try {
        this._post(type, requestId, payload);
      } catch (error) {
        clearTimeout(timer);
        this._requests.delete(requestId);
        reject(error);
      }
    });
  }

  _post(type, requestId, payload) {
    this._transport.postMessage({
      apiVersion: API_VERSION,
      type,
      requestId,
      timestamp: new Date().toISOString(),
      payload,
    });
  }

  _receive(message) {
    if (this._disposed || !isRecord(message) || message.apiVersion !== API_VERSION ||
        typeof message.type !== 'string' ||
        !(message.requestId === null || typeof message.requestId === 'string') ||
        !isUtcTimestamp(message.timestamp) ||
        !isRecord(message.payload)) {
      return;
    }

    if (message.type === 'host.ready') {
      if (this._readyStatus !== 'connecting') return;
      clearTimeout(this._readyTimer);
      this._readyStatus = 'ready';
      this._readyPayload = message.payload;
      this._resolveReady(message.payload);
      this._emit('ready', message.payload);
    }

    if (message.type === 'host.error' && this._readyStatus === 'connecting') {
      this._failReady(new Error(message.payload.message || 'DrillPaper host rejected the handshake.'));
    }

    if (message.requestId !== null) {
      const request = this._requests.get(message.requestId);
      if (request && (message.type === request.responseType || message.type === 'host.error')) {
        clearTimeout(request.timer);
        this._requests.delete(message.requestId);
        if (message.type === 'host.error') {
          request.reject(new Error(message.payload.message || 'DrillPaper request failed.'));
        } else {
          const response = message.type === 'metrics.snapshot'
            ? { ...message.payload, timestamp: message.timestamp }
            : message.payload;
          request.resolve(response);
        }
      }
    }

    const eventPayload = message.type === 'metrics.snapshot' || message.type === 'metrics.changed'
      ? { ...message.payload, timestamp: message.timestamp }
      : message.payload;
    this._emit(message.type, eventPayload);
    if (message.type === 'metrics.snapshot' || message.type === 'metrics.changed') {
      this._emit('metrics', eventPayload);
    }
  }

  _failReady(error) {
    if (this._readyStatus !== 'connecting') return;
    clearTimeout(this._readyTimer);
    this._readyStatus = 'failed';
    this._readyError = error;
    this._rejectReady(error);
  }

  _emit(eventName, payload) {
    const listeners = this._listeners.get(eventName);
    if (!listeners) return;
    for (const listener of [...listeners]) {
      try {
        listener(payload);
      } catch (error) {
        console.error(`DrillPaper listener for ${eventName} failed:`, error);
      }
    }
  }
}

let defaultClient;
function getDefaultClient() {
  defaultClient ??= new DrillPaperClient();
  return defaultClient;
}

export const DrillPaper = Object.freeze({
  ready: () => getDefaultClient().ready(),
  getSnapshot: () => getDefaultClient().getSnapshot(),
  getHistory: (options) => getDefaultClient().getHistory(options),
  subscribe: (options) => getDefaultClient().subscribe(options),
  unsubscribe: () => getDefaultClient().unsubscribe(),
  on: (eventName, listener) => getDefaultClient().on(eventName, listener),
});

// Compatibility aliases retain the names used in the initial project handoff.
export { DrillPaperClient as DesktopMonitorClient };
export const DesktopMonitor = DrillPaper;
