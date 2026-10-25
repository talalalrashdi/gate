(() => {
  const root=document.getElementById('admin-fixed-orders'),base=document.querySelector('meta[name="companyportal-api-base"]')?.content;if(!root||!base)return;
  const endpoint=path=>new URL('api/admin/fixed-orders'+path,new URL(base.replace(/\/?$/,'/'),location.href));
  const byId=id=>document.getElementById(id),list=byId('fixed-order-admin-list'),search=byId('fixed-order-admin-search'),status=byId('fixed-order-admin-status'),retry=byId('fixed-order-admin-retry'),add=byId('fixed-order-add'),editor=byId('fixed-order-editor'),form=byId('fixed-order-form'),save=byId('fixed-order-save'),error=byId('fixed-order-form-error');
  const fields={timestamp:byId('fixed-order-date'),timestamp2:byId('fixed-order-date2'),timestampType:byId('fixed-order-date-type'),contentAfter:byId('fixed-order-after'),contentBefor:byId('fixed-order-before'),contentText:byId('fixed-order-content')};
  const make=(tag,text)=>{const n=document.createElement(tag);if(text!==undefined)n.textContent=text;return n;};
  let rows=[],current=null,original='',loaded=false,busy=false,isNew=false;
  const request=(path,method='GET',body)=>fetch(endpoint(path),{method,credentials:'include',cache:'no-store',signal:AbortSignal.timeout(15000),...(method==='GET'?{}:{headers:{'Content-Type':'application/json','X-CompanyPortal-Request':'fixed-orders'},body:JSON.stringify(body)})});
  const values=()=>({timestamp:fields.timestamp.value||null,timestamp2:fields.timestamp2.value||null,timestampType:fields.timestampType.value===''?null:Number(fields.timestampType.value),contentAfter:fields.contentAfter.value,contentBefor:fields.contentBefor.value.trim()?fields.contentBefor.value:null,contentText:fields.contentText.value});
  const dirty=()=>!editor.hidden&&(isNew||JSON.stringify(values())!==original);
  function message(text,canRetry=false){status.textContent=text;retry.hidden=!canRetry;}
  function sync(){
    const row=values(),before=row.contentText.includes('ds{0}de');fields.contentBefor.required=before;
    byId('fixed-order-preview-title').textContent=row.contentAfter.trim()||'توجيه سامٍ';
    byId('fixed-order-preview-date').textContent=row.timestamp?'السنة '+row.timestamp.slice(0,4)+' · '+row.timestamp.split('-').reverse().join('/'):'التاريخ غير محدد';
    const p=byId('fixed-order-preview-text');p.replaceChildren();window.CompanyPortalFixedOrderText.append(p,row);
    byId('fixed-order-dirty').textContent=dirty()?'تغييرات غير محفوظة':'لا توجد تغييرات غير محفوظة';save.disabled=busy||!dirty();
  }
  function lock(){root.querySelectorAll('input,textarea,button').forEach(n=>{n.disabled=busy;});add.disabled=busy||!loaded;if(!editor.hidden)sync();}
  const normalize=v=>(v||'').normalize('NFKD').replace(/[\u064B-\u065F\u0670]/g,'').replace(/[أإآ]/g,'ا').replace(/ى/g,'ي').toLowerCase().trim();
  function renderList(){
    const q=normalize(search.value);list.replaceChildren(...rows.filter(r=>normalize([r.contentAfter,r.contentBefor,r.contentText,r.timestamp].join(' ')).includes(q)).map(row=>{
      const b=make('button');b.type='button';b.setAttribute('aria-pressed',String(current?.fixedOrderId===row.fixedOrderId));b.append(make('strong',row.contentAfter?.trim()||'توجيه سامٍ'),make('small',row.timestamp||'التاريخ غير محدد'));b.addEventListener('click',()=>choose(row));return b;
    }));if(!list.children.length)list.append(make('p','لا توجد توجيهات مطابقة.'));
  }
  function choose(row){
    if(busy||(dirty()&&!confirm('إلغاء التغييرات غير المحفوظة وفتح التوجيه؟')))return;
    current=row;isNew=!row;editor.hidden=false;error.hidden=true;
    const data=row||{timestamp:null,timestamp2:null,timestampType:null,contentBefor:null,contentAfter:'',contentText:'بتغيير ds{0}de إلى ss{1}se'};
    for(const [key,input] of Object.entries(fields))input.value=data[key]??'';
    original=JSON.stringify(values());byId('fixed-order-editor-title').textContent=isNew?'توجيه جديد':'تعديل التوجيه';save.textContent=isNew?'حفظ ونشر التوجيه':'حفظ التغييرات';renderList();sync();fields.contentAfter.focus();
  }
  async function load(selectId){
    busy=true;lock();message('جارٍ تحميل التوجيهات السامية…');
    try{
      const response=await request('');if(!response.ok)throw new Error(String(response.status));rows=await response.json();loaded=true;renderList();message('السجل جاهز. تُنشر التغييرات لجميع مستخدمي البوابة.');
      if(selectId){current=rows.find(r=>r.fixedOrderId===selectId)||null;isNew=false;editor.hidden=true;}
    }catch(e){loaded=false;rows=[];current=null;editor.hidden=true;list.replaceChildren();message(e.message==='401'||e.message==='403'?'ليس لديك صلاحية إدارة التوجيهات السامية.':'تعذر تحميل السجل. تحقق من الاتصال وقاعدة البيانات.',true);}
    finally{busy=false;lock();if(selectId&&loaded){const row=current;current=null;if(row)choose(row);}}
  }
  form.addEventListener('input',()=>{error.hidden=true;sync();});
  root.querySelectorAll('[data-order-insert]').forEach(b=>b.addEventListener('click',()=>{
    const input=fields.contentText,text=b.dataset.orderInsert;if(input.value.length-(input.selectionEnd-input.selectionStart)+text.length>1000){error.textContent='بلغت الصياغة الحد الأقصى: 1000 حرف.';error.hidden=false;return;}
    input.setRangeText(text,input.selectionStart,input.selectionEnd,'end');input.focus();sync();
  }));
  root.querySelectorAll('[data-order-preset]').forEach(b=>b.addEventListener('click',()=>{if(fields.contentText.value&& !confirm('استبدال الصياغة الحالية بالصياغة المختارة؟'))return;fields.contentText.value=b.dataset.orderPreset==='change'?'بتغيير ds{0}de إلى ss{1}se':'ds{0}de';sync();fields.contentText.focus();}));
  form.addEventListener('submit',async e=>{
    e.preventDefault();sync();if(busy||!dirty()||!form.reportValidity())return;
    const body=values(),id=current?.fixedOrderId;busy=true;lock();error.hidden=true;message('جارٍ حفظ التوجيه…');
    try{
      const response=await request(isNew?'':'/'+id,isNew?'POST':'PUT',body);
      if(!response.ok){
        if(response.status===401||response.status===403){rows=[];loaded=false;list.replaceChildren();editor.hidden=true;message('ليس لديك صلاحية إدارة التوجيهات السامية.',true);return;}
        error.textContent=response.status===400?'تحقق من العنوان والصياغة والنص السابق ونوع التاريخ وحدود الأحرف. استخدم أزرار الإدراج للعلامات.':response.status===404?'لم يعد التوجيه موجودًا. أعد تحميل السجل.':'تعذر الحفظ. تحقق من الاتصال وأعد المحاولة.';error.hidden=false;message('لم يتم الحفظ.');return;
      }
      const savedId=isNew?(await response.json()).fixedOrderId:id;isNew=false;editor.hidden=true;busy=false;await load(savedId);if(loaded)message('تم الحفظ. يظهر التوجيه بالتنسيق المعروض عند إعادة فتح قائمة التوجيهات في البوابة.');
    }catch{error.textContent='تعذر تأكيد الحفظ. أعد تحميل السجل للتحقق قبل إعادة المحاولة.';error.hidden=false;message('تعذر تأكيد الحفظ.',true);}
    finally{busy=false;lock();}
  });
  byId('fixed-order-cancel').addEventListener('click',()=>{if(dirty()&&!confirm('إلغاء التغييرات غير المحفوظة؟'))return;editor.hidden=true;current=null;isNew=false;renderList();});
  add.addEventListener('click',()=>choose(null));search.addEventListener('input',renderList);retry.addEventListener('click',()=>{if(!busy&&(!dirty()||confirm('إعادة التحميل ستلغي التغييرات غير المحفوظة. متابعة؟'))){editor.hidden=true;current=null;load();}});
  document.querySelectorAll('[data-admin-section="fixed-orders"]').forEach(b=>b.addEventListener('click',()=>{if(!loaded&&!busy)load();}));window.addEventListener('popstate',()=>{if(location.hash==='#fixed-orders'&&!loaded&&!busy)load();});
  window.addEventListener('beforeunload',e=>{if(dirty()){e.preventDefault();e.returnValue='';}});
  if(document.body.dataset.adminStart==='fixed-orders'||location.hash==='#fixed-orders')load();
})();
