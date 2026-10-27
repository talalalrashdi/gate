(() => {
  const notice=document.getElementById('portal-floating-alert'),alert=document.getElementById('portal-floating-notice');
  const toggle=document.getElementById('portal-notices-visibility'),dialog=document.getElementById('decision-notices-dialog');
  const base=document.querySelector('meta[name="companyportal-api-base"]')?.content;
  if(!notice||!alert||!toggle||!dialog||!base)return;
  let initialized=false,seenEligible=new Set();
  const visibleChannels=new Set(),dismissedNotices=new Set(),pendingDismissals=new Set();
  const dismissStatus=notice.querySelector('[data-notice-dismiss-status]');
  let rows=[],noticeIndex=0,index=0,timer,rotation;
  const endpoint=id=>new URL('api/decisions/'+id+'/pdf',new URL(base.replace(/\/?$/,'/'),location.href)).href;
  const content=alert.querySelector('.portal-floating-notice-content');
  const link=document.createElement('a');link.className=content.className;link.target='_blank';link.rel='noopener noreferrer';
  link.append(...content.childNodes);content.replaceWith(link);
  const make=(tag,text)=>{const n=document.createElement(tag);n.textContent=text;return n;};
  function available(channel){const now=Date.now();return rows.filter(r=>(channel!==2||!r.hasRead)&&(channel!==1||!dismissedNotices.has(r.decisionId))&&r.notices?.some(n=>n.channelId===channel&&Date.parse(n.fromAt)<=now&&now<Date.parse(n.toAt)));}
  function fill(target,row){
    target.href=row.isSimulation?'#':endpoint(row.decisionId);if(row.isSimulation){target.removeAttribute('target');target.dataset.simulation='true';}else{target.target='_blank';delete target.dataset.simulation;}target.dataset.decisionId=row.decisionId;target.replaceChildren();
    if(!row.hasRead){const badge=make('small','جديد');badge.className='portal-decision-unread';target.append(badge);}
    target.append(make('strong',row.title));
    target.append(make('small',row.decisionType+' · '+new Intl.DateTimeFormat('ar-OM',{dateStyle:'medium'}).format(new Date(row.publishedAt))));
  }
  function render(){
    clearTimeout(timer);clearTimeout(rotation);
    const notices=available(1),alerts=available(2);
    const eligible=[...notices.map(row=>({row,channel:1})),...alerts.map(row=>({row,channel:2}))];
    const fresh=eligible.filter(({row,channel})=>initialized&&!row.hasRead&&!seenEligible.has(channel+':'+row.decisionId));
    eligible.forEach(({row,channel})=>seenEligible.add(channel+':'+row.decisionId));
    if(fresh.length){
      fresh.forEach(n=>visibleChannels.add(n.channel));
      const freshNotice=fresh.find(n=>n.channel===1),freshAlert=fresh.find(n=>n.channel===2);
      if(freshNotice)noticeIndex=notices.findIndex(r=>r.decisionId===freshNotice.row.decisionId);
      if(freshAlert)index=alerts.findIndex(r=>r.decisionId===freshAlert.row.decisionId);
    }
    const expanded=visibleChannels.size>0;
    toggle.setAttribute('aria-expanded',String(expanded));toggle.title=expanded?'إخفاء التنويه والتنبيهات':'إظهار التنويه والتنبيهات';toggle.setAttribute('aria-label',toggle.title);
    index=Math.max(0,Math.min(index,Math.max(0,alerts.length-1)));noticeIndex=Math.max(0,Math.min(noticeIndex,Math.max(0,notices.length-1)));
    notice.hidden=document.hidden||!visibleChannels.has(1)||!notices.length;alert.hidden=document.hidden||!visibleChannels.has(2)||!alerts.length;
    if(notices.length){notice.querySelector('[data-notice-type]').textContent=notices[noticeIndex].decisionType;fill(notice.querySelector('[data-notice-link]'),notices[noticeIndex]);notice.querySelector('[data-notice-position]').textContent=(noticeIndex+1)+' / '+notices.length;notice.querySelector('[data-notice-prev]').disabled=noticeIndex===0;notice.querySelector('[data-notice-next]').disabled=noticeIndex===notices.length-1;notice.querySelector('.portal-notice-paging').hidden=notices.length<2;}
    if(alerts.length){fill(link,alerts[index]);alert.querySelector('.portal-floating-notice-position').textContent=(index+1)+' / '+alerts.length;
      alert.querySelector('.portal-floating-notice-prev').disabled=index===0;alert.querySelector('.portal-floating-notice-next').disabled=index===alerts.length-1;}
    if(dialog.open)renderList();
    // Boundary timers and visible carousel rotation do not make network requests.
    const next=rows.flatMap(r=>r.notices??[]).flatMap(n=>[Date.parse(n.fromAt),Date.parse(n.toAt)]).filter(t=>t>Date.now()).sort((a,b)=>a-b)[0];
    if(next&&!document.hidden)timer=setTimeout(render,Math.min(2147483647,Math.max(20,next-Date.now()+20)));
    if(!alert.hidden&&alerts.length>1&&!dialog.open&&!alert.matches(':hover,:focus-within'))rotation=setTimeout(()=>{index=(index+1)%alerts.length;render();},8000);
  }
  function renderList(){
    const list=dialog.querySelector('[data-notices-list]');list.replaceChildren();
    for(const channel of [1,2]){const items=available(channel);if(!items.length)continue;list.append(make('h3',channel===1?'تنويه':'تنبيه'));
      for(const row of items){const item=document.createElement('a');item.target='_blank';item.rel='noopener noreferrer';fill(item,row);list.append(item);}}
    dialog.querySelector('[data-notices-status]').textContent=list.children.length?'التنبيهات المقروءة تُغلق تلقائيًا؛ بقية المواد ضمن مدة العرض المحددة.':'لا توجد تنويهات أو تنبيهات ضمن فترة العرض.';
  }
  if(document.getElementById('portal-simulation')){
    document.addEventListener('portal:simulation-reveal',event=>{
      // The decision's matched admin channels are the only channels this event can open.
      for(const channel of event.detail.channels){
        const items=available(channel),position=items.findIndex(r=>r.decisionId===event.detail.decisionId);
        if(position<0)continue;visibleChannels.add(channel);if(channel===1)noticeIndex=position;else if(channel===2)index=position;
      }
      render();
    });
    document.addEventListener('portal:simulation-reset',()=>{visibleChannels.clear();for(const id of dismissedNotices)if(id.startsWith('simulation-'))dismissedNotices.delete(id);noticeIndex=0;index=0;render();});
  }
  document.addEventListener('portal:decisions',event=>{rows=event.detail.rows;render();if(event.detail.loaded&&event.detail.origin!=='simulation')initialized=true;});
  document.addEventListener('portal:decision-read',event=>{if(link.dataset.decisionId===event.detail)visibleChannels.delete(2);rows.filter(r=>r.decisionId===event.detail).forEach(r=>r.hasRead=true);render();});
  document.addEventListener('portal:decision-read-error',()=>{dialog.querySelector('[data-notices-status]').textContent='تعذر حفظ حالة القراءة. يمكنك إعادة فتح المادة بعد تحديث الصفحة.';});
  toggle.addEventListener('click',()=>{
    if(visibleChannels.size)visibleChannels.clear();else{visibleChannels.add(1);visibleChannels.add(2);}
    render();
  });
  notice.querySelector('[data-notice-prev]').addEventListener('click',()=>{noticeIndex--;render();});
  notice.querySelector('[data-notice-next]').addEventListener('click',()=>{noticeIndex++;render();});
  alert.querySelector('.portal-floating-notice-prev').addEventListener('click',()=>{index--;render();});
  alert.querySelector('.portal-floating-notice-next').addEventListener('click',()=>{index++;render();});
  alert.querySelector('.portal-floating-notice-close').addEventListener('click',()=>{visibleChannels.delete(2);render();toggle.focus({preventScroll:true});});
  async function dismissNotice(){
    const row=available(1)[noticeIndex];if(!row||pendingDismissals.has(row.decisionId))return;
    const id=row.decisionId;dismissStatus.hidden=true;dismissedNotices.add(id);
    if(!available(1).length)visibleChannels.delete(1);render();
    if(notice.hidden)toggle.focus({preventScroll:true});
    // Simulated dismissals are local only; real dismissals belong to the current DB user.
    if(row.isSimulation)return;
    pendingDismissals.add(id);
    try{
      const url=new URL('api/decisions/'+id+'/dismiss-notice',new URL(base.replace(/\/?$/,'/'),location.href));
      const response=await fetch(url,{method:'POST',credentials:'include',cache:'no-store',headers:{'X-CompanyPortal-Request':'decision-dismiss'},signal:AbortSignal.timeout(15000)});
      if(!response.ok)throw new Error();
    }catch{
      dismissedNotices.delete(id);visibleChannels.add(1);noticeIndex=Math.max(0,available(1).findIndex(r=>r.decisionId===id));render();
      dismissStatus.textContent='تعذر حفظ الإخفاء. أعد الضغط على × للمحاولة مجددًا.';dismissStatus.hidden=false;
    }finally{pendingDismissals.delete(id);}
  }
  function open(){renderList();dialog.showModal();render();}
  alert.querySelector('.portal-floating-notice-all').addEventListener('click',open);notice.querySelector('[data-notice-close]').addEventListener('click',()=>void dismissNotice());
  dialog.querySelector('[data-notices-close]').addEventListener('click',()=>dialog.close());dialog.addEventListener('close',render);
  alert.addEventListener('mouseenter',()=>clearTimeout(rotation));alert.addEventListener('mouseleave',render);alert.addEventListener('focusin',()=>clearTimeout(rotation));alert.addEventListener('focusout',()=>setTimeout(render,0));
  document.addEventListener('visibilitychange',render);window.addEventListener('pagehide',()=>{clearTimeout(timer);clearTimeout(rotation);});render();
})();
