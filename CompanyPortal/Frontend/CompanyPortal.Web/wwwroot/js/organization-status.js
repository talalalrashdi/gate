(() => {
  const status = document.querySelector('.portal-org-status');
  if (!status) return;
  const user = status.closest('.portal-user');
  const alerts = user?.querySelector('.portal-alert-visibility');
  const themes = user?.querySelector('.portal-theme-menu');
  if (user) user.insertBefore(status, themes || alerts || user.firstChild);
  const menu = status.querySelector('.portal-org-status-menu');
  const states = {
    yellow: { title: 'تنبيه احترازي', color: 'أصفر', summary: 'توجد حالة تستدعي الانتباه والاستعداد، مع استمرار العمل وفق الإجراءات المعتادة ما لم يصدر تحديث رسمي.', actions: ['تابع قنوات المؤسسة الرسمية باستمرار.', 'تأكد من جاهزية وسائل التواصل وبيانات الاتصال.', 'راجع تعليمات السلامة الخاصة بموقعك.'] },
    orange: { title: 'حالة مرتفعة', color: 'برتقالي', summary: 'ارتفع مستوى الحالة ويتطلب الأمر تقليل الحركة غير الضرورية ورفع الجاهزية حتى وصول تعليمات جديدة.', actions: ['التزم بتوجيهات المسؤول المباشر وفريق السلامة.', 'أجّل التنقل والاجتماعات غير الضرورية.', 'جهّز المتطلبات الأساسية لخطة الاستجابة أو الإخلاء.'] },
    red: { title: 'حالة طوارئ', color: 'أحمر', summary: 'حالة طارئة تتطلب إيقاف الإجراءات الاعتيادية وتنفيذ التعليمات الرسمية بصورة فورية.', actions: ['توقف عن العمل المعتاد وحافظ على الهدوء.', 'نفّذ تعليمات الطوارئ أو الإخلاء فور صدورها.', 'توجه إلى نقطة التجمع ولا تعد إلى الموقع قبل التصريح.'] }
  };
  const detail = document.createElement('section');
  detail.className = 'portal-org-status-detail';
  detail.hidden = true;
  detail.innerHTML = '<button type="button" class="portal-org-status-back" aria-label="عودة إلى جميع الحالات"><span aria-hidden="true">→</span> عودة إلى جميع الحالات</button><div class="portal-org-status-detail-head"><span class="portal-org-status-dot" aria-hidden="true"></span><div><small></small><h2></h2></div></div><p></p><h3>ما الذي يجب فعله؟</h3><ul></ul>';
  menu.append(detail);
  status.querySelectorAll('.portal-org-status-list article').forEach((article, index) => {
    const key = ['yellow', 'orange', 'red'][index];
    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'portal-org-status-option';
    button.dataset.statusKey = key;
    button.setAttribute('aria-label', `عرض تفاصيل ${states[key].title}`);
    button.innerHTML = article.innerHTML;
    const arrow = document.createElement('span');
    arrow.className = 'portal-org-status-arrow'; arrow.setAttribute('aria-hidden', 'true'); arrow.textContent = '←'; button.append(arrow);
    const optionTitle = button.querySelector('strong');
    optionTitle.id = `portal-org-status-${key}`;
    button.setAttribute('aria-labelledby', optionTitle.id);
    article.replaceWith(button);
  });
  function showDetail(key) {
    const state = states[key];
    if (!state) return;
    detail.querySelector('.portal-org-status-dot').className = `portal-org-status-dot is-${key}`;
    detail.querySelector('.portal-org-status-detail-head small').textContent = state.color;
    detail.querySelector('h2').textContent = state.title;
    detail.querySelector(':scope > p').textContent = state.summary;
    detail.querySelector('ul').replaceChildren(...state.actions.map(action => { const item = document.createElement('li'); item.textContent = action; return item; }));
    detail.hidden = false;
    menu.classList.add('is-detail');
    detail.querySelector('.portal-org-status-back').focus();
  }
  function showOverview() {
    menu.classList.remove('is-detail');
    detail.hidden = true;
  }
  menu.addEventListener('click', event => {
    const option = event.target.closest('[data-status-key]');
    if (option) showDetail(option.dataset.statusKey);
    if (event.target.closest('.portal-org-status-back')) showOverview();
  });
  status.addEventListener('toggle', () => { if (!status.open) showOverview(); });
  document.addEventListener('click', event => {
    if (status.open && !status.contains(event.target)) status.open = false;
  });
  document.addEventListener('keydown', event => {
    if (event.key !== 'Escape' || !status.open) return;
    status.open = false;
    status.querySelector('summary').focus();
  });

  // Current status from Mng.CurrentStatus (ColorValue 1-4 → green/yellow/orange/red) via the API.
  const apiBase = document.querySelector('meta[name="companyportal-api-base"]')?.content;
  const summary = status.querySelector('summary');
  const current = {
    green: { title: 'الحالة الطبيعية', color: 'أخضر', summary: 'العمل مستمر بصورة طبيعية. اتبع إجراءات العمل المعتادة وراقب القنوات الرسمية للتحديثات.' },
    ...states
  };
  function formatUpdated(value) {
    const match = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})/.exec(value || '');
    if (!match) return null;
    const [, year, month, day, hour, minute] = match.map(Number);
    const date = new Intl.DateTimeFormat('ar-OM-u-nu-latn', { day: 'numeric', month: 'long', year: 'numeric' }).format(new Date(year, month - 1, day));
    const time = `${String(hour % 12 || 12).padStart(2, '0')}:${String(minute).padStart(2, '0')} ${hour < 12 ? 'صباحًا' : 'مساءً'}`;
    return { date, time, iso: value };
  }
  let lastPaint = null;
  function paint(key, title, badge, text, updated, simulated = false) {
    lastPaint = [key, updated, simulated];
    status.dataset.status = key;
    summary.querySelector('.portal-org-status-dot').className = `portal-org-status-dot is-${key}`;
    summary.querySelector('.portal-org-status-copy strong').textContent = title;
    summary.setAttribute('aria-label', `حالة المؤسسة: ${title}`);
    const head = menu.querySelector(':scope > header');
    const label = head.querySelector('.portal-org-status-badge');
    label.className = `portal-org-status-badge is-${key}`;
    label.textContent = badge;
    head.querySelector('.portal-org-status-simulated')?.remove();
    if (simulated) { const tag = document.createElement('span'); tag.className = 'portal-org-status-simulated'; tag.textContent = 'محاكاة'; label.after(tag); }
    const dot = document.createElement('span');
    dot.className = `portal-org-status-dot is-${key}`;
    dot.setAttribute('aria-hidden', 'true');
    head.querySelector('h2').replaceChildren(dot, title);
    const box = menu.querySelector('.portal-org-status-current');
    box.className = `portal-org-status-current is-${key}`;
    box.textContent = text;
    menu.querySelectorAll('.portal-org-status-option').forEach(option => {
      const isCurrent = option.dataset.statusKey === key;
      option.classList.toggle('is-current', isCurrent);
      option.querySelector('.portal-org-status-tag')?.remove();
      if (isCurrent) { const tag = document.createElement('span'); tag.className = 'portal-org-status-tag'; tag.textContent = 'الحالة الحالية'; option.querySelector('strong').after(tag); }
    });
    const when = formatUpdated(updated);
    menu.querySelectorAll('.portal-org-status-updated time').forEach(time => {
      if (when) { time.dateTime = when.iso; time.textContent = `${when.date} · ${when.time}`; }
      else { time.removeAttribute('datetime'); time.textContent = '—'; }
    });
  }
  let loaded = false, simulatedColor = null;
  async function load() {
    if (simulatedColor) return;
    if (!apiBase) { paint('unknown', 'الحالة غير متاحة', 'غير متاح', 'خدمة حالة المؤسسة غير مهيأة.', null); return; }
    try {
      const url = new URL('api/organization-status', new URL(apiBase.replace(/\/?$/, '/'), location.href));
      const response = await fetch(url, { credentials: 'include', cache: 'no-store', signal: AbortSignal.timeout(15000) });
      if (response.status === 204) { paint('unknown', 'لم تُسجَّل حالة', 'غير محدد', 'لم تُسجَّل حالة المؤسسة بعد. تابع القنوات الرسمية للتحديثات.', null); return; }
      if (!response.ok) throw new Error(String(response.status));
      const data = await response.json();
      const state = current[data.color];
      if (!state) throw new Error('Unknown status colour.');
      if (simulatedColor) return;
      paint(data.color, state.title, state.color, state.summary, data.lastUpdated);
      loaded = true;
    } catch {
      if (loaded) return; // keep the last good status on a failed refresh
      paint('unknown', 'الحالة غير متاحة', 'غير متاح', 'تعذر تحميل حالة المؤسسة. تابع القنوات الرسمية للتحديثات.', null);
    }
  }
  if (document.getElementById('portal-simulation')) {
    const pad = n => String(n).padStart(2, '0');
    const simulate = color => {
      if (!current[color]) { simulatedColor = null; void load(); return; }
      simulatedColor = color;
      const now = new Date(), stamp = `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}T${pad(now.getHours())}:${pad(now.getMinutes())}:00`;
      showOverview();
      paint(color, current[color].title, current[color].color, current[color].summary, stamp, true);
    };
    document.addEventListener('portal:org-status-simulation', event => simulate(event.detail.color));
    document.addEventListener('portal:simulate', event => { if (event.detail.kind === 'reset' && simulatedColor) simulate('real'); });
  }
  // Titles/texts/steps per level from Mng.StatusLevels (admin: /admin/header-content); built-in text stays if this fails.
  async function loadLevels() {
    try {
      const url = new URL('api/header-content/status-levels', new URL(apiBase.replace(/\/?$/, '/'), location.href));
      const response = await fetch(url, { credentials: 'include', cache: 'no-store', signal: AbortSignal.timeout(15000) });
      if (!response.ok) return;
      const levels = await response.json();
      if (!Array.isArray(levels)) return;
      for (const level of levels) {
        const state = current[level.color];
        if (!state) continue;
        Object.assign(state, { title: level.title, color: level.colorName, summary: level.summary, actions: Array.isArray(level.actions) ? level.actions : [] });
        const option = menu.querySelector(`.portal-org-status-option[data-status-key="${level.color}"]`);
        if (!option) continue;
        option.querySelector('strong').textContent = level.title;
        const name = option.querySelector('small'), guide = option.querySelector('p');
        if (name) name.textContent = level.colorName;
        if (guide) guide.textContent = level.guideText || '';
      }
      if (lastPaint && current[lastPaint[0]]) { const [key, updated, simulated] = lastPaint, state = current[key]; paint(key, state.title, state.color, state.summary, updated, simulated); }
    } catch { }
  }
  if (apiBase) void loadLevels();
  void load();
  setInterval(() => { if (!document.hidden) void load(); }, 120000);
  document.addEventListener('visibilitychange', () => { if (!document.hidden) void load(); });
})();
