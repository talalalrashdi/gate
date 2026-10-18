(() => {
  const root=document.querySelector('.portal-editorial');if(!root)return;
  const techTrack=root.querySelector('#editorial-tech-track'),techPrev=root.querySelector('#editorial-tech-prev'),techNext=root.querySelector('#editorial-tech-next');
  if(techTrack&&techPrev&&techNext){
    function updateTechControls(){const max=Math.max(0,techTrack.scrollWidth-techTrack.clientWidth),position=Math.abs(techTrack.scrollLeft);techPrev.disabled=position<2;techNext.disabled=position>=max-2;}
    function moveTech(direction){const card=techTrack.firstElementChild;if(!card)return;const step=card.getBoundingClientRect().width+(parseFloat(getComputedStyle(techTrack).columnGap)||0);techTrack.scrollBy({left:direction*step,behavior:matchMedia('(prefers-reduced-motion: reduce)').matches?'instant':'smooth'});}
    techPrev.addEventListener('click',()=>moveTech(1));techNext.addEventListener('click',()=>moveTech(-1));
    techTrack.addEventListener('scroll',updateTechControls,{passive:true});techTrack.addEventListener('keydown',event=>{if(event.target!==techTrack)return;if(event.key==='ArrowLeft'||event.key==='ArrowRight'){event.preventDefault();moveTech(event.key==='ArrowLeft'?-1:1);}});
    techTrack.addEventListener('focusin',event=>{const card=event.target.closest('.editorial-article-card');if(!card)return;const bounds=card.getBoundingClientRect(),viewport=techTrack.getBoundingClientRect();if(bounds.left<viewport.left||bounds.right>viewport.right)card.scrollIntoView({behavior:'instant',block:'nearest',inline:'nearest'});});
    new ResizeObserver(updateTechControls).observe(techTrack);updateTechControls();
  }
  const sectionNav=document.querySelector('.portal-media-subnav'),navTrack=sectionNav.querySelector('.portal-media-subnav-links');
  const editorialMotion=matchMedia('(prefers-reduced-motion: reduce)');
  const navItems=[...sectionNav.querySelectorAll('a[href^="#"]')].map(link=>({link,target:document.querySelector(link.getAttribute('href'))})).filter(item=>item.target).sort((a,b)=>a.target.compareDocumentPosition(b.target)&Node.DOCUMENT_POSITION_FOLLOWING?-1:1);
  let activeNavLink=null,navFrame=false;
  function markNav(link){
    if(activeNavLink===link)return;activeNavLink=link;
    navItems.forEach(item=>{if(item.link===link)item.link.setAttribute('aria-current','location');else item.link.removeAttribute('aria-current');});
    if(link){const bounds=navTrack.getBoundingClientRect(),item=link.getBoundingClientRect();if(item.left<bounds.left||item.right>bounds.right)navTrack.scrollBy({left:item.left+item.width/2-bounds.left-bounds.width/2,behavior:editorialMotion.matches?'instant':'smooth'});}
  }
  function updateDock(){
    navFrame=false;
    // Sections such as the magazine and references now sit outside the editorial root.
    const bounds=root.getBoundingClientRect();
    const offset=Math.max(0,sectionNav.getBoundingClientRect().bottom)+16;
    const anchor=Math.min(window.innerHeight-1,offset+1);
    const positions=navItems.map(item=>({item,rect:item.target.getBoundingClientRect()})).filter(({rect})=>rect.height>0);
    let nextLink=positions.filter(({rect})=>rect.top<=anchor).at(-1)?.item.link||null;
    const maxScroll=Math.max(0,document.documentElement.scrollHeight-window.innerHeight);
    if(maxScroll>0&&window.scrollY>=maxScroll-2&&positions.at(-1)?.rect.top<window.innerHeight)nextLink=positions.at(-1).item.link;
    const value=offset+'px';
    if(document.documentElement.style.getPropertyValue('--portal-section-anchor-offset')!==value)document.documentElement.style.setProperty('--portal-section-anchor-offset',value);
    if(bounds.top<window.innerHeight*.85)root.classList.add('editorial-has-entered');
    markNav(nextLink);
  }
  function scheduleDock(){if(!navFrame){navFrame=true;requestAnimationFrame(updateDock);}}
  navItems.forEach(item=>item.link.addEventListener('click',()=>{ updateDock(); markNav(item.link); }));
  window.addEventListener('scroll',scheduleDock,{passive:true});window.addEventListener('resize',scheduleDock,{passive:true});
  document.addEventListener('visibilitychange',scheduleDock);document.addEventListener('companyportal:theme-change',scheduleDock);editorialMotion.addEventListener('change',scheduleDock);
  const sectionObserver=new ResizeObserver(scheduleDock);
  new Set([root,document.querySelector('.portal-header'),...navItems.map(item=>item.target)]).forEach(node=>{if(node)sectionObserver.observe(node);});
  updateDock();
  const articles={
    'tech-lab':{title:'مساحة جديدة لتجربة الأفكار',paragraphs:['خبر تجريبي: تصوّر لمختبر رقمي يتيح للفرق تحويل الأفكار الصغيرة إلى نماذج أولية، ومناقشتها قبل بدء التنفيذ.','تركّز التجربة على اختيار مشكلة واحدة، ورسم مسار مبسّط لحلها، ثم مشاركة النموذج مع المستخدمين وتوثيق ملاحظاتهم.','هذا نموذج تحريري لتصنيف التقنية، وليس إعلانًا عن مبادرة قائمة في المؤسسة.']},
    'tech-dashboard':{title:'المعلومة أوضح، والصورة أشمل',paragraphs:['خبر تجريبي: تصور للوحة مؤشرات موحدة تعرض تقدم الأعمال والنتائج في مساحة واحدة، مع إمكانية الانتقال من الملخص إلى التفاصيل.','تجمع الفكرة بين وضوح الأرقام وتاريخ تحديثها وتعريف كل مؤشر، ليصبح استعراض المعلومات أسرع وأكثر قابلية للفهم.','المحتوى توضيحي لتجربة الواجهة؛ لا يعرض بيانات فعلية أو إعلانًا عن نظام مطبّق.']},
    'book-writing':{title:'كتابة تصنع الوضوح — دليل قصير',paragraphs:['ابدأ بالمطلوب: أخبر القارئ بما يحتاج إلى معرفته أو فعله في الجملة الأولى.','امنح كل فقرة فكرة واحدة، واستخدم عناوين قصيرة تساعد على استعراض النص.','اختم بخطوة واضحة: ما الإجراء التالي، ومن يتولاه، ومتى؟ هذا دليل توضيحي أصلي لمساحة العمل.']},
    'book-learning':{title:'تعلّم كل يوم — دليل قصير',paragraphs:['اختر سؤالًا صغيرًا من واقع عملك، ثم ابحث عن فكرة تساعدك على الإجابة عنه.','دوّن الفكرة بلغتك وجرّبها في مهمة بسيطة. التجربة تجعل المعرفة أقرب إلى الممارسة.','شارك ما تعلمته مع الفريق، واحتفظ بملاحظة عمّا ستغيّره في المرة المقبلة. هذا محتوى تجريبي أصلي.']},
    'book-time':{title:'مساحة لوقتك — دليل قصير',paragraphs:['ابدأ بتحديد النتيجة الأهم لليوم، واترك لها وقتًا واضحًا في جدولك.','اجمع الأعمال المتشابهة معًا، واحتفظ بمساحة مرنة للطلبات غير المتوقعة.','راجع يومك بسؤال واحد: ما الذي يستحق وقتًا أكثر غدًا، وما الذي يمكن تبسيطه؟ هذا دليل توضيحي أصلي.']},
    'tech-workflow':{title:'خطوات أقل، مساحة أكبر للإنجاز',paragraphs:['ابدأ بملاحظة خطوة تتكرر في عملك: نقل معلومة بين ملفين، تجهيز ملخص ثابت، أو إرسال تذكير. دوّن المدخلات والنتيجة المطلوبة قبل التفكير في الأداة.','اختر تجربة صغيرة وواضحة، واحتفظ بمراجعة بشرية للنتائج. الهدف من الأتمتة هو تقليل العمل المتكرر وإتاحة وقت أكبر لما يحتاج إلى تفكير.','هذا محتوى تجريبي لتصنيف التقنية، وليس إعلانًا عن خدمة مطبّقة في المؤسسة.']},
    'tech-knowledge':{title:'ملفات مرتبة، معرفة أقرب',paragraphs:['المكتبة الرقمية المفيدة تبدأ بأسماء واضحة وتصنيفات قليلة مفهومة. اجعل عنوان الملف يصف موضوعه، ودوّن الإصدار وتاريخ التحديث حيث يسهل العثور عليهما.','اتفق مع فريقك على مكان للنسخة المعتمدة، وأرشف النسخ القديمة بوضوح. أضف وصفًا مختصرًا يوضح متى يستخدم المستند وما الذي سيجده القارئ داخله.','هذا دليل توضيحي ضمن المحتوى التجريبي لمساحة العمل.']},
    collaboration:{title:'مساحات للتعاون، وأفكار تصنع الفرق',paragraphs:['تبدأ ثقافة التعاون حين يجد كل فرد مساحة آمنة لعرض أفكاره وطرح أسئلته. ليس المطلوب اجتماعًا إضافيًا، بل لحظة واضحة نتشارك فيها ما تعلّمناه وما نحتاج إلى فهمه.','خصص وقتًا قصيرًا لمشاركة تجربة واحدة، وأتح الفرصة لأعضاء الفريق لإضافة ملاحظاتهم. دوّن الفكرة التي يمكن تطبيقها وحدد خطوة تالية صغيرة.','هذا نص تحريري تجريبي لعرض شكل الخبر، ولا يصف فعالية حدثت بالفعل.']},
    services:{title:'خطوة أقرب إلى خدمات أكثر سهولة',paragraphs:['تساعد نقطة البداية الموحدة المستخدم على الوصول إلى الخدمة الصحيحة دون التنقل بين مسارات كثيرة. تبدأ التجربة بتسمية واضحة، ثم متطلبات مختصرة، ثم إجراء يمكن فهمه بسهولة.','عندما نعرض حالة الطلب والخطوة التالية في مكان واحد، تصبح المتابعة أقل جهدًا وتقل الحاجة إلى الاستفسارات المتكررة. هذا تصور تجريبي لمحتوى أخبار تطوير الخدمات.']},
    knowledge:{title:'المعرفة تكبر حين نشاركها',paragraphs:['قد تكون أفضل فكرة في الفريق ملاحظة صغيرة دوّنها أحد الموظفين أثناء العمل. إتاحة مساحة لهذه الملاحظات تحوّل التجربة الفردية إلى معرفة مشتركة.','ابدأ بوصف ما حدث، ثم ما تعلمته، ثم ما ستفعله بطريقة مختلفة. ثلاث جمل مفيدة قد تكون أهم من عرض طويل لا ينتهي بإجراء.']},
    focus:{title:'مساحة للتركيز في يوم مزدحم',paragraphs:['قبل أن تبدأ يومك، اختر نتيجة واحدة مهمة تريد الوصول إليها. اكتبها بصيغة واضحة، وحدد أصغر خطوة تتيح لك البدء فيها.','اجمع الأعمال المتشابهة في فترات محددة، واترك نافذة زمنية للعمل الذي يتطلب تركيزًا. لا تحتاج البداية إلى وقت طويل؛ تحتاج إلى قرار واضح بشأن ما ستؤجله مؤقتًا.','في نهاية اليوم، راجع ما أنجزته وما أعاقك. استخدم هذه الملاحظة لتحسين يوم الغد، لا للحكم على يومك بالكامل.']},
    meetings:{title:'اجتماعات أقل، أثر أكبر',paragraphs:['اسأل قبل إرسال الدعوة: ما القرار الذي نريد اتخاذه؟ إذا كان الهدف مجرد مشاركة معلومة، فقد تكفي رسالة واضحة أو مستند قصير.','شارك السؤال والمواد اللازمة مسبقًا. أثناء الاجتماع، امنح كل موضوع وقتًا محددًا ودوّن القرارات فور الاتفاق عليها.','اختم بذكر المسؤول عن كل خطوة وموعدها. الاجتماع المفيد لا يُقاس بطوله، بل بوضوح ما يحدث بعده.']},
    'summary-week':{title:'هذا الأسبوع في ثلاث نقاط',paragraphs:['1. ابدأ بالأولوية: اختر مهمة واحدة ذات أثر قبل الانشغال بالطلبات الصغيرة.','2. شارك المعرفة: دوّن ما تعلمته بطريقة يمكن لغيرك تطبيقها.','3. أغلق المسار: حوّل كل نقاش إلى خطوة محددة أو قرار موثّق.']},
    'summary-project':{title:'قبل أن تبدأ مشروعك',paragraphs:['الهدف: ما المشكلة التي نريد حلها، ولمن؟','النطاق: ما الذي سننجزه الآن، وما الذي سنؤجله؟','الخطوة التالية: ما أصغر تجربة يمكن أن تمنحنا معلومة مفيدة قبل الاستثمار في التنفيذ الكامل؟']},
    'summary-reading':{title:'قراءة تستحق وقتك',paragraphs:['اختر سؤالًا واحدًا تريد أن تجيب عنه القراءة. احتفظ بملاحظة قصيرة، ثم حوّل فكرة واحدة إلى تجربة في عملك.','ناقش ما جرّبته مع زميل؛ فالمعرفة تصبح أوضح عندما نعيد شرحها ونختبر فائدتها.']},
    'book-work':{title:'فنّ العمل بوضوح — دليل قصير',paragraphs:['الفصل الأول: سمِّ النتيجة. تبدأ الخطة المفيدة بتحديد ما يجب أن يتغير، لا بعدّ الأنشطة التي سننفذها.','الفصل الثاني: صغّر الخطوة. قسّم العمل إلى أجزاء يمكن إنهاؤها ومراجعتها، واترك لكل خطوة تعريفًا واضحًا للاكتمال.','الفصل الثالث: اكتب لكي تُفهم. استخدم لغة مباشرة وقدم السياق الضروري وحدد المطلوب من القارئ.','الخلاصة: وضوح الهدف والخطوة والمعلومة يقلل الجهد الذي نبذله في التنسيق. هذا دليل تجريبي أصلي لإظهار تجربة القراءة.']},
    'book-team':{title:'فريق واحد، أثر مشترك — دليل قصير',paragraphs:['الفصل الأول: اتفقوا على الطريقة. وضّحوا أين تُشارك الملفات، وكيف تُتابع القرارات، ومتى يحتاج الموضوع إلى اجتماع.','الفصل الثاني: اسألوا مبكرًا. السؤال في بداية المسار يساعد على اكتشاف الاختلاف في التوقعات قبل أن يتحول إلى إعادة عمل.','الفصل الثالث: اجعلوا التقدير محددًا. اذكروا الفعل الذي صنع فرقًا، وأثره على الفريق أو المستخدم.','هذا محتوى توضيحي من إعداد مساحة العمل، وليس نسخة من كتاب منشور.']},
    'book-ideas':{title:'دفتر الأفكار الصغيرة — دليل قصير',paragraphs:['راقب: ما الخطوة التي تتكرر دون أن تضيف قيمة؟ دوّنها كما تراها، دون أن تقفز إلى الحل.','اقترح: اختر تغييرًا بسيطًا يمكن تنفيذه بأقل جهد، وحدد ما تتوقع أن يتحسن.','جرّب: شارك الفكرة مع من يستخدمون المسار، ثم قارن التجربة بالتوقعات.','تعلّم: احتفظ بما نجح، وعدّل ما يحتاج إلى تحسين. الابتكار سلسلة من خطوات التعلم الصغيرة.']}
  };
  const readingDialog=document.getElementById('editorial-reading-dialog');
  function openEditorialArticle(id){
    const item=articles[id];if(!item)return;
    document.getElementById('editorial-reading-title').textContent=item.title;
    const copy=document.getElementById('editorial-reading-copy');copy.replaceChildren();
    item.paragraphs.forEach(text=>{const paragraph=document.createElement('p');paragraph.textContent=text;copy.append(paragraph);});if(!readingDialog.open)readingDialog.showModal();readingDialog.scrollTop=0;
  }
  root.querySelectorAll('[data-editorial-read]').forEach(button=>button.addEventListener('click',()=>openEditorialArticle(button.dataset.editorialRead)));
  const collections={news:{title:'أخبار عامة',ids:['collaboration','services','knowledge']},articles:{title:'المقالات',ids:['focus','meetings']},summaries:{title:'الملخصات',ids:['summary-week','summary-project','summary-reading']},tech:{title:'التقنية',ids:['tech-workflow','tech-knowledge','tech-lab','tech-dashboard']},books:{title:'رفّ الكتب',ids:['book-work','book-team','book-ideas','book-writing','book-learning','book-time']}};
  root.querySelectorAll('[data-editorial-more]').forEach(button=>button.addEventListener('click',()=>{
    const kind=button.dataset.editorialMore,collection=collections[kind];
    document.getElementById('editorial-reading-title').textContent=collection?.title||'صور وفيديو الفعاليات';
    const copy=document.getElementById('editorial-reading-copy');copy.replaceChildren();const list=document.createElement('div');list.className='editorial-more-list';
    function addItem(title,action){const row=document.createElement('button');row.type='button';const text=document.createElement('span'),arrow=document.createElement('span');text.textContent=title;arrow.textContent='←';arrow.setAttribute('aria-hidden','true');row.append(text,arrow);row.addEventListener('click',action);list.append(row);}
    if(collection)collection.ids.forEach(id=>addItem(articles[id].title,()=>openEditorialArticle(id)));
    else {addItem('ألبوم الصور — بعدساتنا، عُمان أقرب',()=>{readingDialog.close();root.querySelector('[data-editorial-gallery]').click();});addItem('فيديو الفعالية — المشاهدة أو اختيار ملف محلي',()=>{readingDialog.close();const target=root.querySelector('.editorial-video-card');target.setAttribute('tabindex','-1');target.focus({preventScroll:true});target.scrollIntoView({behavior:matchMedia('(prefers-reduced-motion: reduce)').matches?'instant':'smooth',block:'center'});});}
    copy.append(list);readingDialog.showModal();
  }));
  document.querySelectorAll('.editorial-dialog [data-editorial-close]').forEach(button=>button.addEventListener('click',()=>button.closest('dialog').close()));
  let saved=[];try{const value=JSON.parse(localStorage.getItem('clerio-editorial-saved')||'[]');if(Array.isArray(value))saved=value.filter(id=>typeof id==='string');}catch{}
  root.querySelectorAll('[data-editorial-save]').forEach(button=>{
    const id=button.dataset.editorialSave;const title=articles[id].title;
    const update=()=>{const selected=saved.includes(id);button.setAttribute('aria-pressed',String(selected));button.setAttribute('aria-label',`${selected?'إلغاء حفظ':'حفظ'} ${title}`);};update();
    button.addEventListener('click',()=>{saved=saved.includes(id)?saved.filter(value=>value!==id):[...saved,id];try{localStorage.setItem('clerio-editorial-saved',JSON.stringify(saved));}catch{}update();});
  });
  const photos=[{src:'./assets/hero-oman-desert.png',caption:'رمال عُمان · صورة توضيحية'},{src:'./assets/hero-oman-fort.png',caption:'قلاع وحصون · صورة توضيحية'},{src:'./assets/hero-oman-mosque.png',caption:'جمال العمارة العُمانية · صورة توضيحية'}];
  const preview=root.querySelector('.editorial-photo-slider'),previewSlides=preview?[...preview.querySelectorAll('[data-photo-slide]')]:[];
  let previewIndex=1;
  function selectPreview(index){
    if(!preview)return;
    previewIndex=(index+photos.length)%photos.length;
    previewSlides.forEach((slide,i)=>{
      const difference=(i-previewIndex+photos.length)%photos.length,selected=i===previewIndex;
      slide.classList.toggle('is-selected',selected);slide.style.setProperty('--photo-slot',selected?'0':difference===1?'-1':'1');
      slide.querySelector('[data-photo-select]').setAttribute('aria-pressed',String(selected));slide.querySelector('.editorial-photo-enlarge').hidden=!selected;
    });
    root.querySelector('[data-photo-status]').textContent=(previewIndex+1)+' / '+photos.length;
  }
  if(preview){
    root.querySelector('[data-photo-prev]').addEventListener('click',()=>selectPreview(previewIndex-1));root.querySelector('[data-photo-next]').addEventListener('click',()=>selectPreview(previewIndex+1));
    preview.querySelectorAll('[data-photo-select]').forEach(button=>button.addEventListener('click',()=>selectPreview(Number(button.dataset.photoSelect))));
    preview.addEventListener('keydown',event=>{if(event.key==='ArrowLeft'||event.key==='ArrowRight'){event.preventDefault();selectPreview(previewIndex+(event.key==='ArrowLeft'?1:-1));}});
    let touch;preview.addEventListener('touchstart',event=>{touch={x:event.touches[0].clientX,y:event.touches[0].clientY};},{passive:true});preview.addEventListener('touchend',event=>{if(!touch)return;const dx=event.changedTouches[0].clientX-touch.x,dy=event.changedTouches[0].clientY-touch.y;touch=null;if(Math.abs(dx)>45&&Math.abs(dx)>Math.abs(dy)*1.5)selectPreview(previewIndex+(dx>0?1:-1));},{passive:true});
    selectPreview(1);
  }
  const gallery=document.getElementById('editorial-gallery-dialog');let photoIndex=0;
  const photoThumbs=gallery.querySelector('.editorial-gallery-thumbnails'),photoRange=gallery.querySelector('[data-gallery-range]'),photoPage=gallery.querySelector('[data-gallery-page]'),photoZoom=gallery.querySelector('[data-gallery-zoom]'),photoStage=gallery.querySelector('.editorial-gallery-stage');
  const photoNumber=value=>value.toLocaleString('ar-OM-u-nu-latn');
  root.querySelector('[data-photo-count]')?.replaceChildren(document.createTextNode(photoNumber(photos.length)+' صور'));
  if(photoThumbs){
    photos.forEach((photo,index)=>{
      const button=document.createElement('button'),image=document.createElement('img');button.type='button';button.dataset.galleryIndex=String(index);button.setAttribute('aria-label','عرض الصورة '+photoNumber(index+1)+': '+photo.caption);
      image.src=photo.src;image.alt='';image.loading='lazy';image.decoding='async';button.append(image);photoThumbs.append(button);
    });
    photoThumbs.addEventListener('click',event=>{const button=event.target.closest('[data-gallery-index]');if(button)selectPhoto(Number(button.dataset.galleryIndex));});
  }
  if(photoRange)photoRange.max=String(photos.length);if(photoPage)photoPage.max=String(photos.length);
  function zoomPhoto(value){
    gallery.classList.toggle('is-zoomed',value);photoZoom?.setAttribute('aria-pressed',String(value));photoZoom?.setAttribute('aria-label',value?'إعادة الصورة إلى حجمها الطبيعي':'تكبير الصورة');
    if(!value&&photoStage){photoStage.scrollTop=0;photoStage.scrollLeft=0;}
  }
  function renderPhoto(){
    const photo=photos[photoIndex],image=document.getElementById('editorial-gallery-image');image.src=photo.src;image.alt=photo.caption;
    document.getElementById('editorial-gallery-caption').textContent=photo.caption;document.getElementById('editorial-gallery-status').textContent=photoNumber(photoIndex+1)+' / '+photoNumber(photos.length);
    document.getElementById('editorial-gallery-prev').disabled=photoIndex===0;document.getElementById('editorial-gallery-next').disabled=photoIndex===photos.length-1;
    if(photoRange)photoRange.value=String(photoIndex+1);if(photoPage)photoPage.value=String(photoIndex+1);
    if(photoThumbs)[...photoThumbs.children].forEach((button,index)=>button.setAttribute('aria-pressed',String(index===photoIndex)));
    zoomPhoto(false);selectPreview(photoIndex);
    if(gallery.open)photoThumbs?.children[photoIndex]?.scrollIntoView({block:'nearest',inline:'center',behavior:'instant'});
  }
  function selectPhoto(index){photoIndex=Math.max(0,Math.min(photos.length-1,Number(index)||0));renderPhoto();}
  root.querySelectorAll('[data-editorial-gallery]').forEach(button=>button.addEventListener('click',()=>{selectPhoto(button.dataset.editorialGallery);gallery.showModal();photoThumbs?.children[photoIndex]?.scrollIntoView({block:'nearest',inline:'center',behavior:'instant'});}));
  function movePhoto(step){selectPhoto(photoIndex+step);}
  document.getElementById('editorial-gallery-prev').addEventListener('click',()=>movePhoto(-1));document.getElementById('editorial-gallery-next').addEventListener('click',()=>movePhoto(1));
  photoRange?.addEventListener('input',()=>selectPhoto(Number(photoRange.value)-1));photoPage?.addEventListener('change',()=>selectPhoto(Number(photoPage.value)-1));
  photoPage?.addEventListener('keydown',event=>{if(event.key==='Enter'){event.preventDefault();selectPhoto(Number(photoPage.value)-1);}});
  photoZoom?.addEventListener('click',()=>zoomPhoto(!gallery.classList.contains('is-zoomed')));
  if(photoZoom)document.getElementById('editorial-gallery-image').addEventListener('dblclick',()=>zoomPhoto(!gallery.classList.contains('is-zoomed')));
  gallery.addEventListener('keydown',event=>{
    if(event.target.matches('input'))return;
    if(event.key==='ArrowLeft'||event.key==='ArrowRight'){event.preventDefault();movePhoto(event.key==='ArrowLeft'?1:-1);}
    else if(event.key==='Home'||event.key==='End'){event.preventDefault();selectPhoto(event.key==='Home'?0:photos.length-1);}
  });
  if(photoStage){let touch;photoStage.addEventListener('touchstart',event=>{touch={x:event.touches[0].clientX,y:event.touches[0].clientY};},{passive:true});photoStage.addEventListener('touchend',event=>{if(!touch||gallery.classList.contains('is-zoomed'))return;const dx=event.changedTouches[0].clientX-touch.x,dy=event.changedTouches[0].clientY-touch.y;touch=null;if(Math.abs(dx)>55&&Math.abs(dx)>Math.abs(dy)*1.5)movePhoto(dx>0?1:-1);},{passive:true});}
  const videoCarousel=root.querySelector('.editorial-video-carousel');
  if(videoCarousel){
    const track=videoCarousel.querySelector('.editorial-video-track');
    const slides=[...track.querySelectorAll('.editorial-video-card')];
    const previous=root.querySelector('[data-video-prev]'),next=root.querySelector('[data-video-next]'),status=root.querySelector('[data-video-status]'),viewport=videoCarousel.querySelector('.editorial-video-viewport');
    const urls=new Map(),motion=matchMedia('(prefers-reduced-motion: reduce)');
    let current=0,frame=0;
    function paint(){
      previous.disabled=current===0;next.disabled=current===slides.length-1;
      status.textContent=(current+1)+' / '+slides.length;
      const offset=Math.abs(track.scrollLeft),max=track.scrollWidth-track.clientWidth;viewport?.classList.toggle('has-hidden-start',offset>2);viewport?.classList.toggle('has-hidden-end',offset<max-2);
      slides.forEach((slide,index)=>{slide.inert=index!==current;if(index!==current)slide.querySelector('video').pause();});
    }
    function position(index){const max=Math.max(0,track.scrollWidth-track.clientWidth);return Math.max(-max,Math.min(0,slides[index].offsetLeft-slides[0].offsetLeft));}
    function move(step,instant=false){
      current=Math.max(0,Math.min(slides.length-1,current+step));
      paint();track.scrollTo({left:position(current),behavior:instant||motion.matches?'instant':'smooth'});
    }
    previous.addEventListener('click',()=>move(-1));next.addEventListener('click',()=>move(1));
    track.addEventListener('keydown',event=>{if(event.target!==track)return;if(event.key==='ArrowLeft'||event.key==='ArrowRight'){event.preventDefault();move(event.key==='ArrowLeft'?1:-1);}});
    track.addEventListener('scroll',()=>{cancelAnimationFrame(frame);frame=requestAnimationFrame(()=>{current=slides.reduce((best,slide,index)=>Math.abs(position(index)-track.scrollLeft)<Math.abs(position(best)-track.scrollLeft)?index:best,0);paint();});},{passive:true});
    new ResizeObserver(()=>move(0,true)).observe(track);
    slides.forEach(slide=>{
      const video=slide.querySelector('video'),input=slide.querySelector('input[type="file"]'),play=slide.querySelector('.editorial-video-play'),note=slide.querySelector('[role="status"]');
      const notify=text=>{note.hidden=false;note.textContent=text;};
      const playing=value=>{slide.classList.toggle('is-playing',value);video.controls=value;};
      play.addEventListener('click',()=>{if(!urls.has(video)){input.click();return;}video.play().catch(()=>{playing(false);notify('تعذّر تشغيل الفيديو. جرّب ملفًا متوافقًا مع المتصفح.');});});
      input.addEventListener('change',()=>{
        const file=input.files[0];if(!file)return;
        if(!file.type.startsWith('video/')){notify('اختر ملف فيديو صالحًا للمعاينة.');return;}
        video.pause();if(urls.has(video))URL.revokeObjectURL(urls.get(video));
        const url=URL.createObjectURL(file);urls.set(video,url);video.src=url;video.load();playing(false);notify('معاينة محلية: '+file.name);
      });
      video.addEventListener('play',()=>playing(true));video.addEventListener('pause',()=>playing(false));video.addEventListener('ended',()=>playing(false));
      video.addEventListener('error',()=>{if(urls.has(video)){playing(false);notify('تعذّر تشغيل هذا الملف. جرّب فيديو MP4 متوافقًا مع المتصفح.');}});
    });
    window.addEventListener('pagehide',event=>{slides.forEach(slide=>slide.querySelector('video').pause());if(!event.persisted)urls.forEach(url=>URL.revokeObjectURL(url));});
    paint();
  }else{
  const video=document.getElementById('editorial-event-video');let videoURL;
  document.getElementById('editorial-video-file').addEventListener('change',event=>{
    const file=event.target.files[0];if(!file)return;if(!file.type.startsWith('video/')){document.getElementById('editorial-video-note').textContent='اختر ملف فيديو صالحًا للمعاينة.';return;}
    video.pause();if(videoURL)URL.revokeObjectURL(videoURL);videoURL=URL.createObjectURL(file);video.src=videoURL;video.load();document.getElementById('editorial-video-note').textContent=`معاينة محلية: ${file.name}`;
  });
  video.addEventListener('error',()=>{if(videoURL)document.getElementById('editorial-video-note').textContent='تعذّر تشغيل هذا الملف. جرّب فيديو MP4 متوافقًا مع المتصفح.';});
  window.addEventListener('pagehide',()=>{if(videoURL)URL.revokeObjectURL(videoURL);});

  }

  if(!document.getElementById('editorial-book-stage'))return;
  const pages=[
    {cover:true,kicker:'مجلة كليريو / سبتمبر 2026',title:'وُجهات.',text:['من تفاصيل يومنا، تبدأ الحكاية.'],image:'./assets/hero-oman-fort.png'},
    {kicker:'رسالة العدد',title:'نفتح صفحة جديدة',text:['هذا العدد مساحة للتأمل في طريقة عملنا، والتعلّم من تفاصيل المكان والناس.','اقلب الصفحات على مهل؛ كل موضوع دعوة لفكرة أو خطوة جديدة.'],list:['ثقافة العمل — الصفحتان 3 و4','من عُمان — الصفحتان 5 و6','أفكار للغد — الصفحتان 7 و8']},
    {kicker:'ثقافة العمل / 01',title:'وضوح صغير، أثر كبير',text:['حين نعرف لماذا نعمل على مهمة ما، تصبح قراراتنا أكثر وضوحًا. ابدأ بتحديد النتيجة المطلوبة، ثم اختر خطوة يمكن إنجازها ومراجعتها.','اكتب ما تحتاجه من زميلك في جملة مباشرة. وضوح الرسالة يوفر الوقت ويمنح الطرف الآخر فرصة أفضل للمساعدة.']},
    {kicker:'ثقافة العمل / 02',title:'الفريق مساحة للتعلّم',text:['لا تنتظر اكتمال التجربة لتشارك ما تعلمته. ملاحظة مفيدة في منتصف المسار قد تساعد فريقًا آخر على تجاوز عائق مشابه.'],list:['شارك السياق قبل النتيجة.','اذكر ما نجح وما يحتاج إلى تحسين.','اترك سؤالًا يفتح باب الحوار.']},
    {kicker:'من عُمان / 03',title:'ذاكرة المكان',image:'./assets/hero-oman-mosque.png',text:['في العمارة العُمانية تفاصيل تدعونا إلى التمهّل. يتجاور الضوء والظل، وتمنح المساحات إحساسًا بالاتزان.','صورة توضيحية من مجموعة المشاهد المستخدمة في الموقع.']},
    {kicker:'من عُمان / 04',title:'إيقاع أهدأ',image:'./assets/hero-oman-desert.png',text:['تعيدنا الخطوط البسيطة في الطبيعة إلى فكرة مهمة: ليست كل مساحة بحاجة إلى الامتلاء. أحيانًا تكون المساحة الفارغة ما يجعل المعنى أوضح.']},
    {kicker:'أفكار للغد / 05',title:'جرّب فكرة واحدة',text:['اختر تفصيلًا صغيرًا في يوم العمل يمكن تحسينه. اسأل من يشاركونك التجربة، ودوّن اقتراحًا يمكن تطبيقه خلال أسبوع.'],list:['ما المشكلة التي لاحظتها؟','ما أصغر تغيير يمكن تجربته؟','كيف ستعرف أن التجربة أفادت؟']},
    {kicker:'ختام العدد',title:'الحكاية القادمة… منك',text:['قصة تعلّم، تجربة تعاون، أو صورة التقطتها في مكان تحبه؛ لكل مساهمة فرصة لأن تصبح نافذة يطل منها الفريق على فكرة جديدة.','هذا العدد نموذج تفاعلي من ثماني صفحات، بمحتوى توضيحي أصلي، وليس ملف PDF أو مجلة رسمية منشورة.']}
  ];
  const stage=document.getElementById('editorial-book-stage'),spread=document.getElementById('editorial-spread'),reader=document.getElementById('editorial-magazine-reader'),previous=document.getElementById('editorial-book-prev'),next=document.getElementById('editorial-book-next');
  const motion=matchMedia('(prefers-reduced-motion: reduce)');let spreadIndex=0,turning=false,flipTimer,expanded=false,previousFocus;
  function createPage(page,index){const article=document.createElement('article');article.className=`editorial-page${page.cover?' editorial-mag-cover':''}`;const kicker=document.createElement('small');kicker.textContent=page.kicker;const title=document.createElement('h4');title.textContent=page.title;article.append(kicker,title);if(page.image){const image=document.createElement('img');image.loading='lazy';image.decoding='async';image.src=page.image;image.alt=page.title+' — صورة توضيحية';article.append(image);}page.text.forEach(text=>{const paragraph=document.createElement('p');paragraph.textContent=text;article.append(paragraph);});if(page.list){const list=document.createElement('ul');page.list.forEach(text=>{const item=document.createElement('li');item.textContent=text;list.append(item);});article.append(list);}const number=document.createElement('footer');number.className='editorial-page-number';number.textContent=String(index+1).toLocaleString('ar-EG-u-nu-latn');number.textContent=(index+1).toLocaleString('ar-EG-u-nu-latn');article.append(number);return article;}
  function updateReaderControls(){previous.disabled=turning||spreadIndex===0;next.disabled=turning||spreadIndex===3;root.querySelectorAll('[data-editorial-spread]').forEach(button=>{button.disabled=turning;button.setAttribute('aria-pressed',String(Number(button.dataset.editorialSpread)===spreadIndex));});}
  function renderSpread(){spread.replaceChildren(createPage(pages[spreadIndex*2],spreadIndex*2),createPage(pages[spreadIndex*2+1],spreadIndex*2+1));document.getElementById('editorial-book-status').textContent=`${(spreadIndex*2+1).toLocaleString('ar-EG-u-nu-latn')}–${(spreadIndex*2+2).toLocaleString('ar-EG-u-nu-latn')} من 8`;updateReaderControls();}
  function turnTo(index){if(turning||index<0||index>3||index===spreadIndex)return;const forward=index>spreadIndex;const clone=spread.children[forward?1:0].cloneNode(true);spreadIndex=index;renderSpread();if(motion.matches||matchMedia('(max-width:560px)').matches)return;turning=true;updateReaderControls();clone.classList.add('editorial-page-flip',forward?'is-forward':'is-backward');clone.setAttribute('aria-hidden','true');stage.append(clone);const finish=()=>{clearTimeout(flipTimer);clone.remove();turning=false;updateReaderControls();};clone.addEventListener('animationend',finish,{once:true});flipTimer=setTimeout(finish,650);}
  previous.addEventListener('click',()=>turnTo(spreadIndex-1));next.addEventListener('click',()=>turnTo(spreadIndex+1));root.querySelectorAll('[data-editorial-spread]').forEach(button=>button.addEventListener('click',()=>turnTo(Number(button.dataset.editorialSpread))));
  stage.addEventListener('keydown',event=>{if(event.key==='ArrowLeft'||event.key==='ArrowRight'){event.preventDefault();turnTo(spreadIndex+(event.key==='ArrowLeft'?1:-1));}});
  let touchStart;stage.addEventListener('touchstart',event=>{const touch=event.touches[0];touchStart={x:touch.clientX,y:touch.clientY};},{passive:true});stage.addEventListener('touchend',event=>{if(!touchStart)return;const touch=event.changedTouches[0],x=touch.clientX-touchStart.x,y=touch.clientY-touchStart.y;touchStart=null;if(Math.abs(x)>65&&Math.abs(x)>Math.abs(y)*1.5)turnTo(spreadIndex+(x>0?1:-1));},{passive:true});
  const expand=document.getElementById('editorial-reader-expand');
  function setExpanded(value){expanded=value;reader.classList.toggle('is-expanded',value);document.body.classList.toggle('editorial-reader-open',value);expand.setAttribute('aria-pressed',String(value));expand.setAttribute('aria-label',value?'إغلاق القراءة الموسعة':'تكبير قارئ المجلة');expand.textContent=value?'إغلاق القراءة ✕':'توسيع القراءة ↗';if(value){previousFocus=document.activeElement;reader.setAttribute('role','dialog');reader.setAttribute('aria-modal','true');reader.setAttribute('aria-label','قارئ مجلة الشهر');document.querySelector('.portal-header').inert=true;[...document.querySelectorAll('main > section')].filter(node=>node!==root).forEach(node=>node.inert=true);[...root.querySelector('.editorial-inner').children].filter(node=>!node.contains(reader)).forEach(node=>node.inert=true);document.querySelector('.editorial-magazine-intro').inert=true;document.querySelector('.portal-footer').inert=true;expand.focus();}else{reader.removeAttribute('role');reader.removeAttribute('aria-modal');reader.removeAttribute('aria-label');document.querySelectorAll('[inert]').forEach(node=>node.inert=false);previousFocus?.focus({preventScroll:true});}}
  expand.addEventListener('click',()=>setExpanded(!expanded));reader.addEventListener('keydown',event=>{if(!expanded)return;if(event.key==='Escape'){event.preventDefault();setExpanded(false);}if(event.key==='Tab'){const items=[...reader.querySelectorAll('button:not(:disabled),[tabindex="0"]')],first=items[0],last=items.at(-1);if(event.shiftKey&&document.activeElement===first){event.preventDefault();last.focus();}else if(!event.shiftKey&&document.activeElement===last){event.preventDefault();first.focus();}}});renderSpread();
})();
