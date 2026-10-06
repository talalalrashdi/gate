(() => {
  const trigger = document.getElementById('documents-sheet-trigger');
  const sheet = document.getElementById('documents-sheet');
  if (!trigger || !sheet) return;
  const departments = {
    'الموارد البشرية': ['طلب إجازة', 'طلب مباشرة عمل', 'طلب شهادة راتب', 'تحديث بيانات الموظف', 'دليل شؤون الموظفين', 'نموذج تقييم الأداء'],
    'الشؤون المالية': ['طلب صرف مستحقات', 'نموذج مطالبة مالية', 'طلب سلفة', 'تسوية عهدة مالية', 'دليل الإجراءات المالية', 'نموذج بدل مهمة رسمية'],
    'تقنية المعلومات': ['طلب صلاحيات نظام', 'طلب دعم فني', 'استلام جهاز حاسب', 'طلب بريد إلكتروني', 'دليل أمن المعلومات', 'نموذج تسليم أجهزة'],
    'الشؤون الإدارية': ['طلب حجز قاعة', 'طلب مركبة رسمية', 'طلب مستلزمات مكتبية', 'محضر استلام وتسليم', 'دليل الخدمات الإدارية', 'نموذج طلب صيانة'],
    'المشتريات والعقود': ['طلب شراء', 'نموذج مقارنة عروض', 'محضر فحص مواد', 'نموذج تقييم مورد', 'دليل إجراءات المشتريات', 'نموذج متابعة عقد']
  };
  const panel = document.createElement('div');
  panel.className = 'b-documents-content';
  panel.innerHTML = `<div class="b-documents-categories" role="group" aria-label="تصفية حسب تصنيف الملف"><button type="button" data-category="" aria-pressed="true" aria-controls="documents-list">الكل</button><button type="button" data-category="forms" aria-pressed="false" aria-controls="documents-list">استمارات</button><button type="button" data-category="documents" aria-pressed="false" aria-controls="documents-list">وثائق</button></div><div class="b-documents-filters"><label class="b-documents-search">البحث عن ملف<input type="search" placeholder="ابحث باسم الاستمارة أو الوثيقة…" aria-controls="documents-list"></label><label>الجهة<select aria-controls="documents-list"><option value="">جميع الجهات</option></select></label></div><div class="b-documents-summary"><span role="status" aria-live="polite"></span><small>مسميات توضيحية</small></div><ul id="documents-list" class="b-documents-list" aria-label="الاستمارات والوثائق المتاحة"></ul><p class="b-documents-empty" hidden>لا توجد ملفات مطابقة للبحث.</p>`;
  sheet.append(panel);
  const search = panel.querySelector('input');
  const department = panel.querySelector('select');
  const list = panel.querySelector('ul');
  const count = panel.querySelector('[role="status"]');
  const empty = panel.querySelector('.b-documents-empty');
  const categories = panel.querySelectorAll('[data-category]');
  let category = '';
  const files = [];
  Object.entries(departments).forEach(([name, titles]) => {
    department.add(new Option(name, name));
    titles.forEach((title, index) => files.push({ title, department: name, category: /^(دليل|محضر)/.test(title) ? 'documents' : 'forms', type: index % 3 === 1 ? 'PDF' : 'Word' }));
  });
  const normalize = text => text.trim().replace(/[أإآ]/g, 'ا').replace(/[\u064B-\u065F\u0640]/g, '').toLowerCase();
  function render() {
    const query = normalize(search.value);
    const matches = files.filter(file => (!category || file.category === category) && (!department.value || file.department === department.value) && normalize(`${file.title} ${file.department} ${file.type}`).includes(query));
    list.scrollTop = 0;
    list.replaceChildren(...matches.map(file => {
      const row = document.createElement('li');
      row.className = 'b-document-row';
      const icon = document.createElement('span');
      icon.className = `b-document-type ${file.type === 'PDF' ? 'is-pdf' : 'is-word'}`;
      icon.setAttribute('aria-hidden', 'true');
      icon.innerHTML = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M14 3H6a1 1 0 0 0-1 1v16a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1V8zM14 3v5h5M8 12h8M8 16h6"/></svg>';
      const copy = document.createElement('div');
      const title = document.createElement('strong');
      title.textContent = `${file.title}.${file.type === 'PDF' ? 'pdf' : 'docx'}`;
      const source = document.createElement('small');
      source.textContent = file.department;
      copy.append(title, source);
      const badge = document.createElement('span');
      badge.className = 'b-document-format';
      badge.textContent = file.type;
      row.append(icon, copy, badge);
      return row;
    }));
    count.textContent = `${matches.length.toLocaleString('ar-EG')} ملف`;
    empty.hidden = matches.length > 0;
  }
  search.addEventListener('input', render);
  department.addEventListener('change', render);
  categories.forEach(button => button.addEventListener('click', () => {
    category = button.dataset.category;
    categories.forEach(item => item.setAttribute('aria-pressed', String(item === button)));
    render();
  }));
  render();
  trigger.addEventListener('click', event => {
    event.preventDefault();
    if (!sheet.open) sheet.showModal();
  });
  sheet.querySelector('.b-documents-sheet-close').addEventListener('click', () => sheet.close());
  sheet.addEventListener('click', event => {
    const bounds = sheet.getBoundingClientRect();
    if (event.target === sheet && (event.clientX < bounds.left || event.clientX > bounds.right || event.clientY < bounds.top || event.clientY > bounds.bottom)) sheet.close();
  });
  sheet.addEventListener('close', () => trigger.focus());
})();
