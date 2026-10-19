(() => {
  const base = document.querySelector('meta[name="companyportal-api-base"]')?.content;
  const toolbar = document.querySelector('.portal-workspace-actions');
  if (!base || !toolbar) return;
  const endpoint = new URL('api/access', new URL(base.replace(/\/?$/, '/'), location.href));
  fetch(endpoint, { credentials: 'include', cache: 'no-store', signal: AbortSignal.timeout(10000) })
    .then(response => response.ok ? response.json() : null)
    .then(access => {
      if (access?.isAdmin !== true) return;
      const link = document.createElement('a'); link.textContent = 'إدارة البطاقات';
      link.href = new URL('admin/cards', document.baseURI).href; toolbar.prepend(link);
    }).catch(() => { /* Admin access is never inferred from browser storage. */ });
})();
