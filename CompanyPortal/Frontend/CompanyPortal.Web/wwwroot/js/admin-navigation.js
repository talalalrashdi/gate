(() => {
  const panels = [...document.querySelectorAll('[data-admin-panel]')];
  const buttons = [...document.querySelectorAll('[data-admin-section]')];
  const titles = {
    overview:['نظرة عامة','إدارة محتوى البوابة ومظهرها من مكان واحد.'],
    cards:['إدارة البطاقات الأساسية','اضبط أسماء البطاقات وترتيبها ومواضعها لجميع المستخدمين.'],
    images:['صور الواجهة','ارفع الصور ونظّم مجموعاتها وحدّد طريقة عرضها في الثيمات.'],
    themes:['الثيمات والمظهر','مساحة مخصصة لإدارة الثيمات والمظهر الافتراضي لاحقًا.']
  };
  function show(key, focus = false) {
    if (!Object.hasOwn(titles, key)) key = document.body.dataset.adminStart || 'overview';
    panels.forEach(panel => { panel.hidden = panel.dataset.adminPanel !== key; });
    buttons.forEach(button => {
      if (!button.closest('.admin-nav')) return;
      if (button.dataset.adminSection === key) button.setAttribute('aria-current','page'); else button.removeAttribute('aria-current');
    });
    const heading = document.getElementById('admin-page-title');
    heading.textContent = titles[key][0]; document.getElementById('admin-page-description').textContent = titles[key][1];
    if (focus) { heading.tabIndex = -1; heading.focus({preventScroll:true}); window.scrollTo({top:0,behavior:'instant'}); }
  }
  buttons.forEach(button => button.addEventListener('click', () => {
    const url = new URL(location.href); url.hash = button.dataset.adminSection;
    history.pushState(null,'',url); show(button.dataset.adminSection,true);
  }));
  window.addEventListener('popstate', () => show(location.hash.slice(1)));
  show(location.hash.slice(1));
})();
