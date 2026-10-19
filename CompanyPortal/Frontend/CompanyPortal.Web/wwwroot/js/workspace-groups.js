(() => {
  const workspace = document.getElementById('workspace-cards');
  const base = document.querySelector('meta[name="companyportal-api-base"]')?.content;
  if (!workspace || !base) return;
  const root = new URL(base.replace(/\/?$/, '/'), location.href);
  const make = (tag, cls, text) => { const node = document.createElement(tag); if (cls) node.className = cls; if (text) node.textContent = text; return node; };
  let groups = [], apps = [], editing = null, selected = new Set(), busy = false;
  const add = make('button', 'portal-work-card portal-workspace-add-group');
  add.type = 'button'; add.disabled = true; add.dataset.widgetCategory = 'applications';
  add.setAttribute('aria-label', 'إضافة بطاقة تطبيقات شخصية');
  const hint = make('small', null, 'جارٍ تحميل بطاقاتك…');
  add.append(make('span', 'portal-group-plus', '+'), make('strong', null, 'بطاقة جديدة'), hint);
  workspace.append(add);
  const dialog = make('dialog', 'portal-group-dialog');
  dialog.setAttribute('aria-labelledby', 'group-dialog-title');
  dialog.innerHTML = '<form><header><h2 id="group-dialog-title">بطاقة جديدة</h2><button type="button" data-group-close aria-label="إغلاق">×</button></header><label class="portal-group-name-label" for="group-name">اسم البطاقة</label><input id="group-name" name="name" maxlength="200" required autocomplete="off"><fieldset><legend>اختر التطبيقات المصرح بها</legend><input type="search" id="group-system-search" aria-label="البحث عن تطبيق" placeholder="ابحث عن تطبيق…"><div class="portal-group-choices"></div><p class="portal-group-no-results" hidden>لا توجد تطبيقات مطابقة.</p></fieldset><p class="portal-group-count" aria-live="polite"></p><p class="portal-group-error" role="alert" hidden></p><footer><button type="button" class="portal-group-delete" hidden>حذف البطاقة</button><button type="button" data-group-close>إلغاء</button><button type="submit" class="portal-group-save">حفظ البطاقة</button></footer></form>';
  document.body.append(dialog);
  const form = dialog.querySelector('form'), name = dialog.querySelector('#group-name'), search = dialog.querySelector('#group-system-search');
  const choices = dialog.querySelector('.portal-group-choices'), error = dialog.querySelector('.portal-group-error'), remove = dialog.querySelector('.portal-group-delete');
  async function request(path, method = 'GET', body) {
    let response;
    try { response = await fetch(new URL(path, root), {
      method, credentials: 'include', cache: 'no-store', signal: AbortSignal.timeout(10000),
      ...(method === 'GET' ? {} : { headers: { 'X-CompanyPortal-Request': 'custom-cards', ...(body ? { 'Content-Type': 'application/json' } : {}) } }),
      ...(body ? { body: JSON.stringify(body) } : {})
    }); } catch { throw new Error('تعذر الاتصال بخدمة البطاقات. حاول مرة أخرى.'); }
    if (!response.ok) throw new Error(response.status === 400 ? 'تحقق من الاسم والتطبيقات المصرح بها وحدود البطاقة.'
      : response.status === 404 ? 'البطاقة أو التطبيق لم يعد متاحًا.'
      : response.status === 403 ? 'الحساب غير مسجل أو غير نشط.' : 'تعذر الاتصال بخدمة البطاقات. حاول مرة أخرى.');
    return response.status === 204 ? null : response.json();
  }
  function render() {
    workspace.querySelectorAll('[data-user-card-id]').forEach(card => card.remove());
    groups.forEach(group => {
      const card = make('article', 'portal-work-card portal-system-group');
      card.dataset.workSystem = 'custom-' + group.userCardId;
      card.dataset.userCardId = String(group.userCardId); card.dataset.widgetCategory = 'applications';
      const heading = make('header', 'portal-work-heading'), icon = make('div', 'portal-work-icon');
      icon.innerHTML = '<i class="iconsax" icon-name="folder-2" aria-hidden="true"></i>';
      const copy = make('div'), title = make('h2', null, group.cardName);
      title.id = 'custom-' + group.userCardId + '-title'; card.setAttribute('aria-labelledby', title.id); copy.append(title); heading.append(icon, copy);
      const actions = make('div', 'systems-work-label'), edit = make('button', 'portal-group-edit', '✎');
      edit.type = 'button'; edit.setAttribute('aria-label', 'تعديل ' + group.cardName); edit.title = 'تعديل ' + group.cardName;
      edit.addEventListener('click', () => open(group.userCardId)); actions.append(edit); heading.append(actions);
      const list = make('ul', 'portal-group-system-list'); list.dataset.widgetPreview = '';
      group.applications.forEach(app => {
        const row = make('li'), link = make('a', null, 'فتح التطبيق ↗');
        link.href = new URL('api/applications/' + app.appId + '/launch', root).href;
        link.target = '_blank'; link.rel = 'noopener'; link.setAttribute('aria-label', 'فتح تطبيق ' + app.appName);
        row.append(make('span', null, app.appName), link); list.append(row);
      });
      card.append(heading, list);
      if (!group.applications.length) card.append(make('p', 'portal-group-empty', 'لا توجد تطبيقات متاحة في هذه البطاقة. يمكنك تعديلها أو حذفها.'));
      workspace.insertBefore(card, add);
    });
    workspace.dispatchEvent(new CustomEvent('workspace:cards-changed'));
    if (typeof updateWorkspaceNavigation === 'function') updateWorkspaceNavigation();
  }
  function count() { dialog.querySelector('.portal-group-count').textContent = selected.size + ' تطبيقات محددة'; }
  function filter() {
    const normalize = value => value.replace(/[أإآ]/g, 'ا').toLowerCase();
    const query = normalize(search.value.trim()); let visible = 0;
    choices.querySelectorAll('label').forEach(label => { label.hidden = !normalize(label.textContent).includes(query); if (!label.hidden) visible++; });
    dialog.querySelector('.portal-group-no-results').hidden = visible !== 0;
  }
  async function open(id = null) {
    if (busy) return;
    add.disabled = true;
    try {
      apps = await request('api/applications');
      editing = id;
      const group = groups.find(item => item.userCardId === id);
      const allowed = new Set(apps.map(app => app.appId));
      selected = new Set((group?.applications || []).map(app => app.appId).filter(appId => allowed.has(appId)));
      name.value = group?.cardName || ''; search.value = ''; error.hidden = true; remove.hidden = !group;
      dialog.querySelector('h2').textContent = group ? 'تعديل البطاقة' : 'بطاقة جديدة'; choices.replaceChildren();
      dialog.querySelector('.portal-group-no-results').textContent = apps.length ? 'لا توجد تطبيقات مطابقة.' : 'لا توجد تطبيقات مصرح بها لحسابك حاليًا.';
      apps.forEach(app => {
        const label = make('label'), input = make('input'); input.type = 'checkbox'; input.value = String(app.appId); input.checked = selected.has(app.appId);
        input.addEventListener('change', () => { if (input.checked) selected.add(app.appId); else selected.delete(app.appId); count(); error.hidden = true; });
        label.append(input, make('span', null, app.appName)); choices.append(label);
      });
      count(); filter(); dialog.showModal(); name.focus();
    } catch (failure) { hint.textContent = failure.message || 'تعذر تحميل التطبيقات.'; }
    finally { add.disabled = false; }
  }
  function reload() { location.hash = 'workspace'; location.reload(); }
  async function mutate(method, body) {
    if (busy) return;
    busy = true; error.hidden = true; form.querySelectorAll('button').forEach(button => { button.disabled = true; });
    try { await request('api/user-cards' + (editing === null ? '' : '/' + editing), method, body); reload(); }
    catch (failure) { error.textContent = failure.message || 'تعذر حفظ البطاقة.'; error.hidden = false; }
    finally { busy = false; form.querySelectorAll('button').forEach(button => { button.disabled = false; }); }
  }
  form.addEventListener('submit', event => {
    event.preventDefault();
    if (!name.value.trim() || selected.size < 1 || selected.size > 100) { error.textContent = 'اكتب اسمًا واختر من 1 إلى 100 تطبيق مصرح به.'; error.hidden = false; return; }
    mutate(editing === null ? 'POST' : 'PUT', { cardName: name.value.trim(), appIds: [...selected] });
  });
  remove.addEventListener('click', () => mutate('DELETE'));
  dialog.querySelectorAll('[data-group-close]').forEach(button => button.addEventListener('click', () => dialog.close()));
  add.addEventListener('click', () => open()); search.addEventListener('input', filter);
  const ready = (async () => {
    try {
      const results = await Promise.all([request('api/applications'), request('api/user-cards')]);
      apps = results[0]; groups = results[1]; render(); add.disabled = false;
      hint.textContent = 'اجمع تطبيقاتك المصرح بها';
    } catch (failure) { hint.textContent = failure.message || 'تعذر تحميل بطاقاتك.'; throw failure; }
  })();
  // Keep startup failures handled even while the later order script is loading.
  ready.catch(() => {});
  window.CompanyPortalCustomCards = { ready };
})();
