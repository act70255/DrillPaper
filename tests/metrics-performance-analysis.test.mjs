import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { analyzePerformance, analyzeAccuracy } from '../scripts/analyze-metrics-performance.mjs';

test('程序樹 CPU 依整機容量及同期時間差計算', () => {
  const rows = [
    { seconds: 0, processes: [{ id: 1, start: 'a', cpu: 0 }], surfaces: [] },
    { seconds: 10, processes: [{ id: 1, start: 'a', cpu: 14 }], surfaces: [] },
  ];
  const result = analyzePerformance(rows, { logicalProcessors: 14 });
  assert.equal(result.cpuMeanPercent, 10);
  assert.equal(result.cpuP95Percent, 10);
  assert.equal(result.sampleIntervalMaxSeconds, 10);
  assert.equal(result.sampleIntervalMeanSeconds, 10);
});

test('PID 重用區間不偽造成有效零 CPU', () => {
  const rows = [
    { seconds: 0, processes: [{ id: 1, start: 'a', cpu: 20 }], surfaces: [] },
    { seconds: 10, processes: [{ id: 1, start: 'b', cpu: 2 }], surfaces: [] },
  ];
  const result = analyzePerformance(rows, { logicalProcessors: 14 });
  assert.equal(result.cpuMeanPercent, null);
  assert.equal(result.invalidCpuIntervals, 1);
});

test('長測按完整時間序列算記憶體斜率與首末五分鐘中位數', () => {
  const rows = [
    { seconds: 0, processes: [{ id: 1, start: 'a', cpu: 0, private: 1048576, working: 1048576, handles: 10, threads: 2 }], surfaces: [] },
    { seconds: 300, processes: [{ id: 1, start: 'a', cpu: 1, private: 6291456, working: 6291456, handles: 10, threads: 2 }], surfaces: [] },
    { seconds: 600, processes: [{ id: 1, start: 'a', cpu: 2, private: 11534336, working: 11534336, handles: 10, threads: 2 }], surfaces: [] },
  ];
  const result = analyzePerformance(rows, { logicalProcessors: 14, duration: 1800, result: 'COMPLETED' });
  assert.equal(result.privateSlopeMiBPerMinute, 1);
  assert.equal(result.privateWindowDeltaMiB, 5);
  assert.equal(result.durationMet, false);
});

test('觀察頻率使用屬性變化計數，缺失 GPU 不當作零活動', () => {
  const rows = [
    { seconds: 0, processes: [{ id: 1, start: 'a', cpu: 0 }], surfaces: [{ hwnd: '7', metricsChanges: 0, healthChanges: 0 }], gpu: {}, gpuError: '無法取得' },
    { seconds: 10, processes: [{ id: 1, start: 'a', cpu: 1 }], surfaces: [{ hwnd: '7', metricsChanges: 9, healthChanges: 2 }], gpu: {}, gpuError: '無法取得' },
  ];
  const result = analyzePerformance(rows, { logicalProcessors: 14 });
  assert.equal(result.surfaceRates[0].metricsHz, 0.9);
  assert.equal(result.surfaceRates[0].healthHz, 0.2);
  assert.equal(result.gpuEngineSumMeanPercent, null);
});

test('不完整讀值及無效時間軸不能產生可用 CPU 結論', () => {
  const rows = [
    { seconds: 0, processes: [{ id: 1, start: 'a', cpu: 0 }], surfaces: [], complete: false },
    { seconds: 10, processes: [{ id: 1, start: 'a', cpu: 1 }], surfaces: [], complete: true },
  ];
  assert.equal(analyzePerformance(rows, { logicalProcessors: 14 }).cpuMeanPercent, null);
  assert.throws(() => analyzePerformance([], { logicalProcessors: 14 }), /無效/);
  assert.throws(() => analyzePerformance(rows, { logicalProcessors: 0 }), /無效/);
});

test('硬體比較排除錯開窗口，未取得 GPU 不冒充零', () => {
  const rows = [
    { phase: 0, baseline: true, skewMilliseconds: 1, network: { status: 0, tick: 0, interfaces: [] } },
    { phase: 0, skewMilliseconds: 1, referenceQueryStatus: 0,
      cpu: { hasValue: true, quality: 0, unit: 0, value: 12 }, referenceCpu: { value: 12.5 },
      gpu: { hasValue: false, value: 0 }, referenceNetwork: { status: 0, tick: 1000, interfaces: [] } },
    { phase: 0, skewMilliseconds: 101, referenceQueryStatus: 0,
      cpu: { hasValue: true, quality: 0, unit: 0, value: 99 }, referenceCpu: { value: 0 },
      gpu: { hasValue: false, value: 0 }, referenceNetwork: { status: 0, tick: 2000, interfaces: [] } },
  ];
  const result = analyzeAccuracy(rows);
  assert.equal(result.phases[0].cpu.samples, 1);
  assert.equal(result.phases[0].cpu.meanAbsoluteError, 0.5);
  assert.equal(result.phases[0].cpu.result, 'PARTIAL');
  assert.equal(result.gpuAvailableSamples, 0);
});

test('拒絕既有證據目錄時原結果保持不變', () => {
  const parent = path.join(os.homedir(), 'DrillPaperTests');
  fs.mkdirSync(parent, { recursive: true });
  const folder = fs.mkdtempSync(path.join(parent, 'rc06-refusal-'));
  try {
    const file = path.join(folder, 'result.json');
    fs.writeFileSync(file, '{"original":"不可覆寫"}\n');
    const child = spawnSync('pwsh', ['-NoProfile', '-File', path.resolve('scripts/test-metrics-performance.ps1'),
      '-ApplicationPath', process.execPath, '-EvidenceDirectory', folder, '-Scenario', 'MinimalSingle', '-DurationSeconds', '1'],
    { encoding: 'utf8', windowsHide: true, timeout: 30000 });
    assert.equal(child.status, 1, child.stderr);
    assert.equal(fs.readFileSync(file, 'utf8'), '{"original":"不可覆寫"}\n');
    assert.match(child.stderr, /錯誤：效能觀測未完成/);
  } finally {
    if (path.dirname(folder) === parent && path.basename(folder).startsWith('rc06-refusal-')) fs.rmSync(folder, { recursive: true });
  }
});

test('部分程序資源不會造成假性記憶體下降', () => {
  const rows = [
    { seconds: 0, processes: [{ id: 1, start: 'a', cpu: 0, private: 10485760, working: 10485760, handles: 10, threads: 2 }], surfaces: [], complete: true },
    { seconds: 300, processes: [{ id: 1, start: 'a', cpu: 1, private: 20971520, working: 20971520, handles: 10, threads: 2 }], surfaces: [], complete: true },
    { seconds: 600, processes: [{ id: 1, start: 'a', cpu: 2, private: 0, working: 0, handles: 1, threads: 1 }], surfaces: [], complete: false },
  ];
  const result = analyzePerformance(rows, { logicalProcessors: 14 });
  assert.equal(result.privateSlopeMiBPerMinute, 2);
  assert.equal(result.privateMeanMiB, 15);
  assert.equal(result.excludedResourceSamples, 1);
});

test('速率窗口上一端點錯開時下一筆也不判定精度通過', () => {
  const rows = [
    { phase: 0, baseline: true, skewMilliseconds: 1, network: { status: 0, tick: 0, interfaces: [] } },
    { phase: 0, skewMilliseconds: 101, referenceQueryStatus: 0, cpu: { hasValue: true, quality: 0, unit: 0, value: 12 }, referenceCpu: { value: 12 }, referenceNetwork: { status: 0, tick: 1000, interfaces: [] } },
    { phase: 0, skewMilliseconds: 1, referenceQueryStatus: 0, cpu: { hasValue: true, quality: 0, unit: 0, value: 12 }, referenceCpu: { value: 12 }, referenceNetwork: { status: 0, tick: 2000, interfaces: [] } },
  ];
  assert.equal(analyzeAccuracy(rows).phases[0].cpu.samples, 0);
});

test('GPU engine 僅統計同筆已核實程序，不採用未知 PID', () => {
  const rows = [
    { seconds: 0, processes: [{ id: 1, start: 'a', cpu: 0 }], surfaces: [], gpu: { pid_1_engine: 3, pid_99_engine: 90 } },
    { seconds: 10, processes: [{ id: 1, start: 'a', cpu: 1 }], surfaces: [], gpu: { pid_1_engine: 3, pid_99_engine: 90 } },
  ];
  assert.equal(analyzePerformance(rows, { logicalProcessors: 14 }).gpuEngineSumMeanPercent, 3);
});

test('逐筆驗證有效主題，保存的主題名稱不能代替畫面宿主狀態', () => {
  const rows = [
    { seconds: 0, processes: [{ id: 1, start: 'a', cpu: 0 }], surfaces: [{ hwnd: '7', load: 2, ready: 1, visible: true, caption: 'Dashboard — Live metrics' }] },
    { seconds: 10, processes: [{ id: 1, start: 'a', cpu: 1 }], surfaces: [{ hwnd: '7', load: 2, ready: 1, visible: true, caption: 'Minimal Monitor — Live metrics' }] },
  ];
  const result = analyzePerformance(rows, { logicalProcessors: 14, scenario: 'DashboardSingle' });
  assert.equal(result.surfaceValidation.valid, false);
  assert.equal(result.surfaceValidation.invalidRows, 1);
});

test('RAM total 的單筆超容差不會被平均值掩蓋', () => {
  const rows = Array.from({ length: 30 }, (_, index) => ({ phase: 0, skewMilliseconds: 1,
    memoryTotal: { hasValue: true, quality: 0, unit: 1, value: index === 29 ? 1073750016 : 1073741824 },
    referenceMemory: { valid: true, pageSize: 4096, total: 1073741824 },
  }));
  assert.equal(analyzeAccuracy(rows).phases[0].memoryTotal.result, 'FAIL');
});
