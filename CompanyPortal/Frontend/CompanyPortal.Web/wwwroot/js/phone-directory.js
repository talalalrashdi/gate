(() => {
  const panel=document.getElementById('portal-search-panel'),input=document.getElementById('portal-search-input'),list=document.getElementById('portal-search-results'),status=document.getElementById('portal-search-status');
  const base=document.querySelector('meta[name="companyportal-api-base"]')?.content;
  if(!panel||!base)return;
  const hint=panel.querySelector('.portal-search-keyboard-hint'),hintText=hint?.textContent||'';
  let timer,request,detailRequest,version=0,page=1,term='',selected=-1,targetId=null,simulation=null,rendered=0,openContact=null;
  const make=(tag,text)=>{const el=document.createElement(tag);if(text)el.textContent=text;return el;};
  const svg=(paths,size=16)=>{const el=document.createElementNS('http://www.w3.org/2000/svg','svg');el.setAttribute('viewBox','0 0 24 24');el.setAttribute('width',size);el.setAttribute('height',size);el.setAttribute('fill','none');el.setAttribute('stroke','currentColor');el.setAttribute('stroke-width','1.8');el.setAttribute('stroke-linecap','round');el.setAttribute('stroke-linejoin','round');el.setAttribute('aria-hidden','true');el.innerHTML=paths;return el;};
  const phoneIcon=size=>svg('<path d="M5 3.5h3.2l1.6 4.2-2.1 1.3a11 11 0 0 0 5.3 5.3l1.3-2.1 4.2 1.6v3.2a2 2 0 0 1-2.2 2A16.5 16.5 0 0 1 3 5.7a2 2 0 0 1 2-2.2Z"/>',size);
  const loadMore=make('button','عرض المزيد');loadMore.type='button';loadMore.className='phone-directory-load-more';loadMore.hidden=true;list.after(loadMore);
  loadMore.addEventListener('click',()=>{page++;void load(true);});
  const simulationNote=make('div');simulationNote.className='phone-directory-simulation';simulationNote.hidden=true;
  const simulationLabel=make('span','محاكاة دليل الهاتف — أشخاص وبيانات توضيحية'),exitSimulation=make('button','العودة للدليل الحقيقي');exitSimulation.type='button';simulationNote.append(simulationLabel,exitSimulation);list.before(simulationNote);
  function resetSimulation(){simulation=null;simulationNote.hidden=true;if(panel.dataset.searchMode==='phone'){close();list.replaceChildren();input.value='';status.textContent='اكتب الاسم أو رقم المكتب للبحث، أو اضغط دليل الهاتف لعرض القائمة.';}}
  exitSimulation.addEventListener('click',resetSimulation);
  if(document.getElementById('portal-simulation')){
    document.addEventListener('portal:phone-simulation',event=>{simulation=event.detail;document.querySelector('[data-search-mode="phone"]').click();search(true);});
    document.addEventListener('portal:simulate',event=>{if(event.detail.kind==='reset')resetSimulation();});
  }
  function close(){simulationNote.hidden=true;clearTimeout(timer);request?.abort();version++;loadMore.hidden=true;closeDetail(false);list.removeAttribute('aria-busy');if(hint)hint.textContent=hintText;}
  const endpoint=path=>new URL(path,new URL(base.replace(/\/?$/,'/'),location.href));
  // Folds Arabic diacritics/letter variants per character so matches can be mapped back to the original text.
  const fold=ch=>[...ch.normalize('NFKD')].filter(c=>!/[ً-ٰٟـ]/.test(c)).join('').replace(/[أإآ]/g,'ا').replace(/ى/g,'ي').toLowerCase();
  const normalize=value=>[...String(value||'')].map(fold).join('');
  function highlight(text,query){
    const out=document.createDocumentFragment(),q=normalize(query).trim();text=String(text||'');
    let folded='';const map=[];for(let i=0;i<text.length;i++)for(const c of fold(text[i])){folded+=c;map.push(i);}
    const at=q?folded.indexOf(q):-1;if(at<0){out.append(text);return out;}
    const start=map[at],end=map[at+q.length-1]+1;out.append(text.slice(0,start),make('mark',text.slice(start,end)),text.slice(end));return out;
  }
  function numberText(number,className,icon=false){
    const box=make('span');box.className=className;
    const digits=make('span');digits.dir='ltr';digits.append(highlight(number,term));if(icon)box.append(phoneIcon(17));box.append(digits);return box;
  }
  const isPresent=person=>person.attendanceStatus?.trim()==='موجود';
  function avatarFor(person){
    const avatar=make('span',(person.name||'؟').trim().slice(0,1));avatar.className='phone-directory-avatar';avatar.setAttribute('aria-hidden','true');
    if(!person.isSimulation&&person.personalID&&/^\d+$/.test(person.personalID)){const photo=make('img');photo.alt='';photo.loading='lazy';photo.src=endpoint('api/phone-directory/photo/'+person.personalID).href;photo.addEventListener('load',()=>photo.naturalWidth>1?avatar.classList.add('has-photo'):photo.remove());photo.addEventListener('error',()=>photo.remove(),{once:true});avatar.append(photo);}
    return avatar;
  }
  function emailAction(person){
    if(person.isSimulation&&person.simulationEmail){const mail=make('button','✉');mail.type='button';mail.className='phone-directory-email';mail.setAttribute('aria-label','معاينة بريد إلى '+person.name);mail.addEventListener('click',event=>{event.stopPropagation();document.dispatchEvent(new CustomEvent('portal:simulation-open',{detail:{title:'معاينة رسالة إلى '+person.name,text:'إلى: '+person.simulationEmail+' — محاكاة فقط، لا يتم فتح OWA أو إرسال بريد.'}}));});return mail;}
    if(!person.isSimulation&&person.composeUrl){const url=new URL(person.composeUrl);if(['https:','http:'].includes(url.protocol)){const mail=make('a');mail.className='phone-directory-email';mail.href=url.href;mail.target='_blank';mail.rel='noopener noreferrer';mail.title='كتابة بريد إلى '+person.name;mail.setAttribute('aria-label',mail.title);const icon=make('span','✉');icon.setAttribute('aria-hidden','true');mail.append(icon);mail.addEventListener('click',event=>event.stopPropagation());return mail;}}
    return null;
  }
  function search(all=false,assignedId=null){
    targetId=assignedId;
    close();simulationNote.hidden=!simulation;page=1;term=input.value.trim();selected=-1;input.removeAttribute('aria-activedescendant');
    if(hint)hint.textContent='↑ ↓ للتنقل · Enter لعرض التفاصيل';
    if(!term&&!all){list.replaceChildren();status.textContent='اكتب الاسم أو رقم المكتب للبحث، أو اضغط دليل الهاتف لعرض القائمة.';return;}
    if(term.length>200){list.replaceChildren();status.textContent='الحد الأقصى للبحث 200 حرف.';return;}
    // Results update from the first letter; the previous list stays visible until the new one arrives.
    if(!list.querySelector('.phone-directory-contact'))status.textContent='جارٍ البحث…';
    timer=setTimeout(load,all||simulation?0:120);
  }
  function render(person){
    const name=person.name||'غير محدد',present=isPresent(person),index=rendered++;
    const card=make('div');card.className='portal-search-option portal-search-contact phone-directory-contact';card.id='phone-result-'+index;card.tabIndex=-1;card.setAttribute('role','option');card.setAttribute('aria-selected','false');
    const info=make('div');info.className='phone-directory-info';
    const title=make('strong');title.append(highlight(name,term));info.append(title);
    const meta=[person.jobDesignate,person.employeeSectionName].filter(Boolean).join(' · ');if(meta){const line=make('small');line.append(highlight(meta,term));info.append(line);}
    if(!present&&person.personalIDAssignedTo&&person.assignedToFullName){
      const link=make('button');link.type='button';link.className='phone-directory-assigned';link.setAttribute('aria-label','عرض المكلف: '+person.assignedToFullName);
      link.append(make('span','المكلف'),make('b',person.assignedToFullName),svg('<path d="m14 6-6 6 6 6"/>',14));
      link.addEventListener('click',event=>{event.stopPropagation();input.value=person.assignedToFullName;search(true,person.personalIDAssignedTo);input.focus({preventScroll:true});});
      info.append(link);
    }
    const presence=make('span');presence.className='phone-directory-status';
    if(person.attendanceStatus&&!present){presence.textContent=person.attendanceStatus.trim();presence.classList.add('is-away');}
    else if(present){const text=make('span','، موجود');text.className='phone-directory-sr';title.append(text);}
    const extension=person.officePhoneNumber?numberText(person.officePhoneNumber,'phone-directory-extension',true):make('span','—');
    if(!person.officePhoneNumber){extension.className='phone-directory-extension is-empty';extension.title='لا يوجد رقم مكتب';}
    const actions=make('div');actions.className='phone-directory-actions';const mail=emailAction(person);if(mail)actions.append(mail);
    const more=make('button');more.type='button';more.className='phone-directory-more';more.title='التفاصيل';more.setAttribute('aria-label','تفاصيل '+name);more.append(svg('<path d="m6 9 6 6 6-6"/>',20));more.setAttribute('aria-expanded','false');more.setAttribute('aria-controls','phone-detail-'+index);
    more.addEventListener('click',event=>{event.stopPropagation();openContact?.person===person?closeDetail(true):openDetail(card,person,more,index);});actions.append(more);
    card.append(avatarFor(person),info,presence,extension,actions);
    card.addEventListener('click',()=>more.click());
    card.addEventListener('keydown',event=>{if(event.key==='Escape'&&openContact?.card===card){event.preventDefault();event.stopPropagation();closeDetail(true);}});
    return card;
  }
  const moreInfo=new WeakMap();
  function openDetail(card,person,trigger,index){
    closeDetail(false);
    const detail=make('section');detail.className='phone-directory-detail';detail.id='phone-detail-'+index;detail.setAttribute('aria-label','تفاصيل '+(person.name||'جهة الاتصال'));
    detail.addEventListener('click',event=>event.stopPropagation());
    openContact={card,person,trigger,detail};trigger.setAttribute('aria-expanded','true');card.classList.add('is-open');card.append(detail);
    void loadDetail(person);
    requestAnimationFrame(()=>card.scrollIntoView({block:'nearest'}));
  }
  function closeDetail(restore){
    detailRequest?.abort();if(!openContact)return;
    const {card,trigger,detail}=openContact;openContact=null;trigger.setAttribute('aria-expanded','false');card.classList.remove('is-open');detail.remove();
    if(restore&&trigger.isConnected)trigger.focus({preventScroll:true});
  }
  async function loadDetail(person){
    const body=openContact.detail;
    const cached=moreInfo.get(person);if(cached){fillDetail(body,cached);return;}
    body.replaceChildren(make('p','جارٍ التحميل…'));detailRequest=new AbortController();const signal=detailRequest.signal;
    try{
      let data;
      if(person.isSimulation)data=person.moreInfo;
      else{
        if(!person.persID||!person.employeeTypeID)throw new Error('معرّف جهة الاتصال غير متاح.');
        const url=endpoint('api/phone-directory/more');url.searchParams.set('id',person.persID);url.searchParams.set('employeeTypeId',person.employeeTypeID);
        const response=await fetch(url,{credentials:'include',cache:'no-store',signal:AbortSignal.any([signal,AbortSignal.timeout(20000)])});data=await response.json();
        if(!response.ok)throw new Error(data.title||'تعذر تحميل المزيد.');
      }
      if(signal.aborted||openContact?.person!==person)return;
      moreInfo.set(person,data);fillDetail(body,data);
    }catch(error){
      if(signal.aborted||openContact?.person!==person)return;
      body.replaceChildren(make('p',error.name==='TimeoutError'?'انتهت مهلة التحميل.':error.message));const retry=make('button','إعادة المحاولة');retry.type='button';retry.className='phone-directory-retry';retry.addEventListener('click',()=>void loadDetail(person));body.append(retry);
    }
  }
  function fillDetail(body,data){
    body.replaceChildren();
    const phones=Array.isArray(data.phoneNumbers)?data.phoneNumbers.filter(phone=>phone.number):[];
    if(phones.length){
      const section=make('section'),table=make('table'),head=make('tr'),rows=make('tbody'),labels=['الرقم','النوع','المكان','المدينة','ملاحظات'];
      section.append(make('h4','أرقام التواصل'));table.className='phone-directory-numbers';
      for(const label of labels){const th=make('th',label);th.scope='col';head.append(th);}
      for(const phone of phones){
        const row=make('tr'),number=make('td');number.append(numberText(phone.number,'phone-directory-number'));row.append(number);
        for(const [i,value] of [phone.phoneTypeName,phone.phonePlace,phone.phoneStateName,phone.note].entries()){const cell=make('td',value||'—');if(!value)cell.className='is-empty';cell.dataset.label=labels[i+1];row.append(cell);}
        rows.append(row);
      }
      const thead=make('thead');thead.append(head);table.append(thead,rows);section.append(table);body.append(section);
    }
    const addresses=[['العنوان الحالي',data.contactAddress?.currentAddress],['العنوان الدائم',data.contactAddress?.permanentAddress]].filter(([,value])=>value);
    if(addresses.length){const section=make('section'),dl=make('dl');section.append(make('h4','العنوان'));for(const [label,value] of addresses){const row=make('div');row.append(make('dt',label),make('dd',value));dl.append(row);}section.append(dl);body.append(section);}
    if(!body.children.length)body.append(make('p','لا توجد معلومات إضافية.'));
  }
  async function load(append=false){
    request?.abort();request=new AbortController();const mine=++version;
    if(append){loadMore.disabled=true;loadMore.textContent='جارٍ التحميل…';}
    else{loadMore.hidden=true;closeDetail(false);selected=-1;input.removeAttribute('aria-activedescendant');}
    list.setAttribute('aria-busy','true');
    try{
      let data;
      if(simulation){
        const found=simulation.filter(p=>normalize([p.name,p.officePhoneNumber,p.employeeTypeName,p.employeeSectionName].join(' ')).includes(normalize(term)));
        data={contacts:found.slice((page-1)*10,page*10),total:found.length};
      }else{
        const url=endpoint('api/phone-directory');url.searchParams.set('query',term);url.searchParams.set('pageNum',String(page));
        const response=await fetch(url,{credentials:'include',cache:'no-store',signal:AbortSignal.any([request.signal,AbortSignal.timeout(20000)])});
        data=await response.json();if(!response.ok)throw new Error(data.title||'تعذر تحميل دليل الهاتف. حاول مجددًا.');
      }
      if(mine!==version||panel.hidden||panel.dataset.searchMode!=='phone')return;
      if(!Array.isArray(data.contacts))throw new Error('استجابة دليل الهاتف غير صالحة.');
      const contacts=targetId?data.contacts.filter(person=>String(person.personalID)===String(targetId)):data.contacts;
      if(!append){list.replaceChildren();list.scrollTop=0;}
      for(const person of contacts)list.append(render(person));
      const hasMore=page*10<data.total,count=list.querySelectorAll('.phone-directory-contact').length;
      status.textContent=targetId?(count?'جهة الاتصال المكلّفة':(hasMore?'لم تظهر جهة الاتصال المكلّفة بعد. اضغط عرض المزيد.':'لم يتم العثور على جهة الاتصال المكلّفة.')):data.total?`${data.total} جهة اتصال`+(hasMore?` · عرض ${page*10}`:''):'لا توجد جهات اتصال مطابقة.';
      loadMore.textContent='عرض المزيد';loadMore.disabled=false;loadMore.hidden=!hasMore;
    }catch(error){
      if(mine!==version||request.signal.aborted)return;
      status.textContent=error.name==='TimeoutError'?'انتهت مهلة البحث. حاول مجددًا.':error.message;
      if(append){page--;loadMore.textContent='عرض المزيد';loadMore.disabled=false;}
      else{list.replaceChildren();const retry=make('button','إعادة المحاولة');retry.type='button';retry.className='phone-directory-retry';retry.addEventListener('click',()=>void load());list.append(retry);}
    }finally{if(mine===version)list.removeAttribute('aria-busy');}
  }
  function key(event){
    const cards=[...list.querySelectorAll('.phone-directory-contact')];if(!cards.length)return;
    if(event.key==='ArrowDown'||event.key==='ArrowUp'){event.preventDefault();selected=selected<0?(event.key==='ArrowDown'?0:cards.length-1):(selected+(event.key==='ArrowDown'?1:-1)+cards.length)%cards.length;cards.forEach((c,i)=>c.setAttribute('aria-selected',String(i===selected)));input.setAttribute('aria-activedescendant',cards[selected].id);cards[selected].scrollIntoView({block:'nearest'});}
    if(event.key==='Enter'){event.preventDefault();cards[Math.max(0,selected)].querySelector('.phone-directory-more').click();}
  }
  document.addEventListener('visibilitychange',()=>{if(document.hidden){close();list.replaceChildren();status.textContent='أعد البحث لعرض جهات الاتصال.';}});
  window.CompanyPortalPhoneDirectory={search,close,key};
})();
