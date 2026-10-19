(() => {
  const base = document.querySelector('meta[name="companyportal-api-base"]')?.content;
  const themes = document.querySelector('.portal-header .portal-theme-menu');
  if (!base || !themes) return;
  const endpoint = new URL('api/access', new URL(base.replace(/\/?$/, '/'), location.href));
  fetch(endpoint, { credentials: 'include', cache: 'no-store', signal: AbortSignal.timeout(10000) })
    .then(response => response.ok ? response.json() : null)
    .then(access => {
      if (access?.isAdmin !== true) return;
      const link = document.createElement('a');
      link.className = 'portal-theme-trigger portal-admin-link';
      link.setAttribute('aria-label', 'إدارة البوابة'); link.title = 'إدارة البوابة';
      link.href = new URL('admin/cards', document.baseURI).href;
      const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
      for (const [name, value] of Object.entries({ viewBox:'0 0 24 24', width:'20', height:'20', fill:'none', stroke:'currentColor', 'stroke-width':'1.7', 'stroke-linecap':'round', 'stroke-linejoin':'round', 'aria-hidden':'true' })) svg.setAttribute(name, value);
      const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
      path.setAttribute('d', 'M12 3 4 6v5c0 5 4 8 8 10 4-2 8-5 8-10V6l-8-3Z M8.5 12l2.5 2.5 4.5-5');
      svg.append(path); link.append(svg); themes.after(link);
    }).catch(() => { /* Admin access is never inferred from browser storage. */ });
})();
