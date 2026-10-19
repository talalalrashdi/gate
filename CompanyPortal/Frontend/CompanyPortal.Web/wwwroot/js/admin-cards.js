(() => {
  const base = document.querySelector('meta[name="companyportal-api-base"]')?.content;
  const root = document.getElementById('admin-cards'), status = document.getElementById('admin-status');
  if (!base || !root || !status) return;
  const workspace = document.getElementById('admin-workspace'), access = document.getElementById('admin-access-message'), retry = document.getElementById('admin-retry');
  const endpoint = path => new URL(path, new URL(base.replace(/\/?$/, '/'), location.href));
  const request = (path, options = {}) => fetch(endpoint(path), { credentials:'include', cache:'no-store', signal:AbortSignal.timeout(10000), ...options });
  const setStatus = (text, state = 'ready', canRetry = false) => { status.textContent = text; status.parentElement.dataset.state = state; retry.hidden = !canRetry; };
  const unavailable = response => response.status === 401 || response.status === 403 ? 'ليس لديك صلاحية إدارة البوابة.'
    : response.status === 400 ? 'تحقق من الاسم والموضع. قد تشغل بطاقة ثابتة هذا الموضع.' : 'تعذر الاتصال بخدمة الإدارة. حاول مجددًا.';
  let busy = false, records = [];
  const summaries = () => {
    const fixed = records.filter(card => card.isFixed).length;
    for (const [selector, value] of [['[data-admin-total]', records.length], ['[data-admin-fixed]', fixed], ['[data-admin-movable]', records.length-fixed]])
      document.querySelectorAll(selector).forEach(node => { node.textContent = String(value); });
  };
  const authorize = allowed => {
    workspace.hidden = !allowed; access.hidden = allowed;
    document.querySelectorAll('.admin-nav [data-admin-section]').forEach(button => { button.disabled = !allowed; });
    if (!allowed) { root.replaceChildren(); records = []; summaries(); access.querySelector('p').textContent = 'تحقق من صلاحية حسابك واتصال خدمة الإدارة، ثم أعد المحاولة.'; }
  };
  const refreshButtons = () => root.querySelectorAll('form').forEach(form => form.dispatchEvent(new Event('admin:refresh')));
  const render = cards => {
    records = cards; summaries(); root.replaceChildren();
    cards.forEach((card, index) => {
      const form = document.createElement('form'); form.className = 'admin-card'; form.setAttribute('aria-label', 'إعدادات ' + card.cardName);
      const number = document.createElement('span'); number.className = 'admin-card-number'; number.textContent = String(index+1).padStart(2,'0'); number.setAttribute('aria-hidden','true'); form.append(number);
      const field = (caption, type, value, className) => {
        const label = document.createElement('label'); label.className = className;
        const text = document.createElement('span'); text.textContent = caption; label.append(text);
        const input = document.createElement('input'); input.type = type; input.value = value; input.required = true; label.append(input); form.append(label); return input;
      };
      const name = field('اسم البطاقة','text',card.cardName,'admin-name'); name.maxLength = 200;
      const order = field('الموضع','number',card.displayOrder,'admin-order'); order.min = 1; order.max = cards.length; order.step = 1;
      const fixedLabel = document.createElement('label'); fixedLabel.className = 'admin-fixed';
      const fixedCaption = document.createElement('span'); fixedCaption.textContent = 'موضع البطاقة';
      const line = document.createElement('span'); line.className = 'admin-switch-line';
      const fixed = document.createElement('input'); fixed.type = 'checkbox'; fixed.checked = card.isFixed; fixed.setAttribute('role','switch'); fixed.setAttribute('aria-label','تثبيت البطاقة في هذا الموضع');
      const fixedText = document.createElement('span'); line.append(fixed,fixedText); fixedLabel.append(fixedCaption,line); form.append(fixedLabel);
      const save = document.createElement('button'); save.type = 'submit'; save.textContent = 'حفظ التغييرات'; form.append(save);
      const note = document.createElement('p'); note.className = 'admin-card-note'; form.append(note);
      const values = () => ({cardName:name.value.trim(),displayOrder:Number(order.value),isFixed:fixed.checked});
      const sync = () => {
        const value = values(), dirty = value.cardName !== card.cardName || value.displayOrder !== card.displayOrder || value.isFixed !== card.isFixed;
        form.classList.toggle('is-dirty',dirty); save.disabled = busy || !dirty;
        fixedText.textContent = fixed.checked ? 'ثابتة' : 'متحركة';
        note.textContent = dirty ? 'تغييرات غير محفوظة' : fixed.checked ? 'موضع محدد من الإدارة؛ لا يمكن للمستخدم نقل هذه البطاقة.' : 'يمكن للمستخدم إعادة ترتيب هذه البطاقة.';
      };
      form.addEventListener('input',sync); form.addEventListener('change',sync); form.addEventListener('admin:refresh',sync);
      form.addEventListener('submit', async event => {
        event.preventDefault(); if (busy) return;
        if (!name.value.trim()) { name.focus(); setStatus('أدخل اسم البطاقة.','error'); return; }
        const selected = values(); busy = true;
        root.querySelectorAll('button,input').forEach(node => { node.disabled = true; }); setStatus('جارٍ حفظ إعدادات البطاقة…','loading');
        try {
          const response = await request('api/admin/cards/' + card.cardId, { method:'PUT', headers:{'Content-Type':'application/json','X-CompanyPortal-Request':'admin-cards'},body:JSON.stringify(selected) });
          if (!response.ok) {
            if (response.status === 401 || response.status === 403) authorize(false);
            setStatus(unavailable(response),'error',workspace.hidden); return;
          }
          // Update this row only: saving one card must not discard edits in another.
          Object.assign(card,selected); name.value = card.cardName; form.setAttribute('aria-label','إعدادات ' + card.cardName); summaries();
          setStatus('تم حفظ إعدادات البطاقة. تظهر التغييرات في البوابة عند إعادة تحميلها.');
        } catch { setStatus('تعذر تأكيد الحفظ. أعد تحميل الصفحة للتحقق قبل المحاولة مجددًا.','error'); }
        finally { busy = false; root.querySelectorAll('input').forEach(node => { node.disabled = false; }); refreshButtons(); }
      });
      root.append(form); sync();
    });
  };
  async function load() {
    retry.hidden = true; setStatus('جارٍ التحقق من الصلاحية…','loading');
    try {
      const response = await request('api/admin/cards');
      if (!response.ok) { authorize(false); setStatus(unavailable(response),'error',true); return; }
      render(await response.json()); authorize(true); setStatus('تم التحقق من صلاحية حسابك. إعدادات الإدارة جاهزة.');
    } catch { authorize(false); setStatus('خدمة الإدارة غير متاحة حاليًا.','error',true); }
  }
  retry.addEventListener('click',load); load();
})();
