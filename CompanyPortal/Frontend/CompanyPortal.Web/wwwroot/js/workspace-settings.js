(() => {
  const base = document.querySelector('meta[name="companyportal-api-base"]')?.content;
  const workspace = document.getElementById('workspace-cards');
  const toolbar = document.querySelector('.portal-workspace-toolbar');
  if (!base || !workspace || !toolbar) return;
  const endpoint = new URL('api/user-settings/card-order', new URL(base.replace(/\/?$/, '/'), location.href));
  const status = document.createElement('small');
  status.id = 'workspace-sync-status';
  status.setAttribute('role', 'status');
  status.setAttribute('aria-live', 'polite');
  toolbar.append(status);
  const show = text => { status.textContent = text; };
  const policy = window.CompanyPortalWorkspacePolicy;
  const cacheKey = 'companyportal-master-card-policy-v1';
  let definitions = null;
  const keys = () => [...workspace.querySelectorAll('[data-work-system]:not([data-work-group])')].map(card => card.dataset.workSystem);
  const valid = ids => Array.isArray(ids) && ids.length === keys().length
    && new Set(ids).size === ids.length && ids.every(id => keys().includes(id));
  const apply = cardKeys => workspace.dispatchEvent(new CustomEvent('workspace:order-select', { detail: { cardKeys, cards: definitions } }));
  try {
    const cached = JSON.parse(localStorage.getItem(cacheKey));
    if (policy.valid(cached, keys())) { definitions = cached; apply(policy.normalize(keys(), definitions)); }
  } catch { /* Without a cached policy, reordering waits for the master definitions. */ }
  const failed = response => response.status === 403
    ? 'الحساب غير مسجل أو غير نشط. الترتيب محلي فقط.'
    : response.status === 400 ? 'تعذر حفظ الترتيب. أعد تحميل الصفحة لتحديث البطاقات.'
    : 'تعذر حفظ الترتيب في حسابك. يُستخدم محليًا فقط.';
  const request = cardKeys => fetch(endpoint, {
    method: cardKeys ? 'PUT' : 'GET', credentials: 'include', cache: 'no-store',
    signal: AbortSignal.timeout(10000),
    ...(cardKeys ? { headers: { 'Content-Type': 'application/json', 'X-CompanyPortal-Request': 'card-order' },
      body: JSON.stringify({ cardKeys }) } : {})
  });
  let version = 0, writes = Promise.resolve();
  const initial = (async () => {
    show('جارٍ تحميل ترتيب البطاقات…');
    try {
      const response = await request();
      if (!response.ok) { show(failed(response)); return; }
      const result = await response.json();
      if (!valid(result.cardKeys) || !policy.valid(result.cards, keys())) throw new Error('Card catalog mismatch');
      definitions = result.cards;
      try { localStorage.setItem(cacheKey, JSON.stringify(definitions)); } catch { /* Account saves remain available. */ }
      apply(policy.normalize(version || !result.isSaved ? keys() : result.cardKeys, definitions));
      if (!version) show(result.isSaved ? 'تم تحميل ترتيب بطاقات حسابك.' : 'يُحفظ ترتيب البطاقات في حسابك عند تغييره.');
    } catch {
      if (!version) show('تعذر تحميل ترتيب حسابك. يُستخدم ترتيب هذا المتصفح.');
    }
  })();
  workspace.addEventListener('workspace:order-changed', event => {
    const cardKeys = event.detail?.cardKeys;
    if (!valid(cardKeys)) return;
    const selected = [...cardKeys], current = ++version;
    show('جارٍ حفظ ترتيب البطاقات…');
    writes = writes.then(async () => {
      await initial;
      if (current !== version) return;
      if (!definitions) { show('تعذر تحميل مواضع البطاقات. أعد تحميل الصفحة.'); return; }
      const normalized = policy.normalize(selected, definitions);
      apply(normalized);
      try {
        const response = await request(normalized);
        if (current === version) show(response.ok ? 'ترتيب البطاقات محفوظ لحسابك.' : failed(response));
      } catch {
        if (current === version) show('تعذر حفظ الترتيب في حسابك. يُستخدم محليًا فقط.');
      }
    });
  });
})();
