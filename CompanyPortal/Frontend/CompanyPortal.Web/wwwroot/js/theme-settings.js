(() => {
  const base = document.querySelector('meta[name="companyportal-api-base"]')?.content;
  const options = document.getElementById('portal-theme-options');
  if (!base || !options) return;
  const status = document.createElement('small');
  status.id = 'theme-sync-status';
  status.setAttribute('role', 'status');
  status.setAttribute('aria-live', 'polite');
  options.append(status);
  const url = new URL('api/user-settings/theme', new URL(base.replace(/\/?$/, '/'), location.href));
  const allowed = new Set(['majestic', 'official', 'formal']);
  let version = 0, applying = false, writes = Promise.resolve();
  const show = text => { status.textContent = text; };
  const failed = response => {
    if (response.status === 403) return 'الحساب غير مسجل أو غير نشط. لم يُحفظ المظهر في حسابك.';
    if (response.status === 401) return 'تعذر التحقق من حساب Windows. المظهر محفوظ على هذا المتصفح فقط.';
    return 'تعذر الحفظ في حسابك. المظهر محفوظ على هذا المتصفح فقط.';
  };
  const request = (method, theme) => fetch(url, {
    method, credentials: 'include', cache: 'no-store', signal: AbortSignal.timeout(10000),
    ...(method === 'PUT' ? {
      headers: { 'Content-Type': 'application/json', 'X-CompanyPortal-Request': 'theme' },
      body: JSON.stringify({ theme })
    } : {})
  });

  const initial = (async () => {
    show('جارٍ تحميل مظهر الحساب…');
    try {
      const response = await request('GET');
      if (!response.ok) { if (!version) show(failed(response)); return; }
      const settings = await response.json();
      if (!allowed.has(settings.theme)) throw new Error('Invalid saved theme');
      // Never overwrite a newer selection made while the initial request was pending.
      if (version) return;
      applying = true;
      try { document.querySelector(`[data-theme-option="${settings.theme}"]`)?.click(); }
      finally { applying = false; }
      show(settings.isSaved ? 'تم تحميل مظهر حسابك.' : 'المظهر الافتراضي لحسابك.');
    } catch { if (!version) show('تعذر تحميل مظهر حسابك. يُستخدم اختيار هذا المتصفح.'); }
  })();

  document.addEventListener('companyportal:theme-change', event => {
    if (applying || !allowed.has(event.detail?.theme)) return;
    const theme = event.detail.theme, current = ++version;
    show('جارٍ حفظ المظهر…');
    // Serialize writes so an older slow response cannot replace the latest selection.
    writes = writes.then(async () => {
      await initial;
      if (current !== version) return;
      try {
        const response = await request('PUT', theme);
        if (current === version) show(response.ok ? 'المظهر محفوظ لحسابك.' : failed(response));
      } catch { if (current === version) show('تعذر الحفظ في حسابك. المظهر محفوظ على هذا المتصفح فقط.'); }
    });
  });
})();
