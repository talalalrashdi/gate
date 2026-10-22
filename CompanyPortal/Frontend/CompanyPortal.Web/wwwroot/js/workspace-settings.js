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
  let definitions = null;
  const keys = () => [...workspace.querySelectorAll('[data-work-system]:not([data-work-group])')].map(card => card.dataset.workSystem);
  const valid = ids => Array.isArray(ids) && ids.length === keys().length
    && new Set(ids).size === ids.length && ids.every(id => keys().includes(id));
  const apply = cardKeys => workspace.dispatchEvent(new CustomEvent('workspace:order-select', { detail: { cardKeys, cards: definitions } }));
  // Visibility and audience are server decisions. Never restore a previous
  // account's catalog/roles/application names from localStorage.
  workspace.querySelectorAll('[data-work-system]:not([data-user-card-id])').forEach(card => { card.hidden = true; });
  function renderMasters(cards) {
    const master = cards.filter(card => !card.isCustom), allowed = new Set(master.map(card => card.cardKey));
    workspace.querySelectorAll('[data-work-system]:not([data-user-card-id])').forEach(card => {
      if (!allowed.has(card.dataset.workSystem)) card.remove();
    });
    const make = (tag, cls, text) => { const node = document.createElement(tag); if (cls) node.className = cls; if (text) node.textContent = text; return node; };
    master.forEach(definition => {
      let card = [...workspace.querySelectorAll('[data-work-system]')].find(node => node.dataset.workSystem === definition.cardKey);
      if (definition.cardType === 'applications') {
        if (card) card.remove();
        card = make('article','portal-work-card portal-system-group');
        card.dataset.workSystem = definition.cardKey; card.dataset.widgetCategory = 'applications'; card.dataset.masterApplicationCard = '';
        const heading = make('header','portal-work-heading'), title = make('h2',null,definition.cardName);
        title.id = definition.cardKey + '-title'; card.setAttribute('aria-labelledby',title.id); heading.append(title);
        const list = make('ul','portal-group-system-list'); list.dataset.widgetPreview = '';
        definition.applications.forEach(app => {
          const row = make('li'), link = make('a',null,'فتح التطبيق ↗');
          link.href = new URL('api/applications/' + app.appId + '/launch',new URL(base.replace(/\/?$/, '/'),location.href)).href;
          link.target = '_blank'; link.rel = 'noopener'; link.setAttribute('aria-label','فتح تطبيق ' + app.appName);
          row.append(make('span',null,app.appName),link); list.append(row);
        });
        card.append(heading,list);
        if (!definition.applications.length) card.append(make('p','portal-group-empty','لا توجد تطبيقات مصرح بها لحسابك في هذه البطاقة.'));
        workspace.insertBefore(card,workspace.querySelector('.portal-workspace-add-group'));
      }
      if (card) card.hidden = false;
    });
    workspace.dispatchEvent(new CustomEvent('workspace:cards-changed'));
  }
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
      // Custom cards are fetched for this account, never restored from browser data.
      await window.CompanyPortalCustomCards?.ready;
      const response = await request();
      if (!response.ok) { show(failed(response)); return; }
      const result = await response.json();
      if (!policy.valid(result.cards,result.cardKeys) || result.cards.some(card => !card.isCustom && !['connected','applications'].includes(card.cardType))
          || result.cards.some(card => card.cardType === 'applications' && (!Array.isArray(card.applications)
            || card.applications.some(app => !Number.isInteger(app.appId) || app.appId < 1 || typeof app.appName !== 'string')))) throw new Error('Invalid card catalog');
      renderMasters(result.cards);
      if (!valid(result.cardKeys) || !policy.valid(result.cards, keys())) throw new Error('Card catalog mismatch');
      definitions = result.cards;
      workspace.setAttribute('data-card-catalog-ready','');
      apply(policy.normalize(version ? keys() : result.cardKeys, definitions));
      if (!version) show(result.isSaved ? 'تم تحميل ترتيب بطاقات حسابك.' : 'يُحفظ ترتيب البطاقات في حسابك عند تغييره.');
    } catch {
      if (!version) show('تعذر تحميل البطاقات المتاحة لحسابك. أعد تحميل الصفحة للمحاولة مجددًا.');
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
