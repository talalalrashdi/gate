// Runs the real synchronization module; live SQL and browser checks are separate.
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import vm from 'node:vm';
const policySource = await readFile(new URL('../Frontend/CompanyPortal.Web/wwwroot/js/workspace-policy.js', import.meta.url), 'utf8');
const policyContext = { window: {} };
vm.runInNewContext(policySource, policyContext);
const policy = policyContext.window.CompanyPortalWorkspacePolicy;
const definitions = ['library', 'inbox', 'email'].map((cardKey, index) => ({ cardKey, cardName: cardKey, displayOrder: index + 1, isFixed: false, isCustom: false, userCardId: null, cardType:'connected', applications:[] }));
const locked = definitions.map(card => ({ ...card, isFixed: card.cardKey === 'inbox' }));
const customDefinition = { cardKey: 'custom-41', cardName: 'Private card name', displayOrder: 4, isFixed: false, isCustom: true, userCardId: 41 };
assert.equal(policy.valid([...locked, customDefinition], ['library','inbox','email','custom-41']), true);
assert.equal(policy.valid([...locked, {...customDefinition,isFixed:true}], ['library','inbox','email','custom-41']), false);
assert.deepEqual(Array.from(policy.normalize(['custom-41','inbox','email','library'], [...locked,customDefinition])), ['custom-41','inbox','email','library']);
assert.equal(policy.valid(locked, definitions.map(card => card.cardKey)), true);
assert.deepEqual(Array.from(policy.normalize(['inbox','email','library'], locked)), ['email','inbox','library']);
assert.equal(policy.valid([...locked.slice(0,2), {...locked[2], isFixed:true, displayOrder:2}], ['library','inbox','email']), false);
const source = await readFile(new URL('../Frontend/CompanyPortal.Web/wwwroot/js/workspace-settings.js', import.meta.url), 'utf8');
const settle = async () => { for (let i = 0; i < 12; i++) await new Promise(resolve => setImmediate(resolve)); };
async function fixture({ held = false, offline = false, isSaved = true, mismatch = false, custom = false } = {}) {
  const listeners = new Map(), writes = [], applied = [];
  const status = { setAttribute() {} };
  let currentKeys = ['library', 'inbox', 'email'];
  const cached = new Map();
  const workspace = {
    setAttribute() {},
    querySelectorAll: selector => currentKeys.filter(id => !selector.includes('data-user-card-id') || !id.startsWith('custom-')).map(id => ({ dataset: { workSystem: id }, remove() { currentKeys=currentKeys.filter(key=>key!==id); } })),
    addEventListener: (type, action) => listeners.set(type, action),
    dispatchEvent: event => { if(event.type==='workspace:order-select'){applied.push(event.detail.cardKeys); currentKeys = Array.from(event.detail.cardKeys);} }
  };
  let release;
  const gate = held ? new Promise(resolve => { release = resolve; }) : Promise.resolve();
  vm.runInNewContext(source, {
    window: { CompanyPortalWorkspacePolicy: policy, CompanyPortalCustomCards: { ready: Promise.resolve().then(() => { if (custom) currentKeys.push('custom-41'); }) } },
    localStorage: { getItem: () => offline ? JSON.stringify(definitions) : null, setItem(key,value) { cached.set(key,value); } },
    URL, location: { href: 'http://portal.test/' }, AbortSignal: { timeout() {} },
    CustomEvent: class { constructor(type, options) { this.type = type; this.detail = options?.detail; } },
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
      return { ok: true, json: async () => ({ cardKeys: mismatch ? ['missing'] : ['email', 'library', 'inbox', ...(custom ? ['custom-41'] : [])], cards: [...definitions,...(custom ? [customDefinition] : [])], isSaved }) };
    }
  });
  await settle();
  return { applied, writes, status, release, cached, reorder(cardKeys) { currentKeys = cardKeys; listeners.get('workspace:order-changed')({ detail: { cardKeys } }); } };
}
const saved = await fixture();
assert.deepEqual(JSON.parse(JSON.stringify(saved.applied)), [['email', 'library', 'inbox']]);
assert.equal(saved.writes.length, 0, 'Loading must not write');
const unsaved = await fixture({ isSaved: false });
assert.deepEqual(Array.from(unsaved.applied[0]), ['email','library','inbox'], 'Use the server default order for an unsaved account');
saved.reorder(['inbox', 'email', 'library']); saved.reorder(['email', 'inbox', 'library']);
await settle();
assert.deepEqual(saved.writes, [['email', 'inbox', 'library']], 'Keep latest unsent order');
saved.reorder(['library', 'library', 'email']);
await settle();
assert.equal(saved.writes.length, 1, 'Reject duplicates');
const delayed = await fixture({ held: true });
delayed.reorder(['inbox', 'library', 'email']); delayed.release(); await settle();
assert.deepEqual(Array.from(delayed.applied[0]), ['inbox','library','email'], 'Late read applies policy without overriding newer user order');
assert.deepEqual(delayed.writes, [['inbox', 'library', 'email']]);
const offline = await fixture({ offline: true });
offline.reorder(['email', 'inbox', 'library']); await settle();
assert.equal(offline.applied.length,0,'Never restore a cached audience/catalog as authorization');
assert.equal(offline.writes.length,0,'Do not save an unverified catalog');
assert.equal((await fixture({ mismatch: true })).applied.length, 0, 'Catalog mismatch must preserve local layout');
const personal = await fixture({ custom: true });
assert.equal(personal.applied[0].length, 4, 'Wait for account-owned cards before loading their combined order');
assert.equal([...personal.cached.values()].some(value => value.includes('Private card name') || value.includes('custom-41')), false, 'Never cache personal card definitions');
console.log('Workspace synchronization checks passed: read-only loading, server defaults, latest order, delayed reads, invalid lists and fail-closed offline catalog.');
