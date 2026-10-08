(() => {
  const workspace=document.getElementById('workspace-cards');if(!workspace)return;
  const key='clerio-workspace-card-order-v1';
  const concealKey='clerio-workspace-concealed-cards-v1';
  const cards=[...workspace.querySelectorAll('[data-work-system]')];
  const byId=new Map(cards.map(card=>[card.dataset.workSystem,card]));
  const visible=()=>[...workspace.querySelectorAll('[data-work-system]')].filter(card=>!card.hidden);
  let concealed;try{const saved=JSON.parse(localStorage.getItem(concealKey));concealed=new Set(Array.isArray(saved)?saved:[]);}catch{concealed=new Set();}
  let drag=null,frame=0;
  function refresh(){if(typeof updateWorkspaceNavigation==='function')updateWorkspaceNavigation();}
  function restore(raw){
    let ids;try{ids=JSON.parse(raw);}catch{return;}
    if(!Array.isArray(ids))return;
    const ordered=[...new Set(ids)].filter(id=>byId.has(id));
    cards.forEach(card=>{if(!ordered.includes(card.dataset.workSystem))ordered.push(card.dataset.workSystem);});
    ordered.forEach(id=>workspace.insertBefore(byId.get(id),workspace.querySelector('.b-workspace-add-group')||workspace.querySelector('.sc-work-empty')));
    refresh();
  }
  try{restore(localStorage.getItem(key));}catch{}
  // Restoring DOM order can make scroll snapping follow the old first card.
  // Align the restored first card at the RTL start once the page is ready.
  let userNavigated=false;
  function alignStart(){
    if(userNavigated)return;
    workspace.scrollTo({left:0,behavior:'instant'});
    refresh();
  }
  ['pointerdown','wheel','keydown'].forEach(type=>workspace.addEventListener(type,()=>{userNavigated=true;},{passive:true}));
  alignStart();
  requestAnimationFrame(alignStart);
  window.addEventListener('pageshow',()=>{userNavigated=false;requestAnimationFrame(alignStart);});
  document.fonts?.ready.then(()=>requestAnimationFrame(alignStart));
  function save(card){
    let saved=true;try{localStorage.setItem(key,JSON.stringify([...workspace.querySelectorAll('[data-work-system]')].map(item=>item.dataset.workSystem)));}catch{saved=false;}
    refresh();const position=visible().indexOf(card)+1;
    if(typeof showToast==='function')showToast(`تم نقل ${card.querySelector('h2').textContent} إلى الموضع ${position.toLocaleString('ar-EG-u-nu-latn')}${saved?'':' · تعذّر حفظ الترتيب؛ متاح لهذه الجلسة فقط'}`);
  }
  function clearMarkers(){cards.forEach(card=>card.classList.remove('drop-before','drop-after'));}
  function locate(){
    clearMarkers();const others=visible().filter(card=>card!==drag.card);
    const bounds=workspace.getBoundingClientRect();
    drag.valid=drag.y>=bounds.top-35&&drag.y<=bounds.bottom+35&&drag.x>=bounds.left-60&&drag.x<=bounds.right+60;
    drag.before=null;if(!drag.valid||!others.length)return;
    const grid=getComputedStyle(workspace).display==='grid';
    drag.before=others.find(card=>{const box=card.getBoundingClientRect();return grid?(drag.y<box.top||(drag.y<=box.bottom&&drag.x>box.left+box.width/2)):drag.x>box.left+box.width/2;})||null;
    (drag.before||others.at(-1)).classList.add(drag.before?'drop-before':'drop-after');
  }
  function tick(time){
    if(!drag?.active)return;
    const box=workspace.getBoundingClientRect(),elapsed=Math.min(32,time-(drag.time||time));drag.time=time;
    const speed=drag.x<box.left+48?-1:drag.x>box.right-48?1:0;
    if(getComputedStyle(workspace).display==='grid'){
      const vertical=drag.y<80?-1:drag.y>window.innerHeight-80?1:0;
      if(vertical)window.scrollBy(0,vertical*elapsed*.65);
    }else if(drag.y>=box.top-35&&drag.y<=box.bottom+35&&speed)workspace.scrollLeft+=speed*elapsed*.65;
    locate();frame=requestAnimationFrame(tick);
  }
  function finish(commit){
    if(!drag)return;const current=drag;drag=null;cancelAnimationFrame(frame);
    if(current.handle.hasPointerCapture(current.pointer))current.handle.releasePointerCapture(current.pointer);
    current.ghost?.remove();current.card.classList.remove('is-drag-source');clearMarkers();
    if(commit&&current.active&&current.valid){
      const last=visible().filter(card=>card!==current.card).at(-1);
      workspace.insertBefore(current.card,current.before||(last?last.nextSibling:workspace.querySelector('.b-workspace-add-group')||workspace.querySelector('.sc-work-empty')));
      save(current.card);
    }
    workspace.classList.remove('is-reordering');
    current.handle.focus({preventScroll:true});refresh();
  }
  const bound=new WeakSet();
  function bindCard(card){
    if(bound.has(card))return;bound.add(card);
    const handle=document.createElement('button');handle.type='button';handle.className='b-workspace-grip';
    const title=card.querySelector('h2').textContent;
    handle.setAttribute('aria-label',`ترتيب ${title}: اسحب أو استخدم سهمي اليمين واليسار`);
    handle.title='اسحب لتغيير الموضع · أو استخدم سهمي اليمين واليسار';
    handle.innerHTML='<svg viewBox="0 0 16 20" fill="currentColor" aria-hidden="true"><circle cx="5" cy="4" r="1.5"/><circle cx="11" cy="4" r="1.5"/><circle cx="5" cy="10" r="1.5"/><circle cx="11" cy="10" r="1.5"/><circle cx="5" cy="16" r="1.5"/><circle cx="11" cy="16" r="1.5"/></svg>';
    const actions=document.createElement('div');actions.className='b-workspace-card-actions';
    const conceal=document.createElement('button');conceal.type='button';conceal.className='b-workspace-conceal';
    function paintConceal(){const hidden=concealed.has(card.dataset.workSystem);card.classList.toggle('is-content-concealed',hidden);conceal.setAttribute('aria-pressed',String(hidden));conceal.setAttribute('aria-label',`${hidden?'إظهار':'تغبيش'} محتوى ${title}`);conceal.title=conceal.getAttribute('aria-label');conceal.innerHTML=hidden?'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" aria-hidden="true"><path d="M3 3l18 18M10.6 10.7a2 2 0 0 0 2.7 2.7M9.9 4.4A10.7 10.7 0 0 1 12 4c5.5 0 9 6 9 6a16 16 0 0 1-2.2 2.8M6.3 6.3C4.2 7.7 3 10 3 10s3.5 6 9 6c1 0 2-.2 2.8-.5"/></svg>':'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" aria-hidden="true"><path d="M3 12s3.5-6 9-6 9 6 9 6-3.5 6-9 6-9-6-9-6Z"/><circle cx="12" cy="12" r="2.5"/></svg>';}
    paintConceal();
    conceal.addEventListener('click',()=>{const id=card.dataset.workSystem;if(concealed.has(id))concealed.delete(id);else concealed.add(id);try{localStorage.setItem(concealKey,JSON.stringify([...concealed]));}catch{}paintConceal();});
    const pinGroup=card.querySelector('.sc-work-label');
    if(pinGroup){
      const pin=pinGroup.querySelector('button');
      pin.title=pin.getAttribute('aria-label');
      const separator=document.createElement('span');separator.className='b-workspace-action-divider';separator.textContent='|';separator.setAttribute('aria-hidden','true');
      actions.append(pinGroup,conceal,separator);
    }
    if(!pinGroup)actions.append(conceal);
    actions.append(handle);card.append(actions);
    handle.addEventListener('keydown',event=>{
      if(!['ArrowLeft','ArrowRight'].includes(event.key)||drag)return;
      event.preventDefault();event.stopPropagation();const list=visible(),index=list.indexOf(card),step=event.key==='ArrowLeft'?1:-1,target=list[index+step];if(!target)return;
      workspace.insertBefore(card,step>0?target.nextSibling:target);handle.focus({preventScroll:true});card.scrollIntoView({behavior:'instant',block:'nearest',inline:'nearest'});save(card);
    });
    handle.addEventListener('pointerdown',event=>{
      if(event.button!==0||!event.isPrimary||drag)return;
      drag={card:card,handle,pointer:event.pointerId,startX:event.clientX,startY:event.clientY,x:event.clientX,y:event.clientY,active:false,valid:false};handle.setPointerCapture(event.pointerId);
    });
    handle.addEventListener('pointermove',event=>{
      if(!drag||event.pointerId!==drag.pointer)return;drag.x=event.clientX;drag.y=event.clientY;
      if(!drag.active&&Math.hypot(drag.x-drag.startX,drag.y-drag.startY)<6)return;
      if(!drag.active){drag.active=true;workspace.classList.add('is-reordering');card.classList.add('is-drag-source');drag.ghost=document.createElement('div');drag.ghost.className='b-workspace-drag-preview';drag.ghost.textContent=title;drag.ghost.setAttribute('aria-hidden','true');document.body.append(drag.ghost);frame=requestAnimationFrame(tick);}
      drag.ghost.style.left=`${Math.max(8,Math.min(window.innerWidth-250,drag.x+14))}px`;drag.ghost.style.top=`${Math.max(8,drag.y-45)}px`;locate();
    });
    handle.addEventListener('pointerup',event=>{if(drag?.pointer===event.pointerId)finish(true);});
    handle.addEventListener('pointercancel',()=>finish(false));handle.addEventListener('lostpointercapture',()=>finish(false));
  }
  cards.forEach(bindCard);
  workspace.addEventListener('workspace:cards-changed',()=>{
    finish(false);
    cards.splice(0,cards.length,...workspace.querySelectorAll('[data-work-system]'));
    byId.clear();cards.forEach(card=>{byId.set(card.dataset.workSystem,card);bindCard(card);});
    try{restore(localStorage.getItem(key));}catch{}
    refresh();
  });
  document.addEventListener('keydown',event=>{if(event.key==='Escape'&&drag){event.preventDefault();finish(false);}});
  window.addEventListener('blur',()=>finish(false));
  window.addEventListener('storage',event=>{if(event.key===key){finish(false);restore(event.newValue);}});
})();
