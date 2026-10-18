// Migration naming map. Shared with the verifier; not shipped to the browser.
export const fileNames = {
  'design-b.css': 'site.css',
  'design-b.js': 'site.js',
  'design-b-intro.js': 'personal-workspace.js',
  'design-b-personal-carousel.js': 'navigation-controls.js',
  'design-b-widget-layout.js': 'workspace-pagination.js',
  'design-b-status.js': 'organization-status.js',
  'design-b-majestic-news.js': 'news-headlines.js',
  'design-b-header.css': 'header.css',
  'design-b-header-scroll.css': 'header-scroll.css',
  'design-b-workspace.css': 'workspace.css',
  'design-b-layout.css': 'layout.css',
  'design-b-calendar-integrated.css': 'personal-workspace.css',
  'design-b-planner.css': 'planner.css',
  'design-b-floating-calendar.css': 'floating-calendar.css',
  'design-b-themes.css': 'themes.css',
  'design-b-palette.css': 'palette.css',
  'design-b-typography.css': 'typography.css',
  'design-b-majestic-theme.css': 'theme-majestic.css',
  'design-b-formal-theme.css': 'theme-formal.css',
  'design-b-national-theme.css': 'theme-national.css'
};

for (const [oldStem, newStem, extensions] of [
  ['workspace-groups', 'workspace-groups', ['js']],
  ['workspace-order', 'workspace-order', ['js']],
  ['electronic-services', 'electronic-services', ['js']],
  ['editorial', 'editorial', ['css', 'js']],
  ['magazine', 'magazine', ['js']],
  ['library', 'library', ['css', 'js']],
  ['safety', 'safety', ['js']],
  ['systems', 'systems-catalog', ['css', 'js']],
  ['documents-sheet', 'documents-dialog', ['css', 'js']],
  ['policies-sheet', 'policies-dialog', ['js']],
  ['notice-strip', 'notice-strip', ['css', 'js']],
  ['floating-notices', 'floating-notices', ['js']],
  ['section-nav', 'section-navigation', ['css', 'js']]
]) {
  for (const extension of extensions) fileNames[`design-b-${oldStem}.${extension}`] = `${newStem}.${extension}`;
}

export const themeNames = { 1: 'business', 2: 'official', 3: 'formal', 4: 'majestic', 5: 'news' };

export function renameFrontendSource(source) {
  const preservedKeys = [];
  // Storage names are data contracts, not disposable design labels.
  let text = source.replace(/(['"])(?:clerio-|companyportal-)[^'"\r\n]*\1/g, value => {
    preservedKeys.push(value);
    return `__PRESERVED_STORAGE_${preservedKeys.length - 1}__`;
  });

  for (const [oldName, newName] of Object.entries(fileNames)) text = text.replaceAll(oldName, newName);
  text = text
    .replace(/intro-option-([1-5])/g, (_, number) => `theme-${themeNames[number]}`)
    .replace(/data-intro-option="([1-5])"/g, (_, number) => `data-theme-option="${themeNames[number]}"`)
    .replaceAll('data-intro-option', 'data-theme-option')
    .replaceAll('dataset.introOption', 'dataset.themeOption')
    .replaceAll('b-intro-switch', 'portal-theme-switch')
    .replaceAll('b-intro-options', 'portal-theme-options')
    .replaceAll('b-intro-panel', 'portal-theme-panel');

  // Include dynamic class prefixes, data attributes and CSS custom properties.
  for (const [oldPrefix, newPrefix] of [
    ['bt-task', 'planner-task'],
    ['bt-majestic-', 'theme-majestic-'],
    ['bt-formal-', 'theme-formal-'],
    ['bt-national-', 'theme-national-'],
    ['bt-', 'personal-'],
    ['bn-', 'news-'],
    ['ed-', 'editorial-'],
    ['sc-', 'systems-'],
    ['dl-', 'documents-'],
    ['b-', 'portal-']
  ]) {
    text = text.replace(new RegExp(`(?<![a-zA-Z0-9_])${oldPrefix}`, 'g'), newPrefix);
  }
  for (const [oldPrefix, newPrefix] of [['b', 'portal'], ['bt', 'personal'], ['bn', 'news'], ['ed', 'editorial'], ['sc', 'systems'], ['dl', 'documents']]) {
    text = text.replace(new RegExp(`dataset\\.${oldPrefix}([A-Z])`, 'g'), `dataset.${newPrefix}$1`);
  }
  text = text
    .replaceAll('clerio:theme-change', 'companyportal:theme-change')
    .replaceAll('sc:reveal', 'systems:reveal')
    .replaceAll('Design B', 'CompanyPortal')
    .replaceAll('Design C', 'retired design')
    .replaceAll('تنقل تصميم ب', 'تنقل البوابة')
    .replaceAll('تصميم ب · مساحة عمل داخلية أكثر وضوحًا', 'البوابة · مساحة عمل داخلية أكثر وضوحًا');

  return text.replace(/__PRESERVED_STORAGE_(\d+)__/g, (_, index) => preservedKeys[Number(index)]);
}
