/* Employee calendar editing. Drafts stay in this dialog until explicitly saved. */
window.CompanyPortalCalendarEditor = options => {
  const make=(tag,text)=>{const n=document.createElement(tag);if(text!==undefined)n.textContent=text;return n;};
  const btn=text=>{const b=make('button',text);b.type='button';return b;};
  const local=(value,dateOnly=false)=>{const parts=new Intl.DateTimeFormat('en-CA',{timeZone:options.zone(),year:'numeric',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit',hourCycle:'h23'}).formatToParts(new Date(value));const p=t=>parts.find(x=>x.type===t).value;return `${p('year')}-${p('month')}-${p('day')}`+(dateOnly?'':`T${p('hour')}:${p('minute')}`);};
  const instant=value=>{
    const raw=value.length===10?value+'T00:00':value,wanted=Date.parse(raw+'Z');let result=wanted;
    for(let i=0;i<4;i++){const actual=Date.parse(local(result)+'Z');const delta=wanted-actual;if(!delta)break;result+=delta;}
    if(!Number.isFinite(result)||local(result)!==raw)throw new Error('الوقت المحدد غير صالح في المنطقة الزمنية للتقويم.');
    return new Date(result).toISOString();
  };
  const addDay=(date,n)=>{const d=new Date(date+'T12:00Z');d.setUTCDate(d.getUTCDate()+n);return d.toISOString().slice(0,10);};
  let active=null;
  function shell(title){
    if(active)return null;
    const dialog=make('dialog');dialog.className='exchange-editor';dialog.dir='rtl';
    const heading=make('h2',title),close=btn('إغلاق'),head=make('header'),form=make('form'),error=make('p'),foot=make('footer');
    const id='exchange-editor-heading';heading.id=id;dialog.setAttribute('aria-labelledby',id);error.className='exchange-editor-error';error.setAttribute('role','alert');
    head.append(heading,close);dialog.append(head,form,error,foot);document.body.append(dialog);
    const origin=document.activeElement,overflow=document.body.style.overflow;document.body.style.overflow='hidden';active=dialog;
    let busy=false,dirty=false,confirming=false;
    const dispose=()=>{dialog.close();dialog.remove();active=null;document.body.style.overflow=overflow;origin?.focus({preventScroll:true});};
    const ask=async(text,action='تأكيد')=>{
      if(confirming)return false;confirming=true;
      const box=make('section'),message=make('p',text),yes=btn(action),no=btn('إلغاء');box.className='exchange-editor-confirm';yes.className='is-danger';box.append(message,yes,no);form.inert=true;foot.inert=true;close.disabled=true;dialog.append(box);no.focus();
      return new Promise(resolve=>{const finish=value=>{box.remove();form.inert=false;foot.inert=false;close.disabled=false;confirming=false;resolve(value);};yes.onclick=()=>finish(true);no.onclick=()=>finish(false);});
    };
    const dismiss=async()=>{if(busy||confirming)return;if(!dirty||await ask('لديك تغييرات غير محفوظة. هل تريد تجاهلها؟','تجاهل التغييرات'))dispose();};
    close.onclick=dismiss;dialog.addEventListener('cancel',e=>{e.preventDefault();void dismiss();});
    form.addEventListener('input',()=>dirty=true);form.addEventListener('change',()=>dirty=true);
    dialog.showModal();
    return {dialog,form,foot,error,ask,dispose,setBusy(value){busy=value;close.disabled=value;form.inert=value;foot.inert=value;dialog.setAttribute('aria-busy',String(value));},fail(e){error.textContent=e.message||'تعذر إتمام العملية. أعد المحاولة.';},clean(){dirty=false;}};
  }
  const field=(form,title,type='text',max)=>{const label=make('label',title),input=make(type==='textarea'?'textarea':'input');if(type!=='textarea')input.type=type;if(max)input.maxLength=max;label.append(input);form.append(label);return input;};
  async function open(item=null){
    const selected=options.calendar();if(!selected)return;const calendarKey=selected.key;
    const ui=shell(item?'تفاصيل الموعد':'موعد جديد');if(!ui)return;
    ui.form.append(make('p','التقويم: '+selected.name));
    let details=null;
    if(item){
      ui.setBusy(true);
      try{details=await options.request('api/schedule/appointments?'+new URLSearchParams({calendar:calendarKey,itemId:item.itemId}));}
      catch(e){ui.fail(e);ui.setBusy(false);return;}
      ui.setBusy(false);
    }
    const editable=!item?!!options.rights()?.create:!!details.canEdit;
    const subject=field(ui.form,'العنوان','text',255),location=field(ui.form,'المكان','text',255),body=field(ui.form,'التفاصيل','textarea',5000),allDay=field(ui.form,'طوال اليوم','checkbox'),start=field(ui.form,'البداية','datetime-local'),end=field(ui.form,'النهاية','datetime-local'),privateItem=field(ui.form,'موعد خاص','checkbox');
    subject.required=true;start.required=true;end.required=true;
    const note=make('p');note.className='exchange-editor-hint';ui.form.append(note);
    const defaults=()=>{const date=options.day();start.value=date+'T09:00';end.value=date+'T10:00';};
    defaults();
    if(details){subject.value=details.subject;location.value=details.location;body.value=details.body;allDay.checked=details.isAllDay;privateItem.checked=details.isPrivate;}
    const dates=()=>{start.type=end.type=allDay.checked?'date':'datetime-local';if(details){start.value=local(details.start,allDay.checked);end.value=allDay.checked?addDay(local(details.end,true),-1):local(details.end);}else if(allDay.checked){start.value=end.value=options.day();}else defaults();note.textContent=allDay.checked?'تاريخ النهاية هو آخر يوم مشمول بالموعد.':'الأوقات حسب المنطقة الزمنية: '+options.zone();};
    dates();allDay.onchange=dates;
    const inputs=[subject,location,body,allDay,start,end,privateItem];inputs.forEach(n=>n.disabled=!editable);
    if(details?.calendarItemType&&details.calendarItemType!=='Single')ui.form.append(make('p',details.calendarItemType==='RecurringMaster'?'عدّل سلسلة التكرار من Outlook.':'التعديل والحذف لهذا التكرار فقط، ولا يغيّران بقية السلسلة.'));
    let acknowledgement=null;
    if(details?.isMeeting){acknowledgement=field(ui.form,'أوافق على إرسال تحديث أو إلغاء الاجتماع إلى المشاركين عبر Exchange.','checkbox');if(!details.canEdit&&!details.canDelete)acknowledgement.disabled=true;}
    if(item&&!editable)ui.form.append(make('p','العرض فقط. يحدد Exchange صلاحية تعديل هذا الموعد.'));
    const save=btn(item?'حفظ التغييرات':'إنشاء الموعد');save.type='submit';save.setAttribute('form','exchange-appointment-form');ui.form.id='exchange-appointment-form';save.hidden=!editable;
    ui.foot.append(save);
    const refresh=()=>{ui.dispose();options.changed(calendarKey);};
    ui.form.onsubmit=async event=>{
      event.preventDefault();if(!editable||!ui.form.reportValidity())return;ui.error.textContent='';
      try{
        if(details?.isMeeting&&!acknowledgement.checked)throw new Error('أكد إرسال تحديث الاجتماع للمشاركين قبل الحفظ.');
        const begin=instant(start.value),finish=instant(allDay.checked?addDay(end.value,1):end.value);
        if(Date.parse(finish)<=Date.parse(begin))throw new Error('يجب أن تكون نهاية الموعد بعد بدايته.');
        if(Date.parse(finish)-Date.parse(begin)>366*86400000)throw new Error('يجب ألا تتجاوز مدة الموعد 366 يومًا.');
        ui.setBusy(true);
        await options.request('api/schedule/appointments',item?'PUT':'POST',{calendarKey,itemId:details?.itemId,changeKey:details?.changeKey,subject:subject.value.trim(),location:location.value,body:body.value,start:begin,end:finish,isAllDay:allDay.checked,isPrivate:privateItem.checked,confirmMeetingNotifications:!!acknowledgement?.checked});
        refresh();window.showToast?.('تم حفظ الموعد.');
      }catch(e){ui.fail(e);ui.setBusy(false);}
    };
    if(details?.canDelete){const remove=btn('حذف الموعد');remove.className='is-danger';ui.foot.append(remove);remove.onclick=async()=>{
      ui.error.textContent='';if(details.isMeeting&&!acknowledgement.checked){ui.fail(new Error('أكد إرسال إلغاء الاجتماع للمشاركين قبل الحذف.'));return;}
      if(!await ui.ask(details.isMeeting?'حذف هذا الاجتماع وإرسال الإلغاء للمشاركين؟':'حذف هذا الموعد من التقويم؟','حذف الموعد'))return;
      ui.setBusy(true);try{await options.request('api/schedule/appointments','DELETE',{calendarKey,itemId:details.itemId,changeKey:details.changeKey,confirmMeetingNotifications:!!acknowledgement?.checked});refresh();window.showToast?.('تم حذف الموعد.');}catch(e){ui.fail(e);ui.setBusy(false);}
    };}
    ui.clean();subject.focus();
  }
  function shared(){
    const ui=shell('فتح تقويم مشترك');if(!ui)return;
    ui.form.append(make('p','أدخل البريد الإلكتروني لصاحب التقويم. لا يمنح هذا أي صلاحيات جديدة؛ يتحقق Exchange من صلاحيات المشاركة والتفويض.'));
    const mailbox=field(ui.form,'البريد الإلكتروني','email',320);mailbox.required=true;mailbox.dir='ltr';
    const submit=btn('فتح التقويم');submit.type='submit';ui.form.append(submit);
    ui.form.onsubmit=async e=>{e.preventDefault();if(!ui.form.reportValidity())return;ui.setBusy(true);ui.error.textContent='';try{const value=await options.request('api/schedule/calendars/open','POST',{mailbox:mailbox.value.trim()});options.opened(value);ui.dispose();}catch(error){ui.fail(error);ui.setBusy(false);}};
    mailbox.focus();
  }
  return {open,shared};
};
