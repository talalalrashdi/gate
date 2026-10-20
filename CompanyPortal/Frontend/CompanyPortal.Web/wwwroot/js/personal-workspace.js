(() => {
  const section = document.getElementById('systems');
  if (!section) return;
  const read = (key, fallback) => { try { return JSON.parse(localStorage.getItem(key)) ?? fallback; } catch { return fallback; } };
  const save = (key, value) => { try { localStorage.setItem(key, JSON.stringify(value)); return true; } catch { return false; } };
  const byId = id => document.getElementById(id);
  const themeButtons = [...document.querySelectorAll('[data-theme-option]')];
  const themePanels = [...section.querySelectorAll('.portal-theme-panel')];
  const officialFrame = byId('theme-official-frame');
  const alertsSection = byId('portal-alerts-section');
  const alertsHome = alertsSection?.parentElement;
  const alertsNext = alertsSection?.nextSibling;
  const sharedCalendar = section.querySelector('.personal-calendar-main');
  const sharedPlanner = sharedCalendar?.closest('.personal-planner');
  const plannerHome = sharedPlanner?.parentElement;
  const plannerNext = sharedPlanner?.nextSibling;
  const taskAddButton = byId('planner-task-add-toggle');
  const taskAddHome = taskAddButton?.parentElement;
  const sharedComposer = byId('planner-task-composer');
  const composerHome = sharedComposer?.parentElement;
  const composerNext = sharedComposer?.nextSibling;
  const officialCalendar = byId('theme-official-calendar');
  const workCalendar = byId('theme-work-calendar');
  const sharedNews = section.querySelector('.theme-official-news');
  const floatingCalendar = byId('portal-floating-calendar');
  const floatingBody = byId('portal-floating-calendar-body');
  if (floatingCalendar) {
    section.append(floatingCalendar);
    floatingCalendar.showPopover?.();
  }
  const sceneImages = [...document.querySelectorAll('[data-official-image]')];
  const sceneStories = {
    fort: ['منيو جديد، لخيارات أكثر.', 'اكتشف خيارات الفطور والغداء في مطعم الشركة، وخطّط لاستراحتك القادمة.', 'جديد مطعم الشركة', 'استعرض المنيو', [['الفطور', 'ساندويتشات طازجة، فواكه موسمية، وقهوة وشاي.'], ['الغداء', 'أطباق رئيسية متنوعة، سلطات، وخيارات نباتية.'], ['قبل الطلب', 'اسأل فريق المطعم عن مكونات الوجبات ومسببات الحساسية.']]],
    mosque: ['خدمات الموظفين، أقرب إليك.', 'تعرّف على خطوات الوصول إلى الاستمارات والوثائق التي تحتاجها في يومك.', 'توضيح للموظفين', 'اعرف التفاصيل', [['وصول سريع', 'افتح الاستمارات والوثائق من القائمة الرئيسية واختر الخدمة المطلوبة.'], ['قبل إرسال الطلب', 'راجع البيانات والمرفقات اللازمة لضمان اكتمال الطلب.']]],
    desert: ['استراحة قصيرة، ويوم أكثر نشاطًا.', 'خطوات بسيطة تساعدك على ترتيب يومك والمحافظة على نشاطك أثناء العمل.', 'تنبيه يهمك', 'اطّلع على النصائح', [['نظّم يومك', 'رتّب مهامك في تقويم الأعمال وحدّد وقتًا للاستراحة.'], ['جدّد نشاطك', 'تحرّك قليلًا بين فترات العمل واحرص على شرب الماء.']]]
  };
  const sceneIconPaths = {
    fort: 'M7 3c-2 2 2 3 0 5m5-5c-2 2 2 3 0 5m5-5c-2 2 2 3 0 5M4 11h16a8 8 0 0 1-16 0Zm2 0h12M8 18l-2 4m10-4 2 4M7 20h10',
    mosque: 'M8 4H5v17h14V8l-4-4H8Zm6 0v5h5M8 13h8m-8 4h6',
    desert: 'M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9M10 21h4M12 2V1'
  };
  function createSceneIcon(scene) {
    const icon = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    icon.classList.add('theme-official-story-icon');
    icon.setAttribute('viewBox', '0 0 24 24');
    icon.setAttribute('fill', 'none');
    icon.setAttribute('stroke', 'currentColor');
    icon.setAttribute('stroke-width', '1.5');
    icon.setAttribute('stroke-linecap', 'round');
    icon.setAttribute('stroke-linejoin', 'round');
    icon.setAttribute('aria-hidden', 'true');
    const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
    path.setAttribute('d', sceneIconPaths[scene]);
    icon.append(path);
    return icon;
  }
  const announcementDialog = byId('personal-announcement-dialog');
  byId('theme-official-story-action')?.addEventListener('click', () => {
    const story = sceneStories[sceneImages[sceneIndex]?.dataset.officialImage];
    if (!story || !announcementDialog) return;
    byId('personal-announcement-label').textContent = story[2];
    byId('personal-announcement-title').textContent = story[0];
    byId('personal-announcement-description').textContent = story[1];
    const details = byId('personal-announcement-details');
    details.replaceChildren();
    story[4].forEach(([title, description]) => {
      const item = document.createElement('section'), heading = document.createElement('h3'), copy = document.createElement('p');
      heading.textContent = title; copy.textContent = description; item.append(heading, copy); details.append(item);
    });
    announcementDialog.showModal();
    syncOfficialPlayback();
  });
  announcementDialog?.addEventListener('close', syncOfficialPlayback);
  announcementDialog?.addEventListener('click', event => {
    const bounds = announcementDialog.getBoundingClientRect();
    if (event.target === announcementDialog && (event.clientX < bounds.left || event.clientX > bounds.right || event.clientY < bounds.top || event.clientY > bounds.bottom)) announcementDialog.close();
  });
  const backdrop = document.querySelector('.theme-official-backdrop');
  const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
  let sceneIndex = 0, sceneTimer, playbackPaused = reducedMotion.matches;
  const themes = {
    official: { theme: 'official', panel: 'theme-official', label: 'الرسمي', labelledBy: 'personal-calendar-title' },
    work: { theme: 'work', panel: 'theme-work', label: 'العملي', labelledBy: 'theme-work-title' },
    'national-day': { theme: 'national-day', panel: 'theme-national-day', label: 'اليوم الوطني', labelledBy: 'personal-national-day-title' }
  };
  // Only offer themes whose panel and selector still exist on this page.
  Object.keys(themes).forEach(option => {
    if (!byId(themes[option].panel) || !themeButtons.some(button => button.dataset.themeOption === option)) delete themes[option];
  });
  // Visible numbers are presentation only; theme keys and panel IDs describe their purpose.
  const defaultTheme = 'official';
  // Start CompanyPortal with its new default without overwriting the original portal preference.
  const themePreferenceKey = 'companyportal-opening-theme-v2';
  function selectTheme(option, themeName) {
    option = Object.hasOwn(themes, option) && byId(themes[option].panel) ? option : defaultTheme;
    const selected = themes[option];
    section.dataset.theme = selected.theme;
    document.body.dataset.siteTheme = selected.theme;
    themeButtons.forEach(button => {
      const active = button.dataset.themeOption === option;
      button.setAttribute('aria-pressed', String(active));
    });
    themePanels.forEach(panel => { panel.hidden = panel.id !== selected.panel; });
    if (sharedNews) byId(option === 'work' ? 'theme-work' : 'theme-official')?.append(sharedNews);
    if (alertsSection && alertsHome && officialFrame) {
      if (option === 'official') (sharedNews?.querySelector('.personal-news-bottom') || byId('theme-official')).append(alertsSection);
      else alertsHome.insertBefore(alertsSection, alertsNext);
    }
    if (sharedPlanner && plannerHome && officialCalendar) {
      if (option === 'work' && workCalendar) {
        workCalendar.append(sharedPlanner);
        if (sharedComposer) workCalendar.append(sharedComposer);
      } else if (floatingBody) {
        floatingBody.append(sharedPlanner);
        if (sharedComposer) floatingCalendar.append(sharedComposer);
      } else if (option === 'official') {
        officialCalendar.append(sharedPlanner);
        if (sharedComposer) officialCalendar.append(sharedComposer);
      } else {
        plannerHome.insertBefore(sharedPlanner, plannerNext);
        if (sharedComposer && composerHome) composerHome.insertBefore(sharedComposer, composerNext);
      }
    }
    if (taskAddButton && taskAddHome) {
      if (option === 'work') sharedPlanner.querySelector('.personal-planner-head').append(taskAddButton);
      else taskAddHome.append(taskAddButton);
    }
    if (byId('personal-calendar-title')) byId('personal-calendar-title').textContent = option === 'work' ? 'برنامج اليوم' : 'تقويم الأعمال';
    floatingCalendar?.showPopover?.();
    section.setAttribute('aria-labelledby', selected.labelledBy);
    byId('personal-theme-name').textContent = themeName || selected.label;
    save(themePreferenceKey, option);
    syncOfficialPlayback();
    document.dispatchEvent(new CustomEvent('companyportal:theme-change', { detail: { theme: selected.theme } }));
  }
  const themeMenu = byId('portal-theme-options')?.closest('details');
  themeButtons.forEach(button => button.addEventListener('click', () => { selectTheme(button.dataset.themeOption); if (themeMenu) themeMenu.open = false; }));
  // The API identifies themes by ThemeId; this bridge only selects a supported layout.
  document.addEventListener('companyportal:theme-select', event => {
    if (Object.hasOwn(themes, event.detail?.layoutKey))
      selectTheme(event.detail.layoutKey, event.detail.themeName);
  });
  function showOfficialScene(index) {
    sceneIndex = index;
    const scene = sceneImages[index]?.dataset.officialImage;
    sceneImages.forEach(image => image.classList.toggle('is-active', image.dataset.officialImage === scene));
    const story = sceneStories[scene];
    if (story && byId('theme-official-story-title')) {
      byId('theme-official-story-title').replaceChildren(createSceneIcon(scene), document.createTextNode(story[0]));
      byId('theme-official-story-description').textContent = story[1];
      byId('theme-official-story-label').textContent = story[2];
      byId('theme-official-story-action').replaceChildren(document.createTextNode(story[3] + ' ←'));
    }
  }
  function syncOfficialPlayback() {
    clearTimeout(sceneTimer);
    if (!backdrop || !sceneImages.length || backdrop.dataset.managed) return;
    const paused = playbackPaused;
    const photoTheme = document.body.dataset.siteTheme === 'official' || (document.body.dataset.siteTheme === 'work' && document.querySelector('.portal-news-personal'));
    const running = !backdrop.dataset.managed && !paused && !document.hidden && !announcementDialog?.open && photoTheme;
    backdrop.dataset.paused = String(!running);
    if (running) sceneTimer = setTimeout(() => {
      showOfficialScene((sceneIndex + 1) % sceneImages.length);
      syncOfficialPlayback();
    }, 8000);
  }
  document.addEventListener('companyportal:theme-images', () => {
    if (!backdrop?.dataset.managed) showOfficialScene(0);
    syncOfficialPlayback();
  });
  if (backdrop) {
    document.addEventListener('visibilitychange', syncOfficialPlayback);
    reducedMotion.addEventListener('change', () => {
      playbackPaused = reducedMotion.matches;
      syncOfficialPlayback();
    });
  }
  showOfficialScene(0);
  // Preserve selections saved before descriptive theme keys were introduced.
  const legacyThemeNames = { 1: 'business', 2: 'national-day', 3: 'work', 4: 'official', 5: 'news' };
  const savedTheme = read(themePreferenceKey, null);
  const previousTheme = read('companyportal-opening-theme-v1', null);
  const previousNames = { majestic: 'official', formal: 'work', official: 'national-day' };
  selectTheme(savedTheme ?? legacyThemeNames[previousTheme] ?? previousNames[previousTheme] ?? defaultTheme);
  const today = new Date();
  const dateKey = date => `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
  const todayKey = dateKey(today);
  const validDate = value => typeof value === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(value) && dateKey(new Date(value + 'T12:00:00')) === value;
  const validTime = value => typeof value === 'string' && /^([01]\d|2[0-3]):[0-5]\d$/.test(value);
  const dateLabel = value => new Date(value + 'T12:00:00').toLocaleDateString('ar-OM-u-nu-latn', { weekday: 'long', day: 'numeric', month: 'long' });
  const number = value => value.toLocaleString('ar-EG-u-nu-latn');
  const types = { task: 'مهمة', meeting: 'اجتماع', call: 'اتصال', delivery: 'تسليم مشروع', note: 'ملاحظة', event: 'حدث أو مناسبة' };
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
    const icon = document.createElement('span'); icon.className = 'planner-task-icon';
    icon.innerHTML = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${paths[type] || paths.task}</svg>`;
    return icon;
  }
  let selected = todayKey, month = new Date(today.getFullYear(), today.getMonth(), 1);
  let tasks = read('clerio-personal-tasks', []);
  if (!Array.isArray(tasks)) tasks = [];
  tasks = tasks.filter(task => task && typeof task.title === 'string' && typeof task.done === 'boolean').map(task => ({
    ...task, date: validDate(task.date) ? task.date : todayKey,
    time: validTime(task.time) ? task.time : '', type: task.id === 'floating-national-day-demo' && task.type === 'note' ? 'event' : validType(task.type), body: typeof task.body === 'string' ? task.body : ''
  }));
  let notes = read('clerio-business-notes', {});
  if (!notes || Array.isArray(notes) || typeof notes !== 'object') notes = {};
  // Examples are anchored once and explicitly labeled, not official observance dates.
  let demoDate = read('clerio-business-demo-date', null);
  if (!validDate(demoDate)) { demoDate = todayKey; save('clerio-business-demo-date', demoDate); }
  const offsetDate = offset => { const date = new Date(demoDate + 'T12:00:00'); date.setDate(date.getDate() + offset); return dateKey(date); };
  const occasions = [
    ...(floatingCalendar ? [{ date: '2026-10-15', title: 'اليوم الوطني العماني', symbol: '✦', official: true, detail: 'مضافة إلى التقويم بتاريخ 15 أكتوبر 2026.' }] : []),
    ...(floatingCalendar ? [{ date: '2026-10-08', title: 'اليوم الوطني العماني', symbol: '✦', detail: 'حدث تجريبي لليوم، وليس تاريخ المناسبة الرسمي.' }] : []),
    { date: demoDate, title: 'يوم القلب', symbol: '♡', detail: 'تذكير بالعناية بصحتك خلال يوم العمل.' },
    { date: offsetDate(3), title: 'يوم مشاركة المعرفة', symbol: '✦', detail: 'فكرة أو تجربة تستحق المشاركة مع الفريق.' },
    { date: offsetDate(7), title: 'مبادرة تطوعية', symbol: '◇', detail: 'مساحة للمشاركة وصناعة أثر إيجابي.' }
  ];
  if (floatingCalendar && !read('clerio-national-day-2026-10-15-added', false)) {
    if (!tasks.some(task => task.date === '2026-10-15' && task.title === 'اليوم الوطني العماني' && task.type === 'event')) {
      tasks.push({ id: 'national-day-2026-10-15', date: '2026-10-15', title: 'اليوم الوطني العماني', type: 'event', time: '', body: 'مناسبة رسمية', done: false, demo: false });
    }
    if (save('clerio-personal-tasks', tasks)) save('clerio-national-day-2026-10-15-added', true);
  }
  if (floatingCalendar && !read('clerio-floating-calendar-examples-v1', false)) {
    const examples = [
      { id: 'floating-national-day-demo', title: 'اليوم الوطني العماني', type: 'event', time: '', body: 'حدث تجريبي لليوم، وليس تاريخ المناسبة الرسمي.' },
      { id: 'floating-meeting-seven-demo', title: 'اجتماع الساعة 7', type: 'meeting', time: '07:00', body: '' }
    ];
    examples.forEach(example => {
      if (!tasks.some(task => task.id === example.id)) tasks.push({ ...example, date: '2026-10-08', done: false, demo: true });
    });
    if (save('clerio-personal-tasks', tasks)) save('clerio-floating-calendar-examples-v1', true);
  }
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
  const timeline = byId('planner-task-preview'), composer = byId('planner-task-composer'), form = byId('planner-task-form');
  let editing = null;
  const announce = message => { const status = byId('planner-task-status'); if (status) status.textContent = message; };
  function persistTasks(message) {
    announce(save('clerio-personal-tasks', tasks) ? message : 'تعذّر الحفظ في المتصفح؛ التغييرات متاحة حتى إغلاق الصفحة.');
    renderFloatingSummary();
  }
  let floatingExpanded = false;
  let floatingContentCollapsed = false;
  function syncFloatingContent() {
    if (!floatingCalendar) return;
    const expanded = floatingExpanded && !floatingContentCollapsed;
    floatingBody.hidden = !expanded;
    byId('portal-calendar-summary').hidden = floatingExpanded || floatingContentCollapsed;
    floatingCalendar.classList.toggle('is-expanded', expanded);
    const toggle = byId('portal-calendar-toggle');
    toggle.setAttribute('aria-expanded', String(expanded));
    toggle.setAttribute('aria-label', expanded ? 'طي تقويم الأعمال' : 'توسيع تقويم الأعمال');
    toggle.textContent = expanded ? '−' : '＋';
    const contentToggle = byId('portal-calendar-content-toggle');
    contentToggle.setAttribute('aria-expanded', String(!floatingContentCollapsed));
    contentToggle.setAttribute('aria-label', floatingContentCollapsed ? 'عرض محتوى التقويم' : 'طي محتوى التقويم');
    contentToggle.querySelector('path')?.setAttribute('d', floatingContentCollapsed ? 'm6 10 6 6 6-6' : 'm6 14 6-6 6 6');
  }
  function setFloatingExpanded(expanded) {
    floatingExpanded = expanded;
    floatingContentCollapsed = false;
    syncFloatingContent();
  }
  byId('portal-calendar-content-toggle')?.addEventListener('click', () => {
    floatingContentCollapsed = !floatingContentCollapsed;
    syncFloatingContent();
  });
  byId('portal-calendar-toggle')?.addEventListener('click', () => setFloatingExpanded(floatingBody.hidden));
  function renderFloatingSummary() {
    const summary = byId('portal-calendar-summary');
    if (!summary) return;
    summary.replaceChildren();
    const upcoming = tasks.filter(task => !task.done && task.date >= todayKey).sort((a,b) => a.date.localeCompare(b.date) || (a.time || '99').localeCompare(b.time || '99')).slice(0,3);
    const handle = byId('portal-calendar-content-toggle')?.closest('.portal-floating-calendar-handle');
    if (handle) handle.hidden = !upcoming.length;
    if (!upcoming.length) {
      const empty = document.createElement('p'); empty.textContent = 'لا توجد مواعيد أو تذكيرات قادمة.'; summary.append(empty); return;
    }
    upcoming.forEach(task => {
      const button = document.createElement('button'); button.type = 'button'; button.className = 'portal-calendar-summary-item';
      button.dataset.kind = task.type === 'event' ? 'event' : 'work';
      const title = document.createElement('strong'), detail = document.createElement('small');
      title.textContent = task.title;
      detail.textContent = `${dateLabel(task.date)}${task.time ? ' · ' + task.time : ''} · ${types[task.type]}${task.demo ? ' · نموذج' : ''}`;
      button.append(title, detail);
      button.addEventListener('click', () => { selected = task.date; month = new Date(task.date + 'T12:00:00'); month.setDate(1); render(); setFloatingExpanded(true); });
      summary.append(button);
    });
  }
  function updateFade() { timeline.parentElement.classList.toggle('has-more', timeline.scrollHeight - timeline.clientHeight - timeline.scrollTop > 2); }
  timeline.addEventListener('scroll', updateFade, { passive: true });
  new ResizeObserver(updateFade).observe(timeline);
  function counts() {
    const daily = tasks.filter(task => task.date === selected), work = daily.filter(task => task.type !== 'note'), noteCount = daily.length - work.length;
    const summary = [];
    if (work.length) summary.push(`${number(work.filter(task => task.done).length)} / ${number(work.length)} مكتملة`);
    if (noteCount) summary.push(`ملاحظات: ${number(noteCount)}`);
    const counter = byId('personal-day-count');
    if (counter) counter.textContent = summary.join(' · ') || 'يوم متاح';
  }
  function draw() {
    byId('personal-month-label').textContent = month.toLocaleDateString('ar-OM-u-nu-latn', { month: 'long', year: 'numeric' });
    const grid = byId('personal-month-grid'); grid.replaceChildren();
    ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'].forEach(day => { const label = document.createElement('span'); label.className = 'personal-weekday'; label.textContent = day; grid.append(label); });
    for (let i = 0; i < month.getDay(); i++) { const blank = document.createElement('span'); blank.setAttribute('aria-hidden', 'true'); grid.append(blank); }
    const days = new Date(month.getFullYear(), month.getMonth() + 1, 0).getDate();
    for (let day = 1; day <= days; day++) {
      const date = dateKey(new Date(month.getFullYear(), month.getMonth(), day));
      const daily = tasks.filter(task => task.date === date), occasion = occasions.find(item => item.date === date);
      const button = document.createElement('button'); button.type = 'button'; button.textContent = number(day); button.dataset.date = date;
      const label = dateLabel(date) + (daily.length ? `، ${number(daily.length)} عناصر في جدول اليوم` : '') + (occasion ? `، ${occasion.title} — ${occasion.official ? 'مناسبة رسمية' : 'مناسبة توضيحية'}` : '');
      button.setAttribute('aria-label', label); button.title = label; button.setAttribute('aria-pressed', String(selected === date));
      if (date === todayKey) button.setAttribute('aria-current', 'date');
      button.classList.toggle('has-tasks', daily.some(task => task.type !== 'event')); button.classList.toggle('has-occasion', Boolean(occasion) || daily.some(task => task.type === 'event'));
      button.addEventListener('click', () => { selected = date; render(); grid.querySelector(`[data-date="${date}"]`).focus({ preventScroll: true }); });
      grid.append(button);
    }
  }
  function renderOccasion() {
    const box = byId('personal-occasion'); if (!box) return; box.replaceChildren(); const occasion = occasions.find(item => item.date === selected);
    box.hidden = !occasion;
    if (!occasion) return;
    const symbol = document.createElement('span'); symbol.className = 'personal-occasion-symbol'; symbol.setAttribute('aria-hidden', 'true'); symbol.textContent = occasion.symbol;
    const copy = document.createElement('div'), title = document.createElement('strong'), detail = document.createElement('small');
    title.textContent = occasion.title;
    detail.textContent = `${occasion.official ? 'مناسبة رسمية' : 'مناسبة توضيحية'} · ${occasion.detail}`;
    copy.append(title, detail); box.append(symbol, copy);
  }
  function updateComposerType() {
    const type = validType(byId('planner-task-type').value), isNote = type === 'note' || type === 'event';
    byId('personal-note-field').hidden = !isNote;
    byId('personal-time-field').hidden = isNote;
    byId('planner-task-time').disabled = isNote;
    byId('planner-task-input').placeholder = isNote ? 'عنوان مختصر للملاحظة' : 'ماذا تريد إنجازه؟';
    byId('personal-entry-title').textContent = `${editing ? 'تعديل' : 'إضافة'} ${types[type]}`;
    byId('planner-task-submit').textContent = editing ? 'حفظ التعديل' : (isNote ? 'إضافة الملاحظة' : 'إضافة العمل');
  }
  byId('planner-task-type').addEventListener('change', updateComposerType);
  function openComposer(type = 'task', task = null) {
    editing = task; form.reset(); byId('planner-task-input').setCustomValidity('');
    byId('planner-task-input').value = task?.title || ''; byId('planner-task-type').value = task?.type || type;
    byId('planner-task-date').value = task?.date || selected; byId('planner-task-time').value = task?.time || '';
    byId('personal-note-body').value = task?.body || '';
    updateComposerType(); byId('personal-entry-status').textContent = '';
    composer.showModal(); byId('planner-task-input').focus();
  }
  function renderTasks() {
    renderFloatingSummary();
    const daily = tasks.filter(task => task.date === selected).sort((a, b) => Number(b.type === 'note') - Number(a.type === 'note') || (a.time || '99').localeCompare(b.time || '99'));
    timeline.replaceChildren(); section.querySelector('.personal-agenda').classList.toggle('is-empty', !daily.length);
    if (!daily.length) {
      const empty = document.createElement('div'); empty.className = 'personal-empty-day'; empty.setAttribute('role', 'status');
      empty.innerHTML = '<svg viewBox="0 0 48 48" fill="none" stroke="currentColor" stroke-width="1.25" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="9" y="10" width="30" height="31" rx="5"/><path d="M16 6v8m16-8v8M9 20h30m-22 8h5m-5 6h12"/></svg>';
      const message = document.createElement('p'); message.textContent = 'لا توجد مهام مسجلة لهذا اليوم';
      empty.append(message); timeline.append(empty);
    }
    const work = document.body.dataset.siteTheme === 'work';
    daily.forEach(task => {
      const row = document.createElement('div'); row.className = 'planner-task-row'; row.dataset.type = task.type;
      const time = document.createElement('time'); time.className = 'planner-task-hour'; time.textContent = task.time || 'مرن'; if (task.time) time.dateTime = `${task.date}T${task.time}`;
      const check = document.createElement('input'); check.type = 'checkbox'; check.checked = task.done; check.setAttribute('aria-label', `إتمام ${task.title}`);
      const copy = document.createElement('button'); copy.type = 'button'; copy.className = 'planner-task-copy'; copy.setAttribute('aria-label', `تعديل ${task.title}`);
      const title = document.createElement('strong'); title.className = 'planner-task-title'; title.append(taskIcon(task.type), document.createTextNode(task.title)); const status = document.createElement('small');
      const updateStatus = () => { status.textContent = `${types[task.type]}${task.demo ? ' · نموذج' : ''}${task.done ? ' · مكتملة' : ''}`; };
      const toggleOnClick = work && task.type !== 'note' && task.type !== 'event';
      const syncCompletion = () => {
        row.classList.toggle('is-done', Boolean(task.done));
        if (toggleOnClick) {
          copy.setAttribute('aria-pressed', String(Boolean(task.done)));
          copy.setAttribute('aria-label', (task.done ? 'إلغاء إتمام ' : 'إتمام ') + task.title);
        }
        updateStatus();
      };
      syncCompletion(); copy.append(title, status);
      copy.addEventListener('click', () => {
        if (!toggleOnClick) { openComposer(task.type, task); return; }
        task.done = !task.done; syncCompletion(); persistTasks('تم تحديث حالة العمل.'); counts(); draw();
      });
      check.addEventListener('change', () => { task.done = check.checked; updateStatus(); persistTasks('تم تحديث حالة العمل.'); counts(); draw(); });
      const remove = document.createElement('button'); remove.type = 'button'; remove.className = 'planner-task-remove'; remove.append(taskIcon('trash')); remove.setAttribute('aria-label', `حذف ${task.title}`); remove.title = `حذف ${task.title}`;
      remove.addEventListener('click', () => { tasks = tasks.filter(item => item !== task); persistTasks('تم حذف العمل.'); renderTasks(); counts(); draw(); byId('planner-task-add-toggle').focus({ preventScroll: true }); });
      if (task.type === 'note' || task.type === 'event') {
        const label = document.createElement('small'); label.className = 'personal-note-label'; label.textContent = types[task.type];
        const body = document.createElement('span'); body.className = 'personal-note-preview'; body.textContent = task.body || '';
        copy.replaceChildren(label, title, body);
        row.append(copy, remove);
      } else if (work) {
        const actions = document.createElement('div'); actions.className = 'planner-task-actions';
        const edit = document.createElement('button'); edit.type = 'button'; edit.className = 'planner-task-edit'; edit.setAttribute('aria-label', 'تعديل ' + task.title); edit.title = 'تعديل المهمة';
        edit.innerHTML = '<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="m14 5 5 5M4 20l4-1 12-12a3.5 3.5 0 0 0-5-5L3 14l-1 5Z"/></svg>';
        edit.addEventListener('click', () => openComposer(task.type, task));
        actions.append(edit, remove); row.append(time, copy, actions);
      } else row.append(time, check, copy, remove);
      timeline.append(row);
    });
    requestAnimationFrame(updateFade);
  }
  function render() {
    const selectedLabel = byId('personal-selected-label');
    if (selectedLabel) selectedLabel.textContent = dateLabel(selected);
    counts(); renderTasks(); draw(); renderOccasion();
  }
  function renderTodayDate() {
    const now = new Date(), footer = byId('personal-today-date');
    if (!footer) return;
    const weekday = new Intl.DateTimeFormat('ar-OM-u-nu-latn', { weekday: 'long' }).format(now);
    const hijri = new Intl.DateTimeFormat('ar-SA-u-ca-islamic-umalqura-nu-latn', { day: 'numeric', month: 'long', year: 'numeric' }).format(now);
    const date = document.createElement('time'); date.dateTime = dateKey(now); date.dir = 'ltr';
    date.textContent = `${now.getDate()}-${now.getMonth() + 1}-${now.getFullYear()}`;
    const equivalent = document.createElement('span'); equivalent.textContent = `الموافق ${hijri}`;
    footer.replaceChildren(`اليوم ${weekday} `, date, ' ', equivalent);
  }
  renderTodayDate();
  document.addEventListener('visibilitychange', () => { if (!document.hidden) renderTodayDate(); });
  byId('personal-month-prev').addEventListener('click', () => { month.setMonth(month.getMonth() - 1); draw(); });
  byId('personal-month-next').addEventListener('click', () => { month.setMonth(month.getMonth() + 1); draw(); });
  byId('planner-task-add-toggle').addEventListener('click', () => openComposer());
  section.querySelectorAll('[data-entry-type]').forEach(button => button.addEventListener('click', () => openComposer(button.dataset.entryType)));
  byId('planner-task-cancel').addEventListener('click', () => composer.close()); composer.addEventListener('close', () => { editing = null; });
  byId('planner-task-input').addEventListener('input', event => event.target.setCustomValidity(''));
  form.addEventListener('submit', event => {
    event.preventDefault(); const input = byId('planner-task-input'), title = input.value.trim();
    if (!title) { input.setCustomValidity('اكتب عنوان العمل'); input.reportValidity(); return; }
    const date = byId('planner-task-date').value;
    if (!validDate(date)) { byId('personal-entry-status').textContent = 'اختر تاريخًا صالحًا.'; return; }
    const time = byId('planner-task-time').value, type = validType(byId('planner-task-type').value);
    const data = { title, date, time: type !== 'note' && validTime(time) ? time : '', type, body: byId('personal-note-body').value.trim(), demo: false };
    if (type === 'note') data.done = false;
    if (editing) Object.assign(editing, data); else tasks.push({ ...data, done: false });
    persistTasks(editing ? 'تم حفظ التعديل.' : 'تمت إضافة العمل.'); selected = date; month = new Date(date + 'T12:00:00'); month.setDate(1);
    composer.close(); render(); byId('planner-task-add-toggle').focus({ preventScroll: true });
  });
  render();
})();
