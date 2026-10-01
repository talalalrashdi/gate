(() => {
  const section = document.getElementById('systems');
  if (!section) return;
  const read = (key, fallback) => { try { return JSON.parse(localStorage.getItem(key)) ?? fallback; } catch { return fallback; } };
  const save = (key, value) => { try { localStorage.setItem(key, JSON.stringify(value)); return true; } catch { return false; } };
  const byId = id => document.getElementById(id);
  const themeButtons = [...document.querySelectorAll('[data-intro-option]')];
  const themePanels = [...section.querySelectorAll('.b-intro-panel')];
  const siteHeader = document.querySelector('.b-header');
  const headerHome = siteHeader?.parentElement;
  const headerNext = siteHeader?.nextSibling;
  const majesticFrame = byId('bt-majestic-frame');
  const sharedCalendar = section.querySelector('.bt-calendar-main');
  const sharedPlanner = sharedCalendar?.closest('.bt-planner');
  const plannerHome = sharedPlanner?.parentElement;
  const plannerNext = sharedPlanner?.nextSibling;
  const sharedComposer = byId('bt-task-composer');
  const composerHome = sharedComposer?.parentElement;
  const composerNext = sharedComposer?.nextSibling;
  const majesticCalendar = byId('bt-majestic-calendar');
  const sceneButtons = [...document.querySelectorAll('[data-majestic-scene]')];
  const sceneImages = [...document.querySelectorAll('[data-majestic-image]')];
  const backdrop = document.querySelector('.bt-majestic-backdrop');
  const playbackButton = document.querySelector('.bt-majestic-playback');
  const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
  let sceneIndex = 0, sceneTimer, playbackPaused = reducedMotion.matches;
  const themes = {
    1: { theme: 'business', panel: 'intro-option-1', label: 'الأعمال', labelledBy: 'workspace-title' },
    2: { theme: 'official', panel: 'intro-option-2', label: 'الوطنية', labelledBy: 'bt-official-title' },
    3: { theme: 'formal', panel: 'intro-option-3', label: 'الرسمية', labelledBy: 'bt-formal-title' },
    4: { theme: 'majestic', panel: 'intro-option-4', label: 'الشامخة', labelledBy: 'bt-majestic-title' }
  };
  function selectTheme(option) {
    option = Object.hasOwn(themes, option) && byId(themes[option].panel) ? option : '1';
    const selected = themes[option];
    section.dataset.theme = selected.theme;
    document.body.dataset.siteTheme = selected.theme;
    themeButtons.forEach(button => {
      const active = button.dataset.introOption === option;
      button.setAttribute('aria-pressed', String(active));
    });
    themePanels.forEach(panel => { panel.hidden = panel.id !== selected.panel; });
    if (siteHeader && headerHome && majesticFrame) {
      if (option === '4') majesticFrame.prepend(siteHeader);
      else headerHome.insertBefore(siteHeader, headerNext);
    }
    if (sharedPlanner && plannerHome && majesticCalendar) {
      if (option === '4') {
        majesticCalendar.append(sharedPlanner);
        if (sharedComposer) majesticCalendar.append(sharedComposer);
      } else {
        plannerHome.insertBefore(sharedPlanner, plannerNext);
        if (sharedComposer && composerHome) composerHome.insertBefore(sharedComposer, composerNext);
      }
    }
    section.setAttribute('aria-labelledby', selected.labelledBy);
    byId('bt-theme-name').textContent = selected.label;
    save('clerio-opening-theme', option);
    syncMajesticPlayback();
  }
  const themeMenu = byId('b-theme-options')?.closest('details');
  themeButtons.forEach(button => button.addEventListener('click', () => { selectTheme(button.dataset.introOption); if (themeMenu) themeMenu.open = false; }));
  function showMajesticScene(index) {
    sceneIndex = index;
    const scene = sceneButtons[index]?.dataset.majesticScene;
    sceneButtons.forEach((button, i) => button.setAttribute('aria-pressed', String(i === index)));
    sceneImages.forEach(image => image.classList.toggle('is-active', image.dataset.majesticImage === scene));
  }
  function syncMajesticPlayback() {
    clearTimeout(sceneTimer);
    if (!backdrop || !sceneButtons.length) return;
    const paused = playbackPaused;
    const running = !paused && !document.hidden && document.body.dataset.siteTheme === 'majestic';
    backdrop.dataset.paused = String(!running);
    playbackButton?.setAttribute('aria-pressed', String(paused));
    if (playbackButton) {
      playbackButton.textContent = paused ? 'تشغيل الحركة' : 'إيقاف الحركة';
    }
    if (running) sceneTimer = setTimeout(() => {
      showMajesticScene((sceneIndex + 1) % sceneButtons.length);
      syncMajesticPlayback();
    }, 8000);
  }
  sceneButtons.forEach((button, index) => button.addEventListener('click', () => {
    showMajesticScene(index);
    syncMajesticPlayback();
  }));
  playbackButton?.addEventListener('click', () => {
    playbackPaused = !playbackPaused;
    syncMajesticPlayback();
  });
  if (backdrop) {
    document.addEventListener('visibilitychange', syncMajesticPlayback);
    reducedMotion.addEventListener('change', () => {
      playbackPaused = reducedMotion.matches;
      syncMajesticPlayback();
    });
  }
  selectTheme(read('clerio-opening-theme', '1'));
  const today = new Date();
  const dateKey = date => `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
  const todayKey = dateKey(today);
  const validDate = value => typeof value === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(value) && dateKey(new Date(value + 'T12:00:00')) === value;
  const validTime = value => typeof value === 'string' && /^([01]\d|2[0-3]):[0-5]\d$/.test(value);
  const dateLabel = value => new Date(value + 'T12:00:00').toLocaleDateString('ar-OM', { weekday: 'long', day: 'numeric', month: 'long' });
  const number = value => value.toLocaleString('ar-EG');
  const types = { task: 'مهمة', meeting: 'اجتماع', call: 'اتصال', delivery: 'تسليم مشروع', note: 'ملاحظة' };
  const validType = type => Object.hasOwn(types, type) ? type : 'task';
  function taskIcon(type) {
    const paths = {
      task: '<rect x="4" y="4" width="16" height="16" rx="4"/><path d="m8 12 3 3 5-6"/>',
      meeting: '<circle cx="9" cy="8" r="3"/><path d="M3 20v-2a6 6 0 0 1 12 0v2m1-15a3 3 0 0 1 0 6m3 9v-2a6 6 0 0 0-3-5"/>',
      call: '<path d="m8 3 3 5-3 3a15 15 0 0 0 5 5l3-3 5 3-1 4c-1 3-8 0-12-4S1 5 4 4z"/>',
      delivery: '<path d="m12 3 9 5v9l-9 5-9-5V8zm-9 5 9 5 9-5m-9 5v9M7 6l9 5"/>',
      note: '<path d="M14 3H5v18h14V8zm0 0v5h5M8 12h8m-8 4h6"/>',
      trash: '<path d="M3 6h18M9 6V3h6v3M5 6l1 15h12l1-15M10 10v7m4-7v7"/>'
    };
    const icon = document.createElement('span'); icon.className = 'bt-task-icon';
    icon.innerHTML = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${paths[type] || paths.task}</svg>`;
    return icon;
  }
  let selected = todayKey, month = new Date(today.getFullYear(), today.getMonth(), 1);
  let tasks = read('clerio-personal-tasks', []);
  if (!Array.isArray(tasks)) tasks = [];
  tasks = tasks.filter(task => task && typeof task.title === 'string' && typeof task.done === 'boolean').map(task => ({
    ...task, date: validDate(task.date) ? task.date : todayKey,
    time: validTime(task.time) ? task.time : '', type: validType(task.type), body: typeof task.body === 'string' ? task.body : ''
  }));
  let notes = read('clerio-business-notes', {});
  if (!notes || Array.isArray(notes) || typeof notes !== 'object') notes = {};
  // Examples are anchored once and explicitly labeled, not official observance dates.
  let demoDate = read('clerio-business-demo-date', null);
  if (!validDate(demoDate)) { demoDate = todayKey; save('clerio-business-demo-date', demoDate); }
  const offsetDate = offset => { const date = new Date(demoDate + 'T12:00:00'); date.setDate(date.getDate() + offset); return dateKey(date); };
  const occasions = [
    { date: demoDate, title: 'يوم القلب', symbol: '♡', detail: 'تذكير بالعناية بصحتك خلال يوم العمل.' },
    { date: offsetDate(3), title: 'يوم مشاركة المعرفة', symbol: '✦', detail: 'فكرة أو تجربة تستحق المشاركة مع الفريق.' },
    { date: offsetDate(7), title: 'مبادرة تطوعية', symbol: '◇', detail: 'مساحة للمشاركة وصناعة أثر إيجابي.' }
  ];
  if (!read('clerio-business-examples-v1', false)) {
    if (!tasks.length) {
      tasks = [
        { title: 'مراجعة أولويات الأسبوع', type: 'task', time: '08:30' },
        { title: 'اجتماع متابعة الفريق', type: 'meeting', time: '10:00' },
        { title: 'اتصال لمتابعة متطلبات العميل', type: 'call', time: '11:30' },
        { title: 'تسليم النسخة الأولية للمشروع', type: 'delivery', time: '14:00' }
      ].map(task => ({ ...task, date: todayKey, done: false, demo: true }));
      save('clerio-personal-tasks', tasks);
    }
    if (!Object.hasOwn(notes, todayKey)) {
      notes[todayKey] = 'ملاحظة توضيحية — يمكنك تعديلها:\n• تجهيز نقاط اجتماع الفريق.\n• مراجعة متطلبات المشروع قبل التسليم.';
      save('clerio-business-notes', notes);
    }
    save('clerio-business-examples-v1', true);
  }
  // Copy existing dated notes once; retain the original storage as a recovery source.
  if (!read('clerio-business-notes-merged-v1', false)) {
    Object.entries(notes).forEach(([date, body]) => {
      if (validDate(date) && typeof body === 'string' && body.trim() && !tasks.some(task => task.legacyNoteDate === date)) {
        tasks.push({ title: 'ملاحظات اليوم', body, type: 'note', date, time: '', done: false, legacyNoteDate: date });
      }
    });
    if (save('clerio-personal-tasks', tasks)) save('clerio-business-notes-merged-v1', true);
  }
  const timeline = byId('bt-task-preview'), composer = byId('bt-task-composer'), form = byId('bt-task-form');
  let editing = null;
  const announce = message => { const status = byId('bt-task-status'); if (status) status.textContent = message; };
  function persistTasks(message) {
    announce(save('clerio-personal-tasks', tasks) ? message : 'تعذّر الحفظ في المتصفح؛ التغييرات متاحة حتى إغلاق الصفحة.');
  }
  function updateFade() { timeline.parentElement.classList.toggle('has-more', timeline.scrollHeight - timeline.clientHeight - timeline.scrollTop > 2); }
  timeline.addEventListener('scroll', updateFade, { passive: true });
  new ResizeObserver(updateFade).observe(timeline);
  function counts() {
    const daily = tasks.filter(task => task.date === selected), work = daily.filter(task => task.type !== 'note'), noteCount = daily.length - work.length;
    const summary = [];
    if (work.length) summary.push(`${number(work.filter(task => task.done).length)} / ${number(work.length)} مكتملة`);
    if (noteCount) summary.push(`ملاحظات: ${number(noteCount)}`);
    const counter = byId('bt-day-count');
    if (counter) counter.textContent = summary.join(' · ') || 'يوم متاح';
  }
  function draw() {
    byId('bt-month-label').textContent = month.toLocaleDateString('ar-OM', { month: 'long', year: 'numeric' });
    const grid = byId('bt-month-grid'); grid.replaceChildren();
    ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'].forEach(day => { const label = document.createElement('span'); label.className = 'bt-weekday'; label.textContent = day; grid.append(label); });
    for (let i = 0; i < month.getDay(); i++) { const blank = document.createElement('span'); blank.setAttribute('aria-hidden', 'true'); grid.append(blank); }
    const days = new Date(month.getFullYear(), month.getMonth() + 1, 0).getDate();
    for (let day = 1; day <= days; day++) {
      const date = dateKey(new Date(month.getFullYear(), month.getMonth(), day));
      const daily = tasks.filter(task => task.date === date), occasion = occasions.find(item => item.date === date);
      const button = document.createElement('button'); button.type = 'button'; button.textContent = number(day); button.dataset.date = date;
      const label = dateLabel(date) + (daily.length ? `، ${number(daily.length)} عناصر في جدول اليوم` : '') + (occasion ? `، ${occasion.title} — مناسبة توضيحية` : '');
      button.setAttribute('aria-label', label); button.title = label; button.setAttribute('aria-pressed', String(selected === date));
      if (date === todayKey) button.setAttribute('aria-current', 'date');
      button.classList.toggle('has-tasks', daily.length > 0); button.classList.toggle('has-occasion', Boolean(occasion));
      button.addEventListener('click', () => { selected = date; render(); grid.querySelector(`[data-date="${date}"]`).focus({ preventScroll: true }); });
      grid.append(button);
    }
  }
  function renderOccasion() {
    const box = byId('bt-occasion'); if (!box) return; box.replaceChildren(); const occasion = occasions.find(item => item.date === selected);
    box.hidden = !occasion;
    if (!occasion) return;
    const symbol = document.createElement('span'); symbol.className = 'bt-occasion-symbol'; symbol.setAttribute('aria-hidden', 'true'); symbol.textContent = occasion.symbol;
    const copy = document.createElement('div'), title = document.createElement('strong'), detail = document.createElement('small');
    title.textContent = occasion.title;
    detail.textContent = `مناسبة توضيحية · ${occasion.detail}`;
    copy.append(title, detail); box.append(symbol, copy);
  }
  function updateComposerType() {
    const type = validType(byId('bt-task-type').value), isNote = type === 'note';
    byId('bt-note-field').hidden = !isNote;
    byId('bt-time-field').hidden = isNote;
    byId('bt-task-time').disabled = isNote;
    byId('bt-task-input').placeholder = isNote ? 'عنوان مختصر للملاحظة' : 'ماذا تريد إنجازه؟';
    byId('bt-entry-title').textContent = `${editing ? 'تعديل' : 'إضافة'} ${types[type]}`;
    byId('bt-task-submit').textContent = editing ? 'حفظ التعديل' : (isNote ? 'إضافة الملاحظة' : 'إضافة العمل');
  }
  byId('bt-task-type').addEventListener('change', updateComposerType);
  function openComposer(type = 'task', task = null) {
    editing = task; form.reset(); byId('bt-task-input').setCustomValidity('');
    byId('bt-task-input').value = task?.title || ''; byId('bt-task-type').value = task?.type || type;
    byId('bt-task-date').value = task?.date || selected; byId('bt-task-time').value = task?.time || '';
    byId('bt-note-body').value = task?.body || '';
    updateComposerType(); byId('bt-entry-status').textContent = '';
    composer.showModal(); byId('bt-task-input').focus();
  }
  function renderTasks() {
    const daily = tasks.filter(task => task.date === selected).sort((a, b) => Number(b.type === 'note') - Number(a.type === 'note') || (a.time || '99').localeCompare(b.time || '99'));
    timeline.replaceChildren(); section.querySelector('.bt-agenda').classList.toggle('is-empty', !daily.length);
    if (!daily.length) {
      const empty = document.createElement('div'); empty.className = 'bt-empty-day'; empty.setAttribute('role', 'status');
      empty.innerHTML = '<svg viewBox="0 0 48 48" fill="none" stroke="currentColor" stroke-width="1.25" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="9" y="10" width="30" height="31" rx="5"/><path d="M16 6v8m16-8v8M9 20h30m-22 8h5m-5 6h12"/></svg>';
      const message = document.createElement('p'); message.textContent = 'لا توجد مهام مسجلة لهذا اليوم';
      empty.append(message); timeline.append(empty);
    }
    daily.forEach(task => {
      const row = document.createElement('div'); row.className = 'bt-task-row'; row.dataset.type = task.type;
      const time = document.createElement('time'); time.className = 'bt-task-hour'; time.textContent = task.time || 'مرن'; if (task.time) time.dateTime = `${task.date}T${task.time}`;
      const check = document.createElement('input'); check.type = 'checkbox'; check.checked = task.done; check.setAttribute('aria-label', `إتمام ${task.title}`);
      const copy = document.createElement('button'); copy.type = 'button'; copy.className = 'bt-task-copy'; copy.setAttribute('aria-label', `تعديل ${task.title}`);
      const title = document.createElement('strong'); title.className = 'bt-task-title'; title.append(taskIcon(task.type), document.createTextNode(task.title)); const status = document.createElement('small');
      const updateStatus = () => { status.textContent = `${types[task.type]}${task.demo ? ' · نموذج' : ''}${task.done ? ' · مكتملة' : ''}`; };
      updateStatus(); copy.append(title, status); copy.addEventListener('click', () => openComposer(task.type, task));
      check.addEventListener('change', () => { task.done = check.checked; updateStatus(); persistTasks('تم تحديث حالة العمل.'); counts(); draw(); });
      const remove = document.createElement('button'); remove.type = 'button'; remove.className = 'bt-task-remove'; remove.append(taskIcon('trash')); remove.setAttribute('aria-label', `حذف ${task.title}`); remove.title = `حذف ${task.title}`;
      remove.addEventListener('click', () => { tasks = tasks.filter(item => item !== task); persistTasks('تم حذف العمل.'); renderTasks(); counts(); draw(); byId('bt-task-add-toggle').focus({ preventScroll: true }); });
      if (task.type === 'note') {
        const label = document.createElement('small'); label.className = 'bt-note-label'; label.textContent = 'ملاحظة';
        const body = document.createElement('span'); body.className = 'bt-note-preview'; body.textContent = task.body || '';
        copy.replaceChildren(label, title, body);
        row.append(copy, remove);
      } else row.append(time, check, copy, remove);
      timeline.append(row);
    });
    requestAnimationFrame(updateFade);
  }
  function render() {
    const selectedLabel = byId('bt-selected-label');
    if (selectedLabel) selectedLabel.textContent = dateLabel(selected);
    counts(); renderTasks(); draw(); renderOccasion();
  }
  function renderTodayDate() {
    const now = new Date(), footer = byId('bt-today-date');
    if (!footer) return;
    const weekday = new Intl.DateTimeFormat('ar-OM', { weekday: 'long' }).format(now);
    const hijri = new Intl.DateTimeFormat('ar-SA-u-ca-islamic-umalqura-nu-latn', { day: 'numeric', month: 'long', year: 'numeric' }).format(now);
    const date = document.createElement('time'); date.dateTime = dateKey(now); date.dir = 'ltr';
    date.textContent = `${now.getDate()}-${now.getMonth() + 1}-${now.getFullYear()}`;
    const equivalent = document.createElement('span'); equivalent.textContent = `الموافق ${hijri}`;
    footer.replaceChildren(`اليوم ${weekday} `, date, ' ', equivalent);
  }
  renderTodayDate();
  document.addEventListener('visibilitychange', () => { if (!document.hidden) renderTodayDate(); });
  byId('bt-month-prev').addEventListener('click', () => { month.setMonth(month.getMonth() - 1); draw(); });
  byId('bt-month-next').addEventListener('click', () => { month.setMonth(month.getMonth() + 1); draw(); });
  byId('bt-task-add-toggle').addEventListener('click', () => openComposer());
  section.querySelectorAll('[data-entry-type]').forEach(button => button.addEventListener('click', () => openComposer(button.dataset.entryType)));
  byId('bt-task-cancel').addEventListener('click', () => composer.close()); composer.addEventListener('close', () => { editing = null; });
  byId('bt-task-input').addEventListener('input', event => event.target.setCustomValidity(''));
  form.addEventListener('submit', event => {
    event.preventDefault(); const input = byId('bt-task-input'), title = input.value.trim();
    if (!title) { input.setCustomValidity('اكتب عنوان العمل'); input.reportValidity(); return; }
    const date = byId('bt-task-date').value;
    if (!validDate(date)) { byId('bt-entry-status').textContent = 'اختر تاريخًا صالحًا.'; return; }
    const time = byId('bt-task-time').value, type = validType(byId('bt-task-type').value);
    const data = { title, date, time: type !== 'note' && validTime(time) ? time : '', type, body: byId('bt-note-body').value.trim(), demo: false };
    if (type === 'note') data.done = false;
    if (editing) Object.assign(editing, data); else tasks.push({ ...data, done: false });
    persistTasks(editing ? 'تم حفظ التعديل.' : 'تمت إضافة العمل.'); selected = date; month = new Date(date + 'T12:00:00'); month.setDate(1);
    composer.close(); render(); byId('bt-task-add-toggle').focus({ preventScroll: true });
  });
  render();
})();
