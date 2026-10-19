(() => {
  const base = document.querySelector('meta[name="companyportal-api-base"]')?.content;
  const root = document.getElementById('admin-cards'), status = document.getElementById('admin-status');
  if (!base || !root || !status) return;
  const endpoint = path => new URL(path, new URL(base.replace(/\/?$/, '/'), location.href));
  const request = (path, options = {}) => fetch(endpoint(path), {
    credentials: 'include', cache: 'no-store', signal: AbortSignal.timeout(10000), ...options
  });
  const unavailable = response => response.status === 403 ? 'ليس لديك صلاحية إدارة البوابة.'
    : response.status === 400 ? 'تحقق من الاسم والموضع. قد تشغل بطاقة ثابتة هذا الموضع.'
    : 'تعذر الاتصال بخدمة الإدارة. حاول مجددًا.';
  let busy = false;
  const render = cards => {
    root.replaceChildren();
    cards.forEach(card => {
      const form = document.createElement('form'); form.className = 'admin-card';
      const field = (caption, type, value) => {
        const label = document.createElement('label'); label.textContent = caption;
        const input = document.createElement('input'); input.type = type;
        if (type === 'checkbox') { input.checked = value; label.className = 'admin-fixed'; }
        else { input.value = value; input.required = true; }
        label.append(input); form.append(label); return input;
      };
      const name = field('اسم البطاقة', 'text', card.cardName); name.maxLength = 200;
      const order = field('الموضع', 'number', card.displayOrder); order.min = 1; order.max = cards.length; order.step = 1;
      const fixed = field('ثابتة في هذا الموضع', 'checkbox', card.isFixed);
      const save = document.createElement('button'); save.type = 'submit'; save.textContent = 'حفظ'; form.append(save);
      form.addEventListener('submit', async event => {
        event.preventDefault(); if (busy) return;
        if (!name.value.trim()) { name.focus(); status.textContent = 'أدخل اسم البطاقة.'; return; }
        busy = true; root.querySelectorAll('button,input').forEach(el => { el.disabled = true; });
        status.textContent = 'جارٍ الحفظ…';
        try {
          const response = await request('api/admin/cards/' + card.cardId, {
            method: 'PUT', headers: { 'Content-Type': 'application/json', 'X-CompanyPortal-Request': 'admin-cards' },
            body: JSON.stringify({ cardName: name.value.trim(), displayOrder: Number(order.value), isFixed: fixed.checked })
          });
          if (!response.ok) {
            if (response.status === 403) root.replaceChildren();
            status.textContent = unavailable(response); return;
          }
          // Reload authoritative values, including timestamps and current permissions.
          await load('تم حفظ إعدادات البطاقة. تظهر التغييرات في البوابة عند إعادة تحميلها.');
        } catch { status.textContent = 'تعذر تأكيد الحفظ. أعد تحميل الصفحة للتحقق قبل المحاولة مجددًا.'; }
        finally { busy = false; root.querySelectorAll('button,input').forEach(el => { el.disabled = false; }); }
      });
      root.append(form);
    });
  };
  async function load(message) {
    const response = await request('api/admin/cards');
    if (!response.ok) { root.replaceChildren(); status.textContent = unavailable(response); return; }
    render(await response.json()); status.textContent = message;
  }
  load('يمكنك تعديل البطاقات الأساسية.').catch(() => { status.textContent = 'خدمة الإدارة غير متاحة حاليًا.'; });
})();
