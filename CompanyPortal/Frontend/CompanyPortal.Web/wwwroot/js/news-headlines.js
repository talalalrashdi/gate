(() => {
  const headlines = document.querySelector('.theme-official-headlines');
  const board = document.getElementById('editorial-agency-news');
  const base = document.querySelector('meta[name="companyportal-api-base"]')?.content;
  const dates = ['theme-official-today', 'editorial-current-date'].map(id => document.getElementById(id)).filter(Boolean);
  const dateOptions = { day: 'numeric', month: 'long', year: 'numeric', timeZone: 'Asia/Muscat' };
  const gregorian = new Intl.DateTimeFormat('ar-OM-u-ca-gregory-nu-latn', { ...dateOptions, weekday: 'long' });
  const hijri = new Intl.DateTimeFormat('ar-OM-u-ca-islamic-nu-latn', dateOptions);
  const updateDate = () => dates.forEach(node => {
    node.firstElementChild.textContent = `اليوم ${gregorian.format(new Date())}`;
    node.lastElementChild.textContent = `الموافق ${hijri.format(new Date())}`;
  });
  updateDate(); setInterval(updateDate, 60000); document.addEventListener('visibilitychange', updateDate);
  if (!headlines || !board || !base) return;
  const endpoint = path => new URL(path, new URL(base.replace(/\/?$/, '/'), location.href)).href;
  const make = (tag, className, text) => {
    const node = document.createElement(tag); if (className) node.className = className;
    if (text !== undefined) node.textContent = text; return node;
  };
  const title = (story, className) => {
    const node = make(story.hasPdf ? 'a' : 'b', className, story.subject);
    if (story.hasPdf) {
      node.href = endpoint(`api/news/${story.newsId}/pdf`); node.target = '_blank'; node.rel = 'noopener noreferrer';
      node.setAttribute('aria-label', story.subject + ' — فتح PDF في علامة تبويب جديدة');
    }
    return node;
  };
  const newsDate = story => {
    const node = make('time');
    // Preserve the calendar day of a SQL datetime without inventing its timezone.
    if (story.publishedAt) {
      const day = story.publishedAt.slice(0, 10); node.dateTime = day;
      const parsed = new Date(day + 'T12:00:00+04:00');
      if (!Number.isNaN(parsed.valueOf())) node.textContent = new Intl.DateTimeFormat('ar-OM-u-nu-latn', dateOptions).format(parsed);
    }
    return node;
  };
  const picture = (story, className) => {
    if (!story.hasPicture) return null;
    const image = make('img', className); image.src = endpoint(`api/news/${story.newsId}/picture`);
    image.alt = ''; image.loading = 'lazy'; image.decoding = 'async';
    image.addEventListener('error', () => {
      image.closest('.editorial-news-list-story')?.classList.add('news-without-picture');
      image.closest('.has-photo')?.classList.remove('has-photo');
      image.closest('.editorial-news-card-image')?.remove(); image.remove();
    });
    return image;
  };
  const status = make('p', 'news-status', 'جارٍ تحميل الأخبار…');
  status.setAttribute('role', 'status'); status.setAttribute('aria-live', 'polite'); board.before(status);
  const feature = make('div', 'editorial-news-feature');
  const selected = make('article', 'editorial-news-feature-story'); selected.id = 'editorial-news-selected'; selected.setAttribute('aria-live','polite'); selected.setAttribute('aria-atomic','true'); feature.append(selected);
  const stream = make('div', 'editorial-news-stream'), header = make('header'); header.append(make('h4', null, 'أخبار اليوم'));
  const controls = make('div', 'editorial-news-list-controls'), arrows = make('div', 'portal-arrow-controls');
  const previous = make('button', 'portal-arrow-button', '→'), next = make('button', 'portal-arrow-button', '←');
  previous.type = next.type = 'button'; previous.setAttribute('aria-label', 'صفحة الأخبار السابقة'); next.setAttribute('aria-label', 'عرض المزيد من أخبار اليوم');
  const pageStatus = make('output', 'editorial-news-page-status'); pageStatus.setAttribute('aria-live', 'polite');
  arrows.append(previous, next); controls.append(pageStatus, arrows); header.append(controls);
  const newsList = make('ol', 'editorial-news-list'); newsList.id = 'editorial-news-paged-list'; stream.append(header, newsList); board.replaceChildren(feature, stream);
  let page = 1, total = 0, loading = false;
  let headlineItems=[],firstPageItems=[],currentPageItems=[],simulatedItems=[],carouselRefresh,realStatus='جارٍ تحميل الأخبار…';
  const simulationEnabled=!!document.getElementById('portal-simulation');
  const pageSize = 8;
  const showStory = story => {
    selected.dataset.newsId=String(story.newsId);
    [...newsList.children].forEach(item=>{const button=item.querySelector('.news-story-selector'),active=button.dataset.newsId===String(story.newsId);item.classList.toggle('is-selected',active);button.setAttribute('aria-pressed',String(active));});
    selected.classList.toggle('is-breaking', story.isImportant); selected.replaceChildren();
    const image = picture(story);
    if (image) { const visual = make('div', 'editorial-news-card-image'); visual.append(image); selected.append(visual); }
    const copy = make('div', 'editorial-news-item-copy'), heading = make('h3'), label = make('header');
    if (story.isImportant) label.append(make('span', 'editorial-news-breaking-badge', 'خبر عاجل'));
    heading.append(title(story)); const footer = make('footer'); footer.append(newsDate(story));
    if (story.attachmentConflict) footer.append(make('small', null, 'مرفق الخبر غير متاح حاليًا.'));
    copy.append(label, heading, footer); selected.append(copy);
  };
  const renderPage = items => {
    newsList.replaceChildren(); feature.hidden = !items.length;
    items.forEach(story => {
      const item = make('li'), article = make('article', 'editorial-news-list-story'), copy = make('div', 'editorial-news-item-copy');
      item.classList.toggle('is-breaking', story.isImportant);
      const image = picture(story, 'editorial-news-thumbnail'); if (image) article.append(image); else article.classList.add('news-without-picture');
      const label = make('header'); if (story.isImportant) label.append(make('span', 'editorial-news-breaking-badge', 'خبر عاجل'));
      const heading = make('h3'); heading.append(make('span','editorial-news-select',story.subject));
      const footer = make('footer'); footer.append(newsDate(story));
      const select = make('button', 'news-story-selector'); select.type = 'button'; select.dataset.newsId=String(story.newsId);
      select.setAttribute('aria-label', 'عرض الخبر: ' + story.subject); select.setAttribute('aria-controls', selected.id); select.setAttribute('aria-pressed','false');
      select.addEventListener('click', () => { showStory(story); if (matchMedia('(max-width:760px)').matches) feature.scrollIntoView({ block:'start', behavior:'instant' }); });
      copy.append(label, heading, footer); article.append(copy); item.append(article,select); newsList.append(item);
    });
    if(items.length)showStory(items[0]);else{selected.replaceChildren();delete selected.dataset.newsId;}
  };
  const headlinePanel = headlines.closest('.theme-official-news');
  const headlineControlGroup=headlinePanel.querySelector('.theme-official-news-controls');
  const headlineControls = [...headlineControlGroup.querySelectorAll('button')];
  headlineControlGroup.hidden=true;
  headlineControls.forEach(button => { button.disabled = true; });
  function renderHeadlines(items) {
    headlines.replaceChildren();headlineControlGroup.hidden=!items.length;
    items.forEach((story, index) => {
      const item = make('li'), surface = make('div', 'news-headline-surface'), text = make('span'), heading = make('strong');
      item.classList.toggle('is-breaking', story.isImportant); item.classList.toggle('is-featured', index === 0);
      const image = picture(story); if (image) { item.classList.add('has-photo'); surface.append(image); }
      heading.append(title(story)); const credit = make('small');
      if (story.isImportant) credit.append('خبر عاجل · '); credit.append(newsDate(story));
      text.append(heading, credit); surface.append(text); item.append(surface); headlines.append(item);
    });
    if (items.length) startHeadlineCarousel();
    if(!items.length){headlineControls.forEach(button=>button.disabled=true);carouselRefresh?.();}
  }
  async function load(targetPage) {
    if (loading) return; loading = true; previous.disabled = next.disabled = true;
    status.textContent = 'جارٍ تحميل الأخبار…'; board.setAttribute('aria-busy', 'true');
    try {
      const includeHeadlines=!headlines.dataset.loaded;
      const response = await fetch(endpoint(`api/news?page=${targetPage}&pageSize=${pageSize}${includeHeadlines?'&includeHeadlines=true':''}`), { credentials:'include', cache:'no-store', signal:AbortSignal.timeout(15000) });
      if (!response.ok) throw new Error('News unavailable');
      const result = await response.json();
      if (!Array.isArray(result.items) || !Number.isInteger(result.totalCount) || result.totalCount < 0) throw new Error('Invalid news response');
      page = targetPage; total = result.totalCount;currentPageItems=result.items;if(page===1)firstPageItems=result.items;renderPage(page===1?[...simulatedItems,...result.items]:result.items);
      if (includeHeadlines) { if(!Array.isArray(result.headlines))throw new Error('Invalid headline response');headlineItems=result.headlines;renderHeadlines([...simulatedItems,...headlineItems].slice(0,5));headlines.dataset.loaded='true'; }
      status.textContent = total ? '' : 'لا توجد أخبار اليوم.';
      pageStatus.textContent = total ? `${page} / ${Math.ceil(total / pageSize)}` : '0 / 0';
    } catch {
      renderPage([]); pageStatus.textContent = ''; status.replaceChildren(document.createTextNode('تعذر تحميل الأخبار. '));
      const retry = make('button', 'news-preview', 'إعادة المحاولة'); retry.type = 'button'; retry.onclick = () => load(targetPage); status.append(retry);
      if (!headlines.dataset.loaded) headlines.replaceChildren(make('li', 'news-empty', 'الأخبار غير متاحة حاليًا.'));
    } finally {
      realStatus=status.textContent;loading = false; board.setAttribute('aria-busy', 'false'); previous.disabled = page <= 1; next.disabled = page * pageSize >= total;
    }
  }
  previous.onclick = () => load(page - 1); next.onclick = () => load(page + 1);
  load(1);
  if(simulationEnabled)document.addEventListener('portal:simulate',event=>{
    const kind=event.detail?.kind;if(!['news','breaking','reset'].includes(kind))return;
    if(kind==='reset')simulatedItems=[];else{simulatedItems.unshift({newsId:'simulation-'+event.detail.id,subject:event.detail.title,publishedAt:new Date().toISOString(),isImportant:kind==='breaking',hasPdf:false,hasPicture:false,isSimulation:true});simulatedItems=simulatedItems.slice(0,20);}
    page=1;currentPageItems=firstPageItems;renderPage([...simulatedItems,...currentPageItems]);renderHeadlines([...simulatedItems,...headlineItems].slice(0,5));
    previous.disabled=true;next.disabled=pageSize>=total;status.textContent=simulatedItems.length?'محاكاة محلية — الأخبار الحقيقية محفوظة دون تعديل.':realStatus;pageStatus.textContent='1 / '+Math.max(1,Math.ceil(total/pageSize));
  });
  function startHeadlineCarousel() {
    if(carouselRefresh){carouselRefresh();return;}
    const list = headlines;
    const panel = list.closest('.theme-official-news');
    const controls = [...panel.querySelectorAll('.theme-official-news-controls button')];
    const motion = matchMedia('(prefers-reduced-motion: reduce)');
    let timer, rotating = false, visible = false, hovered = false, focused = false;
    function syncWindow() {
      [...list.children].forEach((item, index) => { item.inert = index >= 3; });
    }
    function setRotating(value) {
      rotating = value;
      list.classList.toggle('is-rotating', value);
      controls.forEach(button => { button.disabled = value || list.children.length < 2; });
    }
    function rotate(direction = 1) {
      if (rotating || list.children.length < 2) return;
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
        if(first.parentElement!==list){setRotating(false);syncWindow();schedule();return;}
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
    setRotating(false);
    panel.querySelector('[data-news-prev]').addEventListener('click', () => rotate(-1));
    panel.querySelector('[data-news-next]').addEventListener('click', () => rotate(1));
    function schedule() {
      clearTimeout(timer);
      if (rotating || !visible || hovered || focused || motion.matches || document.hidden || !['official', 'work'].includes(document.body.dataset.siteTheme) || list.children.length < 2) return;
      timer = setTimeout(() => rotate(1), 6500);
    }
    new IntersectionObserver(entries => { visible = entries[0].isIntersecting; schedule(); }).observe(panel);
    panel.addEventListener('pointerenter', () => { hovered = true; schedule(); });
    panel.addEventListener('pointerleave', () => { hovered = false; schedule(); });
    panel.addEventListener('focusin', () => { focused = true; schedule(); });
    panel.addEventListener('focusout', event => { focused = panel.contains(event.relatedTarget); schedule(); });
    motion.addEventListener('change', schedule);
    document.addEventListener('visibilitychange', schedule);
    document.addEventListener('companyportal:theme-change', schedule);
    carouselRefresh=()=>{clearTimeout(timer);setRotating(false);syncWindow();schedule();};
  }
})();
