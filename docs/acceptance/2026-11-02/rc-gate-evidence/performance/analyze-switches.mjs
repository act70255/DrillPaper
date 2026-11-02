import fs from 'node:fs';
import path from 'node:path';

// 僅分析一次性切換證據；不改寫來源、不判定未事先定義的資源門檻。
try {
  const folder = process.argv[2];
  if (!folder) throw new Error('必須指定切換原始資料目錄。');
  const rows = fs.readFileSync(path.join(folder, 'switches.jsonl'), 'utf8').trim().split(/\r?\n/).map(line => JSON.parse(line));
  const metadata = JSON.parse(fs.readFileSync(path.join(folder, 'result.json'), 'utf8').replace(/^\uFEFF/, ''));
  const previous = new Map(metadata.initial.map(surface => [surface.hwnd, surface]));
  const validation = rows.map((row, index) => {
    const expected = index % 2 === 0 ? 'Dashboard' : 'Minimal Monitor';
    const valid = row.index === index + 1 && row.result === 'PASS' && row.seconds <= 20
      && row.surfaces.length === 2 && row.surfaces.every(surface => {
        const before = previous.get(surface.hwnd);
        return before && surface.load > before.load && surface.ready > before.ready
          && surface.health > before.health && surface.metrics > row.pushBaseline[surface.hwnd]
          && surface.visible && surface.parent && surface.caption.includes(expected) && surface.caption.endsWith('Live metrics');
      });
    for (const surface of row.surfaces) previous.set(surface.hwnd, surface);
    return { index: row.index, valid };
  });
  const samples = rows.flatMap(row => ['before', 'after'].map(phase => ({ index: row.index, phase, ...row[phase] })));
  const complete = samples.filter(sample => sample.complete);
  const seconds = rows.map(row => row.seconds).sort((a, b) => a - b);
  const summary = {
    requested: 100, recorded: rows.length, failures: rows.filter(row => row.result !== 'PASS').length,
    independentValidationFailures: validation.filter(row => !row.valid),
    secondsMean: seconds.reduce((sum, value) => sum + value, 0) / seconds.length,
    secondsP95: seconds[Math.ceil(seconds.length * 0.95) - 1], secondsMax: seconds.at(-1), secondsMin: seconds[0],
    resourceSamples: samples.length, incompleteResourceSamples: samples.length - complete.length,
    missingReads: samples.flatMap(sample => sample.skipped),
    firstComplete: complete[0], lastComplete: complete.at(-1),
    privateDeltaMiB: (complete.at(-1).totals.private - complete[0].totals.private) / 1048576,
    handlesDelta: complete.at(-1).totals.handles - complete[0].totals.handles,
    threadsDelta: complete.at(-1).totals.threads - complete[0].totals.threads,
    processCounts: [...new Set(complete.map(sample => sample.processes.length))],
    cleanup: { exitCode: metadata.exitCode, survivors: metadata.survivors, shutdown: metadata.shutdown ?? null },
    resourceCriterion: '切換期非穩態，僅列原始前後值；06 長測門檻另套用 7200 秒 soak。',
  };
  const columns = ['index', 'phase', 'utc', 'complete', 'privateBytes', 'handles', 'threads', 'processCount'];
  const csv = [columns.join(','), ...samples.map(sample => [sample.index, sample.phase, sample.utc, sample.complete,
    sample.totals?.private ?? '', sample.totals?.handles ?? '', sample.totals?.threads ?? '', sample.processes.length].join(','))].join('\n') + '\n';
  fs.writeFileSync(path.join(folder, 'switch-resources.csv'), csv, { flag: 'wx' });
  fs.writeFileSync(path.join(folder, 'switch-summary.json'), JSON.stringify(summary, null, 2) + '\n', { flag: 'wx' });
  console.log(JSON.stringify({ ...summary, firstComplete: undefined, lastComplete: undefined }, null, 2));
} catch (error) {
  console.error(`錯誤：切換證據分析未完成：${error.message}`);
  process.exitCode = 1;
}
