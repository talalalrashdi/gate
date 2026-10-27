document.querySelectorAll('[data-pdf-library-admin]').forEach(root => {
  const base=document.querySelector('meta[name="companyportal-api-base"]')?.content;if(!base)return;
  const section=root.dataset.pdfLibraryAdmin,isSafety=section==='safety',route=isSafety?'safety-library':'document-library';
  const terms=text=>isSafety?text.replaceAll('تبويبات الوثائق','كتيبات السلامة').replaceAll('التبويب','الكتيب').replaceAll('تبويب','كتيب').replaceAll('إدارة الوثائق','إدارة كتيبات السلامة').replaceAll('تحميل الوثائق','تحميل كتيبات السلامة'):text;
  const endpoint=path=>new URL('api/admin/'+route+path,new URL(base.replace(/\/?$/,'/'),location.href));
  const list=root.querySelector('[data-library-list]'),status=root.querySelector('[data-library-status]'),retry=root.querySelector('[data-library-retry]'),add=root.querySelector('[data-library-add]');
  const make=(tag,cls,text)=>{const n=document.createElement(tag);if(cls)n.className=cls;if(text!==undefined)n.textContent=terms(text);return n;};
  let catalog,loaded=false,busy=false;
  const dirty=()=>!!root.querySelector('.is-dirty');
  const core=window.AdminCore;
  const request=(path,method='GET',body)=>core.request(endpoint(path),{method,body,header:route});
  function message(text,canRetry=false){core.feedback(status,terms(text));retry.hidden=!canRetry;}
  function lock(){root.querySelectorAll('input,select,button').forEach(n=>{n.disabled=busy;});add.disabled=busy||!loaded;root.querySelectorAll('form').forEach(f=>f.dispatchEvent(new Event('library:sync')));}
  function form(tab,isNew=false){
    const f=make('form','admin-document-form');if(isNew)f.dataset.newTab='';f.setAttribute('aria-label',terms(isNew?'تبويب جديد':'تبويب '+tab.tabName));
    const field=(text,type='text')=>{const l=make('label',null,text),i=make('input');i.type=type;l.append(i);f.append(l);return i;};
    const name=field('اسم التبويب');name.required=true;name.maxLength=200;name.value=tab.tabName;
    const fl=make('label',null,'المجلد'),folder=make('select');folder.required=true;fl.append(folder);f.append(fl);
    const none=make('option',null,'اختر المجلد');none.value='';folder.append(none);
    const folders=[...new Map(catalog.documents.map(d=>[d.folderId,{id:d.folderId,name:d.folderName}])).values()];
    if(tab.folderId&&!folders.some(v=>v.id===tab.folderId))folders.push({id:tab.folderId,name:'مجلد غير متاح لحسابك'});
    folders.forEach(v=>{const o=make('option',null,v.name);o.value=v.id;folder.append(o);});folder.value=tab.folderId||'';
    const order=field('ترتيب التبويب','number');order.required=true;order.min=0;order.max=2147483647;order.step=1;order.value=tab.displayOrder;
    const files=make('fieldset');f.append(files);let selected=new Set(catalog.items.filter(i=>i.documentTabId===tab.documentTabId).map(i=>i.documentId));
    const activeLabel=make('label','admin-document-active'),active=make('input');active.type='checkbox';active.checked=tab.active;activeLabel.append(active,make('span',null,'إظهار التبويب'));f.append(activeLabel);
    const save=make('button','admin-primary',isNew?'إنشاء التبويب':'حفظ التغييرات');save.type='submit';f.append(save);
    if(isNew){const cancel=make('button',null,'إلغاء');cancel.type='button';cancel.addEventListener('click',async()=>{if(!busy&&await core.discard())f.remove();});f.append(cancel);}
    const note=make('p','admin-document-note');f.append(note);
    const values=()=>({tabName:name.value.trim(),folderId:Number(folder.value),displayOrder:Number(order.value),active:active.checked,documentIds:[...selected].sort()});
    let original=JSON.stringify(values());
    function sync(){const changed=isNew||JSON.stringify(values())!==original;f.classList.toggle('is-dirty',changed);save.disabled=busy||!changed||!selected.size||!folder.value;note.textContent=changed?'تغييرات غير محفوظة':terms('تم حفظ إعدادات التبويب.');}
    function filesList(){
      files.replaceChildren(make('legend',null,isSafety?'ملف PDF للكتيب — اختر ملفًا واحدًا':'ملفات PDF — اختر ما يظهر في التبويب'));
      const docs=catalog.documents.filter(d=>d.folderId===Number(folder.value));
      for(const id of selected)if(!docs.some(d=>d.documentId===id))docs.push({documentId:id,documentName:'ملف محفوظ غير متاح في المجلد لحسابك — أزِل اختياره أو راجع الصلاحية'});
      docs.forEach(doc=>{const l=make('label'),c=make('input');c.type=isSafety?'radio':'checkbox';if(isSafety)c.name='booklet-pdf';c.value=doc.documentId;c.checked=selected.has(doc.documentId);l.append(c,make('span',null,doc.documentName));files.append(l);c.addEventListener('change',()=>{if(c.checked){if(isSafety)selected.clear();selected.add(c.value);}else selected.delete(c.value);sync();});});
      if(!docs.length)files.append(make('p',null,'لا توجد ملفات PDF مسجلة ومتاحة في هذا المجلد.'));
    }
    folder.addEventListener('change',()=>{selected.clear();filesList();sync();});f.addEventListener('input',sync);f.addEventListener('change',sync);f.addEventListener('library:sync',sync);
    f.addEventListener('submit',async e=>{
      e.preventDefault();if(busy||!f.reportValidity())return;const value=values();if(!value.tabName||!selected.size)return;
      busy=true;lock();message('جارٍ حفظ التبويب…');
      try{
        const response=await request(isNew?'':'/'+tab.documentTabId,isNew?'POST':'PUT',value);
        if(!response.ok){
          if(response.status===401||response.status===403){loaded=false;list.replaceChildren();catalog=null;}
          message(response.status===400?'تحقق من المجلد والملفات المحددة. يجب أن تكون ملفات PDF متاحة لحسابك.':response.status===401||response.status===403?'ليس لديك صلاحية إدارة الوثائق.':response.status===404?'التبويب لم يعد موجودًا؛ أعد تحميل القائمة.':'تعذر حفظ التبويب. أعد المحاولة.',true);return;
        }
        const result=await response.json();tab.documentTabId=result.documentTabId;Object.assign(tab,value);if(isNew)catalog.tabs.push(tab);
        catalog.items=catalog.items.filter(i=>i.documentTabId!==tab.documentTabId).concat(value.documentIds.map(id=>({documentTabId:tab.documentTabId,documentId:id})));
        original=JSON.stringify(value);f.classList.remove('is-dirty');f.replaceWith(form(tab));message('تم الحفظ. تظهر التغييرات للموظفين عند إعادة تحميل البوابة.');
      }catch{message('تعذر تأكيد الحفظ. أعد تحميل القائمة للتحقق قبل إعادة المحاولة.',true);}
      finally{busy=false;lock();}
    });filesList();sync();core.watch(section,f,()=>f.classList.contains('is-dirty'),()=>busy);return f;
  }
  async function load(){
    if(busy)return;busy=true;lock();message('جارٍ تحميل تبويبات الوثائق…');
    try{
      const response=await request('');if(!response.ok)throw new Error(String(response.status));
      catalog=await response.json();loaded=true;list.replaceChildren(...catalog.tabs.map(t=>form(t)));
      message(catalog.documents.length?'اختر الملفات المسجلة من المجلد المطلوب.':'لا توجد ملفات PDF متاحة لحسابك. راجع التسجيل والصلاحيات.');
    }catch(e){loaded=false;catalog=null;list.replaceChildren();message(e.message==='401'||e.message==='403'?'ليس لديك صلاحية إدارة الوثائق.':'تعذر تحميل الوثائق. تحقق من الاتصال وقاعدة البيانات.',true);}
    finally{busy=false;lock();}
  }
  add.addEventListener('click',()=>{if(!busy&&!list.querySelector('[data-new-tab]')){const f=form({tabName:'',folderId:0,displayOrder:(catalog.tabs.length+1)*10,active:true},true);list.prepend(f);f.querySelector('input').focus();}});
  retry.addEventListener('click',async()=>{if(!busy&&(!dirty()||await core.discard()))load();});
  core.watch(section,root,()=>false,()=>busy);
  core.whenSection(section,()=>{if(!loaded&&!busy)load();});
});
