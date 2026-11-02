/** 分析同期程序樹 CPU，以整機容量正規化。
 * Args:
 *     rows: 依單調時間排序的資源樣本。
 *     metadata: 包含實際邏輯處理器數的觀測設定。
 * Returns:
 *     時間加權 CPU 平均與區間 p95。
 */
export function analyzePerformance(rows, metadata) {
  if (rows.length < 2 || !Number.isInteger(metadata.logicalProcessors) || metadata.logicalProcessors < 1
      || rows.some((row, index) => !Number.isFinite(row.seconds) || (index && row.seconds <= rows[index - 1].seconds)
        || !row.processes?.length || row.processes.some(p => !Number.isFinite(p.cpu) || p.cpu < 0 || !p.start))) {
    throw new Error('無效的時間序列、程序讀值或邏輯處理器數量。');
  }
  const intervals = [];
  let invalidCpuIntervals = 0;
  for (let index = 1; index < rows.length; index++) {
    const before = rows[index - 1], after = rows[index];
    const seconds = after.seconds - before.seconds;
    const delta = after.processes.reduce((sum, p) => sum + p.cpu, 0)
      - before.processes.reduce((sum, p) => sum + p.cpu, 0);
    const oldIdentities = before.processes.map(p => `${p.id}/${p.start}`).sort().join(';');
    const newIdentities = after.processes.map(p => `${p.id}/${p.start}`).sort().join(';');
    if (oldIdentities !== newIdentities || delta < 0 || seconds <= 0 || before.complete === false || after.complete === false) { invalidCpuIntervals++; continue; }
    intervals.push({ seconds, percent: delta / seconds / metadata.logicalProcessors * 100 });
  }
  const sorted = intervals.map(item => item.percent).sort((a, b) => a - b);
  const totalSeconds = intervals.reduce((sum, item) => sum + item.seconds, 0);
  const span = rows.at(-1).seconds - rows[0].seconds;
  const resourceRows = rows.filter(row => row.complete !== false);
  const totals = resourceRows.map(row => ({ seconds: row.seconds,
    private: row.processes.reduce((sum, p) => sum + p.private, 0) / 1048576,
    working: row.processes.reduce((sum, p) => sum + p.working, 0) / 1048576,
    handles: row.processes.reduce((sum, p) => sum + p.handles, 0),
    threads: row.processes.reduce((sum, p) => sum + p.threads, 0),
  }));
  const firstWindow = totals.filter(row => row.seconds - rows[0].seconds <= 300);
  const lastWindow = totals.filter(row => rows.at(-1).seconds - row.seconds <= 300);
  const xMean = mean(totals.map(row => row.seconds));
  const yMean = mean(totals.map(row => row.private));
  const variance = totals.reduce((sum, row) => sum + (row.seconds - xMean) ** 2, 0);
  const covariance = totals.reduce((sum, row) => sum + (row.seconds - xMean) * (row.private - yMean), 0);
  const surfaceRates = rows[0].surfaces.map(first => {
    const last = rows.at(-1).surfaces.find(surface => surface.hwnd === first.hwnd);
    return { hwnd: first.hwnd, metricsHz: last ? (last.metricsChanges - first.metricsChanges) / span : null,
      healthHz: last ? (last.healthChanges - first.healthChanges) / span : null };
  });
  const gpuSamples = rows.filter(row => !row.gpuError).flatMap(row => {
    const verified = new Set(row.processes.map(process => process.id));
    const values = Object.entries(row.gpu ?? {}).filter(([name, value]) => {
      const match = /^pid_(\d+)_/.exec(name);
      return match && verified.has(Number(match[1])) && Number.isFinite(value);
    }).map(([, value]) => value);
    return values.length ? [values.reduce((sum, value) => sum + value, 0)] : [];
  });
  return {
    cpuMeanPercent: totalSeconds ? intervals.reduce((sum, item) => sum + item.percent * item.seconds, 0) / totalSeconds : null,
    cpuP95Percent: sorted.length ? sorted[Math.ceil(sorted.length * 0.95) - 1] : null,
    invalidCpuIntervals,
    samples: rows.length, spanSeconds: span, durationMet: span >= metadata.duration,
    sampleIntervalMeanSeconds: span / (rows.length - 1),
    sampleIntervalMaxSeconds: Math.max(...rows.slice(1).map((row, index) => row.seconds - rows[index].seconds)),
    privateSlopeMiBPerMinute: variance ? covariance / variance * 60 : null,
    privateWindowDeltaMiB: difference(median(lastWindow.map(row => row.private)), median(firstWindow.map(row => row.private))),
    workingMeanMiB: mean(totals.map(row => row.working)),
    privateMeanMiB: yMean,
    handlesWindowDelta: difference(median(lastWindow.map(row => row.handles)), median(firstWindow.map(row => row.handles))),
    threadsWindowDelta: difference(median(lastWindow.map(row => row.threads)), median(firstWindow.map(row => row.threads))),
    totals,
    excludedResourceSamples: rows.length - resourceRows.length,
    resourceSpanSeconds: totals.length > 1 ? totals.at(-1).seconds - totals[0].seconds : null,
    surfaceRates,
    gpuEngineSumMeanPercent: mean(gpuSamples), gpuValidSamples: gpuSamples.length,
    surfaceValidation: metadata.scenario ? validateSurfaces(rows, metadata.scenario) : null,
    gpuUnknownInstances: rows.reduce((sum, row) => sum + Object.keys(row.gpu ?? {}).filter(name => {
      const match = /^pid_(\d+)_/.exec(name);
      return !match || !row.processes.some(process => process.id === Number(match[1]));
    }).length, 0),
  };
}

/** 對每筆原始宿主狀態核對主題、目標數、世代及播放狀態。
 * Args:
 *     rows: 原始時間序列。
 *     scenario: 事前指定的量測情境。
 * Returns:
 *     完整掃描的結果與不符筆數。
 */
function validateSurfaces(rows, scenario) {
  const expectedCount = scenario.endsWith('Single') ? 1 : 2;
  const expectedTheme = scenario.startsWith('Minimal') ? 'Minimal Monitor' : 'Dashboard';
  const paused = scenario === 'DashboardPaused';
  const initial = new Map(rows[0].surfaces.map(surface => [surface.hwnd, `${surface.load}/${surface.ready}`]));
  const invalidRows = rows.filter(row => row.surfaces.length !== expectedCount || row.surfaces.some(surface =>
    !surface.ready || !surface.load || initial.get(surface.hwnd) !== `${surface.load}/${surface.ready}`
    || !surface.caption?.includes(expectedTheme) || surface.visible === paused
    || !surface.caption.endsWith(paused ? '已暫停' : 'Live metrics'))).length;
  return { valid: invalidRows === 0, invalidRows, expectedCount, expectedTheme, paused };
}

/** 計算有限數列的平均；缺失數值不補零。
 * Args:
 *     values: 數值陣列。
 * Returns:
 *     平均或 null。
 */
function mean(values) { return values.length && values.every(Number.isFinite) ? values.reduce((sum, value) => sum + value, 0) / values.length : null; }

/** 計算首末窗口的中位數。
 * Args:
 *     values: 觀測數列。
 * Returns:
 *     中位數或 null。
 */
function median(values) {
  if (!values.length || !values.every(Number.isFinite)) return null;
  const sorted = values.toSorted((a, b) => a - b), middle = Math.floor(sorted.length / 2);
  return sorted.length % 2 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2;
}

/** 只有兩個有效窗口才計算差值。
 * Args:
 *     after: 末窗口值。
 *     before: 首窗口值。
 * Returns:
 *     有效差值或 null。
 */
function difference(after, before) { return after !== null && before !== null ? after - before : null; }
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';


/** 比較同期 collector 與系統參考，不將缺失品質轉成零。
 * Args:
 *     rows: 原生硬體探針 JSONL，包括各階段暖機基準。
 * Returns:
 *     逐階段精度、排除窗口及 GPU 可用性統計。
 */
export function analyzeAccuracy(rows) {
  const phases = [];
  for (let phase = 0; phase < 3; phase++) {
    const selected = rows.filter(row => row.phase === phase);
    const pairs = { cpu: [], memoryUsed: [], memoryTotal: [], disk: [], receive: [], transmit: [] };
    let previous = null, previousAligned = false, excludedWindows = 0;
    for (const row of selected) {
      if (row.baseline) { previous = row.network; previousAligned = Number.isFinite(row.skewMilliseconds) && row.skewMilliseconds <= 100; continue; }
      const aligned = Number.isFinite(row.skewMilliseconds) && row.skewMilliseconds <= 100;
      if (!aligned) { excludedWindows++; previous = row.referenceNetwork; previousAligned = false; continue; }
      const rateAligned = previousAligned && row.referenceQueryStatus === 0;
      for (const [name, reference, unit] of [
        ['cpu', rateAligned ? row.referenceCpu?.value : null, 0],
        ['disk', rateAligned ? row.referenceDisk?.value : null, 0],
        ['memoryUsed', row.referenceMemory?.valid ? row.referenceMemory.used : null, 1],
        ['memoryTotal', row.referenceMemory?.valid ? row.referenceMemory.total : null, 1],
      ]) {
        const metric = row[name];
        if (metric?.hasValue && metric.quality === 0 && metric.unit === unit && Number.isFinite(metric.value) && Number.isFinite(reference))
          pairs[name].push({ value: metric.value, reference });
      }
      const current = row.referenceNetwork;
      if (rateAligned && previous?.status === 0 && current?.status === 0 && current.tick > previous.tick && current.interfaces.length
          && previous.interfaces.every(item => item.status === 0 && Number.isFinite(item.receive) && Number.isFinite(item.transmit))
          && current.interfaces.every(item => item.status === 0 && Number.isFinite(item.receive) && Number.isFinite(item.transmit))
          && current.interfaces.map(item => item.luid).sort().join() === previous.interfaces.map(item => item.luid).sort().join()) {
        for (const name of ['receive', 'transmit']) {
          const oldCount = previous.interfaces.reduce((sum, item) => sum + item[name], 0);
          const newCount = current.interfaces.reduce((sum, item) => sum + item[name], 0);
          const metric = row[name];
          if (newCount >= oldCount && metric?.hasValue && metric.quality === 0 && metric.unit === 2 && Number.isFinite(metric.value))
            pairs[name].push({ value: metric.value, reference: (newCount - oldCount) * 1000 / (current.tick - previous.tick) });
        }
      }
      previous = current;
      previousAligned = aligned && row.referenceQueryStatus === 0;
    }
    const report = { phase, samples: selected.filter(row => !row.baseline).length, excludedWindows };
    for (const [name, values] of Object.entries(pairs)) {
      const error = mean(values.map(pair => Math.abs(pair.value - pair.reference)));
      const maximumError = values.length ? Math.max(...values.map(pair => Math.abs(pair.value - pair.reference))) : null;
      const referenceMean = mean(values.map(pair => pair.reference));
      const threshold = name === 'memoryUsed' ? 64 * 1048576 : name === 'memoryTotal'
        ? selected.find(row => row.referenceMemory?.valid)?.referenceMemory.pageSize ?? null
        : ['receive', 'transmit'].includes(name) ? Math.max(65536, (referenceMean ?? 0) * 0.1) : 5;
      const comparedError = name === 'memoryTotal' ? maximumError : error;
      report[name] = { samples: values.length, meanAbsoluteError: error, maximumAbsoluteError: maximumError, referenceMean, threshold,
        result: comparedError !== null && threshold !== null && comparedError > threshold ? 'FAIL' : comparedError !== null && threshold !== null && values.length === 30 ? 'PASS' : 'PARTIAL' };
    }
    phases.push(report);
  }
  return { phases, gpuAvailableSamples: rows.filter(row => !row.baseline && row.gpu?.hasValue).length,
    gpuUnavailableSamples: rows.filter(row => !row.baseline && row.gpu && !row.gpu.hasValue).length };
}

/** 讀取 UTF-8 JSONL，排除檔尾空行。
 * Args:
 *     file: 原始證據檔。
 * Returns:
 *     不修改來源的樣本陣列。
 */
function readRows(file) { return fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, '').trim().split(/\r?\n/).filter(Boolean).map(line => JSON.parse(line)); }

/** 分析 CLI，保留來源並產生可重算摘要及資源 CSV。
 * Args:
 *     args: 情境目錄，或 --accuracy 與硬體證據檔。
 */
function main(args) {
  try {
    if (args[0] === '--accuracy' && args.length === 2) {
      const summary = analyzeAccuracy(readRows(args[1]));
      fs.writeFileSync(args[1] + '.summary.json', JSON.stringify(summary, null, 2) + '\n');
      console.log(JSON.stringify(summary, null, 2));
      return;
    }
    if (args.length !== 1) throw new Error('必須指定情境證據目錄，或 --accuracy 與硬體 JSONL 路徑。');
    const folder = args[0];
    const metadata = JSON.parse(fs.readFileSync(path.join(folder, 'result.json'), 'utf8').replace(/^\uFEFF/, ''));
    const rows = readRows(path.join(folder, 'samples.jsonl'));
    const summary = analyzePerformance(rows, metadata);
    const columns = ['seconds', 'private', 'working', 'handles', 'threads'];
    fs.writeFileSync(path.join(folder, 'resources.csv'), [columns.join(','), ...summary.totals.map(row => columns.map(key => row[key] ?? '').join(','))].join('\n') + '\n');
    delete summary.totals;
    summary.collectionResult = metadata.result;
    summary.shutdown = metadata.exitCode === 0 && !metadata.shutdown && metadata.children?.length > 0 && metadata.survivors?.length === 0;
    summary.incompleteSamples = rows.filter(row => row.complete === false).length;
    summary.processCounts = [...new Set(rows.map(row => row.processes.length))];
    fs.writeFileSync(path.join(folder, 'summary.json'), JSON.stringify(summary, null, 2) + '\n');
    console.log(JSON.stringify(summary, null, 2));
  } catch (error) {
    const log = path.resolve('artifacts/acceptance/rc06-analysis-errors', `${Date.now()}.log`);
    fs.mkdirSync(path.dirname(log), { recursive: true }); fs.writeFileSync(log, String(error.stack));
    console.error(`錯誤：無法分析效能證據，請確認輸入、時間軸及程序身分。詳細日誌：${log}`);
    process.exitCode = 1;
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) main(process.argv.slice(2));
