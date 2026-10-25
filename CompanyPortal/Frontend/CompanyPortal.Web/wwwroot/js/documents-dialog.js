(() => {
  const trigger=document.getElementById('documents-sheet-trigger'),sheet=document.getElementById('documents-sheet');
  const base=document.querySelector('meta[name="companyportal-api-base"]')?.content;
  if(!trigger||!sheet||!base)return;
  const search=sheet.querySelector('#document-search'),folder=sheet.querySelector('#document-folder');
  const list=sheet.querySelector('#documents-list'),status=sheet.querySelector('#document-status'),retry=sheet.querySelector('#document-retry');
  const formats=[...sheet.querySelectorAll('[data-document-format]')];
  const endpoint=path=>new URL(path,new URL(base.replace(/\/?$/,'/'),location.href)).href;
  const make=(tag,cls,text)=>{const node=document.createElement(tag);if(cls)node.className=cls;if(text!==undefined)node.textContent=text;return node;};
  const normalize=text=>text.normalize('NFKC').replace(/[\u064B-\u065F\u0670\u0640]/g,'').replace(/[أإآ]/g,'ا').replace(/ى/g,'ي').toLocaleLowerCase('ar').trim();
  let rows=[],format='all',controller,generation=0,ready=false;
  function clear(){rows=[];ready=false;list.replaceChildren();folder.replaceChildren(make('option',null,'جميع المجلدات'));folder.firstElementChild.value='';}
  function render(){
    if(!ready)return;
    const query=normalize(search.value);
    const matches=rows.filter(row=>(format==='all'||(format==='pdf')===row.isPdf)&&(!folder.value||String(row.folderId)===folder.value)
      &&normalize(row.documentName+' '+row.fileName+' '+row.folderPath).includes(query));
    list.scrollTop=0;list.replaceChildren();
    for(const row of matches){
      const li=make('li'),link=make('a','portal-document-row');link.href=endpoint('api/documents/'+row.documentId+'/file');link.rel='noopener noreferrer';
      if(row.isPdf)link.target='_blank';
      link.setAttribute('aria-label',row.documentName+(row.isPdf?' — عرض PDF في علامة تبويب جديدة':' — تنزيل الملف'));
      const extension=row.fileName.split('.').length>1?row.fileName.split('.').pop().toUpperCase():'ملف';
      const icon=make('span','portal-document-type '+(row.isPdf?'is-pdf':'is-word'),row.isPdf?'PDF':'↓');icon.setAttribute('aria-hidden','true');
      const copy=make('div');copy.append(make('strong',null,row.documentName),make('small',null,row.folderPath),make('small',null,row.fileName));
      link.append(icon,copy,make('span','portal-document-format',extension));li.append(link);list.append(li);
    }
    status.textContent=matches.length?matches.length.toLocaleString('ar-OM')+' ملف':rows.length?'لا توجد ملفات مطابقة للبحث.':'لا توجد ملفات متاحة حاليًا.';
  }
  async function load(){
    controller?.abort();controller=new AbortController();const current=++generation;
    clear();retry.hidden=true;status.textContent='جارٍ تحميل الاستمارات والوثائق…';list.setAttribute('aria-busy','true');
    try{
      const response=await fetch(endpoint('api/documents'),{credentials:'include',cache:'no-store',signal:AbortSignal.any([controller.signal,AbortSignal.timeout(15000)])});
      if(!response.ok)throw new Error(response.status===403?'الحساب غير مسجل أو غير نشط في البوابة.':response.status===401?'تعذر التحقق من حساب Windows.':'تعذر تحميل الاستمارات والوثائق. أعد المحاولة.');
      const data=await response.json();if(current!==generation||!sheet.open)return;
      if(!Array.isArray(data)||new Set(data.map(row=>row?.documentId?.toLowerCase())).size!==data.length||data.some(row=>!row||typeof row.documentId!=='string'
        ||! /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(row.documentId)
        ||!['documentName','fileName','folderName','folderPath'].every(key=>typeof row[key]==='string')||!Number.isInteger(row.folderId)
        ||!(row.parentId===null||Number.isInteger(row.parentId))||typeof row.isPdf!=='boolean'))throw new Error('تعذر قراءة بيانات الملفات.');
      rows=data;ready=true;
      const folders=new Map(rows.map(row=>[row.folderId,row.folderPath]));
      for(const [id,path] of [...folders].sort((a,b)=>a[1].localeCompare(b[1],'ar'))){const option=make('option',null,path);option.value=String(id);folder.append(option);}
      render();
    }catch(error){if(current!==generation||!sheet.open)return;clear();status.textContent=error.name==='Error'?error.message:'تعذر الاتصال بخدمة الملفات. أعد المحاولة.';retry.hidden=false;}
    finally{if(current===generation)list.setAttribute('aria-busy','false');}
  }
  search.addEventListener('input',render);folder.addEventListener('change',render);retry.addEventListener('click',load);
  formats.forEach(button=>button.addEventListener('click',()=>{format=button.dataset.documentFormat;formats.forEach(item=>item.setAttribute('aria-pressed',String(item===button)));render();}));
  trigger.setAttribute('aria-expanded','false');
  trigger.addEventListener('click',event=>{event.preventDefault();if(sheet.open)return;if(typeof closeSearch==='function')closeSearch(false);sheet.showModal();trigger.setAttribute('aria-expanded','true');load();});
  sheet.querySelector('.portal-documents-sheet-close').addEventListener('click',()=>sheet.close());
  sheet.addEventListener('click',event=>{const bounds=sheet.getBoundingClientRect();if(event.target===sheet&&(event.clientX<bounds.left||event.clientX>bounds.right||event.clientY<bounds.top||event.clientY>bounds.bottom))sheet.close();});
  sheet.addEventListener('close',()=>{generation++;controller?.abort();clear();trigger.setAttribute('aria-expanded','false');if(!document.querySelector('dialog[open]'))trigger.focus({preventScroll:true});});
  document.addEventListener('visibilitychange',()=>{if(document.hidden){generation++;controller?.abort();clear();}else if(sheet.open)load();});
  window.addEventListener('pagehide',()=>{generation++;controller?.abort();clear();});
})();