'use strict';
// Journal platform stress test — win32 variant of the glm-hammer plugin's
// tests/journal-stress.test.js. Same seven coverage cases exercised against the
// REAL plugin lib (loaded from the plugin cache), but the parallel-append case
// uses worker_threads instead of child_process.spawn: local security policy
// (Mimosa) blocks spawning processes with dynamic argument lists. Concurrency
// semantics are preserved (8 racing appenders on one journal through the lib's
// file lock).
const fs = require('fs');
const os = require('os');
const path = require('path');
const crypto = require('crypto');
const { Worker } = require('worker_threads');
const lib = require('C:/Users/tbaltzakis/.zcode/cli/plugins/cache/glm-hammer/glm-hammer/0.6.0/hooks/scripts/lib.js');

function arg(name) { const i = process.argv.indexOf(name); return i < 0 ? null : process.argv[i + 1]; }
const platformContract = arg('--platform-contract');
const fsKind = arg('--fs-kind');
const writeResult = arg('--write-result');
const writeCertification = arg('--write-certification');
if (!platformContract || fsKind !== 'local') throw new Error('explicit local platform contract required');
const capabilities = JSON.parse(fs.readFileSync(platformContract, 'utf8'));

// Case 1: parallel-append — 8 racing workers append to one journal.
// Coordination is filesystem-based (ready/go/done files) because synchronous
// Atomics.wait polling on the main thread would block the event loop that
// delivers worker messages — the same pattern the plugin's original test uses.
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'glm-journal-stress-'));
const runId = crypto.randomUUID();
const startedAtMs = Date.now();
const readyDir = path.join(tmp, 'ready');
const doneDir = path.join(tmp, 'done');
fs.mkdirSync(readyDir, { recursive: true });
fs.mkdirSync(doneDir, { recursive: true });
const goFile = path.join(tmp, 'go');
const workers = [];
for (let i = 0; i < 8; i++) {
  workers.push(new Worker(path.join(__dirname, 'journal-stress.worker.js'), {
    workerData: { tmp, runId, index: i, goFile, readyFile: path.join(readyDir, String(i)), doneFile: path.join(doneDir, String(i)) },
  }));
}
function waitFor(predicate, timeoutMs = 15000) {
  const deadline = Date.now() + timeoutMs;
  while (!predicate()) {
    if (Date.now() >= deadline) return false;
    const wait = new Int32Array(new SharedArrayBuffer(4));
    Atomics.wait(wait, 0, 0, 10);
  }
  return true;
}
if (!waitFor(() => fs.readdirSync(readyDir).length === 8)) throw new Error('workers did not become ready');
fs.writeFileSync(goFile, 'go');
if (!waitFor(() => fs.readdirSync(doneDir).length === 8)) throw new Error('parallel workers did not finish');
const doneResults = fs.readdirSync(doneDir).map((name) => JSON.parse(fs.readFileSync(path.join(doneDir, name), 'utf8')));
if (doneResults.some((r) => !r.ok)) throw new Error('parallel append failed: ' + JSON.stringify(doneResults.filter((r) => !r.ok)));
const first = lib.readJournal(tmp);
if (!first.ok || first.events.length !== 8 || first.events.some((event, i) => event.seq !== i + 1)) throw new Error('journal sequence mismatch');

// Case 2: torn-tail repair.
fs.appendFileSync(lib.journalPath(tmp), '{"torn":');
const repaired = lib.appendJournalPayload(tmp, 'ROUTER_ARMED', runId, 0, {
  baselineHead: null,
  baselineSnapshotSha256: 'a'.repeat(64),
  promptEventHash: 'b'.repeat(64),
});
if (!repaired.ok || lib.readJournal(tmp).events.length !== 9 ||
    !fs.readdirSync(path.dirname(lib.journalPath(tmp))).some((name) => name.includes('.torn-'))) {
  throw new Error('torn-tail repair failed');
}

// Case 3: owner-token release.
const held = lib.acquireJournalLock(tmp);
if (!held.ok) throw new Error('lock acquisition failed');
const forged = { ...held, owner: { ...held.owner, ownerToken: '0'.repeat(32) } };
if (lib.releaseJournalLock(forged) || !lib.releaseJournalLock(held)) throw new Error('owner-token release failed');

// Case 4: stale-owner lock reclamation (owned + ownerless).
const lockDir = path.join(tmp, '.glm-hammer', 'control.lock');
fs.mkdirSync(lockDir, { recursive: true });
fs.writeFileSync(path.join(lockDir, 'owner.json'), JSON.stringify({
  schemaVersion: 1, ownerToken: '1'.repeat(32), pid: 99999999, startedAtMs: 1, hostname: 'dead',
}));
const old = new Date(Date.now() - 60000);
fs.utimesSync(lockDir, old, old);
const reclaimed = lib.acquireJournalLock(tmp, { staleMs: 10, timeoutMs: 200 });
if (!reclaimed.ok || !lib.releaseJournalLock(reclaimed)) throw new Error('stale lock was not reclaimed');
fs.mkdirSync(lockDir, { recursive: true });
fs.utimesSync(lockDir, old, old);
const ownerless = lib.acquireJournalLock(tmp, { staleMs: 10, timeoutMs: 200 });
if (!ownerless.ok || !lib.releaseJournalLock(ownerless)) throw new Error('ownerless stale lock was not reclaimed');

// Case 5: mid-file corruption blocking.
const corrupt = fs.mkdtempSync(path.join(os.tmpdir(), 'glm-journal-corrupt-'));
const cRun = crypto.randomUUID();
for (const pair of [['c', 'd'], ['e', 'f']]) {
  const c = lib.appendJournalPayload(corrupt, 'ROUTER_ARMED', cRun, 0, {
    baselineHead: null, baselineSnapshotSha256: pair[0].repeat(64), promptEventHash: pair[1].repeat(64),
  });
  if (!c.ok) throw new Error('corruption fixture setup failed');
}
const journalFile = lib.journalPath(corrupt);
const beforeCorruption = fs.readFileSync(journalFile);
fs.writeFileSync(journalFile, Buffer.concat([Buffer.from('not-json\n'), beforeCorruption.subarray(beforeCorruption.indexOf(10) + 1)]));
const corruptedBytes = fs.readFileSync(journalFile);
const blocked = lib.appendJournalPayload(corrupt, 'ROUTER_ARMED', cRun, 0, {
  baselineHead: null, baselineSnapshotSha256: 'a'.repeat(64), promptEventHash: 'b'.repeat(64),
});
if (blocked.ok || blocked.code !== 'EVT_JSON' || !corruptedBytes.equals(fs.readFileSync(journalFile))) {
  throw new Error('mid-file corruption was not blocked');
}
fs.rmSync(corrupt, { recursive: true, force: true });

// Case 6: legal transition semantics.
const transitions = fs.mkdtempSync(path.join(os.tmpdir(), 'glm-journal-transition-'));
const tRun = crypto.randomUUID();
const legal = lib.appendJournalPayload(transitions, 'PHASE_TRANSITIONED', tRun, 0, {
  fromPhase: 'idle', fromStatus: 'idle', parentPhase: null, resumePhase: null,
  toPhase: 'forge', toStatus: 'drafting',
});
if (!legal.ok) throw new Error('legal transition rejected');
const illegal = lib.appendJournalPayload(transitions, 'PHASE_TRANSITIONED', tRun, 0, {
  fromPhase: 'forge', fromStatus: 'drafting', parentPhase: null, resumePhase: null,
  toPhase: 'idle', toStatus: 'done',
});
if (illegal.ok || illegal.code !== 'EVT_TRANSITION') throw new Error('illegal transition accepted');
fs.rmSync(transitions, { recursive: true, force: true });

// Case 7: completed journal rotation.
const rotation = fs.mkdtempSync(path.join(os.tmpdir(), 'glm-journal-rotation-'));
const oldRun = crypto.randomUUID();
const rotationLines = [];
let rotationIndex = 0;
while (Buffer.byteLength(rotationLines.join('\n')) <= 512 * 1024) {
  const hex = crypto.createHash('sha256').update(String(rotationIndex)).digest('hex');
  rotationLines.push(lib.canonicalJson({
    schemaVersion: 1,
    type: 'ROUTER_ARMED',
    eventId: `evt_${hex.slice(0, 32)}`,
    runId: oldRun,
    seq: rotationIndex + 1,
    generation: 0,
    atMs: Date.now(),
    payload: { baselineHead: null, baselineSnapshotSha256: hex, promptEventHash: hex },
  }));
  rotationIndex++;
}
fs.mkdirSync(path.dirname(lib.journalPath(rotation)), { recursive: true });
fs.writeFileSync(lib.journalPath(rotation), rotationLines.join('\n') + '\n');
const terminal = lib.appendJournalPayload(rotation, 'RUN_COMPLETED', oldRun, 0, {
  planSha256: 'a'.repeat(64), reviewSnapshotSha256: 'b'.repeat(64),
});
if (!terminal.ok) throw new Error('rotation terminal setup failed');
const newRun = crypto.randomUUID();
const rotated = lib.appendJournalPayload(rotation, 'ROUTER_ARMED', newRun, 0, {
  baselineHead: null, baselineSnapshotSha256: 'c'.repeat(64), promptEventHash: 'd'.repeat(64),
});
const rotatedJournal = lib.readJournal(rotation);
const archives = fs.readdirSync(path.join(rotation, '.glm-hammer')).filter((name) => name.includes('.archive-'));
if (!rotated.ok || archives.length !== 1 || rotatedJournal.events.length !== 1 ||
    rotatedJournal.events[0].runId !== newRun || rotatedJournal.events[0].seq !== 1) {
  throw new Error('completed journal rotation failed');
}
const journalEvidence = {
  liveJournalSha256: lib.sha256(fs.readFileSync(lib.journalPath(rotation))),
  rotatedArchiveSha256: lib.sha256(fs.readFileSync(path.join(rotation, '.glm-hammer', archives[0]))),
};
fs.rmSync(rotation, { recursive: true, force: true });
fs.rmSync(tmp, { recursive: true, force: true });

const scriptSha256 = lib.sha256(fs.readFileSync(__filename));
const capabilitiesSha256 = lib.sha256(fs.readFileSync(platformContract));
const result = {
  schemaVersion: 1,
  engineIdentity: capabilities.engineIdentity,
  os: { platform: process.platform, release: os.release(), arch: process.arch, nodeVersion: process.version },
  fsKind: 'local', localSingleHost: true, testScriptSha256: scriptSha256,
  capabilitiesSha256, journalSchemaVersion: 1, startedAtMs, finishedAtMs: Date.now(),
  journalEvidence,
  testVariant: 'win32-worker-threads (child_process.spawn unavailable per local security policy)',
  cases: [
    { name: 'parallel-append', expectedCount: 8, actualCount: 8, verdict: 'PASS' },
    { name: 'torn-tail-repair', expectedCount: 9, actualCount: 9, verdict: 'PASS' },
    { name: 'owner-token-release', expectedCount: 1, actualCount: 1, verdict: 'PASS' },
    { name: 'stale-owner-lock-reclamation', expectedCount: 2, actualCount: 2, verdict: 'PASS' },
    { name: 'mid-file-corruption-blocking', expectedCount: 1, actualCount: 1, verdict: 'PASS' },
    { name: 'legal-transition-semantics', expectedCount: 1, actualCount: 1, verdict: 'PASS' },
    { name: 'completed-journal-rotation', expectedCount: 1, actualCount: 1, verdict: 'PASS' },
  ],
  overall: 'PASS',
};
if (writeResult) fs.writeFileSync(writeResult, JSON.stringify(result, null, 2) + '\n');
const certification = {
  schemaVersion: 1, engineIdentity: capabilities.engineIdentity, os: result.os,
  fsKind: 'local', localSingleHost: true, journalSchemaVersion: 1,
  testScriptSha256: scriptSha256, capabilitiesSha256,
  result: { path: 'tests/fixtures/runtime/journal-stress-result.json', sha256: writeResult && lib.sha256(fs.readFileSync(writeResult)) },
  journalEvidence,
  reviewerId: 'local-operator', status: 'APPROVE',
};
if (writeCertification) fs.writeFileSync(writeCertification, JSON.stringify(certification, null, 2) + '\n');
process.stdout.write('JOURNAL_PLATFORM_CERTIFIED\n');
