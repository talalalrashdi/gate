(() => {
  const list = document.querySelector('.bt-majestic-headlines');
  if (!list) return;
  // Selected, dated ONA reports; these are not a live news feed.
  const stories = [
    { title: 'متحف عُمان عبر الزمان يستقبل نحو 940 ألف زائر منذ افتتاحه', date: '2026-02-22', url: 'https://omannews.gov.om/topics/ar/119/show/464026/', image: 'https://alroya.om/thumb/830x506/uploads/images/2025/07/VBTAR.jpeg', imageCredit: 'صورة متحف عُمان عبر الزمان — صحيفة الرؤية' },
    { title: 'جنوب الشرقية: رقمنة 14 خدمة حكومية وإنجاز 5694 معاملة خلال 2025', date: '2026-01-25', url: 'https://omannews.gov.om/topics/ar/122/show/462778/rss.ona' },
    { title: 'إطلاق برنامج «تعزيز» لتمكين الفرق الأهلية الرياضية', date: '2026-01-25', url: 'https://omannews.gov.om/topics/ar/8/show/462804/ona' },
    { title: 'حلقة عمل مجلة نزوى توصي بمرصد ثقافي وتحديث رؤية المجلة', date: '2026-01-21', url: 'https://omannews.gov.om/topics/ar/6/show/462659/' },
    { title: '15 مليون ريال عُماني أثر اقتصادي مباشر لسياحة المؤتمرات والمعارض', date: '2026-01-03', url: 'https://omannews.gov.om/topics/ar/7/show/461916/rss.ona' }
  ];
  const publicationDate = new Intl.DateTimeFormat('ar-OM-u-nu-latn', { day: 'numeric', month: 'long', year: 'numeric', timeZone: 'Asia/Muscat' });
  stories.forEach(story => {
    const item = document.createElement('li'), button = document.createElement('button');
    const title = document.createElement('span'), heading = document.createElement('strong'), credit = document.createElement('small');
    item.classList.toggle('has-photo', Boolean(story.image));
    item.classList.toggle('is-featured', !list.children.length);
    if (story.image) {
      const image = document.createElement('img');
      image.src = story.image; image.alt = ''; image.title = story.imageCredit; image.decoding = 'async';
      image.width = 420; image.height = 220;
      image.addEventListener('error', () => { image.remove(); item.classList.remove('has-photo'); syncWindow(); });
      button.append(image);
    }
    heading.textContent = story.title;
    credit.textContent = `العُمانية · ${publicationDate.format(new Date(`${story.date}T12:00:00+04:00`))}`;
    title.append(heading, credit);
    button.type = 'button'; button.append(title);
    button.addEventListener('click', () => window.open(story.url, '_blank', 'noopener,noreferrer'));
    item.append(button); list.append(item);
  });
  const agencyNews = document.getElementById('ed-agency-news');
  if (agencyNews) stories.forEach(story => {
    const card = document.createElement('article'), copy = document.createElement('div');
    card.className = 'ed-news-card'; copy.className = 'ed-news-card-copy';
    if (story.image) {
      card.classList.add('ed-news-card-featured');
      const visual = document.createElement('div'), image = document.createElement('img'), caption = document.createElement('span');
      visual.className = 'ed-news-card-image'; image.src = story.image; image.alt = 'متحف عُمان عبر الزمان'; image.loading = 'lazy'; image.decoding = 'async';
      caption.textContent = story.imageCredit;
      image.addEventListener('error', () => { visual.remove(); card.classList.remove('ed-news-card-featured'); });
      visual.append(image, caption); card.append(visual);
    }
    const header = document.createElement('header'), source = document.createElement('span'), heading = document.createElement('h3');
    source.textContent = 'وكالة الأنباء العُمانية'; header.append(source); heading.textContent = story.title;
    const footer = document.createElement('footer'), date = document.createElement('time'), button = document.createElement('button');
    date.dateTime = story.date; date.textContent = publicationDate.format(new Date(`${story.date}T12:00:00+04:00`));
    button.type = 'button'; button.textContent = 'اقرأ الخبر ↗'; button.addEventListener('click', () => window.open(story.url, '_blank', 'noopener,noreferrer'));
    footer.append(date, button); copy.append(header, heading, footer); card.append(copy); agencyNews.append(card);
  });
  const dates = ['bt-majestic-today', 'ed-current-date'].map(id => document.getElementById(id)).filter(Boolean);
  if (dates.length) {
    const options = { day: 'numeric', month: 'long', year: 'numeric', timeZone: 'Asia/Muscat' };
    const gregorian = new Intl.DateTimeFormat('ar-OM-u-ca-gregory-nu-latn', { ...options, weekday: 'long' });
    const hijri = new Intl.DateTimeFormat('ar-OM-u-ca-islamic-nu-latn', options);
    const updateDate = () => {
      const now = new Date();
      dates.forEach(today => {
        today.firstElementChild.textContent = `اليوم ${gregorian.format(now)}`;
        today.lastElementChild.textContent = `الموافق ${hijri.format(now)}`;
      });
    };
    updateDate();
    setInterval(updateDate, 60000);
    document.addEventListener('visibilitychange', updateDate);
  }
  const panel = list.closest('.bt-majestic-news');
  const controls = [...panel.querySelectorAll('.bt-majestic-news-controls button')];
  const motion = matchMedia('(prefers-reduced-motion: reduce)');
  let timer, rotating = false, visible = false, hovered = false, focused = false;
  function syncWindow() {
    [...list.children].forEach((item, index) => { item.inert = index >= 3; });
  }
  function setRotating(value) {
    rotating = value;
    list.classList.toggle('is-rotating', value);
    controls.forEach(button => { button.disabled = value; });
  }
  function rotate(direction = 1) {
    if (rotating) return;
    clearTimeout(timer);
    const first = list.firstElementChild;
    const incoming = direction > 0 ? list.children[1] : list.lastElementChild;
    setRotating(true);
    if (direction > 0) {
      first.classList.add('is-leaving');
      incoming.classList.add('is-featured');
    } else {
      incoming.classList.add('is-featured', 'is-arriving', 'is-resetting');
      list.prepend(incoming);
      first.classList.remove('is-featured');
      // Commit the collapsed start before smoothly revealing the previous news.
      void incoming.offsetHeight;
      incoming.classList.remove('is-resetting');
      requestAnimationFrame(() => incoming.classList.remove('is-arriving'));
    }
    syncWindow();
    setTimeout(() => {
      if (direction > 0) {
        first.classList.add('is-resetting');
        list.append(first);
        first.classList.remove('is-featured', 'is-leaving');
      }
      requestAnimationFrame(() => requestAnimationFrame(() => {
        first.classList.remove('is-resetting');
        setRotating(false);
        syncWindow();
        schedule();
      }));
    }, motion.matches ? 0 : 1200);
  }
  syncWindow();
  panel.querySelector('[data-news-prev]').addEventListener('click', () => rotate(-1));
  panel.querySelector('[data-news-next]').addEventListener('click', () => rotate(1));
  function schedule() {
    clearTimeout(timer);
    if (rotating || !visible || hovered || focused || motion.matches || document.hidden || !['majestic', 'formal'].includes(document.body.dataset.siteTheme) || list.children.length < 2) return;
    timer = setTimeout(() => rotate(1), 6500);
  }
  new IntersectionObserver(entries => { visible = entries[0].isIntersecting; schedule(); }).observe(panel);
  panel.addEventListener('pointerenter', () => { hovered = true; schedule(); });
  panel.addEventListener('pointerleave', () => { hovered = false; schedule(); });
  panel.addEventListener('focusin', () => { focused = true; schedule(); });
  panel.addEventListener('focusout', event => { focused = panel.contains(event.relatedTarget); schedule(); });
  motion.addEventListener('change', schedule);
  document.addEventListener('visibilitychange', schedule);
  document.addEventListener('clerio:theme-change', schedule);
})();
