// Static checks for automatic external asset requests; not a browser offline test.
import assert from 'node:assert/strict';
import { readFile, readdir, stat } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../Frontend/CompanyPortal.Web/', import.meta.url));
async function files(folder) {
  const entries = await readdir(folder, { withFileTypes: true });
  return (await Promise.all(entries.map(entry => entry.isDirectory()
    ? files(path.join(folder, entry.name)) : [path.join(folder, entry.name)]))).flat();
}
let inspected = 0;
for (const file of [...await files(path.join(root, 'Views')), ...await files(path.join(root, 'wwwroot'))]) {
  if (!/\.(cshtml|js|css|svg)$/.test(file)) continue;
  const source = await readFile(file, 'utf8');
  assert.ok(!/<(?:script|link|img|iframe|source|video|audio)\b[^>]*\b(?:src|href|poster)\s*=\s*["']https?:\/\//i.test(source), `External resource in ${file}`);
  assert.ok(!/\b(?:image|src|poster)\s*[:=]\s*["']https?:\/\//i.test(source), `External dynamic resource in ${file}`);
  assert.ok(!/(?:url\(\s*["']?|@import\s*["'])https?:\/\//i.test(source), `External CSS resource in ${file}`);
  inspected++;
}
const vendor = path.join(root, 'wwwroot/vendor/iconsax');
const css = await readFile(path.join(vendor, 'icons.css'), 'utf8');
for (const match of css.matchAll(/url\(['"]?([^'"\s)]+)['"]?\)/g)) {
  const file = path.resolve(vendor, match[1].split(/[?#]/)[0]);
  assert.ok((await stat(file)).size > 0, `Missing font ${file}`);
}
for (const [extension, signature] of [['woff', 'wOFF'], ['woff2', 'wOF2']]) {
  assert.equal((await readFile(path.join(vendor, `files/iconsax.${extension}`))).subarray(0, 4).toString(), signature, `Invalid ${extension} font`);
}
assert.ok((await readFile(path.join(vendor, 'files/iconsax.svg'), 'utf8')).includes('<svg'), 'Invalid SVG font');
console.log(`Offline asset scan passed for ${inspected} source files; local icon fonts resolve. Outbound source links are retained. Browser offline verification is still required.`);
