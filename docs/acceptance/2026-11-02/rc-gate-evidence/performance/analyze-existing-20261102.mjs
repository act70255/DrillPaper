import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import { analyzePerformance } from '../../../../../scripts/analyze-metrics-performance.mjs';

/** 讀取既有 UTF-8 JSON，不建立或補造 metadata。
 * Args:
 *     file: 既有檔案路徑。
 * Returns:
 *     解析後的資料。
 */
function readJson(file) { return JSON.parse(fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, '')); }

/** 解析全部 JSONL，遇損毀行即停止，不能靜默略過尾筆。
 * Args:
 *     file: 既有 JSONL 路徑。
 * Returns:
 *     保留原順序的樣本。
 */
function readRows(file) { return fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, '').trim().split(/\r?\n/).map(JSON.parse); }

/** 計算有限數列中位數。
 * Args:
 *     values: 非空數列。
 * Returns:
 *     中位數。
 */
function median(values) {
  assert(values.length && values.every(Number.isFinite), '中位數輸入必須完整。');
  const sorted = values.toSorted((a, b) => a - b), mid = Math.floor(sorted.length / 2);
  return sorted.length % 2 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
}

/** 只以新名稱寫入衍生證據，拒絕覆寫。
 * Args:
 *     file: 新檔路徑。
 *     value: JSON 資料。
 */
function save(file, value) { fs.writeFileSync(file, JSON.stringify(value, null, 2) + '\n', { flag: 'wx' }); }

try {
  const [root, output] = process.argv.slice(2);
  assert(root && output, '必須指定原始資料根目錄與新的分析輸出目錄。');
  const environment = readJson(path.join(output, 'environment.json'));
  const rows = readRows(path.join(root, 'soak/samples.jsonl'));
  const launchFile = fs.readdirSync(path.join(root, 'soak')).find(name => /^launch-[^.]+\.json$/.test(name));
  const launch = readJson(path.join(root, 'soak', launchFile));
  assert.deepEqual(launch.args, ['--management', '--preview', '--no-smart-sleep']);
  assert(!fs.existsSync(path.join(root, 'soak/result.json')), '現況已有 metadata，須重新核對強制收尾前提。');
  const metadata = { logicalProcessors: environment.cpu.NumberOfLogicalProcessors, duration: 1800, scenario: 'MinimalMulti' };
  const analysis = analyzePerformance(rows, metadata);
  assert.equal(metadata.logicalProcessors, 14);
  for (const row of rows) {
    for (const proc of row.processes) for (const field of ['private', 'working', 'handles', 'threads']) assert(Number.isFinite(proc[field]));
    assert(Number.isFinite(Date.parse(row.utc)));
  }
  const totals = analysis.totals;
  const first = totals.filter(row => row.seconds - rows[0].seconds <= 300);
  const last = totals.filter(row => rows.at(-1).seconds - row.seconds <= 300);
  const windows = Object.fromEntries(['private', 'working', 'handles', 'threads'].map(field => [field, {
    first: median(first.map(row => row[field])), last: median(last.map(row => row[field])),
  }]));
  const bins = [];
  for (let start = 0; start < analysis.spanSeconds; start += 600) {
    const selected = totals.filter(row => row.seconds - rows[0].seconds >= start && row.seconds - rows[0].seconds < start + 600);
    bins.push({ startSeconds: start, endSeconds: Math.min(start + 600, analysis.spanSeconds), partial: start + 600 > analysis.spanSeconds,
      samples: selected.length, ...Object.fromEntries(['private', 'working', 'handles', 'threads'].map(field => [field, median(selected.map(row => row[field]))])) });
  }
  const identities = rows.map(row => row.processes.map(proc => `${proc.id}/${proc.start}/${proc.role}/${proc.parent}/${proc.path}`).sort().join(';'));
  const compositionChanges = identities.slice(1).filter((key, i) => key !== identities[i]).length;
  const independentCpu = [];
  for (let i = 1; i < rows.length; i++) {
    const a = rows[i - 1], b = rows[i], seconds = b.seconds - a.seconds;
    if (a.complete && b.complete && identities[i - 1] === identities[i]) independentCpu.push({ seconds,
      percent: b.processes.reduce((sum, p) => sum + p.cpu - a.processes.find(old => old.id === p.id && old.start === p.start).cpu, 0) / seconds / 14 * 100 });
  }
  const weighted = independentCpu.reduce((sum, v) => sum + v.percent * v.seconds, 0) / independentCpu.reduce((sum, v) => sum + v.seconds, 0);
  assert(Math.abs(weighted - analysis.cpuMeanPercent) < 1e-10, 'CPU 獨立逐程序核算不一致。');
  const validation = { validJsonRows: rows.length, skippedReads: rows.flatMap(row => row.skipped), compositionChanges,
    processCounts: [...new Set(rows.map(row => row.processes.length))], firstWindowSamples: first.length, lastWindowSamples: last.length,
    intervalOver10Seconds: rows.slice(1).filter((row, i) => row.seconds - rows[i].seconds > 10).length,
    note: '缺失數為檔案中 complete/skipped 與間隔核對；沒有外部序號，無法證明取樣間短命程序均被捕捉。',
    independentCpuMeanPercent: weighted };
  const os = readRows(path.join(root, 'os-state.jsonl'));
  const firstTime = Date.parse(rows[0].utc), lastTime = Date.parse(rows.at(-1).utc);
  const inRange = os.filter(row => Date.parse(row.timestamp) >= firstTime && Date.parse(row.timestamp) <= lastTime);
  const stateCounts = {};
  for (const row of inRange) {
    const key = `${row.sessionFlags === 1 ? 'unlocked' : row.sessionFlags === 0 ? 'locked' : 'unknown'}/${['off', 'on', 'dim'][row.consoleDisplay] ?? 'unknown'}`;
    stateCounts[key] = (stateCounts[key] ?? 0) + 1;
  }
  const aligned = []; let osIndex = 0;
  for (const row of rows) {
    const time = Date.parse(row.utc);
    while (osIndex + 1 < os.length && Date.parse(os[osIndex + 1].timestamp) <= time) osIndex++;
    const state = os[osIndex];
    aligned.push({ utc: row.utc, osUtc: state.timestamp, lagMs: time - Date.parse(state.timestamp), sessionFlags: state.sessionFlags, consoleDisplay: state.consoleDisplay });
  }
  const osSummary = { firstResourceUtc: rows[0].utc, lastResourceUtc: rows.at(-1).utc, osSamples: inRange.length, stateCounts,
    maxOsGapMs: Math.max(...inRange.slice(1).map((row, i) => Date.parse(row.timestamp) - Date.parse(inRange[i].timestamp))),
    maxAlignmentLagMs: Math.max(...aligned.map(row => row.lagMs)),
    staleAlignments: aligned.filter(row => row.lagMs < 0 || row.lagMs > 1000).length,
    allResourcesUnlockedOn: aligned.every(row => row.sessionFlags === 1 && row.consoleDisplay === 1) };
  const switches = readRows(path.join(root, 'switches-formal/switches.jsonl'));
  const switchResult = readJson(path.join(root, 'switches-formal/result.json'));
  const savedSwitchSummary = readJson(path.join(root, 'switches-formal/switch-summary.json'));
  const previous = new Map(switchResult.initial.map(surface => [surface.hwnd, surface]));
  const switchInvalid = [];
  for (const [i, row] of switches.entries()) {
    const valid = row.index === i + 1 && row.result === 'PASS' && row.seconds <= 20 && row.surfaces.length === 2 && row.surfaces.every(surface => {
      const old = previous.get(surface.hwnd);
      return old && surface.load > old.load && surface.ready > old.ready && surface.health > old.health
        && surface.metrics > row.pushBaseline[surface.hwnd] && surface.visible && surface.parent
        && surface.caption.includes(i % 2 === 0 ? 'Dashboard' : 'Minimal Monitor') && surface.caption.endsWith('Live metrics');
    });
    if (!valid) switchInvalid.push(row.index);
    for (const surface of row.surfaces) previous.set(surface.hwnd, surface);
  }
  const switchSamples = switches.flatMap(row => ['before', 'after'].map(phase => ({ index: row.index, phase, ...row[phase] })));
  const times = switches.map(row => row.seconds).sort((a, b) => a - b);
  const switchSummary = { recorded: switches.length, failures: switches.filter(row => row.result !== 'PASS').length,
    independentValidationFailures: switchInvalid, secondsMean: times.reduce((sum, v) => sum + v, 0) / times.length,
    secondsMedian: median(times), secondsP95: times[Math.ceil(times.length * 0.95) - 1], secondsMin: times[0], secondsMax: times.at(-1),
    resourceSamples: switchSamples.length, incompleteResourceSamples: switchSamples.filter(row => !row.complete).length,
    skippedReads: switchSamples.flatMap(row => row.skipped),
    first: switchSamples[0].totals, last: switchSamples.at(-1).totals,
    firstWorkingMiB: switchSamples[0].processes.reduce((sum, p) => sum + p.working, 0) / 1048576,
    lastWorkingMiB: switchSamples.at(-1).processes.reduce((sum, p) => sum + p.working, 0) / 1048576,
    exitCode: switchResult.exitCode, survivors: switchResult.survivors,
    processCounts: [...new Set(switchSamples.map(row => row.processes.length))] };
  for (const key of ['recorded', 'failures', 'secondsMean', 'secondsP95', 'secondsMin', 'secondsMax', 'resourceSamples', 'incompleteResourceSamples']) assert.equal(switchSummary[key], savedSwitchSummary[key]);
  const csv = fs.readFileSync(path.join(root, 'switches-formal/switch-resources.csv'), 'utf8').trim().split(/\r?\n/);
  assert.equal(csv.length, 201);
  for (const [i, row] of switchSamples.entries()) assert.equal(csv[i + 1], [row.index, row.phase, row.utc, row.complete, row.totals.private, row.totals.handles, row.totals.threads, row.processes.length].join(','));
  const criteria = { duration: analysis.durationMet, privateWindow: analysis.privateWindowDeltaMiB <= 32,
    privateSlope: analysis.privateSlopeMiBPerMinute <= 1, handles: analysis.handlesWindowDelta <= 10, threads: analysis.threadsWindowDelta <= 10,
    cpuMean: analysis.cpuMeanPercent <= 1, cpuP95: analysis.cpuP95Percent <= 3 };
  delete analysis.totals;
  const summary = { metadataProvenance: 'result.json 不存在；CPU 核數取 environment.json，情境由 launch、雙宿主及原始主題交叉核對；1800 秒為使用者新決策。',
    metadata, launch, originalRequestedSeconds: 7200, firstUtc: rows[0].utc, lastUtc: rows.at(-1).utc,
    ...analysis, validation, windows, bins, firstTotals: totals[0], lastTotals: totals.at(-1),
    processes: rows[0].processes.map(({ id, start, parent, role, path }) => ({ id, start, parent, role, path })),
    criteria, performanceResult: Object.values(criteria).every(Boolean) ? 'PASS' : 'FAIL', formalExit: 'NOT RUN',
    comparison06: { single: readJson('docs/acceptance/2026-10-30/metrics-performance/minimal-single2/summary.json'),
      multi: readJson('docs/acceptance/2026-10-30/metrics-performance/MinimalMulti/summary.json') } };
  save(path.join(output, 'soak-analysis-20261102.json'), summary);
  save(path.join(output, 'os-analysis-20261102.json'), osSummary);
  save(path.join(output, 'switch-analysis-20261102.json'), switchSummary);
  fs.writeFileSync(path.join(output, 'soak-resources-20261102.csv'), ['seconds,privateMiB,workingMiB,handles,threads', ...totals.map(row => [row.seconds, row.private, row.working, row.handles, row.threads].join(','))].join('\n') + '\n', { flag: 'wx' });
  console.log(JSON.stringify({ ...summary, comparison06: undefined, processes: undefined, launch: undefined, os: osSummary, switches: switchSummary }, null, 2));
} catch (error) {
  const diagnostic = path.resolve(`rc11-analysis-error-${Date.now()}-${process.pid}.log`);
  try {
    fs.writeFileSync(diagnostic, String(error.stack), { flag: 'wx' });
    console.error(`錯誤：既有證據分析未完成，請確認輸入路徑、檔案與資料格式。詳細日誌：${diagnostic}`);
  } catch {
    console.error('錯誤：既有證據分析未完成，且無法保存詳細日誌；請確認輸入及目前目錄的寫入權限。');
  }
  process.exitCode = 1;
}
