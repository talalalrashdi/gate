(() => {
  const root = document.querySelector('.b-personal-carousel');
  if (!root) return;
  // Keep existing buttons and listeners; share only their visual treatment.
  document.querySelectorAll('.b-alert-controls').forEach(group => {
    const arrows = [...group.querySelectorAll('.b-workspace-prev, .b-workspace-next, .b-alert-prev, .b-alert-next')];
    if (!arrows.length) return;
    const pill = document.createElement('div');
    pill.className = 'b-arrow-controls';
    group.insertBefore(pill, arrows[0]);
    arrows.forEach(button => pill.append(button));
  });
  document.querySelectorAll('.b-personal-controls, .bn-paging, .ed-tech-carousel-controls, .ed-reader-controls, .ed-gallery-controls, .bt-month-nav, .b-arrow-controls').forEach(group => {
    group.classList.add('b-arrow-controls');
    group.querySelectorAll('button').forEach((button, index) => {
      button.classList.add('b-arrow-button');
      const right = group.classList.contains('b-personal-controls') ? index === 1 : index === 0;
      button.innerHTML = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="${right ? 'm9 6 6 6-6 6' : 'm15 6-6 6 6 6'}"/></svg>`;
    });
  });
  const track = root.querySelector('.b-personal-slides');
  const cards = [...track.children];
  const previous = root.querySelector('[data-personal-prev]');
  const next = root.querySelector('[data-personal-next]');
  const status = root.querySelector('.b-personal-status');
  const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)');
  let active = 0, frame = 0;
  const position = index => cards[index].offsetLeft - cards[0].offsetLeft;
  function sync() {
    active = cards.reduce((closest, card, index) =>
      Math.abs(position(index) - track.scrollLeft) < Math.abs(position(closest) - track.scrollLeft) ? index : closest, 0);
    previous.disabled = active === 0;
    next.disabled = active === cards.length - 1;
    cards.forEach((card, index) => { card.inert = index !== active; });
    status.textContent = `البطاقة ${(active + 1).toLocaleString('ar-EG')} من ${cards.length.toLocaleString('ar-EG')}`;
  }
  function move(delta) {
    const index = Math.max(0, Math.min(cards.length - 1, active + delta));
    track.scrollTo({ left: position(index), behavior: reducedMotion.matches ? 'instant' : 'smooth' });
  }
  previous.addEventListener('click', () => move(-1));
  next.addEventListener('click', () => move(1));
  track.addEventListener('keydown', event => {
    if (event.target !== track || !['ArrowLeft', 'ArrowRight'].includes(event.key)) return;
    event.preventDefault(); move(event.key === 'ArrowRight' ? 1 : -1);
  });
  track.addEventListener('scroll', () => {
    cancelAnimationFrame(frame); frame = requestAnimationFrame(sync);
  }, { passive: true });
  new ResizeObserver(() => {
    track.scrollTo({ left: position(active), behavior: 'instant' }); sync();
  }).observe(track);
  sync();
})();
