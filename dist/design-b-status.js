(() => {
  const status = document.querySelector('.b-org-status');
  if (!status) return;
  const user = status.closest('.b-user');
  const alerts = user?.querySelector('.b-alert-visibility');
  if (user && alerts) user.insertBefore(status, alerts);
  const menu = status.querySelector('.b-org-status-menu');
  const states = {
    yellow: { title: 'تنبيه احترازي', color: 'أصفر', summary: 'توجد حالة تستدعي الانتباه والاستعداد، مع استمرار العمل وفق الإجراءات المعتادة ما لم يصدر تحديث رسمي.', actions: ['تابع قنوات المؤسسة الرسمية باستمرار.', 'تأكد من جاهزية وسائل التواصل وبيانات الاتصال.', 'راجع تعليمات السلامة الخاصة بموقعك.'] },
    orange: { title: 'حالة مرتفعة', color: 'برتقالي', summary: 'ارتفع مستوى الحالة ويتطلب الأمر تقليل الحركة غير الضرورية ورفع الجاهزية حتى وصول تعليمات جديدة.', actions: ['التزم بتوجيهات المسؤول المباشر وفريق السلامة.', 'أجّل التنقل والاجتماعات غير الضرورية.', 'جهّز المتطلبات الأساسية لخطة الاستجابة أو الإخلاء.'] },
    red: { title: 'حالة طوارئ', color: 'أحمر', summary: 'حالة طارئة تتطلب إيقاف الإجراءات الاعتيادية وتنفيذ التعليمات الرسمية بصورة فورية.', actions: ['توقف عن العمل المعتاد وحافظ على الهدوء.', 'نفّذ تعليمات الطوارئ أو الإخلاء فور صدورها.', 'توجه إلى نقطة التجمع ولا تعد إلى الموقع قبل التصريح.'] }
  };
  const detail = document.createElement('section');
  detail.className = 'b-org-status-detail';
  detail.hidden = true;
  detail.innerHTML = '<button type="button" class="b-org-status-back" aria-label="عودة إلى جميع الحالات"><span aria-hidden="true">→</span> عودة إلى جميع الحالات</button><div class="b-org-status-detail-head"><span class="b-org-status-dot" aria-hidden="true"></span><div><small></small><h2></h2></div></div><p></p><h3>ما الذي يجب فعله؟</h3><ul></ul>';
  menu.append(detail);
  const updated = menu.querySelector('.b-org-status-updated');
  if (updated) {
    detail.querySelector('.b-org-status-detail-head').append(updated.cloneNode(true));
  }
  status.querySelectorAll('.b-org-status-list article').forEach((article, index) => {
    const key = ['yellow', 'orange', 'red'][index];
    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'b-org-status-option';
    button.dataset.statusKey = key;
    button.setAttribute('aria-label', `عرض تفاصيل ${states[key].title}`);
    button.innerHTML = article.innerHTML;
    const optionTitle = button.querySelector('strong');
    optionTitle.id = `b-org-status-${key}`;
    button.setAttribute('aria-labelledby', optionTitle.id);
    article.replaceWith(button);
  });
  function showDetail(key) {
    const state = states[key];
    if (!state) return;
    detail.querySelector('.b-org-status-dot').className = `b-org-status-dot is-${key}`;
    detail.querySelector('.b-org-status-detail-head small').textContent = state.color;
    detail.querySelector('h2').textContent = state.title;
    detail.querySelector(':scope > p').textContent = state.summary;
    detail.querySelector('ul').replaceChildren(...state.actions.map(action => { const item = document.createElement('li'); item.textContent = action; return item; }));
    detail.hidden = false;
    menu.classList.add('is-detail');
    detail.querySelector('.b-org-status-back').focus();
  }
  function showOverview() {
    menu.classList.remove('is-detail');
    detail.hidden = true;
  }
  menu.addEventListener('click', event => {
    const option = event.target.closest('[data-status-key]');
    if (option) showDetail(option.dataset.statusKey);
    if (event.target.closest('.b-org-status-back')) showOverview();
  });
  status.addEventListener('toggle', () => { if (!status.open) showOverview(); });
  document.addEventListener('click', event => {
    if (status.open && !status.contains(event.target)) status.open = false;
  });
  document.addEventListener('keydown', event => {
    if (event.key !== 'Escape' || !status.open) return;
    status.open = false;
    status.querySelector('summary').focus();
  });
})();
