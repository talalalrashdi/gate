// Executes the actual theme initialization/selection code with a minimal DOM.
// Covers preference compatibility; browser layout/reparenting still needs a browser.
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import vm from 'node:vm';

const root = new URL('../Frontend/CompanyPortal.Web/', import.meta.url);
const script = await readFile(new URL('wwwroot/js/personal-workspace.js', root), 'utf8');
const html = await readFile(new URL('Views/Home/Index.cshtml', root), 'utf8');
const end = script.indexOf('  const today = new Date();');
assert.ok(end > 0, 'Theme initialization boundary exists');
const themeCode = script.slice(0, end) + '\n})();';
const buttonOptions = [...html.matchAll(/data-theme-option="([^"]+)"/g)].map(match => match[1]);
const panelIds = [...html.matchAll(/id="(theme-(?:majestic|official|formal))"/g)].map(match => match[1]);
assert.deepEqual(buttonOptions, ['majestic', 'official', 'formal']);
assert.equal(panelIds.length, 3);

function initialize(saved) {
  const state = new Map([['clerio-opening-theme', JSON.stringify('2')]]);
  if (saved !== undefined) state.set('companyportal-opening-theme-v1', JSON.stringify(saved));
  const buttons = buttonOptions.map(option => ({
    dataset: { themeOption: option }, attributes: {},
    setAttribute(key, value) { this.attributes[key] = value; },
    addEventListener(event, handler) { this[event] = handler; }
  }));
  const panels = panelIds.map(id => ({ id, hidden: true, classList: { contains: () => false } }));
  const label = { textContent: '' };
  const section = {
    dataset: {}, attributes: {}, querySelector: () => null,
    querySelectorAll: () => panels,
    setAttribute(key, value) { this.attributes[key] = value; }
  };
  const headerParent = { insertBefore(node) { node.parentElement = this; } };
  const header = { parentElement: headerParent, nextSibling: null };
  const photoFrame = { prepend(node) { node.parentElement = this; } };
  const elements = new Map([['systems', section], ['personal-theme-name', label], ['theme-majestic-frame', photoFrame], ...panels.map(panel => [panel.id, panel])]);
  const body = { dataset: {} };
  const events = [];
  vm.runInNewContext(themeCode, {
    document: {
      body, hidden: false, getElementById: id => elements.get(id) ?? null,
      querySelector: selector => selector === '.portal-header' ? header : null,
      querySelectorAll: selector => selector === '[data-theme-option]' ? buttons : [],
      dispatchEvent: event => events.push(event), addEventListener() {}
    },
    window: { matchMedia: () => ({ matches: false, addEventListener() {} }) },
    localStorage: { getItem: key => state.get(key) ?? null, setItem: (key, value) => state.set(key, value) },
    CustomEvent: class { constructor(type, options) { this.type = type; this.detail = options.detail; } },
    clearTimeout() {}, setTimeout() {}
  });
  function check(expected) {
    assert.equal(body.dataset.siteTheme, expected);
    assert.equal(section.dataset.theme, expected);
    assert.equal(header.parentElement, headerParent, 'Every theme retains the same shared header outside the photo frame');
    assert.deepEqual(panels.filter(panel => !panel.hidden).map(panel => panel.id), ['theme-' + expected]);
    assert.equal(buttons.filter(button => button.attributes['aria-pressed'] === 'true').length, 1);
    assert.equal(JSON.parse(state.get('companyportal-opening-theme-v1')), expected);
    assert.equal(state.get('clerio-opening-theme'), JSON.stringify('2'), 'Legacy preference remains intact');
    assert.equal(events.at(-1).type, 'companyportal:theme-change');
    assert.equal(events.at(-1).detail.theme, expected);
  }
  return { buttons, check };
}

for (const [saved, expected] of [
  [undefined, 'majestic'], ['4', 'majestic'], ['2', 'official'], ['3', 'formal'],
  [4, 'majestic'], [2, 'official'], [3, 'formal'],
  ['majestic', 'majestic'], ['official', 'official'], ['formal', 'formal'],
  ['invalid', 'majestic'], ['1', 'majestic'], ['5', 'majestic']
]) {
  const session = initialize(saved);
  session.check(expected);
  for (const button of session.buttons) {
    button.click();
    session.check(button.dataset.themeOption);
  }
}
console.log('Theme checks passed: default, legacy/semantic preferences, invalid values, all theme buttons, visibility, events and preserved legacy key.');
