/* Read-only portal document: no persistence, read tracking, business scripts or arbitrary HTML. */
(() => {
  const api=new URL(document.querySelector('meta[name="companyportal-api-base"]').content.replace(/\/?$/,'/'),location.href),message=document.getElementById('draft-message'),shell=document.getElementById('draft-shell');let sections=new Set();
  const make=(tag,text,cls)=>{const n=document.createElement(tag);if(text!==undefined)n.textContent=String(text).slice(0,4000);if(cls)n.className=cls;return n;};
  const text=v=>typeof v==='string'&&v.length<=4000;
  const asset=value=>{try{const u=new URL(value,api);return u.origin===api.origin&&!u.username&&!u.password&&/\/api\/admin\/media\/preview\/[A-Za-z0-9_-]+$/.test(u.pathname)?u.href:null;}catch{return null;}};
  document.addEventListener('submit',e=>e.preventDefault());document.addEventListener('click',e=>{if(e.target.closest('a,button,input,select,textarea'))e.preventDefault();},true);
  document.querySelectorAll('input,select,textarea,button').forEach(e=>e.disabled=true);
  async function apply(section,v){
    if(!v||typeof v!=='object')return;
    window.CompanyPortalTheme.previewLayout('official','الرسمي');window.CompanyPortalTheme.apply({layoutKey:'official'});
    shell.hidden=false;message.textContent='معاينة القالب الرسمي بالقيم غير المحفوظة — لا تُحفظ بيانات ولا تُسجّل قراءة المحتوى.';
    if(section==='fixed-orders'){
      if(!['contentAfter','contentText'].every(k=>text(v[k]))||v.contentBefor!==null&&!text(v.contentBefor))return;
      const timeline=document.getElementById('fixed-orders-timeline'),li=make('li'),article=make('article',undefined,'portal-policy-entry'),head=make('header');
      head.append(make('span','توجيه سامٍ','portal-policy-kind'),make('time',v.timestamp||'التاريخ غير محدد'));article.append(head,make('h3',v.contentAfter||'توجيه سامٍ'));
      const content=make('div',undefined,'portal-policy-example'),p=make('p');CompanyPortalFixedOrderText.append(p,v);content.append(p);article.append(content);li.append(make('span',(v.timestamp||'').slice(0,4),'portal-policy-year'),article);timeline.replaceChildren(li);timeline.hidden=false;
      document.getElementById('fixed-orders-status').textContent='معاينة التوجيه غير المحفوظ';document.getElementById('policies-sheet').showModal();
    }else if(section==='media'){
      if(!text(v.name)||!['image','video','group'].includes(v.kind))return;
      const target=document.querySelector('.editorial-events-grid');target.replaceChildren();const card=make('article',undefined,v.kind==='video'?'editorial-video-card':'editorial-photo-slide'),stage=v.kind==='video'?make('div',undefined,'editorial-video-stage'):card,src=asset(v.url);
      if(src){const media=make(v.kind==='video'?'video':'img');media.src=src;if(v.kind==='video'){media.preload='metadata';media.addEventListener('loadedmetadata',()=>{if(Number.isFinite(media.duration))media.currentTime=Math.min(.1,media.duration/2);},{once:true});stage.append(media,make('button','▶','editorial-video-play'));}else{media.alt=v.name;stage.append(media);}}else stage.append(make('p','لم يتم تحديد صورة غلاف متاحة لهذه المعاينة.'));
      const copy=make('div',undefined,v.kind==='video'?'editorial-event-copy':'editorial-photo-copy');copy.append(make('h3',v.name),make('p',v.active?'ظاهر بعد الحفظ':'مخفي بعد الحفظ؛ يظهر هنا للمعاينة فقط'));stage.append(copy);if(stage!==card)card.append(stage);target.append(card);document.getElementById('portal-media-status').hidden=true;document.querySelector('.editorial-video-toolbar').hidden=true;document.querySelector('.editorial-photo-controls')?.setAttribute('hidden','');document.getElementById('editorial-events').scrollIntoView();
    }else if(section==='notices'||section==='alerts'){
      const container=make('section',undefined,'admin-draft-notices');document.body.append(container);
      const rows=Array.isArray(v.rows)?v.rows.filter(r=>text(r.title)&&text(r.decisionType)).slice(0,3):[];
      if(!rows.length){container.append(make('p','لا توجد قرارات مشمولة ضمن فترة العرض الحالية بالقيم غير المحفوظة.'));}
      for(const row of rows){const block=make('section',undefined,section==='notices'?'portal-floating-alert':'portal-floating-notice');
        if(section==='notices'){block.append(make('strong',row.decisionType),make('a',row.title),make('small',row.publishedAt?.slice(0,10)||''));}
        else{const button=make('button',undefined,'portal-floating-notice-content');button.append(make('span',row.decisionType),make('strong',row.title),make('small',row.publishedAt?.slice(0,10)||''));block.append(button);}container.append(block);}
      window.scrollTo({top:0});
    }else if(section==='header-content'&&v.kind==='numbers'){
      const panel=document.getElementById('portal-search-panel');panel.hidden=false;panel.dataset.searchMode='phone';panel.querySelector('.portal-phone-important').hidden=false;document.getElementById('portal-search-title').textContent='دليل الهاتف';
      const list=document.getElementById('portal-important-numbers');list.replaceChildren();for(const row of (v.rows||[]).slice(0,100)){if(!text(row.title)||!text(row.number)||!row.active)continue;const item=make('div'),number=make('dd',row.number);number.dir='ltr';item.append(make('dt',row.title),number);list.append(item);}
      document.getElementById('portal-important-numbers-note').textContent='معاينة الأرقام الظاهرة فقط';panel.scrollIntoView({block:'center'});
    }else if(section==='header-content'&&v.kind==='status'){
      if(!text(v.title)||!text(v.summary)||!['green','yellow','orange','red'].includes(v.color))return;
      const status=document.querySelector('.portal-org-status');status.open=true;status.querySelector('.portal-org-status-copy strong').textContent=v.title;
      status.querySelectorAll('.portal-org-status-dot').forEach(dot=>dot.className='portal-org-status-dot is-'+v.color);
      const menu=status.querySelector('.portal-org-status-menu'),body=make('section');body.append(make('h2',v.title),make('p',v.colorName||''),make('p',v.summary),make('p',v.guideText||''));const ul=make('ul');String(v.actions||'').split('\n').filter(Boolean).forEach(t=>ul.append(make('li',t)));body.append(ul);menu.replaceChildren(body);status.scrollIntoView({block:'center'});
    }
  }
  window.addEventListener('message',event=>{
    if(event.origin!==location.origin||event.source!==parent||event.data?.type!=='companyportal:content-draft'||!sections.has(event.data.section))return;
    // One draft per document; reopening starts a new frame and cannot accumulate old content.
    if(shell.dataset.received)return;shell.dataset.received='true';void apply(event.data.section,event.data.value).catch(()=>message.textContent='تعذر عرض المعاينة. أغلق النافذة وأعد المحاولة.');
  });
  fetch(new URL('api/access',api),{credentials:'include',cache:'no-store',signal:AbortSignal.timeout(10000)}).then(async r=>{if(!r.ok)throw new Error();const access=await r.json();if(!access.isAdmin)throw new Error();sections=new Set((access.sections||[]).filter(s=>['media','fixed-orders','notices','alerts','header-content'].includes(s)));parent.postMessage({type:'companyportal:content-ready'},location.origin);}).catch(()=>message.textContent='المعاينة متاحة فقط لحساب إدارة القسم.');
})();
