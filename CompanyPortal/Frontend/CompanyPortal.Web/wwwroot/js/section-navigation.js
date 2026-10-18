(() => {
  const widget=document.querySelector('.portal-section-float');if(!widget)return;
  if (widget.classList.contains('portal-floating-calendar')) return;
  const labels={systems:'مساحة العمل',media:'الأخبار والوسائط','editorial-magazine':'مجلة الشهر',policies:'توجيهات وقوانين',library:document.getElementById('library-title')?.textContent.trim()||'الأنظمة الرقمية'};
  const sections=[...document.querySelectorAll('main > .portal-section[id], main > .portal-personal-zone > .portal-section[id]')].filter(node=>!node.hidden).map(node=>({node,title:labels[node.id]||node.querySelector('h2,h1')?.textContent.trim()||node.id}));
  if(!sections.length){widget.hidden=true;return;}
  const previous=document.getElementById('portal-section-previous'),next=document.getElementById('portal-section-next'),toggle=document.getElementById('portal-section-float-toggle'),body=document.getElementById('portal-section-float-body'),progress=document.getElementById('portal-section-progress');
  const number=value=>value.toLocaleString('ar-EG-u-nu-latn',{minimumIntegerDigits:2});
  const motion=matchMedia('(prefers-reduced-motion: reduce)');let current=-1,queued=false;
  function update(){
    queued=false;const anchor=Math.max(115,window.innerHeight*.28);let index=0;
    sections.forEach((section,i)=>{if(section.node.getBoundingClientRect().top<=anchor)index=i;});
    const maximum=Math.max(0,document.documentElement.scrollHeight-window.innerHeight);
    if(maximum>0&&window.scrollY>=maximum-3)index=sections.length-1;
    progress.style.transform=`scaleX(${maximum?Math.min(1,Math.max(0,window.scrollY/maximum)):1})`;
    if(index===current)return;current=index;
    document.getElementById('portal-section-current-title').textContent=sections[index].title;
    document.getElementById('portal-section-position').textContent=`${number(index+1)} / ${number(sections.length)}`;
    previous.disabled=index===0;next.disabled=index===sections.length-1;
    document.getElementById('portal-section-previous-title').textContent=sections[index-1]?.title||'أنت في بداية الصفحة';
    document.getElementById('portal-section-next-title').textContent=sections[index+1]?.title||'وصلت إلى نهاية الصفحة';
    previous.setAttribute('aria-label',previous.disabled?'لا يوجد قسم سابق':`التمرير لأعلى إلى ${sections[index-1].title}`);
    next.setAttribute('aria-label',next.disabled?'لا يوجد قسم تالٍ':`التمرير لأسفل إلى ${sections[index+1].title}`);
  }
  function schedule(){if(!queued){queued=true;requestAnimationFrame(update);}}
  function navigate(step){const target=sections[current+step];if(!target)return;target.node.scrollIntoView({behavior:motion.matches?'instant':'smooth',block:'start'});}
  previous.addEventListener('click',()=>navigate(-1));next.addEventListener('click',()=>navigate(1));
  toggle?.addEventListener('click',()=>{const collapsed=!body.hidden;body.hidden=collapsed;toggle.setAttribute('aria-expanded',String(!collapsed));toggle.setAttribute('aria-label',collapsed?'توسيع بطاقة التنقل':'طي بطاقة التنقل');const icon=toggle.querySelector('path');if(!icon)toggle.textContent=collapsed?'+':'−';icon?.setAttribute('d',collapsed?'M14 4h6v6M20 4l-7 7M10 20H4v-6M4 20l7-7':'M20 10h-6V4M14 10l7-7M4 14h6v6M10 14l-7 7');});
  const notices=widget.querySelector('.bf-notices');
  notices?.addEventListener('click',event=>{
    const close=event.target.closest('.bf-notice-close');if(!close)return;
    close.closest('.bf-notice').remove();const remaining=notices.querySelectorAll('.bf-notice');
    document.getElementById('bf-notice-count').textContent=remaining.length.toLocaleString('ar-EG-u-nu-latn');notices.hidden=remaining.length===0;
    (notices.querySelector('.bf-notice-close')||toggle).focus({preventScroll:true});
    if(typeof showToast==='function')showToast('تم حذف الإشعار من البطاقة العائمة');
  });
  window.addEventListener('scroll',schedule,{passive:true});window.addEventListener('resize',schedule,{passive:true});
  const observer=new ResizeObserver(schedule);observer.observe(document.querySelector('main'));update();
})();
