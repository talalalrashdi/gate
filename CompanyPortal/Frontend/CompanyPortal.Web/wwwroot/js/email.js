(() => {
  const card = document.querySelector('[data-work-system="email"]');
  const base = document.querySelector('meta[name="companyportal-api-base"]')?.content;
  if (!card || !base) return;
  const list = card.querySelector('.portal-email-list'), badge = card.querySelector('[data-count-source="exchange"]');
  const status = card.querySelector('[data-mail-status]'), open = card.querySelector('[data-mail-open]');
  const endpoint = path => new URL(path, new URL(base.replace(/\/?$/, '/'), location.href)).href;
  const make = (tag, text) => { const node = document.createElement(tag); if (text !== undefined) node.textContent = text; return node; };
  let connection, retry, delay = 5000, leaving = false;
  const unavailable = message => {
    list.replaceChildren(); badge.textContent = '—'; badge.setAttribute('aria-label', 'عدد الرسائل غير المقروءة غير متاح');
    status.textContent = message; open.disabled = true;
  };
  const render = data => {
    if (!Number.isInteger(data.unreadCount) || data.unreadCount < 0 || !Array.isArray(data.items) || data.items.length > 20
      || data.items.some(item => typeof item.itemId !== 'string' || !item.itemId || item.itemId.length > 8000
        || typeof item.subject !== 'string' || typeof item.sender !== 'string' || typeof item.isRead !== 'boolean'
        || !Number.isFinite(Date.parse(item.receivedAt)))) throw new Error('Invalid mailbox snapshot');
    const focused = list.contains(document.activeElement) ? document.activeElement?.dataset.mailId : null;
    const fragment = document.createDocumentFragment();
    data.items.forEach(item => {
      const link = make('a'); link.className = 'portal-email-item'; link.dataset.state = item.isRead ? 'read' : 'unread'; link.dataset.mailId = item.itemId;
      link.href = endpoint('api/mail/open?itemId=' + encodeURIComponent(item.itemId)); link.target = '_blank'; link.rel = 'noopener noreferrer';
      link.setAttribute('aria-label', `${item.subject || '(بدون موضوع)'} — ${item.sender}${item.isRead ? '' : ' — غير مقروءة'} — فتح في Outlook Web`);
      const icon = make('span', '✉'); icon.className = 'portal-email-row-icon'; icon.setAttribute('aria-hidden', 'true');
      const text = make('span'); text.append(make('strong', item.subject || '(بدون موضوع)'), make('small', item.sender));
      const time = make('time'); time.dateTime = item.receivedAt;
      time.textContent = new Intl.DateTimeFormat('ar-OM-u-nu-latn', { hour:'2-digit', minute:'2-digit', timeZone:'Asia/Muscat' }).format(new Date(item.receivedAt));
      time.title = new Intl.DateTimeFormat('ar-OM', { dateStyle:'medium', timeStyle:'short', timeZone:'Asia/Muscat' }).format(new Date(item.receivedAt));
      link.append(icon, text, time); fragment.append(link);
    });
    list.replaceChildren(fragment); badge.textContent = String(data.unreadCount);
    badge.setAttribute('aria-label', `${data.unreadCount} رسائل غير مقروءة في صندوق الوارد`);
    status.textContent = data.items.length ? 'البريد متصل · تحديث مباشر' : 'لا توجد رسائل في صندوق الوارد.';
    open.disabled = false;
    if (focused) [...list.children].find(node => node.dataset.mailId === focused)?.focus({ preventScroll:true });
    card.dispatchEvent(new CustomEvent('workspace:cards-changed', { bubbles:true }));
  };
  const reconnect = () => {
    connection?.close(); connection = null;
    unavailable('اتصال البريد غير متاح حاليًا. جارٍ إعادة الاتصال…');
    if (!leaving && !retry) { retry = setTimeout(() => { retry = null; connect(); }, delay); delay = Math.min(30000, delay * 2); }
  };
  function connect() {
    if (leaving || connection) return;
    connection = new EventSource(endpoint('api/mail/stream'), { withCredentials:true });
    connection.addEventListener('inbox', event => {
      try { render(JSON.parse(event.data)); delay = 5000; } catch { reconnect(); }
    });
    connection.addEventListener('unavailable', reconnect);
    connection.onerror = reconnect;
  }
  open.addEventListener('click', () => window.open(endpoint('api/mail/inbox/open'), '_blank', 'noopener,noreferrer'));
  window.addEventListener('pagehide', () => { leaving = true; clearTimeout(retry); retry = null; connection?.close(); connection = null; unavailable('اتصال البريد متوقف.'); });
  window.addEventListener('pageshow', event => { if (event.persisted) { leaving = false; connect(); } });
  unavailable('جارٍ الاتصال بالبريد…'); connect();
})();
