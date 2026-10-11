(() => {
  const notice = document.getElementById('b-floating-notice');
  const source = document.getElementById('b-alerts-section');
  if (!notice || !source) return;
  const cards = [...source.querySelectorAll('.b-alert')];
  const content = notice.querySelector('.b-floating-notice-content');
  const previous = notice.querySelector('.b-floating-notice-prev');
  const next = notice.querySelector('.b-floating-notice-next');
  const tones = { 'قرار جديد': 'decision', 'تنبيه نظام': 'system', 'فرصة تعلّم': 'learning', 'دعوة لقاء': 'meeting', 'تذكير مهم': 'reminder', 'تحديث الموظفين': 'people' };
  const paging=document.createElement('div');paging.className='b-floating-notice-paging';paging.setAttribute('role','group');paging.setAttribute('aria-label','التنقّل بين التنبيهات');
  previous.before(paging);paging.append(previous,notice.querySelector('.b-floating-notice-position'),next);
  const timer=document.createElementNS('http://www.w3.org/2000/svg','svg');timer.classList.add('b-floating-notice-timer');timer.setAttribute('aria-hidden','true');
  const track=document.createElementNS('http://www.w3.org/2000/svg','rect'),progress=document.createElementNS('http://www.w3.org/2000/svg','rect');
  track.classList.add('b-floating-notice-timer-track');progress.classList.add('b-floating-notice-timer-progress');progress.setAttribute('pathLength','100');timer.append(track,progress);paging.prepend(timer);
  new ResizeObserver(()=>{const width=paging.clientWidth,height=paging.clientHeight;timer.setAttribute('viewBox','0 0 '+width+' '+height);[track,progress].forEach(rect=>{rect.setAttribute('x','1');rect.setAttribute('y','1');rect.setAttribute('width',Math.max(0,width-2));rect.setAttribute('height',Math.max(0,height-2));rect.setAttribute('rx',Math.max(0,height/2-1));});}).observe(paging);
  const duration=8000;
  let index=0,elapsed=0,lastTime=null,frame=0,hovered=false,focused=false,visible=false;
  function canRun(){return active().length>1&&!notice.hidden&&visible&&!document.hidden&&!hovered&&!focused&&!document.querySelector('dialog[open]');}
  function paintTimer(){
    const remaining=Math.max(0,1-elapsed/duration);progress.style.strokeDashoffset=String((1-remaining)*100);
    const running=canRun();notice.dataset.autoplay=active().length<2?'idle':running?'running':'paused';
    const title=running?'التنبيه التالي بعد '+Math.ceil(remaining*duration/1000)+' ثوانٍ':'المؤقت متوقف أثناء القراءة أو التفاعل';if(paging.title!==title)paging.title=title;
  }
  function tick(now){
    frame=0;if(!canRun()){lastTime=null;paintTimer();return;}
    if(lastTime!==null)elapsed+=Math.min(now-lastTime,250);lastTime=now;
    if(elapsed>=duration){index=(index+1)%active().length;render();return;}
    paintTimer();frame=requestAnimationFrame(tick);
  }
  function syncTimer(){cancelAnimationFrame(frame);frame=0;lastTime=null;paintTimer();if(canRun())frame=requestAnimationFrame(tick);}
  function resetTimer(){elapsed=0;timer.toggleAttribute('hidden',active().length<2);syncTimer();}
  notice.addEventListener('mouseenter',()=>{hovered=true;syncTimer();});notice.addEventListener('mouseleave',()=>{hovered=false;syncTimer();});
  notice.addEventListener('focusin',()=>{focused=true;syncTimer();});notice.addEventListener('focusout',()=>{setTimeout(()=>{focused=notice.contains(document.activeElement);syncTimer();},0);});
  document.addEventListener('visibilitychange',syncTimer);
  new IntersectionObserver(([entry])=>{visible=entry.isIntersecting;syncTimer();}).observe(notice);
  new MutationObserver(syncTimer).observe(document.body,{subtree:true,attributes:true,attributeFilter:['open']});
  notice.closest('[popover]')?.addEventListener('toggle',syncTimer);
  window.addEventListener('pagehide',()=>{cancelAnimationFrame(frame);frame=0;lastTime=null;});window.addEventListener('pageshow',syncTimer);
  const active = () => cards.filter(card => !card.hidden);
  function render() {
    const remaining = active();
    index = Math.max(0,Math.min(index, Math.max(0, remaining.length - 1)));
    notice.hidden = !remaining.length;
    if (!remaining.length) { resetTimer(); return; }
    const card = remaining[index];
    const title = card.querySelector('h3').textContent;
    const type = card.querySelector('.b-alert-badge')?.textContent.trim() || '';
    notice.dataset.tone = tones[type] || 'system';
    content.querySelector('span').textContent = type;
    content.querySelector('strong').textContent = title;
    content.querySelector('small').textContent = card.querySelector('p').textContent;
    content.setAttribute('aria-label', `عرض تفاصيل ${title}`);
    notice.querySelector('.b-floating-notice-position').textContent = `${index + 1} / ${remaining.length}`;
    previous.disabled = index === 0;
    next.disabled = index >= remaining.length - 1;
    resetTimer();
  }
  previous.addEventListener('click', () => { index--; render(); });
  next.addEventListener('click', () => { index++; render(); });
  content.addEventListener('click', () => active()[index]?.querySelector('.b-alert-open')?.click());
  notice.querySelector('.b-floating-notice-all').addEventListener('click', () => source.querySelector('.bn-all')?.click());
  notice.querySelector('.b-floating-notice-close').addEventListener('click', () => {
    const card = active()[index];
    if (card) card.hidden = true;
    render();
    (notice.hidden ? document.getElementById('b-calendar-toggle') : notice.querySelector('.b-floating-notice-close')).focus({ preventScroll: true });
  });
  const observer = new MutationObserver(render);
  cards.forEach(card => observer.observe(card, { attributes: true, attributeFilter: ['hidden'] }));
  render();
})();
