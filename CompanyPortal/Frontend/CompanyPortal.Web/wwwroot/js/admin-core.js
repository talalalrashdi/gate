/* Shared admin transport, feedback, confirmations, access and draft guards. No business writes. */
(() => {
  'use strict';
  const base=new URL(document.querySelector('meta[name="companyportal-api-base"]').content.replace(/\/?$/,'/'),location.href);
  const trackers=new Set(),sections=new Set();let access=null,accessPending,confirming=false,feedbackUntil=0,feedbackText='',lastFeedback='',lastFeedbackAt=0,leaving=false;
  const dialog=document.getElementById('admin-confirm'),toasts=document.getElementById('admin-toasts');
  const make=(tag,text,cls)=>{const e=document.createElement(tag);if(text!==undefined)e.textContent=text;if(cls)e.className=cls;return e;};
  function notify(text,type='success'){
    if(!text)return;if(text===lastFeedback&&Date.now()-lastFeedbackAt<2000)return;lastFeedback=text;lastFeedbackAt=Date.now();
    const e=make('div',undefined,'admin-toast is-'+type);e.setAttribute('role',type==='error'?'alert':'status');
    const close=make('button','×');close.type='button';close.setAttribute('aria-label','إغلاق الرسالة');close.onclick=()=>e.remove();e.append(make('span',text),close);toasts.append(e);
    if(type!=='error')setTimeout(()=>e.remove(),4500);
  }
  function feedback(element,text,error=false){
    const failed=error||/^(تعذر|لم يتم|لا يمكن|ليس لديك|أدخل|تحقق|بلغت|تجاوزت|حسابك)/.test(text);
    const success=/^تم (الحفظ|حفظ|حذف|الحذف|رفع|إخفاء|تعيين)/.test(text)||text.startsWith('الثيم مباشر');
    const value=failed&&Date.now()<feedbackUntil?feedbackText:text;
    element.textContent=success&&!failed?'':value;element.dataset.error=String(failed);
    if(failed&&!(Date.now()<feedbackUntil))notify(value,'error');else if(success&&!failed)notify(/حذف|الحذف/.test(text)?'تم الحذف':/رفع/.test(text)?'تم الرفع':'تم الحفظ');
    refresh();
  }
  function errorMessage(status){return ({401:'انتهت صلاحية الجلسة. أعد تسجيل الدخول أو تحميل الصفحة.',403:'لا تملك صلاحية هذا القسم.',400:'تحقق من القيم المطلوبة وصحتها.',404:'العنصر غير موجود. أعد تحميل القائمة.',409:'تعذر الحفظ لوجود تعارض. راجع البيانات وأعد المحاولة.',413:'حجم الملف يتجاوز الحد المسموح.',429:'طلبات كثيرة. انتظر قليلًا ثم أعد المحاولة.'})[status]||'تعذر إتمام العملية. تحقق من الاتصال وأعد المحاولة.';}
  function reportTransport(text){feedbackText=text;feedbackUntil=Date.now()+2000;notify(text,'error');}
  async function request(path,options={}){
    // handled: statuses the caller explains with its own specific message, so the generic one is not shown.
    const {method='GET',body,header,timeout=15000,handled=[]}=options,url=new URL(path,base);
    if(url.origin!==base.origin)throw new Error('عنوان خدمة الإدارة غير صالح.');
    const write=!['GET','HEAD'].includes(method),headers={};
    if(write){if(!header)throw new Error('ترويسة طلب الإدارة مطلوبة.');headers['X-CompanyPortal-Request']=header;if(body!==undefined&&!(body instanceof FormData))headers['Content-Type']='application/json';}
    let response;
    try{response=await fetch(url,{method,credentials:'include',cache:'no-store',headers,signal:AbortSignal.timeout(timeout),...(body===undefined?{}:{body:body instanceof FormData?body:JSON.stringify(body)})});}
    catch(error){reportTransport(error.name==='TimeoutError'?'انتهت مهلة الاتصال. تعذر تأكيد العملية؛ تحقق من النتيجة قبل إعادة الحفظ.':'تعذر الاتصال بخدمة البوابة. تحقق من الاتصال وأعد المحاولة.');throw error;}
    if(!response.ok){if(!handled.includes(response.status))reportTransport(errorMessage(response.status));if(response.status===401){access=null;applyAccess();}else if(response.status===403)void loadAccess();}
    if(response.ok&&write&&!url.pathname.endsWith('/preview'))document.dispatchEvent(new CustomEvent('admin:saved',{detail:{header,path:url.pathname}}));
    return response;
  }
  async function confirm(message,{title='تأكيد الإجراء',accept,danger=false}={}){
    if(confirming)return false;confirming=true;const previous=document.activeElement;
    dialog.querySelector('h2').textContent=title;dialog.querySelector('p').textContent=message;
    const yes=dialog.querySelector('[data-confirm-yes]'),no=dialog.querySelector('[data-confirm-no]');yes.textContent=accept||'متابعة';yes.classList.toggle('is-danger',danger);
    return new Promise(resolve=>{
      const finish=value=>{dialog.close();yes.onclick=no.onclick=dialog.oncancel=null;confirming=false;if(previous?.isConnected)previous.focus({preventScroll:true});resolve(value);};
      yes.onclick=()=>finish(true);no.onclick=()=>finish(false);dialog.oncancel=e=>{e.preventDefault();finish(false);};dialog.showModal();no.focus();
    });
  }
  const discard=message=>confirm(message||'توجد تغييرات غير محفوظة. هل تريد المتابعة دون حفظ؟',{title:'تغييرات غير محفوظة',accept:'متابعة دون حفظ',danger:true});
  function watch(section,element,dirty,busy=()=>false){
    const tracker={section,element,dirty,busy};trackers.add(tracker);queueMicrotask(refresh);return tracker;
  }
  function dirtyIn(section){return [...trackers].some(t=>(!section||t.section===section)&&t.element.isConnected&&t.dirty());}
  function busyIn(section){return [...trackers].some(t=>(!section||t.section===section)&&t.element.isConnected&&t.busy());}
  function refresh(){
    for(const t of [...trackers]){
      if(!t.element.isConnected){trackers.delete(t);continue;}
      const dirty=!!t.dirty(),value=String(dirty);if(t.element.dataset.adminDirty!==value)t.element.dataset.adminDirty=value;
      let badge=t.element.querySelector(':scope > .admin-unsaved-badge');
      if(dirty&&!badge){badge=make('span','غير محفوظ','admin-unsaved-badge');t.element.prepend(badge);}else if(!dirty&&badge)badge.remove();
    }
    document.querySelectorAll('.admin-nav [data-admin-section]').forEach(b=>{const value=String(dirtyIn(b.dataset.adminSection));if(b.dataset.unsaved!==value)b.dataset.unsaved=value;});
  }
  function trackForm(section,element,{isNew=false,busy=()=>false}={}){
    const serial=()=>JSON.stringify([...element.querySelectorAll('input:not([data-admin-ignore-dirty]),select:not([data-admin-ignore-dirty]),textarea:not([data-admin-ignore-dirty])')].map(e=>e.type==='file'?[...e.files].map(f=>[f.name,f.size,f.lastModified]):e.type==='checkbox'||e.type==='radio'?e.checked:e.value));
    let baseline=serial(),fresh=isNew;
    const tracker=watch(section,element,()=>fresh||serial()!==baseline,busy);
    return {saved(){baseline=serial();fresh=false;refresh();},dirty:tracker.dirty};
  }
  async function mayLeave(section){if(busyIn(section)){notify('انتظر اكتمال العملية الحالية.','error');return false;}return !dirtyIn(section)||await discard();}
  function applyAccess(){
    sections.clear();if(access?.isAdmin)for(const key of access.sections||[])sections.add(key);
    if(access?.isSuperAdmin)sections.add('history');
    document.querySelectorAll('[data-admin-super]').forEach(e=>e.hidden=!access?.isSuperAdmin);
    const allowed=sections.size>0,workspace=document.getElementById('admin-workspace'),message=document.getElementById('admin-access-message');
    workspace.hidden=!allowed;message.hidden=allowed;
    document.querySelectorAll('[data-admin-section]').forEach(button=>{const ok=allowed&&(button.dataset.adminSection==='overview'||sections.has(button.dataset.adminSection));button.hidden=!ok;button.disabled=!ok;});
    document.querySelectorAll('[data-admin-requires]').forEach(e=>e.hidden=!sections.has(e.dataset.adminRequires));
    if(!allowed)document.getElementById('admin-retry').hidden=false;
    if(!allowed)message.querySelector('p').textContent=access?'لا تملك صلاحية إدارة أقسام البوابة.':'تعذر التحقق من الصلاحية. أعد المحاولة.';
    document.dispatchEvent(new CustomEvent('admin:access',{detail:{allowed}}));
  }
  async function loadAccess(){
    if(accessPending)return accessPending;
    const status=document.getElementById('admin-status'),retry=document.getElementById('admin-retry');retry.hidden=true;status.dataset.state='loading';status.textContent='جارٍ التحقق من الصلاحية…';
    accessPending=(async()=>{try{
      const r=await request('api/access',{timeout:10000});if(!r.ok)throw new Error();const data=await r.json();
      if(typeof data.isAdmin!=='boolean'||!Array.isArray(data.sections)||data.sections.some(s=>typeof s!=='string'))throw new Error();
      access=data;applyAccess();status.dataset.state=data.isAdmin?'ready':'error';status.textContent=data.isAdmin?'تم التحقق من صلاحية الإدارة.':'لا تملك صلاحية إدارة البوابة.';
    }catch{access=null;applyAccess();status.dataset.state='error';status.textContent='تعذر التحقق من صلاحية الإدارة.';retry.hidden=false;}finally{accessPending=null;}})();return accessPending;
  }
  function whenSection(section,action){document.addEventListener('admin:section',event=>{if(event.detail.section===section&&(section==='overview'?sections.size>0:sections.has(section)))action();});if(document.body.dataset.adminCurrent===section&&(section==='overview'?sections.size>0:sections.has(section)))queueMicrotask(action);}
  // Observe only structural/state changes; input values are compared by each editor.
  let queued=false;function schedule(){if(queued)return;queued=true;queueMicrotask(()=>{queued=false;refresh();});}
  document.addEventListener('input',schedule);document.addEventListener('change',schedule);document.addEventListener('click',schedule);
  new MutationObserver(records=>{if(records.some(r=>r.type==='childList'&&[...r.addedNodes,...r.removedNodes].some(n=>n.nodeType===1&&!n.matches('.admin-unsaved-badge'))||r.type==='attributes'))schedule();}).observe(document.getElementById('admin-workspace'),{subtree:true,childList:true,attributes:true,attributeFilter:['class','hidden','disabled']});
  window.addEventListener('beforeunload',e=>{if(!leaving&&(dirtyIn()||busyIn())){e.preventDefault();e.returnValue='';}});
  document.addEventListener('click',async e=>{const a=e.target.closest('a[href]');if(!a||a.target==='_blank'||e.button!==0||e.ctrlKey||e.metaKey||e.shiftKey||e.altKey||!dirtyIn()&&!busyIn())return;const url=new URL(a.href);if(url.href===location.href||url.protocol==='javascript:')return;e.preventDefault();if(await mayLeave()){leaving=true;location.assign(url.href);}},true);
  document.getElementById('admin-retry').onclick=()=>void loadAccess();
  window.AdminCore={request,feedback,notify,confirm,discard,watch,trackForm,refresh,dirtyIn,busyIn,mayLeave,whenSection,can:section=>section==='overview'?sections.size>0:sections.has(section),loadAccess};
  void loadAccess();
})();
