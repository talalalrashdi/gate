(() => {
  const root=document.querySelector('.b-editorial');if(!root)return;
  const techTrack=root.querySelector('#ed-tech-track'),techPrev=root.querySelector('#ed-tech-prev'),techNext=root.querySelector('#ed-tech-next');
  if(techTrack&&techPrev&&techNext){
    function updateTechControls(){const max=Math.max(0,techTrack.scrollWidth-techTrack.clientWidth),position=Math.abs(techTrack.scrollLeft);techPrev.disabled=position<2;techNext.disabled=position>=max-2;}
    function moveTech(direction){const card=techTrack.firstElementChild;if(!card)return;const step=card.getBoundingClientRect().width+(parseFloat(getComputedStyle(techTrack).columnGap)||0);techTrack.scrollBy({left:direction*step,behavior:matchMedia('(prefers-reduced-motion: reduce)').matches?'instant':'smooth'});}
    techPrev.addEventListener('click',()=>moveTech(1));techNext.addEventListener('click',()=>moveTech(-1));
    techTrack.addEventListener('scroll',updateTechControls,{passive:true});techTrack.addEventListener('keydown',event=>{if(event.target!==techTrack)return;if(event.key==='ArrowLeft'||event.key==='ArrowRight'){event.preventDefault();moveTech(event.key==='ArrowLeft'?-1:1);}});
    techTrack.addEventListener('focusin',event=>{const card=event.target.closest('.ed-article-card');if(!card)return;const bounds=card.getBoundingClientRect(),viewport=techTrack.getBoundingClientRect();if(bounds.left<viewport.left||bounds.right>viewport.right)card.scrollIntoView({behavior:'instant',block:'nearest',inline:'nearest'});});
    new ResizeObserver(updateTechControls).observe(techTrack);updateTechControls();
  }
  const sectionNav=document.querySelector('.b-media-subnav'),navTrack=sectionNav.querySelector('.b-media-subnav-links');
  const editorialMotion=matchMedia('(prefers-reduced-motion: reduce)');
  const navItems=[...sectionNav.querySelectorAll('a[href^="#"]')].map(link=>({link,target:document.querySelector(link.getAttribute('href'))})).filter(item=>item.target);
  let activeNavLink=null,navFrame=false;
  function markNav(link){
    if(activeNavLink===link)return;activeNavLink=link;
    navItems.forEach(item=>{if(item.link===link)item.link.setAttribute('aria-current','location');else item.link.removeAttribute('aria-current');});
    if(link){const bounds=navTrack.getBoundingClientRect(),item=link.getBoundingClientRect();if(item.left<bounds.left||item.right>bounds.right)navTrack.scrollBy({left:item.left+item.width/2-bounds.left-bounds.width/2,behavior:editorialMotion.matches?'instant':'smooth'});}
  }
  function updateDock(){
    navFrame=false;
    // Read geometry together before changing styles to avoid repeated layout work.
    const bounds=root.getBoundingClientRect(),anchor=Math.max(sectionNav.getBoundingClientRect().bottom+24,window.innerHeight*.28);
    const inSection=bounds.top<=anchor&&bounds.bottom>anchor;
    let nextLink=null;
    if(inSection){
      const positions=navItems.map(item=>({item,rect:item.target.getBoundingClientRect()}));
      const visible=positions.filter(({rect})=>rect.top<=anchor&&rect.bottom>anchor);
      const candidate=visible.find(({item})=>item.link===activeNavLink)||visible[0];
      nextLink=(candidate?.item||positions.filter(({rect})=>rect.top<=anchor).at(-1)?.item||navItems[0])?.link;
    }
    if(bounds.top<window.innerHeight*.85)root.classList.add('ed-has-entered');
    markNav(nextLink);
  }
  function scheduleDock(){if(!navFrame){navFrame=true;requestAnimationFrame(updateDock);}}
  navItems.forEach(item=>item.link.addEventListener('click',()=>markNav(item.link)));
  window.addEventListener('scroll',scheduleDock,{passive:true});window.addEventListener('resize',scheduleDock,{passive:true});
  document.addEventListener('visibilitychange',scheduleDock);editorialMotion.addEventListener('change',scheduleDock);
  new ResizeObserver(scheduleDock).observe(root);updateDock();
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
  const readingDialog=document.getElementById('ed-reading-dialog');
  function openEditorialArticle(id){
    const item=articles[id];if(!item)return;
    document.getElementById('ed-reading-title').textContent=item.title;
    const copy=document.getElementById('ed-reading-copy');copy.replaceChildren();
    item.paragraphs.forEach(text=>{const paragraph=document.createElement('p');paragraph.textContent=text;copy.append(paragraph);});if(!readingDialog.open)readingDialog.showModal();readingDialog.scrollTop=0;
  }
  root.querySelectorAll('[data-ed-read]').forEach(button=>button.addEventListener('click',()=>openEditorialArticle(button.dataset.edRead)));
  const collections={news:{title:'أخبار عامة',ids:['collaboration','services','knowledge']},articles:{title:'المقالات',ids:['focus','meetings']},summaries:{title:'الملخصات',ids:['summary-week','summary-project','summary-reading']},tech:{title:'التقنية',ids:['tech-workflow','tech-knowledge','tech-lab','tech-dashboard']},books:{title:'رفّ الكتب',ids:['book-work','book-team','book-ideas','book-writing','book-learning','book-time']}};
  root.querySelectorAll('[data-ed-more]').forEach(button=>button.addEventListener('click',()=>{
    const kind=button.dataset.edMore,collection=collections[kind];
    document.getElementById('ed-reading-title').textContent=collection?.title||'صور وفيديو الفعاليات';
    const copy=document.getElementById('ed-reading-copy');copy.replaceChildren();const list=document.createElement('div');list.className='ed-more-list';
    function addItem(title,action){const row=document.createElement('button');row.type='button';const text=document.createElement('span'),arrow=document.createElement('span');text.textContent=title;arrow.textContent='←';arrow.setAttribute('aria-hidden','true');row.append(text,arrow);row.addEventListener('click',action);list.append(row);}
    if(collection)collection.ids.forEach(id=>addItem(articles[id].title,()=>openEditorialArticle(id)));
    else {addItem('ألبوم الصور — بعدساتنا، عُمان أقرب',()=>{readingDialog.close();root.querySelector('[data-ed-gallery]').click();});addItem('فيديو الفعالية — المشاهدة أو اختيار ملف محلي',()=>{readingDialog.close();const target=root.querySelector('.ed-video-card');target.setAttribute('tabindex','-1');target.focus({preventScroll:true});target.scrollIntoView({behavior:matchMedia('(prefers-reduced-motion: reduce)').matches?'instant':'smooth',block:'center'});});}
    copy.append(list);readingDialog.showModal();
  }));
  document.querySelectorAll('.ed-dialog [data-ed-close]').forEach(button=>button.addEventListener('click',()=>button.closest('dialog').close()));
  let saved=[];try{const value=JSON.parse(localStorage.getItem('clerio-editorial-saved')||'[]');if(Array.isArray(value))saved=value.filter(id=>typeof id==='string');}catch{}
  root.querySelectorAll('[data-ed-save]').forEach(button=>{
    const id=button.dataset.edSave;const title=articles[id].title;
    const update=()=>{const selected=saved.includes(id);button.setAttribute('aria-pressed',String(selected));button.setAttribute('aria-label',`${selected?'إلغاء حفظ':'حفظ'} ${title}`);};update();
    button.addEventListener('click',()=>{saved=saved.includes(id)?saved.filter(value=>value!==id):[...saved,id];try{localStorage.setItem('clerio-editorial-saved',JSON.stringify(saved));}catch{}update();});
  });
  const photos=[{src:'./assets/hero-oman-desert.png',caption:'رمال عُمان · صورة توضيحية'},{src:'./assets/hero-oman-fort.png',caption:'قلاع وحصون · صورة توضيحية'},{src:'./assets/hero-oman-mosque.png',caption:'جمال العمارة العُمانية · صورة توضيحية'}];
  const gallery=document.getElementById('ed-gallery-dialog');let photoIndex=0;
  function renderPhoto(){const photo=photos[photoIndex],image=document.getElementById('ed-gallery-image');image.src=photo.src;image.alt=photo.caption;document.getElementById('ed-gallery-caption').textContent=photo.caption;document.getElementById('ed-gallery-status').textContent=`${(photoIndex+1).toLocaleString('ar-EG-u-nu-latn')} / ${photos.length.toLocaleString('ar-EG-u-nu-latn')}`;document.getElementById('ed-gallery-prev').disabled=photoIndex===0;document.getElementById('ed-gallery-next').disabled=photoIndex===photos.length-1;}
  root.querySelector('[data-ed-gallery]').addEventListener('click',()=>{photoIndex=0;renderPhoto();gallery.showModal();});
  function movePhoto(step){photoIndex=Math.max(0,Math.min(photos.length-1,photoIndex+step));renderPhoto();}
  document.getElementById('ed-gallery-prev').addEventListener('click',()=>movePhoto(-1));document.getElementById('ed-gallery-next').addEventListener('click',()=>movePhoto(1));
  gallery.addEventListener('keydown',event=>{if(event.key==='ArrowLeft'||event.key==='ArrowRight'){event.preventDefault();movePhoto(event.key==='ArrowLeft'?1:-1);}});
  const video=document.getElementById('ed-event-video');let videoURL;
  document.getElementById('ed-video-file').addEventListener('change',event=>{
    const file=event.target.files[0];if(!file)return;if(!file.type.startsWith('video/')){document.getElementById('ed-video-note').textContent='اختر ملف فيديو صالحًا للمعاينة.';return;}
    video.pause();if(videoURL)URL.revokeObjectURL(videoURL);videoURL=URL.createObjectURL(file);video.src=videoURL;video.load();document.getElementById('ed-video-note').textContent=`معاينة محلية: ${file.name}`;
  });
  video.addEventListener('error',()=>{if(videoURL)document.getElementById('ed-video-note').textContent='تعذّر تشغيل هذا الملف. جرّب فيديو MP4 متوافقًا مع المتصفح.';});
  window.addEventListener('pagehide',()=>{if(videoURL)URL.revokeObjectURL(videoURL);});

  if(!document.getElementById('ed-book-stage'))return;
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
  const stage=document.getElementById('ed-book-stage'),spread=document.getElementById('ed-spread'),reader=document.getElementById('ed-magazine-reader'),previous=document.getElementById('ed-book-prev'),next=document.getElementById('ed-book-next');
  const motion=matchMedia('(prefers-reduced-motion: reduce)');let spreadIndex=0,turning=false,flipTimer,expanded=false,previousFocus;
  function createPage(page,index){const article=document.createElement('article');article.className=`ed-page${page.cover?' ed-mag-cover':''}`;const kicker=document.createElement('small');kicker.textContent=page.kicker;const title=document.createElement('h4');title.textContent=page.title;article.append(kicker,title);if(page.image){const image=document.createElement('img');image.loading='lazy';image.decoding='async';image.src=page.image;image.alt=page.title+' — صورة توضيحية';article.append(image);}page.text.forEach(text=>{const paragraph=document.createElement('p');paragraph.textContent=text;article.append(paragraph);});if(page.list){const list=document.createElement('ul');page.list.forEach(text=>{const item=document.createElement('li');item.textContent=text;list.append(item);});article.append(list);}const number=document.createElement('footer');number.className='ed-page-number';number.textContent=String(index+1).toLocaleString('ar-EG-u-nu-latn');number.textContent=(index+1).toLocaleString('ar-EG-u-nu-latn');article.append(number);return article;}
  function updateReaderControls(){previous.disabled=turning||spreadIndex===0;next.disabled=turning||spreadIndex===3;root.querySelectorAll('[data-ed-spread]').forEach(button=>{button.disabled=turning;button.setAttribute('aria-pressed',String(Number(button.dataset.edSpread)===spreadIndex));});}
  function renderSpread(){spread.replaceChildren(createPage(pages[spreadIndex*2],spreadIndex*2),createPage(pages[spreadIndex*2+1],spreadIndex*2+1));document.getElementById('ed-book-status').textContent=`${(spreadIndex*2+1).toLocaleString('ar-EG-u-nu-latn')}–${(spreadIndex*2+2).toLocaleString('ar-EG-u-nu-latn')} من 8`;updateReaderControls();}
  function turnTo(index){if(turning||index<0||index>3||index===spreadIndex)return;const forward=index>spreadIndex;const clone=spread.children[forward?1:0].cloneNode(true);spreadIndex=index;renderSpread();if(motion.matches||matchMedia('(max-width:560px)').matches)return;turning=true;updateReaderControls();clone.classList.add('ed-page-flip',forward?'is-forward':'is-backward');clone.setAttribute('aria-hidden','true');stage.append(clone);const finish=()=>{clearTimeout(flipTimer);clone.remove();turning=false;updateReaderControls();};clone.addEventListener('animationend',finish,{once:true});flipTimer=setTimeout(finish,650);}
  previous.addEventListener('click',()=>turnTo(spreadIndex-1));next.addEventListener('click',()=>turnTo(spreadIndex+1));root.querySelectorAll('[data-ed-spread]').forEach(button=>button.addEventListener('click',()=>turnTo(Number(button.dataset.edSpread))));
  stage.addEventListener('keydown',event=>{if(event.key==='ArrowLeft'||event.key==='ArrowRight'){event.preventDefault();turnTo(spreadIndex+(event.key==='ArrowLeft'?1:-1));}});
  let touchStart;stage.addEventListener('touchstart',event=>{const touch=event.touches[0];touchStart={x:touch.clientX,y:touch.clientY};},{passive:true});stage.addEventListener('touchend',event=>{if(!touchStart)return;const touch=event.changedTouches[0],x=touch.clientX-touchStart.x,y=touch.clientY-touchStart.y;touchStart=null;if(Math.abs(x)>65&&Math.abs(x)>Math.abs(y)*1.5)turnTo(spreadIndex+(x>0?1:-1));},{passive:true});
  const expand=document.getElementById('ed-reader-expand');
  function setExpanded(value){expanded=value;reader.classList.toggle('is-expanded',value);document.body.classList.toggle('ed-reader-open',value);expand.setAttribute('aria-pressed',String(value));expand.setAttribute('aria-label',value?'إغلاق القراءة الموسعة':'تكبير قارئ المجلة');expand.textContent=value?'إغلاق القراءة ✕':'توسيع القراءة ↗';if(value){previousFocus=document.activeElement;reader.setAttribute('role','dialog');reader.setAttribute('aria-modal','true');reader.setAttribute('aria-label','قارئ مجلة الشهر');document.querySelector('.b-header').inert=true;[...document.querySelectorAll('main > section')].filter(node=>node!==root).forEach(node=>node.inert=true);[...root.querySelector('.ed-inner').children].filter(node=>!node.contains(reader)).forEach(node=>node.inert=true);document.querySelector('.ed-magazine-intro').inert=true;document.querySelector('.b-footer').inert=true;expand.focus();}else{reader.removeAttribute('role');reader.removeAttribute('aria-modal');reader.removeAttribute('aria-label');document.querySelectorAll('[inert]').forEach(node=>node.inert=false);previousFocus?.focus({preventScroll:true});}}
  expand.addEventListener('click',()=>setExpanded(!expanded));reader.addEventListener('keydown',event=>{if(!expanded)return;if(event.key==='Escape'){event.preventDefault();setExpanded(false);}if(event.key==='Tab'){const items=[...reader.querySelectorAll('button:not(:disabled),[tabindex="0"]')],first=items[0],last=items.at(-1);if(event.shiftKey&&document.activeElement===first){event.preventDefault();last.focus();}else if(!event.shiftKey&&document.activeElement===last){event.preventDefault();first.focus();}}});renderSpread();
})();
