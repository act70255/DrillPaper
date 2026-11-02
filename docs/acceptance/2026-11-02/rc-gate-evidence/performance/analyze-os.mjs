import fs from 'node:fs';
import path from 'node:path';
import readline from 'node:readline';

// OS 狀態是另外的只讀證據；不把鎖定／關屏自動視為產品已暫停。
try {
  const [root, folder, output] = process.argv.slice(2);
  if (!root || !folder || !output) throw new Error('必須指定測試根目錄、soak 目錄及輸出目錄。');
  const rows = fs.readFileSync(path.join(folder, 'samples.jsonl'), 'utf8').trim().split(/\r?\n/).map(line => JSON.parse(line));
  const metadata = JSON.parse(fs.readFileSync(path.join(folder, 'result.json'), 'utf8').replace(/^\uFEFF/, ''));
  const times = rows.map(row => Date.parse(row.utc));
  const first = times[0], last = times.at(-1);
  const assignments = [], segments = [];
  let previous, index = 0, generation = 0, maxGapMs = 0, count = 0;
  const input = readline.createInterface({ input: fs.createReadStream(path.join(root, 'os-state.jsonl')), crlfDelay: Infinity });
  for await (const line of input) {
    if (!line.trim()) continue;
    const observation = JSON.parse(line);
    const time = Date.parse(observation.timestamp);
    if (!Number.isFinite(time)) throw new Error('OS 時間戳無效。');
    const session = observation.sessionFlags === 0 ? 'locked' : observation.sessionFlags === 1 ? 'unlocked' : 'unknown';
    const display = ['off', 'on', 'dim'][observation.consoleDisplay] ?? 'unknown';
    const key = `${session}/${display}`;
    while (index < times.length && times[index] < time) {
      const lagMs = previous ? times[index] - previous.time : null;
      assignments.push({ index, utc: rows[index].utc, key: previous?.key ?? 'unobserved', generation: previous?.generation ?? null, lagMs });
      index++;
    }
    if (previous && time >= first && previous.time <= last) maxGapMs = Math.max(maxGapMs, time - previous.time);
    if (!previous || key !== previous.key) {
      generation++;
      if (time <= last && (!previous || time >= first)) segments.push({ utc: observation.timestamp, time, key, generation });
    }
    previous = { time, key, generation };
    if (time >= first && time <= last) count++;
    if (time > last && index === times.length) break;
  }
  if (assignments.length !== rows.length) throw new Error('OS 觀測未覆蓋全部資源樣本。');
  const groups = new Map();
  for (const assignment of assignments) {
    if (!groups.has(assignment.key)) groups.set(assignment.key, { key: assignment.key, resourceSamples: 0, incompleteResourceSamples: 0, staleOsSamples: 0, pausedSurfaceSamples: 0, validCpuSeconds: 0, cpuWeighted: 0, cpuIntervals: [] });
    const group = groups.get(assignment.key), row = rows[assignment.index];
    group.resourceSamples++;
    if (!row.complete) group.incompleteResourceSamples++;
    if (assignment.lagMs === null || assignment.lagMs > 1000) group.staleOsSamples++;
    if (row.surfaces.some(surface => !surface.visible || surface.caption.endsWith('已暫停'))) group.pausedSurfaceSamples++;
  }
  let excludedCpuIntervals = 0;
  for (let i = 1; i < rows.length; i++) {
    const before = rows[i - 1], after = rows[i], a = assignments[i - 1], b = assignments[i];
    const elapsed = after.seconds - before.seconds;
    const oldIds = before.processes.map(p => `${p.id}/${p.start}`).sort().join(';');
    const newIds = after.processes.map(p => `${p.id}/${p.start}`).sort().join(';');
    const delta = after.processes.reduce((sum, p) => sum + p.cpu, 0) - before.processes.reduce((sum, p) => sum + p.cpu, 0);
    if (!before.complete || !after.complete || oldIds !== newIds || delta < 0 || elapsed <= 0 || a.key !== b.key || a.generation !== b.generation || a.lagMs === null || b.lagMs === null || a.lagMs > 1000 || b.lagMs > 1000 || a.key.includes('unknown') || a.key === 'unobserved') { excludedCpuIntervals++; continue; }
    const percent = delta / elapsed / metadata.logicalProcessors * 100;
    const group = groups.get(b.key);
    group.validCpuSeconds += elapsed; group.cpuWeighted += percent * elapsed; group.cpuIntervals.push(percent);
  }
  const summary = { osSamples: count, maxOsGapMs: maxGapMs, resourceSamples: rows.length, excludedStateCpuIntervals: excludedCpuIntervals,
    firstResourceUtc: rows[0].utc, lastResourceUtc: rows.at(-1).utc,
    initialState: assignments[0].key,
    transitions: segments.filter(segment => segment.time >= first).map(({ time, ...segment }) => segment),
    groups: [...groups.values()].map(group => {
      group.cpuIntervals.sort((a, b) => a - b);
      const result = { ...group, cpuMeanPercent: group.validCpuSeconds ? group.cpuWeighted / group.validCpuSeconds : null,
        cpuP95Percent: group.cpuIntervals.length ? group.cpuIntervals[Math.ceil(group.cpuIntervals.length * 0.95) - 1] : null,
        validCpuIntervals: group.cpuIntervals.length };
      delete result.cpuWeighted; delete result.cpuIntervals; return result;
    }) };
  fs.writeFileSync(path.join(output, 'os-summary.json'), JSON.stringify(summary, null, 2) + '\n', { flag: 'wx' });
  fs.writeFileSync(path.join(output, 'os-resource-alignment.jsonl'), assignments.map(row => JSON.stringify(row)).join('\n') + '\n', { flag: 'wx' });
  console.log(JSON.stringify(summary, null, 2));
} catch (error) {
  console.error(`錯誤：OS 區間分析未完成：${error.message}`);
  process.exitCode = 1;
}
