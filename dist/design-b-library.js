(() => {
  const section = document.getElementById('digital-library');
  if (!section) return;
  const names = {rules:'قوانين المؤسسة',guides:'كتيبات',social:'قانون الحماية الاجتماعية',pdf:'ملفات PDF متنوعة'};
  const documents = [
    {category:'rules',title:'قوانين المؤسسة',description:'المرجع الرئيسي للأنظمة والقواعد المنظمة للعمل داخل المؤسسة.'},
    {category:'rules',title:'سياسات وإجراءات العمل',description:'السياسات الداخلية وإجراءات العمل التي يحتاجها الموظف.'},
    {category:'guides',title:'كتيب الموظف',description:'دليل التعريف بالخدمات والقنوات التي تساعدك في يوم العمل.'},
    {category:'guides',title:'كتيب السلامة والإخلاء',description:'مرجع للاطلاع على تعليمات السلامة وخطة الإخلاء المعتمدة.'},
    {category:'social',title:'قانون الحماية الاجتماعية',description:'مكان مخصص للاطلاع على النسخة الرسمية المعتمدة من القانون.'},
    {category:'social',title:'دليل الحماية الاجتماعية',description:'مكان مخصص للأدلة التوضيحية والأسئلة الشائعة المرتبطة بالقانون.'},
    {category:'pdf',title:'تقارير وملفات مرجعية',description:'تقارير ووثائق عامة متاحة للرجوع إليها.'}
  ];
  let category = 'rules';
  const search = section.querySelector('#dl-search');
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
      note.textContent = 'لم يُرفق ملف لهذه الوثيقة بعد. يمكنك إضافة النسخة المعتمدة من زر «إضافة ملف PDF» ضمن هذا التصنيف.';
      body.append(note);
    }
    dialog.showModal();
  }
  function render() {
    const query = normalize(search.value.trim());
    const filtered = documents.filter(doc => doc.category === category && normalize(doc.title+' '+doc.description).includes(query));
    section.querySelector('#dl-count').textContent = 'عدد الوثائق: '+filtered.length.toLocaleString('ar-OM');
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
    if (!filtered.length) { const empty = document.createElement('p'); empty.className='dl-empty'; empty.textContent='لا توجد وثائق مطابقة. جرّب كلمة أخرى أو أضف ملفًا لهذا التصنيف.'; results.append(empty); }
  }
  section.querySelectorAll('[data-dl-category]').forEach(button => button.addEventListener('click',()=>{
    category = button.dataset.dlCategory;
    section.querySelectorAll('[data-dl-category]').forEach(item=>item.setAttribute('aria-pressed',String(item===button)));
    section.querySelector('#dl-current-title').textContent = names[category]; search.value=''; render();
  }));
  search.addEventListener('input',render);
  section.querySelector('#dl-upload').addEventListener('change',event=>{
    for (const file of event.target.files) {
      if (!/\.pdf$/i.test(file.name) && file.type !== 'application/pdf') continue;
      documents.unshift({category,title:file.name.replace(/\.pdf$/i,''),description:'وثيقة أُضيفت للاستعراض ضمن '+names[category]+'.',url:URL.createObjectURL(file),size:(file.size/1048576).toLocaleString('ar-OM',{maximumFractionDigits:1})+' م.ب'});
    }
    search.value=''; event.target.value=''; render();
  });
  section.querySelector('#dl-close').addEventListener('click',()=>dialog.close());
  dialog.addEventListener('close',()=>body.replaceChildren());
  window.addEventListener('pagehide',()=>documents.forEach(doc=>{if(doc.url)URL.revokeObjectURL(doc.url);}));
  render();
})();
