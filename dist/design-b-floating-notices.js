(() => {
  const notice = document.getElementById('b-floating-notice');
  const source = document.getElementById('b-alerts-section');
  if (!notice || !source) return;
  const cards = [...source.querySelectorAll('.b-alert')];
  const content = notice.querySelector('.b-floating-notice-content');
  const previous = notice.querySelector('.b-floating-notice-prev');
  const next = notice.querySelector('.b-floating-notice-next');
  const tones = { 'قرار جديد': 'decision', 'تنبيه نظام': 'system', 'فرصة تعلّم': 'learning', 'دعوة لقاء': 'meeting', 'تذكير مهم': 'reminder', 'تحديث الموظفين': 'people' };
  let index = 0;
  const active = () => cards.filter(card => !card.hidden);
  function render() {
    const remaining = active();
    index = Math.min(index, Math.max(0, remaining.length - 1));
    notice.hidden = !remaining.length;
    if (!remaining.length) return;
    const card = remaining[index];
    const title = card.querySelector('h3').textContent;
    const type = card.querySelector('.b-alert-badge')?.textContent.trim() || '';
    notice.dataset.tone = tones[type] || 'system';
    content.querySelector('span').textContent = type;
    content.querySelector('strong').textContent = title;
    content.querySelector('small').textContent = card.querySelector('p').textContent;
    content.setAttribute('aria-label', `عرض تفاصيل ${title}`);
    notice.querySelector('.b-floating-notice-position').textContent = `${index + 1} / ${remaining.length}`;
    previous.disabled = index === 0;
    next.disabled = index >= remaining.length - 1;
  }
  previous.addEventListener('click', () => { index--; render(); });
  next.addEventListener('click', () => { index++; render(); });
  content.addEventListener('click', () => active()[index]?.querySelector('.b-alert-open')?.click());
  notice.querySelector('.b-floating-notice-all').addEventListener('click', () => source.querySelector('.bn-all')?.click());
  notice.querySelector('.b-floating-notice-close').addEventListener('click', () => {
    const card = active()[index];
    if (card) card.hidden = true;
    render();
    (notice.hidden ? document.getElementById('b-calendar-toggle') : notice.querySelector('.b-floating-notice-close')).focus({ preventScroll: true });
  });
  const observer = new MutationObserver(render);
  cards.forEach(card => observer.observe(card, { attributes: true, attributeFilter: ['hidden'] }));
  render();
})();
