// Executes the real browser synchronization module with an isolated DOM/API fixture.
// Does not claim to validate SQL Server, Windows authentication or browser layout.
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import vm from 'node:vm';

const source = await readFile(new URL('../Frontend/CompanyPortal.Web/wwwroot/js/theme-settings.js', import.meta.url), 'utf8');
const settle = async () => { for (let n = 0; n < 12; n++) await new Promise(resolve => setImmediate(resolve)); };

async function fixture({ selected = 88, renamed = false, held = false, offline = false } = {}) {
  const definitions = [
    { themeId: 17, themeName: 'Default label', layoutKey: 'official', isDefault: true, displayOrder: 1 },
    { themeId: 43, themeName: 'Independent name', layoutKey: 'work', isDefault: false, displayOrder: 2 },
    { themeId: 88, themeName: renamed ? 'Renamed without changing ID' : 'Another official variant', layoutKey: 'official', isDefault: false, displayOrder: 3 }
  ];
  const events = new Map(), storage = new Map(), writes = [], state = {};
  const details = { open: true };
  class Element {
    constructor() { this.children = []; this.dataset = {}; this.attributes = {}; this.classList = { add() {} }; }
    setAttribute(key, value) { this.attributes[key] = value; }
    append(node) { this.children.push(node); }
    replaceChildren() { this.children = []; }
    closest() { return details; }
    addEventListener(name, callback) { this[name] = callback; }
    querySelector() { return container; }
    querySelectorAll() { return container.children.filter(node => node.dataset.themeId); }
  }
  const container = new Element(), options = new Element();
  let release;
  const gate = held ? new Promise(resolve => { release = resolve; }) : Promise.resolve();
  function dispatch(event) {
    if (event.type === 'companyportal:theme-select') {
      state.layout = event.detail.layoutKey;
      state.name = event.detail.themeName;
      dispatch({ type: 'companyportal:theme-change', detail: { theme: state.layout } });
    }
    for (const handler of events.get(event.type) ?? []) handler(event);
  }
  vm.runInNewContext(source, {
    window: {}, // Optional shared appearance renderer is absent in this isolated fixture.
    URL, location: { href: 'http://portal.test/' }, AbortSignal: { timeout() {} },
    CustomEvent: class { constructor(type, options) { this.type = type; this.detail = options.detail; } },
    localStorage: { getItem: key => storage.get(key) ?? null, setItem: (key, value) => storage.set(key, value), removeItem: key => storage.delete(key) },
    document: {
      querySelector: () => ({ content: 'http://api.test/' }),
      getElementById: () => options,
      createElement: () => new Element(),
      dispatchEvent: dispatch,
      addEventListener(type, callback) { if (!events.has(type)) events.set(type, []); events.get(type).push(callback); }
    },
    async fetch(url, request) {
      if (offline) throw new Error('Offline fixture');
      if (request.method === 'PUT') {
        const body = JSON.parse(request.body);
        assert.deepEqual(Object.keys(body), ['themeId']);
        writes.push(body.themeId);
        selected = body.themeId;
        return { ok: true, status: 204 };
      }
      if (url.pathname === '/api/themes') return { ok: true, json: async () => definitions };
      await gate;
      return { ok: true, json: async () => ({ themeId: selected, isSaved: true }) };
    }
  });
  await settle();
  return { definitions, container, options, writes, state, storage, release,
    userLayout(layout) { state.layout = layout; dispatch({ type: 'companyportal:theme-change', detail: { theme: layout } }); } };
}

const test = await fixture();
assert.equal(test.container.children.length, 3);
assert.equal(test.state.layout, 'official');
assert.equal(test.state.name, 'Another official variant');
assert.equal(test.container.children.find(button => button.attributes['aria-pressed'] === 'true').dataset.themeId, '88');
assert.deepEqual(test.writes, [], 'Reading settings must not create a user row');
test.container.children[1].click();
await settle();
assert.deepEqual(test.writes, [43], 'Persist actual ThemeId, not index/layout/name');
assert.equal(test.state.layout, 'work');
assert.equal(JSON.parse(test.storage.get('companyportal-selected-theme-v1')).themeId, 43);
test.container.children[0].click(); test.container.children[1].click(); test.container.children[2].click();
await settle();
assert.equal(test.writes.at(-1), 88);
assert.equal(test.container.children.find(button => button.attributes['aria-pressed'] === 'true').dataset.themeId, '88');

const renamed = await fixture({ renamed: true });
assert.equal(renamed.state.name, 'Renamed without changing ID');
assert.equal(renamed.state.layout, 'official');
assert.equal(renamed.container.children.find(button => button.attributes['aria-pressed'] === 'true').dataset.themeId, '88');
const delayed = await fixture({ selected: 17, held: true });
delayed.userLayout('work'); delayed.release(); await settle();
assert.equal(delayed.state.layout, 'work');
assert.deepEqual(delayed.writes, [43], 'Initial read must not overwrite a later user selection');
const offline = await fixture({ offline: true });
offline.userLayout('work'); await settle();
assert.equal(offline.state.layout, 'work');
assert.deepEqual(offline.writes, []);
assert.ok(offline.options.children.at(-1).textContent.includes('تعذر الحفظ'));
console.log('Catalog synchronization checks passed: ThemeId persistence, arbitrary display names/IDs, shared layouts, renamed labels, rapid choices, delayed reads and offline fallback. SQL/browser acceptance remains separate.');
