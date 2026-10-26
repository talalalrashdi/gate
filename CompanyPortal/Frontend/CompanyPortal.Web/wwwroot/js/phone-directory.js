(() => {
  const panel=document.getElementById('portal-search-panel'),input=document.getElementById('portal-search-input'),list=document.getElementById('portal-search-results'),status=document.getElementById('portal-search-status');
  const base=document.querySelector('meta[name="companyportal-api-base"]')?.content;
  if(!panel||!base)return;
  let timer,request,version=0,page=1,term='',selected=-1,targetId=null,simulation=null;
  const make=(tag,text)=>{const el=document.createElement(tag);if(text)el.textContent=text;return el;};
  const paging=make('nav');paging.className='phone-directory-pages';paging.setAttribute('aria-label','صفحات دليل الهاتف');paging.hidden=true;list.after(paging);
  const simulationNote=make('div');simulationNote.className='phone-directory-simulation';simulationNote.hidden=true;
  const simulationLabel=make('span','محاكاة دليل الهاتف — أشخاص وبيانات توضيحية'),exitSimulation=make('button','العودة للدليل الحقيقي');exitSimulation.type='button';simulationNote.append(simulationLabel,exitSimulation);list.before(simulationNote);
  function resetSimulation(){simulation=null;simulationNote.hidden=true;if(panel.dataset.searchMode==='phone'){close();list.replaceChildren();input.value='';status.textContent='اكتب الاسم أو رقم المكتب للبحث، أو اضغط دليل الهاتف لعرض القائمة.';}}
  exitSimulation.addEventListener('click',resetSimulation);
  if(document.getElementById('portal-simulation')){
    document.addEventListener('portal:phone-simulation',event=>{simulation=event.detail;document.querySelector('[data-search-mode="phone"]').click();search(true);});
    document.addEventListener('portal:simulate',event=>{if(event.detail.kind==='reset')resetSimulation();});
  }
  function close(){simulationNote.hidden=true;clearTimeout(timer);request?.abort();version++;paging.hidden=true;list.removeAttribute('aria-busy');}
  const endpoint=path=>new URL(path,new URL(base.replace(/\/?$/,'/'),location.href));
  function search(all=false,assignedId=null){
    targetId=assignedId;
    close();simulationNote.hidden=!simulation;page=1;term=input.value.trim();list.replaceChildren();selected=-1;input.removeAttribute('aria-activedescendant');
    if(!term&&!all){status.textContent='اكتب الاسم أو رقم المكتب للبحث، أو اضغط دليل الهاتف لعرض القائمة.';return;}
    if(term.length>200){status.textContent='الحد الأقصى للبحث 200 حرف.';return;}
    status.textContent='جارٍ البحث…';timer=setTimeout(load,all?0:350);
  }
  async function load(){
    request?.abort();request=new AbortController();const mine=++version;
    paging.hidden=true;list.replaceChildren();list.scrollTop=0;selected=-1;input.removeAttribute('aria-activedescendant');list.setAttribute('aria-busy','true');status.textContent='جارٍ البحث…';
    try{
      let data;
      if(simulation){
        const normalize=value=>String(value||'').normalize('NFKD').replace(/[\u064B-\u065F\u0670\u0640]/g,'').replace(/[أإآ]/g,'ا').replace(/ى/g,'ي').toLowerCase();
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
      for(const [i,person] of contacts.entries()){
        const card=make('div');card.className='portal-search-option portal-search-contact phone-directory-contact';card.id='phone-result-'+i;card.tabIndex=-1;card.setAttribute('role','option');card.setAttribute('aria-selected','false');
        const avatar=make('span',(person.name||'؟').trim().slice(0,1));avatar.className='phone-directory-avatar';avatar.setAttribute('aria-hidden','true');
        if(!person.isSimulation&&person.personalID&&/^\d+$/.test(person.personalID)){const photo=make('img');photo.alt='';photo.width=44;photo.height=44;photo.loading='lazy';photo.src=endpoint('api/phone-directory/photo/'+person.personalID).href;photo.addEventListener('load',()=>avatar.classList.add('has-photo'));photo.addEventListener('error',()=>photo.remove(),{once:true});avatar.append(photo);}
        const copy=make('div');copy.append(make('strong',person.name||'غير محدد'),make('small',[person.jobDesignate,person.employeeSectionName].filter(Boolean).join(' · ')));
        const badges=make('div');badges.className='phone-directory-badges';
        if(person.officePhoneNumber){const number=make('span',person.officePhoneNumber);number.className='phone-directory-extension';number.dir='ltr';number.setAttribute('aria-label','رقم المكتب '+person.officePhoneNumber);badges.append(number);}
        if(person.attendanceStatus){const attendance=make('span',person.attendanceStatus);attendance.className='phone-directory-attendance';attendance.classList.add(person.attendanceStatus.trim()==='موجود'?'is-present':'is-away');badges.append(attendance);}copy.append(badges);
        if(person.personalIDAssignedTo&&person.assignedToFullName){const assigned=make('button','المكلف: '+person.assignedToFullName);assigned.type='button';assigned.className='phone-directory-assigned';assigned.addEventListener('click',()=>{input.value=person.assignedToFullName;search(true,person.personalIDAssignedTo);input.focus({preventScroll:true});});copy.append(assigned);}
        const details=make('details'),summary=make('summary','المزيد'),body=make('div');details.append(summary,body);
        let loaded=false,busy=false;
        async function more(){
          if(loaded||busy||!details.open)return;
          busy=true;body.replaceChildren(make('p','جارٍ التحميل…'));const current=version;
          try{
            let data;
            if(person.isSimulation)data=person.moreInfo;
            else{
              if(!person.persID||!person.employeeTypeID)throw new Error('معرّف جهة الاتصال غير متاح.');
              const url=endpoint('api/phone-directory/more');url.searchParams.set('id',person.persID);url.searchParams.set('employeeTypeId',person.employeeTypeID);
              const response=await fetch(url,{credentials:'include',cache:'no-store',signal:AbortSignal.any([request.signal,AbortSignal.timeout(20000)])});data=await response.json();
              if(!response.ok)throw new Error(data.title||'تعذر تحميل المزيد.');
            }
            if(current!==version||!card.isConnected)return;
            body.replaceChildren();
            for(const phone of data.phoneNumbers){const item=make('div');item.className='phone-directory-extra-phone';const number=make('strong',phone.number||'—');number.dir='ltr';item.append(number,make('span',[phone.phoneTypeName,phone.phonePlace,phone.phoneStateName].filter(Boolean).join(' · ')));if(phone.note)item.append(make('small',phone.note));body.append(item);}
            for(const [label,value] of [['العنوان الحالي',data.contactAddress?.currentAddress],['العنوان الدائم',data.contactAddress?.permanentAddress]])if(value)body.append(make('p',label+': '+value));
            if(!body.children.length)body.append(make('p','لا توجد معلومات إضافية.'));loaded=true;
          }catch(error){if(current!==version)return;body.replaceChildren(make('p',error.name==='TimeoutError'?'انتهت مهلة التحميل.':error.message));const retry=make('button','إعادة المحاولة');retry.type='button';retry.addEventListener('click',()=>void more());body.append(retry);}finally{busy=false;}
        }
        details.addEventListener('toggle',()=>void more());copy.append(details);card.append(avatar,copy);
        if(person.isSimulation&&person.simulationEmail){const mail=make('button','✉');mail.type='button';mail.className='phone-directory-email';mail.setAttribute('aria-label','معاينة بريد إلى '+person.name);mail.addEventListener('click',()=>document.dispatchEvent(new CustomEvent('portal:simulation-open',{detail:{title:'معاينة رسالة إلى '+person.name,text:'إلى: '+person.simulationEmail+' — محاكاة فقط، لا يتم فتح OWA أو إرسال بريد.'}})));card.append(mail);}
        if(!person.isSimulation&&person.composeUrl){const url=new URL(person.composeUrl);if(['https:','http:'].includes(url.protocol)){const mail=make('a');mail.className='phone-directory-email';mail.href=url.href;mail.target='_blank';mail.rel='noopener noreferrer';mail.title='كتابة بريد إلى '+person.name;mail.setAttribute('aria-label',mail.title);const icon=make('span','✉');icon.setAttribute('aria-hidden','true');mail.append(icon);card.append(mail);}}
        list.append(card);
      }
      status.textContent=targetId?(contacts.length?'جهة الاتصال المكلّفة':(data.total?'لم تظهر جهة الاتصال المكلّفة في هذه الصفحة. جرّب الصفحة التالية.':'لم يتم العثور على جهة الاتصال المكلّفة.')):data.total?`${data.total} جهة اتصال · صفحة ${page} من ${Math.ceil(data.total/10)}`:'لا توجد جهات اتصال مطابقة.';
      paging.replaceChildren();for(const [label,next,disabled] of [['السابق',page-1,page===1],['التالي',page+1,page*10>=data.total]]){const button=make('button',label);button.type='button';button.disabled=disabled;button.addEventListener('click',()=>{page=next;void load();});paging.append(button);}paging.hidden=data.total<=10;
    }catch(error){
      if(mine!==version||request.signal.aborted)return;
      status.textContent=error.name==='TimeoutError'?'انتهت مهلة البحث. حاول مجددًا.':error.message;
      const retry=make('button','إعادة المحاولة');retry.type='button';retry.addEventListener('click',()=>void load());list.append(retry);
    }finally{if(mine===version)list.removeAttribute('aria-busy');}
  }
  function key(event){
    const cards=[...list.querySelectorAll('.phone-directory-contact')];if(!cards.length)return;
    if(event.key==='ArrowDown'||event.key==='ArrowUp'){event.preventDefault();selected=selected<0?(event.key==='ArrowDown'?0:cards.length-1):(selected+(event.key==='ArrowDown'?1:-1)+cards.length)%cards.length;cards.forEach((c,i)=>c.setAttribute('aria-selected',String(i===selected)));input.setAttribute('aria-activedescendant',cards[selected].id);cards[selected].scrollIntoView({block:'nearest'});}
    if(event.key==='Enter'){event.preventDefault();cards[Math.max(0,selected)].querySelector('summary, a')?.focus();}
  }
  document.addEventListener('visibilitychange',()=>{if(document.hidden){close();list.replaceChildren();status.textContent='أعد البحث لعرض جهات الاتصال.';}});
  window.CompanyPortalPhoneDirectory={search,close,key};
})();
