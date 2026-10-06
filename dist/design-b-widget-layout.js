(() => {
  const grid = document.querySelector('.b-dashboard #workspace-cards');
  if (!grid) return;
  const pages = new WeakMap();
  let frame = 0;
  function prepare(list) {
    if (pages.has(list)) return pages.get(list);
    list.id ||= 'widget-list-' + crypto.randomUUID();
    const nav = document.createElement('nav');
    nav.className = 'b-widget-pages';
    nav.setAttribute('aria-label', 'صفحات ' + (list.closest('.b-work-card')?.querySelector('h2')?.textContent || 'القائمة'));
    const card = list.closest('.b-work-card');
    const row = card.querySelector(':scope > .b-widget-bottom');
    row.prepend(nav);
    const state = { nav, page: 0, signature: '' };
    pages.set(list, state);
    nav.addEventListener('click', event => {
      const button = event.target.closest('[data-widget-page]');
      if (!button) return;
      state.page = Number(button.dataset.widgetPage);
      update();
      list.scrollTop = 0;
    });
    return state;
  }
  function update() {
    grid.querySelectorAll('.b-work-card').forEach(card => {
      const heading = card.querySelector('.b-work-heading');
      const footer = card.querySelector(':scope > .b-work-footer');
      const open = footer?.querySelector('button');
      if (heading && open) {
        open.classList.add('b-card-open');
        heading.append(open);
        if (!footer.textContent.trim()) footer.remove();
      }
      const actions = card.querySelector('.b-workspace-card-actions');
      if (!actions) return;
      let row = card.querySelector(':scope > .b-widget-bottom');
      if (!row) {
        row = document.createElement('div');
        row.className = 'b-widget-bottom';
        card.append(row);
      }
      if (actions.parentElement !== row) row.append(actions);
    });
    grid.querySelectorAll('[data-widget-preview]').forEach(list => {
      const state = prepare(list);
      const items = [...list.children].filter(item => !item.hidden);
      const signature = items.map(item => [...list.children].indexOf(item)).join(',');
      if (state.signature !== signature) { state.page = 0; state.signature = signature; }
      const size = Number(list.dataset.pageSize) || 3;
      const count = Math.ceil(items.length / size);
      state.page = Math.min(state.page, Math.max(0, count - 1));
      [...list.children].forEach(item => {
        const index = items.indexOf(item);
        item.toggleAttribute('data-page-hidden', index < 0 || Math.floor(index / size) !== state.page);
      });
      const focusedPage = state.nav.contains(document.activeElement) ? Number(document.activeElement.dataset.widgetPage) : null;
      if (state.nav.children.length !== count) {
        state.nav.replaceChildren();
        for (let page = 0; page < count; page++) {
          const button = document.createElement('button');
          button.type = 'button';
          button.dataset.widgetPage = String(page);
          button.textContent = String(page + 1);
          button.setAttribute('aria-label', 'الصفحة ' + (page + 1));
          button.setAttribute('aria-controls', list.id);
          state.nav.append(button);
        }
        if (focusedPage !== null) state.nav.children[Math.min(focusedPage, count - 1)]?.focus();
      }
      if (state.nav.hidden !== (count <= 1)) state.nav.hidden = count <= 1;
      [...state.nav.children].forEach((button, index) => {
        if (index === state.page) button.setAttribute('aria-current', 'page');
        else button.removeAttribute('aria-current');
      });
      list.style.minHeight = Math.min(340, Math.max(parseFloat(list.style.minHeight) || 0, list.getBoundingClientRect().height)) + 'px';
    });
  }
  function schedule() { cancelAnimationFrame(frame); frame = requestAnimationFrame(update); }
  new MutationObserver(schedule).observe(grid, { childList: true, subtree: true, attributes: true, attributeFilter: ['hidden'] });
  window.addEventListener('resize', () => {
    grid.querySelectorAll('[data-widget-preview]').forEach(list => { list.style.minHeight = ''; });
    schedule();
  });
  grid.addEventListener('workspace:cards-changed', schedule);
  document.addEventListener('sc:reveal', event => {
    const list = event.detail?.target?.closest('[data-widget-preview]');
    if (!list || !grid.contains(list)) return;
    const state = prepare(list);
    const items = [...list.children].filter(item => !item.hidden);
    const item = items.find(item => item.contains(event.detail.target));
    state.page = Math.max(0, Math.floor(items.indexOf(item) / (Number(list.dataset.pageSize) || 3)));
    update();
  });
  update();
})();
