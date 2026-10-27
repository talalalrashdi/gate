(() => {
  const core=window.AdminCore,form=document.getElementById('history-filters');if(!form)return;
  const by=id=>document.getElementById('history-'+id),list=by('list'),status=by('status'),dialog=by('details');let page=1,total=0,busy=false,generation=0;
  const names={cards:'البطاقات الأساسية',applications:'الأنظمة الإلكترونية',documents:'وثائق تهمك',safety:'تعليمات السلامة','fixed-orders':'التوجيهات السامية','header-content':'أرقام تهمك والحالة',notices:'التنويهات',alerts:'التنبيهات',media:'أخبارنا',images:'صور الواجهة',themes:'الثيمات والمظهر'};
  const actions={create:'أضاف',update:'عدّل',delete:'حذف','apply-to-all':'طبّق على الجميع'};
  const make=(tag,text,cls)=>{const n=document.createElement(tag);if(text!==undefined)n.textContent=text;if(cls)n.className=cls;return n;};
  for(const [value,name] of Object.entries(names)){const o=make('option',name);o.value=value;form.elements.section.append(o);}
  async function details(row){
    by('details-title').textContent=row.itemTitle||'تفاصيل العنصر '+row.itemId;by('details-meta').textContent=AdminChanges.date(row.changedAt)+' · '+row.displayName+' · '+names[row.section]+' · '+actions[row.action];
    by('diff').replaceChildren();by('details-status').textContent='جارٍ تحميل التفاصيل…';dialog.showModal();const current=++generation;
    try{const r=await core.request('api/admin/changes/'+encodeURIComponent(row.changeId));if(!r.ok)throw new Error();const data=await r.json();if(!dialog.open||current!==generation)return;
      const fields=AdminHistoryDiff.compare(data.oldJson?JSON.parse(data.oldJson):null,data.newJson?JSON.parse(data.newJson):null);
      by('details-status').textContent=fields.length?'الحقول المعدّلة مميزة بلون أخضر فاتح.':'لا توجد تفاصيل محفوظة لهذا السجل.';
      for(const field of fields){
        const line=make('section',undefined,'admin-history-diff-row'+(field.changed?' is-changed':''));line.append(make('h3',field.label));
        const columns=make('div',undefined,'admin-history-diff-columns');columns.append(make('pre',field.before),make('pre',field.after));line.append(columns);
        if(field.added.length)line.append(make('p','أضيف: '+field.added.join('، '),'admin-history-added'));
        if(field.removed.length)line.append(make('p','أزيل: '+field.removed.join('، '),'admin-history-removed'));by('diff').append(line);
      }
    }catch{if(dialog.open&&current===generation)by('details-status').textContent='تعذر تحميل التفاصيل. أغلق النافذة وأعد المحاولة.';}
  }
  async function load(){
    if(busy||!core.can('history'))return;busy=true;status.textContent='جارٍ تحميل سجل التعديلات…';list.replaceChildren();form.querySelectorAll('button').forEach(b=>b.disabled=true);by('prev').disabled=by('next').disabled=true;
    try{
      const query=new URLSearchParams({page:String(page)});for(const [key,value] of new FormData(form))if(value)query.set(key,value);
      const r=await core.request('api/admin/changes?'+query);if(!r.ok)throw new Error();const data=await r.json();total=data.total;
      for(const row of data.items){const button=make('button',undefined,'admin-history-row');button.type='button';button.append(make('time',AdminChanges.date(row.changedAt)),make('span',row.displayName),make('span',names[row.section]||row.section),make('span',actions[row.action]||row.action,'admin-badge'),make('strong',row.itemTitle||row.itemType+' #'+row.itemId));button.onclick=()=>void details(row);list.append(button);}
      status.textContent=total?'عدد التعديلات: '+total:'لا توجد تعديلات مطابقة.';by('page').textContent='صفحة '+page+' من '+Math.max(1,Math.ceil(total/25));
      by('prev').disabled=page<=1;by('next').disabled=page*25>=total;
    }catch{status.textContent='تعذر تحميل السجل. تحقق من الاتصال وصلاحية المدير العام ثم اضغط بحث.';}finally{busy=false;form.querySelectorAll('button').forEach(b=>b.disabled=false);}
  }
  by('details-close').onclick=()=>dialog.close();dialog.addEventListener('close',()=>generation++);
  form.onsubmit=e=>{e.preventDefault();if(!form.reportValidity())return;page=1;void load();};form.onreset=()=>queueMicrotask(()=>{page=1;void load();});
  by('prev').onclick=()=>{if(!busy&&page>1){page--;void load();}};by('next').onclick=()=>{if(!busy&&page*25<total){page++;void load();}};
  document.addEventListener('admin:access',()=>{if(!core.can('history')){list.replaceChildren();dialog.close();}});core.whenSection('history',()=>void load());
})();
