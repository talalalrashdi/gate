(() => {
  // Keep existing buttons and listeners; share only their visual treatment.
  document.querySelectorAll('.portal-alert-controls').forEach(group => {
    const arrows = [...group.querySelectorAll('.portal-workspace-prev, .portal-workspace-next, .portal-alert-prev, .portal-alert-next')];
    if (!arrows.length) return;
    const pill = document.createElement('div');
    pill.className = 'portal-arrow-controls';
    group.insertBefore(pill, arrows[0]);
    arrows.forEach(button => pill.append(button));
  });
  document.querySelectorAll('.portal-personal-controls, .news-paging, .editorial-tech-carousel-controls, .editorial-reader-controls, .editorial-gallery-controls, .personal-month-nav, .portal-arrow-controls').forEach(group => {
    group.classList.add('portal-arrow-controls');
    group.querySelectorAll('button').forEach((button, index) => {
      button.classList.add('portal-arrow-button');
      if (button.hasAttribute('data-agency-news-playback')) return;
      const right = group.classList.contains('portal-personal-controls') ? index === 1 : index === 0;
      button.innerHTML = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="${right ? 'm9 6 6 6-6 6' : 'm15 6-6 6 6 6'}"/></svg>`;
    });
  });
})();
