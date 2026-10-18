(() => {
  const list = document.querySelector('.theme-majestic-headlines');
  if (!list) return;
  // Selected, dated ONA reports; these are not a live news feed.
  const breakingStory = {
        title: 'خبر عاجل', date: '2026-10-12', source: 'خبر تجريبي', breaking: true,
        details: ['أعلنت المؤسسة إطلاق بوابة جديدة للخدمات الرقمية، تتيح للموظفين متابعة طلباتهم والوصول إلى الخدمات من مكان واحد.', 'تبدأ تجربة البوابة خلال هذا الأسبوع، على أن تُجمع ملاحظات المستخدمين لتحسين سهولة الاستخدام وتسريع إنجاز المعاملات. هذا النص خبري تجريبي لمعاينة تصميم الأخبار العاجلة.']
  };
  const stories = [
    breakingStory,
    { title: 'متحف عُمان عبر الزمان يستقبل نحو 940 ألف زائر منذ افتتاحه', date: '2026-02-22', url: 'https://omannews.gov.om/topics/ar/119/show/464026/', image: 'https://alroya.om/thumb/830x506/uploads/images/2025/07/VBTAR.jpeg', imageCredit: 'صورة متحف عُمان عبر الزمان — صحيفة الرؤية' },
    { title: 'جنوب الشرقية: رقمنة 14 خدمة حكومية وإنجاز 5694 معاملة خلال 2025', date: '2026-01-25', url: 'https://omannews.gov.om/topics/ar/122/show/462778/rss.ona' },
    { title: 'إطلاق برنامج «تعزيز» لتمكين الفرق الأهلية الرياضية', date: '2026-01-25', url: 'https://omannews.gov.om/topics/ar/8/show/462804/ona' },
    { title: 'حلقة عمل مجلة نزوى توصي بمرصد ثقافي وتحديث رؤية المجلة', date: '2026-01-21', url: 'https://omannews.gov.om/topics/ar/6/show/462659/' },
    { title: '15 مليون ريال عُماني أثر اقتصادي مباشر لسياحة المؤتمرات والمعارض', date: '2026-01-03', url: 'https://omannews.gov.om/topics/ar/7/show/461916/rss.ona' }
  ];
  const publicationDate = new Intl.DateTimeFormat('ar-OM-u-nu-latn', { day: 'numeric', month: 'long', year: 'numeric', timeZone: 'Asia/Muscat' });
  stories.forEach(story => {
    const item = document.createElement('li'), button = document.createElement('button');
    const title = document.createElement('span'), heading = document.createElement('strong'), credit = document.createElement('small');
    item.classList.toggle('is-breaking', Boolean(story.breaking));
    item.classList.toggle('has-photo', Boolean(story.image));
    item.classList.toggle('is-featured', !list.children.length);
    if (story.image) {
      const image = document.createElement('img');
      image.src = story.image; image.alt = ''; image.title = story.imageCredit; image.decoding = 'async';
      image.width = 420; image.height = 220;
      image.addEventListener('error', () => { image.remove(); item.classList.remove('has-photo'); syncWindow(); });
      button.append(image);
    }
    heading.textContent = story.title;
    credit.textContent = `${story.breaking ? 'خبر عاجل · تجريبي' : 'العُمانية'} · ${publicationDate.format(new Date(`${story.date}T12:00:00+04:00`))}`;
    title.append(heading, credit);
    if(story.breaking){const summary=document.createElement('p');summary.textContent=story.details[0];title.append(summary);}
    button.type = 'button'; button.append(title);
    button.addEventListener('click', () => {if(story.breaking){document.querySelector('#editorial-news-paged-list .is-breaking .editorial-news-select')?.click();document.getElementById('editorial-news')?.scrollIntoView({block:'start',behavior:'smooth'});}else window.open(story.url, '_blank', 'noopener,noreferrer');});
    item.append(button); list.append(item);
  });
  const agencyNews = document.getElementById('editorial-agency-news');
  if (agencyNews) {
    const panel=agencyNews.classList.contains('editorial-news-panel');
    const panelStories = panel ? [...stories.filter(story=>!story.breaking),
      { title: 'والي بدبد يبحث تطوير رياضة الفروسية وتعزيز حضورها في الولاية', date: '2026-01-28', source: 'وزارة الداخلية', url: 'https://www.moi.gov.om/ar-om/news/والي-بدبد-يناقش-مع-لجنة-الفروسية-سبل-تطوير-رياضة-الفروسية-بالولاية-20260128084751290' },
      { title: 'ختام فعاليات «شتاء منح» بحضور أكثر من 15 ألف زائر', date: '2026-01-19', source: 'محافظة الداخلية', url: 'https://dg.gov.om/news/details/229' },
      { title: 'فعاليات «شتاء منح» تجمع الثقافة والتراث والترفيه', date: '2026-01-11', source: 'محافظة الداخلية', url: 'https://www.dg.gov.om/news/details/225' },
      { title: 'قطاعا التراث والسياحة يسجلان أداءً متقدمًا خلال 2025', date: '2025-11-22', url: 'https://omannews.gov.om/topics/ar/7/show/460048/rss.ona' }
    ] : stories;
    if(panel){
      const entries=[...panelStories.slice(1),panelStories[0]];
      const thumbnails=['./assets/hero-oman-mosque.png','./assets/hero-oman-fort.png','./assets/hero-oman-mosque.png','./assets/hero-oman-desert.png'];
      // Demonstration copy is explicitly labelled and is separate from the sourced report.
      entries[0]={...entries[0],details:[
        'يوضح هذا النموذج كيف تظهر التفاصيل الإضافية أسفل عنوان الخبر والصورة، مع الحفاظ على سهولة القراءة داخل الصفحة.',
        'يمكن أن تتضمن هذه المساحة وصفًا موسّعًا للخبر، وأبرز النقاط والمعلومات المرتبطة به. النص هنا توضيحي لتجربة العرض، وللاطلاع على التقرير المنشور استخدم رابط المصدر.'
      ]};
      entries.unshift(breakingStory);
      const feature=document.createElement('div');feature.className='editorial-news-feature';
      const toolbar=document.createElement('div');toolbar.className='editorial-news-feature-toolbar';
      const status=document.createElement('output');status.className='editorial-news-feature-status';
      const controls=document.createElement('div');controls.className='portal-arrow-controls';
      function control(label,text){const button=document.createElement('button');button.type='button';button.className='portal-arrow-button';button.setAttribute('aria-label',label);button.textContent=text;button.setAttribute('aria-controls','editorial-news-selected');controls.append(button);return button;}
      const previous=control('الخبر السابق','→'),next=control('الخبر التالي','←'),play=control('إيقاف التبديل التلقائي','Ⅱ');
      previous.dataset.agencyNewsPrev='';next.dataset.agencyNewsNext='';play.dataset.agencyNewsPlayback='';
      const selected=document.createElement('article');selected.className='editorial-news-feature-story';selected.id='editorial-news-selected';selected.setAttribute('aria-label','الخبر المعروض');
      toolbar.append(controls,status);feature.append(toolbar,selected);
      const stream=document.createElement('div');stream.className='editorial-news-stream';
      const streamHeader=document.createElement('header'),label=document.createElement('h4');
      label.textContent='آخر الأخبار';
      const listControls=document.createElement('div');listControls.className='editorial-news-list-controls';
      const pageStatus=document.createElement('output');pageStatus.className='editorial-news-page-status';pageStatus.setAttribute('aria-live','polite');pageStatus.setAttribute('aria-label','صفحة آخر الأخبار');
      const pageArrows=document.createElement('div');pageArrows.className='portal-arrow-controls';pageArrows.setAttribute('role','group');pageArrows.setAttribute('aria-label','صفحات آخر الأخبار');
      function pageButton(label,text){const button=document.createElement('button');button.type='button';button.className='portal-arrow-button';button.textContent=text;button.setAttribute('aria-label',label);button.setAttribute('aria-controls','editorial-news-paged-list');pageArrows.append(button);return button;}
      const pagePrevious=pageButton('صفحة الأخبار السابقة','→'),pageNext=pageButton('عرض المزيد من آخر الأخبار','←');pagePrevious.dataset.newsPagePrev='';pageNext.dataset.newsPageNext='';
      listControls.append(pageStatus,pageArrows);streamHeader.append(label,listControls);
      const newsList=document.createElement('ol');newsList.className='editorial-news-list';newsList.id='editorial-news-paged-list';newsList.setAttribute('aria-label','اختيار خبر لعرضه');
      stream.append(streamHeader,newsList);agencyNews.append(feature,stream);
      const rows=[];
      entries.forEach((story,index)=>{
        const item=document.createElement('li'),card=document.createElement('article'),copy=document.createElement('div'),thumbnail=document.createElement('img');
        card.className='editorial-news-list-story';item.classList.toggle('is-breaking',Boolean(story.breaking));copy.className='editorial-news-item-copy';
        thumbnail.className='editorial-news-thumbnail';thumbnail.src=story.image||thumbnails[index%thumbnails.length];thumbnail.alt='';thumbnail.title=story.imageCredit||'صورة توضيحية';thumbnail.loading='lazy';thumbnail.decoding='async';thumbnail.width=64;thumbnail.height=84;
        const header=document.createElement('header'),sequence=document.createElement('span'),source=document.createElement('span'),heading=document.createElement('h3'),button=document.createElement('button');
        sequence.className='editorial-news-sequence';sequence.textContent=String(index+1).padStart(2,'0');sequence.setAttribute('aria-hidden','true');source.textContent=story.source||'وكالة الأنباء العُمانية';if(story.breaking){source.className='editorial-news-breaking-badge';source.textContent='خبر عاجل · تجريبي';}header.append(sequence,source);
        button.type='button';button.className='editorial-news-select';button.textContent=story.title;button.setAttribute('aria-controls',selected.id);button.setAttribute('aria-pressed','false');heading.append(button);
        const footer=document.createElement('footer'),date=document.createElement('time'),hint=document.createElement('span');
        date.dateTime=story.date;date.textContent=publicationDate.format(new Date(story.date+'T12:00:00+04:00'));hint.className='editorial-news-preview-hint';hint.textContent=story.details?'عرض الخبر والتفاصيل ←':'عرض الخبر ←';
        footer.append(date,hint);copy.append(header,heading,footer);if(!story.breaking)card.append(thumbnail);card.append(copy);item.append(card);newsList.append(item);rows.push({item,button});
        card.addEventListener('click',()=>{show(index,true);if(matchMedia('(max-width:760px)').matches)feature.scrollIntoView({block:'start',behavior:'instant'});schedule();});
      });
      const pageSize=8,pageCount=Math.ceil(entries.length/pageSize);let currentPage=0;
      function showPage(page){
        currentPage=Math.max(0,Math.min(pageCount-1,page));
        rows.forEach((row,i)=>{row.item.hidden=i<currentPage*pageSize||i>=(currentPage+1)*pageSize;});
        pageStatus.textContent=(currentPage+1)+' / '+pageCount;
        pagePrevious.disabled=currentPage===0;pageNext.disabled=currentPage===pageCount-1;
      }
      pagePrevious.addEventListener('click',()=>showPage(currentPage-1));pageNext.addEventListener('click',()=>showPage(currentPage+1));showPage(0);
      let active=0,timer,visible=false,hovered=false,focused=false,playing=!matchMedia('(prefers-reduced-motion: reduce)').matches;
      function show(index,manual=false){
        active=(index+entries.length)%entries.length;
        const story=entries[active],visual=document.createElement('div'),image=document.createElement('img'),caption=document.createElement('span'),copy=document.createElement('div');
        visual.className='editorial-news-card-image';image.src=story.image||thumbnails[active%thumbnails.length];image.alt=story.image?story.title:'';image.decoding='async';caption.textContent=story.imageCredit||'صورة توضيحية';visual.append(image,caption);
        const header=document.createElement('header'),source=document.createElement('span'),heading=document.createElement('h3'),footer=document.createElement('footer'),date=document.createElement('time'),link=document.createElement('a');
        copy.className='editorial-news-item-copy';source.textContent=story.source||'وكالة الأنباء العُمانية';if(story.breaking){source.className='editorial-news-breaking-badge';source.textContent='خبر عاجل · تجريبي';}header.append(source);heading.textContent=story.title;heading.id='editorial-news-selected-title';selected.classList.toggle('is-breaking',Boolean(story.breaking));selected.setAttribute('aria-labelledby',heading.id);
        date.dateTime=story.date;date.textContent=publicationDate.format(new Date(story.date+'T12:00:00+04:00'));link.href=story.url;link.target='_blank';link.rel='noopener noreferrer';link.textContent='اقرأ الخبر من المصدر ↗';footer.append(date);if(story.url)footer.append(link);copy.append(header,heading,footer);
        selected.replaceChildren(...(story.breaking?[copy]:[visual,copy]));
        if(story.details?.length){const details=document.createElement('section'),title=document.createElement('h4');details.className='editorial-news-details';title.textContent='تفاصيل الخبر — نموذج توضيحي';details.append(title);story.details.forEach(text=>{const paragraph=document.createElement('p');paragraph.textContent=text;details.append(paragraph);});selected.append(details);}
        rows.forEach((row,i)=>{row.item.classList.toggle('is-selected',i===active);row.button.setAttribute('aria-pressed',String(i===active));});
        status.setAttribute('aria-live',manual?'polite':'off');status.textContent=(active+1)+' / '+entries.length;
      }
      function schedule(){clearTimeout(timer);if(playing&&visible&&!hovered&&!focused&&!document.hidden)timer=setTimeout(()=>{show(active+1);schedule();},7000);}
      function syncPlayback(){
        const svg=document.createElementNS('http://www.w3.org/2000/svg','svg');svg.setAttribute('viewBox','0 0 24 24');svg.setAttribute('width','20');svg.setAttribute('height','20');svg.setAttribute('fill','currentColor');svg.setAttribute('aria-hidden','true');
        const shape=document.createElementNS('http://www.w3.org/2000/svg','path');shape.setAttribute('d',playing?'M6 4h4v16H6zM14 4h4v16h-4z':'M8 4v16l12-8z');svg.append(shape);play.replaceChildren(svg);
        const label=playing?'إيقاف التبديل التلقائي مؤقتًا':'تشغيل التبديل التلقائي';play.setAttribute('aria-label',label);play.title=label;play.setAttribute('aria-pressed',String(playing));schedule();
      }
      previous.addEventListener('click',()=>{show(active-1,true);schedule();});next.addEventListener('click',()=>{show(active+1,true);schedule();});play.addEventListener('click',()=>{playing=!playing;syncPlayback();});
      agencyNews.addEventListener('mouseenter',()=>{hovered=true;schedule();});agencyNews.addEventListener('mouseleave',()=>{hovered=false;schedule();});
      agencyNews.addEventListener('focusin',()=>{focused=true;schedule();});agencyNews.addEventListener('focusout',()=>{setTimeout(()=>{focused=agencyNews.contains(document.activeElement);schedule();},0);});
      document.addEventListener('visibilitychange',schedule);
      new IntersectionObserver(([entry])=>{visible=entry.isIntersecting;schedule();},{threshold:0.15}).observe(agencyNews);
      show(0);syncPlayback();
    }else{
      // Keep the original card layout and source actions for the other design.
      stories.forEach(story=>{
        const card=document.createElement('article'),copy=document.createElement('div');card.className='editorial-news-card';copy.className='editorial-news-card-copy';
        if(story.image){card.classList.add('editorial-news-card-featured');const visual=document.createElement('div'),image=document.createElement('img'),caption=document.createElement('span');visual.className='editorial-news-card-image';image.src=story.image;image.alt='متحف عُمان عبر الزمان';image.loading='lazy';image.decoding='async';caption.textContent=story.imageCredit;image.addEventListener('error',()=>{visual.remove();card.classList.remove('editorial-news-card-featured');});visual.append(image,caption);card.append(visual);}
        const header=document.createElement('header'),source=document.createElement('span'),heading=document.createElement('h3'),footer=document.createElement('footer'),date=document.createElement('time'),action=document.createElement('button');source.textContent='وكالة الأنباء العُمانية';header.append(source);heading.textContent=story.title;date.dateTime=story.date;date.textContent=publicationDate.format(new Date(story.date+'T12:00:00+04:00'));action.type='button';action.textContent='اقرأ الخبر ↗';action.addEventListener('click',()=>window.open(story.url,'_blank','noopener,noreferrer'));footer.append(date,action);copy.append(header,heading,footer);card.append(copy);agencyNews.append(card);
      });
    }
  }
  const dates = ['theme-majestic-today', 'editorial-current-date'].map(id => document.getElementById(id)).filter(Boolean);
  if (dates.length) {
    const options = { day: 'numeric', month: 'long', year: 'numeric', timeZone: 'Asia/Muscat' };
    const gregorian = new Intl.DateTimeFormat('ar-OM-u-ca-gregory-nu-latn', { ...options, weekday: 'long' });
    const hijri = new Intl.DateTimeFormat('ar-OM-u-ca-islamic-nu-latn', options);
    const updateDate = () => {
      const now = new Date();
      dates.forEach(today => {
        today.firstElementChild.textContent = `اليوم ${gregorian.format(now)}`;
        today.lastElementChild.textContent = `الموافق ${hijri.format(now)}`;
      });
    };
    updateDate();
    setInterval(updateDate, 60000);
    document.addEventListener('visibilitychange', updateDate);
  }
  const panel = list.closest('.theme-majestic-news');
  const controls = [...panel.querySelectorAll('.theme-majestic-news-controls button')];
  const motion = matchMedia('(prefers-reduced-motion: reduce)');
  let timer, rotating = false, visible = false, hovered = false, focused = false;
  function syncWindow() {
    [...list.children].forEach((item, index) => { item.inert = index >= 3; });
  }
  function setRotating(value) {
    rotating = value;
    list.classList.toggle('is-rotating', value);
    controls.forEach(button => { button.disabled = value; });
  }
  function rotate(direction = 1) {
    if (rotating) return;
    clearTimeout(timer);
    const first = list.firstElementChild;
    const incoming = direction > 0 ? list.children[1] : list.lastElementChild;
    setRotating(true);
    if (direction > 0) {
      first.classList.add('is-leaving');
      incoming.classList.add('is-featured');
    } else {
      incoming.classList.add('is-featured', 'is-arriving', 'is-resetting');
      list.prepend(incoming);
      first.classList.remove('is-featured');
      // Commit the collapsed start before smoothly revealing the previous news.
      void incoming.offsetHeight;
      incoming.classList.remove('is-resetting');
      requestAnimationFrame(() => incoming.classList.remove('is-arriving'));
    }
    syncWindow();
    setTimeout(() => {
      if (direction > 0) {
        first.classList.add('is-resetting');
        list.append(first);
        first.classList.remove('is-featured', 'is-leaving');
      }
      requestAnimationFrame(() => requestAnimationFrame(() => {
        first.classList.remove('is-resetting');
        setRotating(false);
        syncWindow();
        schedule();
      }));
    }, motion.matches ? 0 : 1200);
  }
  syncWindow();
  panel.querySelector('[data-news-prev]').addEventListener('click', () => rotate(-1));
  panel.querySelector('[data-news-next]').addEventListener('click', () => rotate(1));
  function schedule() {
    clearTimeout(timer);
    if (rotating || !visible || hovered || focused || motion.matches || document.hidden || !['majestic', 'formal'].includes(document.body.dataset.siteTheme) || list.children.length < 2) return;
    timer = setTimeout(() => rotate(1), 6500);
  }
  new IntersectionObserver(entries => { visible = entries[0].isIntersecting; schedule(); }).observe(panel);
  panel.addEventListener('pointerenter', () => { hovered = true; schedule(); });
  panel.addEventListener('pointerleave', () => { hovered = false; schedule(); });
  panel.addEventListener('focusin', () => { focused = true; schedule(); });
  panel.addEventListener('focusout', event => { focused = panel.contains(event.relatedTarget); schedule(); });
  motion.addEventListener('change', schedule);
  document.addEventListener('visibilitychange', schedule);
  document.addEventListener('companyportal:theme-change', schedule);
})();
