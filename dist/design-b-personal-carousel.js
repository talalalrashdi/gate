(() => {
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
      if (button.hasAttribute('data-agency-news-playback')) return;
      const right = group.classList.contains('b-personal-controls') ? index === 1 : index === 0;
      button.innerHTML = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="${right ? 'm9 6 6 6-6 6' : 'm15 6-6 6 6 6'}"/></svg>`;
    });
  });
})();
