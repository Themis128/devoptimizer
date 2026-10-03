'use strict';
// Worker for journal-stress.test.js case 1 (parallel append). Signals ready via
// file, waits on the go file, then races the other workers to append one
// ROUTER_ARMED event through the plugin lib's file lock, and signals done via
// file. Filesystem coordination: the parent polls synchronously, so worker
// messages on the event loop would never be delivered.
const { workerData } = require('worker_threads');
const crypto = require('crypto');
const fs = require('fs');
const lib = require('C:/Users/tbaltzakis/.zcode/cli/plugins/cache/glm-hammer/glm-hammer/0.6.0/hooks/scripts/lib.js');

function waitFor(predicate, timeoutMs = 15000) {
  const deadline = Date.now() + timeoutMs;
  while (!predicate()) {
    if (Date.now() >= deadline) return false;
    const wait = new Int32Array(new SharedArrayBuffer(4));
    Atomics.wait(wait, 0, 0, 10);
  }
  return true;
}

const { tmp, runId, index, goFile, readyFile, doneFile } = workerData;
fs.writeFileSync(readyFile, String(process.pid));
if (!waitFor(() => fs.existsSync(goFile))) {
  fs.writeFileSync(doneFile, JSON.stringify({ index, ok: false, code: 'GO_TIMEOUT' }));
} else {
  const hash = crypto.createHash('sha256').update('journal-stress-worker-' + index).digest('hex');
  const out = lib.appendJournalPayload(tmp, 'ROUTER_ARMED', runId, 0, {
    baselineHead: null,
    baselineSnapshotSha256: hash,
    promptEventHash: hash,
  });
  fs.writeFileSync(doneFile, JSON.stringify({ index, ok: out.ok, code: out.code || null }));
}
