(() => {
  const section = document.getElementById('digital-library');
  if (!section) return;
  const names = {rules:'قوانين المؤسسة',guides:'كتيبات',social:'قوانين الحماية الاجتماعية'};
  const documents = [
    {category:'rules',title:'قوانين المؤسسة',description:'المرجع الرئيسي للأنظمة والقواعد المنظمة للعمل داخل المؤسسة.'},
    {category:'rules',title:'سياسات وإجراءات العمل',description:'السياسات الداخلية وإجراءات العمل التي يحتاجها الموظف.'},
    {category:'guides',title:'كتيب الموظف',description:'دليل التعريف بالخدمات والقنوات التي تساعدك في يوم العمل.'},
    {category:'guides',title:'كتيب السلامة والإخلاء',description:'مرجع للاطلاع على تعليمات السلامة وخطة الإخلاء المعتمدة.'},
    {category:'social',title:'قانون الحماية الاجتماعية',description:'مكان مخصص للاطلاع على النسخة الرسمية المعتمدة من القانون.'},
    {category:'social',title:'دليل الحماية الاجتماعية',description:'مكان مخصص للأدلة التوضيحية والأسئلة الشائعة المرتبطة بالقانون.'}
  ];
  let category = 'rules';
  const results = section.querySelector('#dl-results');
  const dialog = section.querySelector('#dl-dialog');
  const body = section.querySelector('#dl-dialog-body');
  const normalize = value => value.normalize('NFKD').replace(/[\u064B-\u065F\u0670]/g,'').replace(/[أإآ]/g,'ا').replace(/ى/g,'ي').toLowerCase();
  function openDocument(doc) {
    section.querySelector('#dl-dialog-title').textContent = doc.title;
    section.querySelector('#dl-dialog-category').textContent = names[doc.category];
    section.querySelector('#dl-dialog-description').textContent = doc.description;
    body.replaceChildren();
    if (doc.url) {
      const link = document.createElement('a');
      link.href = doc.url; link.target = '_blank'; link.rel = 'noopener'; link.textContent = 'فتح ملف PDF في نافذة مستقلة ↗';
      const frame = document.createElement('iframe');
      frame.src = doc.url; frame.title = doc.title;
      body.append(link,frame);
    } else {
      const note = document.createElement('p');
      note.textContent = 'لم يُرفق ملف PDF لهذه الوثيقة بعد. ستظهر النسخة المعتمدة هنا عند إرفاقها.';
      body.append(note);
    }
    dialog.showModal();
  }
  function render() {
    const filtered = documents.filter(doc => doc.category === category);
    section.querySelector('#dl-count').textContent = 'عدد الوثائق: '+filtered.length.toLocaleString('ar-OM-u-nu-latn');
    results.replaceChildren();
    for (const doc of filtered) {
      const row = document.createElement('article'); row.className = 'dl-row';
      const icon = document.createElement('span'); icon.className = 'dl-file-icon'; icon.textContent = 'PDF'; icon.setAttribute('aria-hidden','true');
      const content = document.createElement('div');
      const title = document.createElement('h4'); title.textContent = doc.title;
      const description = document.createElement('p'); description.textContent = doc.description;
      const meta = document.createElement('small'); meta.textContent = doc.url ? 'PDF · ملف محلي · '+doc.size : 'نموذج تصنيف · بانتظار إرفاق الملف';
      content.append(title,description,meta);
      const button = document.createElement('button'); button.type = 'button'; button.textContent = doc.url ? 'استعراض الملف ↗' : 'تفاصيل الوثيقة ←'; button.setAttribute('aria-label',(doc.url?'استعراض ':'تفاصيل ')+doc.title); button.addEventListener('click',()=>openDocument(doc));
      row.append(icon,content,button); results.append(row);
    }
    if (!filtered.length) { const empty = document.createElement('p'); empty.className='dl-empty'; empty.textContent='لا توجد ملفات في هذا التصنيف حاليًا.'; results.append(empty); }
  }
  section.querySelectorAll('[data-dl-category]').forEach(button => button.addEventListener('click',()=>{
    category = button.dataset.dlCategory;
    section.querySelectorAll('[data-dl-category]').forEach(item=>item.setAttribute('aria-pressed',String(item===button)));
    section.querySelector('#dl-current-title').textContent = names[category]; render();
  }));
  section.querySelector('#dl-close').addEventListener('click',()=>dialog.close());
  dialog.addEventListener('close',()=>body.replaceChildren());
  window.addEventListener('pagehide',()=>documents.forEach(doc=>{if(doc.url)URL.revokeObjectURL(doc.url);}));
  render();
})();
