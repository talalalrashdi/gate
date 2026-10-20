(() => {
  const base = document.querySelector('meta[name="companyportal-api-base"]')?.content;
  const options = document.getElementById('portal-theme-options');
  if (!base || !options) return;
  const root = new URL(base.replace(/\/?$/, '/'), location.href);
  const layouts = new Set(['official', 'work', 'national-day']);
  const cacheKey = 'companyportal-selected-theme-v1';
  const status = document.createElement('small');
  status.id = 'theme-sync-status';
  status.setAttribute('role', 'status');
  status.setAttribute('aria-live', 'polite');
  options.append(status);
  let catalog = [], selectedId = null, version = 0, applying = false, pendingLayout = null;
  let writes = Promise.resolve(), imageVersion = 0;
  async function loadImages(theme) {
    const current = ++imageVersion;
    document.dispatchEvent(new CustomEvent('companyportal:theme-images', {detail:null}));
    try {
      const response = await request(`api/themes/${theme.themeId}/images`);
      if (!response.ok) return;
      const data = await response.json();
      if (current !== imageVersion || !data.settings || !Array.isArray(data.images) || !data.images.length) return;
      if (!data.images.every(image => Number.isInteger(image.imageId) && image.imageId > 0)) return;
      document.dispatchEvent(new CustomEvent('companyportal:theme-images', {detail:{
        ...data.settings, images:data.images.map(image => ({...image, url:new URL(`api/images/${image.imageId}/content`,root).href}))
      }}));
    } catch { /* Keep the original layout images if the API is unavailable. */ }
  }
  const show = text => { status.textContent = text; };
  const valid = theme => Number.isInteger(theme?.themeId) && theme.themeId > 0
    && typeof theme.themeName === 'string' && theme.themeName.length > 0 && theme.themeName.length <= 200
    && layouts.has(theme.layoutKey);
  const failed = response => response.status === 403
    ? 'الحساب غير مسجل أو غير نشط. لم يُحفظ المظهر في حسابك.'
    : response.status === 401 ? 'تعذر التحقق من حساب Windows. يُستخدم المظهر محليًا فقط.'
    : 'تعذر الحفظ في حسابك. يُستخدم المظهر محليًا فقط.';
  const request = (path, themeId) => fetch(new URL(path, root), {
    method: themeId === undefined ? 'GET' : 'PUT', credentials: 'include', cache: 'no-store',
    signal: AbortSignal.timeout(10000),
    ...(themeId === undefined ? {} : {
      headers: { 'Content-Type': 'application/json', 'X-CompanyPortal-Request': 'theme' },
      body: JSON.stringify({ themeId })
    })
  });

  function apply(theme) {
    selectedId = theme.themeId;
    loadImages(theme);
    applying = true;
    try {
      document.dispatchEvent(new CustomEvent('companyportal:theme-select', {
        detail: { layoutKey: theme.layoutKey, themeName: theme.themeName }
      }));
    } finally { applying = false; }
    window.CompanyPortalTheme?.apply(theme);
    options.querySelectorAll('[data-theme-id]').forEach(button =>
      button.setAttribute('aria-pressed', String(Number(button.dataset.themeId) === selectedId)));
    try { localStorage.setItem(cacheKey, JSON.stringify(theme)); }
    catch { /* Account persistence works even if local storage is blocked. */ }
  }

  function renderCatalog() {
    const container = options.querySelector(':scope > div');
    container.classList.add('portal-theme-catalog');
    container.replaceChildren();
    catalog.forEach((theme, index) => {
      const button = document.createElement('button');
      button.type = 'button';
      button.dataset.themeId = String(theme.themeId);
      button.dataset.themeOption = theme.layoutKey;
      button.textContent = String(index + 1);
      button.title = theme.themeName;
      button.setAttribute('aria-label', `${index + 1} · ${theme.themeName}`);
      button.setAttribute('aria-controls', `theme-${theme.layoutKey}`);
      button.setAttribute('aria-pressed', String(theme.themeId === selectedId));
      button.addEventListener('click', () => {
        apply(theme);
        options.closest('details').open = false;
        queueSave({ themeId: theme.themeId });
      });
      container.append(button);
    });
  }

  try {
    const cached = JSON.parse(localStorage.getItem(cacheKey));
    if (valid(cached)) apply(cached);
  } catch { /* Original layout preference remains available as the fallback. */ }

  const initial = (async () => {
    show('جارٍ تحميل مظاهر الحساب…');
    try {
      const [themesResponse, settingsResponse] = await Promise.all([
        request('api/themes'), request('api/user-settings/theme')
      ]);
      if (!themesResponse.ok) throw new Error('Catalog unavailable');
      const themes = await themesResponse.json();
      if (!Array.isArray(themes) || themes.length === 0 || !themes.every(valid)
        || new Set(themes.map(theme => theme.themeId)).size !== themes.length
        || themes.filter(theme => theme.isDefault).length !== 1) throw new Error('Invalid catalog');
      catalog = themes;
      renderCatalog();
      if (version) {
        const pending = catalog.find(theme => theme.layoutKey === pendingLayout);
        if (pending) apply(pending);
        return;
      }
      if (!settingsResponse.ok) { show(failed(settingsResponse)); return; }
      const settings = await settingsResponse.json();
      const selected = catalog.find(theme => theme.themeId === settings.themeId);
      if (!selected) throw new Error('Selected theme is unavailable');
      apply(selected);
      show(settings.isSaved ? 'تم تحميل مظهر حسابك.' : 'المظهر الافتراضي لحسابك.');
    } catch {
      if (!version) show('تعذر تحميل مظاهر حسابك. يُستخدم اختيار هذا المتصفح.');
    }
  })();

  function queueSave(selection) {
    const current = ++version;
    show('جارٍ حفظ المظهر…');
    writes = writes.then(async () => {
      await initial;
      if (current !== version) return;
      const selected = selection.themeId
        ? catalog.find(theme => theme.themeId === selection.themeId)
        : catalog.find(theme => theme.layoutKey === selection.layoutKey);
      if (!selected) { show('تعذر الحفظ في حسابك. يُستخدم المظهر محليًا فقط.'); return; }
      apply(selected);
      try {
        const response = await request('api/user-settings/theme', selected.themeId);
        if (current === version) show(response.ok ? 'المظهر محفوظ لحسابك.' : failed(response));
      } catch {
        if (current === version) show('تعذر الحفظ في حسابك. يُستخدم المظهر محليًا فقط.');
      }
    });
  }

  // Before catalog arrival (or offline), the original layout buttons remain usable.
  document.addEventListener('companyportal:theme-change', event => {
    if (applying || !layouts.has(event.detail?.theme)) return;
    ++imageVersion;
    document.dispatchEvent(new CustomEvent('companyportal:theme-images', {detail:null}));
    selectedId = null;
    pendingLayout = event.detail.theme;
    try { localStorage.removeItem(cacheKey); } catch { /* No storage is required. */ }
    queueSave({ layoutKey: pendingLayout });
  });
})();
