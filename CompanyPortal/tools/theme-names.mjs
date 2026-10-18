// One-pass compatibility rename used by migration verification (not browser code).
export function renameThemeIdentifiers(source) {
  const names = { majestic: 'official', formal: 'work', official: 'national-day' };
  return source
    .replace(/theme-(majestic|formal|official|national(?!-day))/g,
      (_, name) => 'theme-' + (name === 'national' ? 'national-day' : names[name]))
    .replace(/(['"])(majestic|formal|official)\1/g, (_, quote, name) => quote + names[name] + quote)
    .replace(/^(\s*)(majestic|formal|official)(: \{ theme:)/gm,
      (_, space, name, suffix) => space + (name === 'official' ? "'national-day'" : names[name]) + suffix)
    .replaceAll('personal-official', 'personal-national-day')
    .replaceAll('data-majestic', 'data-official')
    .replaceAll('dataset.majestic', 'dataset.official')
    .replace(/\b\w*Majestic\w*\b/g, word => word.replaceAll('Majestic', 'Official'))
    .replace(/\bmajestic\w*\b/g, word => word.replace('majestic', 'official'))
    .replace(/\b\w*Formal\w*\b/g, word => word.replaceAll('Formal', 'Work'))
    .replace(/\bformal\w*\b/g, word => word.replace('formal', 'work'));
}
