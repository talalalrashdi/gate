// Optional migration check. Run with Node.js while the MVC app is running.
// This compares rendered HTML/assets; it does not execute browser interactions.
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const companyRoot = fileURLToPath(new URL('../', import.meta.url));
const originalRoot = path.resolve(companyRoot, '../dist');
const baseline = JSON.parse(await readFile(path.join(companyRoot, 'docs/frontend-baseline.json'), 'utf8'));
const base = new URL(process.argv[2] ?? 'http://127.0.0.1:5080/');
const digest = bytes => createHash('sha256').update(bytes).digest('hex');
const normalize = text => text.replaceAll('\r\n', '\n').trim();

function migratedPath(file) {
  if (file.endsWith('.css')) return 'css/' + file;
  if (file.endsWith('.js')) return 'js/' + file;
  return file;
}

function expectedHtml(html) {
  return html.replace(/\b(href|src)="\.\/([^\"]+)"/g, (_, attribute, file) => {
    let destination = migratedPath(file);
    if (file === 'design-b.html' || file === 'index.html') destination = '';
    if (file === 'user-profile.html') destination = 'profile';
    return `${attribute}="/${destination}"`;
  });
}

async function request(resource, expectedStatus = 200) {
  const response = await fetch(new URL(resource, base));
  assert.equal(response.status, expectedStatus, resource);
  return response;
}

// Verify that migration did not mutate any original frontend source.
for (const file of baseline.files) {
  assert.equal(digest(await readFile(path.join(originalRoot, file.path))), file.sha256, `Original changed: ${file.path}`);
}

const portal = await readFile(path.join(originalRoot, 'design-b.html'), 'utf8');
const profile = await readFile(path.join(originalRoot, 'user-profile.html'), 'utf8');
for (const route of ['', 'index.html', 'design-b.html']) {
  assert.equal(normalize(await (await request(route)).text()), normalize(expectedHtml(portal)), `Portal differs: /${route}`);
}
for (const route of ['profile', 'profile/', 'user-profile.html']) {
  assert.equal(normalize(await (await request(route)).text()), normalize(expectedHtml(profile)), `Profile differs: /${route}`);
}

// Includes runtime-generated image paths and magazine pages, not just HTML links.
const resources = baseline.files.filter(file => !file.path.endsWith('.html'));
for (let offset = 0; offset < resources.length; offset += 8) {
  await Promise.all(resources.slice(offset, offset + 8).map(async file => {
    const response = await request(migratedPath(file.path));
    const actual = Buffer.from(await response.arrayBuffer());
    let expected = await readFile(path.join(originalRoot, file.path));
    if (file.path.endsWith('.css')) expected = Buffer.from(expected.toString('utf8').replaceAll('./assets/', '../assets/'));
    assert.equal(digest(actual), digest(expected), `Resource differs: ${file.path}`);
  }));
}

// CSS resources resolve relative to /css/, while HTML/JS assets resolve at root.
const styles = baseline.files.filter(file => file.path.endsWith('.css'));
let cssReferences = 0;
for (const file of styles) {
  const cssPath = migratedPath(file.path);
  const css = await (await request(cssPath)).text();
  // Embedded SVG data can itself contain url(...); those are not HTTP assets.
  const withoutDataUrls = css.replace(/url\((['"])data:[\s\S]*?\1\)/g, '');
  for (const match of withoutDataUrls.matchAll(/url\(\s*['"]?([^'"\s)]+)['"]?\s*\)/g)) {
    if (/^(data:|https?:|#)/.test(match[1])) continue;
    const resource = new URL(match[1], new URL(cssPath, base));
    assert.equal((await fetch(resource)).status, 200, resource.href);
    cssReferences++;
  }
}

await request('api/v1/me', 404);
await request('__review', 404);
const error = await request('error', 500);
assert.ok(!(await error.text()).includes('StackTrace'), 'Error page exposes diagnostics');

console.log(JSON.stringify({
  originalFilesUnchanged: baseline.files.length,
  matchingPageRoutes: 6,
  matchingStaticResources: resources.length,
  resolvedCssReferences: cssReferences,
  orderedPortalStyles: baseline.portalStyles.length,
  orderedPortalScripts: baseline.portalScripts.length,
  apiAndViteReviewNotExposed: true,
  browserInteractionsTested: false
}, null, 2));
