// Runs the real synchronization module; live SQL and browser checks are separate.
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import vm from 'node:vm';
const source = await readFile(new URL('../Frontend/CompanyPortal.Web/wwwroot/js/workspace-settings.js', import.meta.url), 'utf8');
const settle = async () => { for (let i = 0; i < 12; i++) await new Promise(resolve => setImmediate(resolve)); };
async function fixture({ held = false, offline = false, isSaved = true, mismatch = false } = {}) {
  const listeners = new Map(), writes = [], applied = [];
  const status = { setAttribute() {} };
  const workspace = {
    querySelectorAll: () => ['library', 'inbox', 'email'].map(id => ({ dataset: { workSystem: id } })),
    addEventListener: (type, action) => listeners.set(type, action),
    dispatchEvent: event => applied.push(event.detail.cardKeys)
  };
  let release;
  const gate = held ? new Promise(resolve => { release = resolve; }) : Promise.resolve();
  vm.runInNewContext(source, {
    URL, location: { href: 'http://portal.test/' }, AbortSignal: { timeout() {} },
    CustomEvent: class { constructor(type, options) { this.type = type; this.detail = options.detail; } },
    document: {
      querySelector: selector => selector.startsWith('meta') ? { content: 'http://api.test/' } : { append() {} },
      getElementById: () => workspace, createElement: () => status
    },
    async fetch(url, request) {
      assert.equal(url.pathname, '/api/user-settings/card-order');
      assert.equal(request.credentials, 'include');
      if (offline) throw new Error('Offline');
      if (request.method === 'PUT') {
        const body = JSON.parse(request.body);
        assert.deepEqual(Object.keys(body), ['cardKeys']);
        assert.equal(request.headers['X-CompanyPortal-Request'], 'card-order');
        writes.push(body.cardKeys);
        return { ok: true };
      }
      await gate;
      return { ok: true, json: async () => ({ cardKeys: mismatch ? ['missing'] : ['email', 'library', 'inbox'], isSaved }) };
    }
  });
  await settle();
  return { applied, writes, status, release, reorder(cardKeys) { listeners.get('workspace:order-changed')({ detail: { cardKeys } }); } };
}
const saved = await fixture();
assert.deepEqual(JSON.parse(JSON.stringify(saved.applied)), [['email', 'library', 'inbox']]);
assert.equal(saved.writes.length, 0, 'Loading must not write');
const unsaved = await fixture({ isSaved: false });
assert.equal(unsaved.applied.length, 0, 'Keep existing browser order until an explicit reorder');
saved.reorder(['inbox', 'email', 'library']); saved.reorder(['email', 'inbox', 'library']);
await settle();
assert.deepEqual(saved.writes, [['email', 'inbox', 'library']], 'Keep latest unsent order');
saved.reorder(['library', 'library', 'email']);
await settle();
assert.equal(saved.writes.length, 1, 'Reject duplicates');
const delayed = await fixture({ held: true });
delayed.reorder(['inbox', 'library', 'email']); delayed.release(); await settle();
assert.equal(delayed.applied.length, 0, 'Late read must not override newer user order');
assert.deepEqual(delayed.writes, [['inbox', 'library', 'email']]);
const offline = await fixture({ offline: true });
offline.reorder(['email', 'inbox', 'library']); await settle();
assert.equal(offline.applied.length, 0);
assert.match(offline.status.textContent, /محلي/);
assert.equal((await fixture({ mismatch: true })).applied.length, 0, 'Catalog mismatch must preserve local layout');
console.log('Workspace synchronization checks passed: read-only loading, local compatibility, latest order, delayed reads, invalid lists and offline fallback.');
