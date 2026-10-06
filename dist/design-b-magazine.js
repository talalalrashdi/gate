(() => {
  const reader = document.getElementById('monthly-reader');
  if (!reader) return;
  const stage = reader.querySelector('.ed-local-stage'), spread = reader.querySelector('.ed-local-spread');
  const message = reader.querySelector('.ed-local-message'), status = reader.querySelector('[data-mag-status]');
  const previous = reader.querySelector('[data-mag-prev]'), next = reader.querySelector('[data-mag-next]');
  const pageInput = reader.querySelector('[data-mag-page]'), range = reader.querySelector('[data-mag-range]');
  const thumbs = reader.querySelector('.ed-local-thumbnails'), thumbButton = reader.querySelector('[data-mag-thumbnails]');
  const zoomButton = reader.querySelector('[data-mag-zoom]'), fullButton = reader.querySelector('[data-mag-fullscreen]');
  const mobile = matchMedia('(max-width:760px)'), reduced = matchMedia('(prefers-reduced-motion:reduce)');
  let pages = [], current = 0, turning = false, turnTimer, touch;
  const manifestURL = new URL(reader.dataset.pages, document.baseURI);
  const number = value => value.toLocaleString('ar-EG');
  const normalize = index => mobile.matches || index === 0 ? index : (index % 2 ? index : index - 1);
  const indexes = () => mobile.matches || current === 0 || current === pages.length - 1 ? [current] : [current, current + 1];
  function imageFor(index, thumbnail = false) {
    const image = document.createElement('img');
    image.src = new URL(pages[index].file, manifestURL).href;
    image.alt = `صفحة ${number(index + 1)} من مجلة وُجهات`;
    image.width = 1500; image.height = Math.round(1500 * pages[index].height / pages[index].width);
    image.loading = thumbnail ? 'lazy' : 'eager'; image.decoding = 'async'; image.draggable = false;
    if (!thumbnail) image.addEventListener('error', () => { message.hidden = false; message.textContent = 'تعذّر تحميل الصفحة. يمكنك فتح ملف PDF من الرابط بجانب المجلة.'; });
    return image;
  }
  function render() {
    const visible = indexes();
    spread.replaceChildren(...visible.map(index => {
      const page = document.createElement('div'); page.className = 'ed-local-page'; page.append(imageFor(index)); return page;
    }));
    spread.classList.toggle('is-single', visible.length === 1);
    status.textContent = `${visible.map(index => number(index + 1)).join('–')} من ${number(pages.length)}`;
    pageInput.value = range.value = String(current + 1);
    previous.disabled = current === 0; next.disabled = visible.at(-1) >= pages.length - 1;
    [...thumbs.children].forEach((button, index) => button.setAttribute('aria-pressed', String(visible.includes(index))));
    stage.scrollTop = stage.scrollLeft = 0;
    message.hidden = true;
  }
  function goTo(index, animate = true) {
    if (!pages.length) return;
    if (turning) { clearTimeout(turnTimer); stage.querySelector('.ed-local-turn')?.remove(); turning = false; }
    index = normalize(Math.max(0, Math.min(pages.length - 1, index)));
    if (index === current) { pageInput.value = range.value = String(current + 1); return; }
    const forward = index > current;
    const clone = animate && !mobile.matches && !reduced.matches && !reader.classList.contains('is-zoomed') ? spread.lastElementChild?.cloneNode(true) : null;
    current = index; render();
    if (clone) {
      turning = true; clone.classList.add('ed-local-turn', forward ? 'is-forward' : 'is-backward'); clone.setAttribute('aria-hidden', 'true'); stage.append(clone);
      const finish = () => { clearTimeout(turnTimer); clone.remove(); turning = false; };
      clone.addEventListener('animationend', finish, {once: true}); turnTimer = setTimeout(finish, 600);
    }
  }
  const advance = () => goTo(indexes().at(-1) + 1);
  const retreat = () => goTo(current - (mobile.matches || current <= 1 ? 1 : 2));
  previous.addEventListener('click', retreat); next.addEventListener('click', advance);
  pageInput.addEventListener('change', () => goTo((Number(pageInput.value) || 1) - 1, false));
  pageInput.addEventListener('keydown', event => { if (event.key === 'Enter') { event.preventDefault(); goTo((Number(pageInput.value) || 1) - 1, false); } });
  range.addEventListener('input', () => goTo(Number(range.value) - 1, false));
  stage.addEventListener('keydown', event => {
    if (event.key === 'ArrowLeft' || event.key === 'ArrowRight') { event.preventDefault(); event.key === 'ArrowLeft' ? advance() : retreat(); }
  });
  stage.addEventListener('touchstart', event => { touch = {x: event.touches[0].clientX, y: event.touches[0].clientY}; }, {passive: true});
  stage.addEventListener('touchend', event => {
    if (!touch || reader.classList.contains('is-zoomed')) return;
    const dx = event.changedTouches[0].clientX - touch.x, dy = event.changedTouches[0].clientY - touch.y; touch = null;
    if (Math.abs(dx) > 55 && Math.abs(dx) > Math.abs(dy) * 1.5) dx > 0 ? advance() : retreat();
  }, {passive: true});
  thumbButton.addEventListener('click', () => {
    if (!pages.length) return;
    if (!thumbs.children.length) pages.forEach((page, index) => {
      const button = document.createElement('button'); button.type = 'button'; button.setAttribute('aria-label', `الانتقال إلى الصفحة ${number(index + 1)}`);
      button.append(imageFor(index, true), document.createTextNode(number(index + 1)));
      button.addEventListener('click', () => { goTo(index, false); thumbs.hidden = true; thumbButton.setAttribute('aria-expanded', 'false'); stage.focus({preventScroll: true}); }); thumbs.append(button);
    });
    thumbs.hidden = !thumbs.hidden; thumbButton.setAttribute('aria-expanded', String(!thumbs.hidden));
    [...thumbs.children].forEach((button, index) => button.setAttribute('aria-pressed', String(indexes().includes(index))));
  });
  zoomButton.addEventListener('click', () => {
    const zoomed = reader.classList.toggle('is-zoomed'); zoomButton.setAttribute('aria-pressed', String(zoomed));
    zoomButton.setAttribute('aria-label', zoomed ? 'تصغير الصفحات' : 'تكبير الصفحات'); zoomButton.textContent = zoomed ? '−' : '＋';
  });
  fullButton.addEventListener('click', async () => {
    try { if (document.fullscreenElement === reader) await document.exitFullscreen(); else await reader.requestFullscreen(); }
    catch { message.hidden = false; message.textContent = 'تعذّر ملء الشاشة في هذا المتصفح. استخدم التكبير أو افتح ملف PDF.'; }
  });
  document.addEventListener('fullscreenchange', () => fullButton.setAttribute('aria-label', document.fullscreenElement === reader ? 'الخروج من ملء الشاشة' : 'ملء الشاشة'));
  mobile.addEventListener('change', () => { if (pages.length) { current = normalize(current); render(); } });
  fetch(manifestURL).then(response => { if (!response.ok) throw new Error('Manifest'); return response.json(); }).then(data => {
    if (!data.pages?.length) throw new Error('Pages'); pages = data.pages;
    pageInput.max = range.max = String(pages.length); pageInput.disabled = range.disabled = false; render();
  }).catch(() => { message.textContent = 'تعذّر تحميل المجلة. يمكنك قراءة ملف PDF من الرابط بجانب القارئ.'; });
})();
