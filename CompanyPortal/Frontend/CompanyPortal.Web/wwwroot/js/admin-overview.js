(() => {
  const core=window.AdminCore,root=document.getElementById('admin-overview-cards'),status=document.getElementById('admin-overview-status'),retry=document.getElementById('admin-overview-retry');
  if(!root)return;let busy=false;
  const labels={'header-content':['حالة المؤسسة','status'],notices:['التنويهات','info-circle'],alerts:['التنبيهات','bell-1'],media:['أخبارنا','video-horizontal'],magazine:['مجلة الشهر','book-open'],changes:['آخر التعديلات','clock']};
  const actions={create:'إضافة',update:'تعديل',delete:'حذف','apply-to-all':'تطبيق للجميع'};
  const make=(tag,text,cls)=>{const n=document.createElement(tag);if(text!==undefined)n.textContent=text;if(cls)n.className=cls;return n;};
  function card(kind,section){
    const [title,name]=labels[kind],article=make('article',undefined,'admin-overview-card'),head=make('div',undefined,'admin-overview-card-heading'),icon=make('i',undefined,'iconsax');icon.setAttribute('icon-name',name);icon.setAttribute('aria-hidden','true');head.append(icon,make('h2',title));article.append(head);
    const body=make('div',undefined,'admin-overview-card-body');article.append(body);
    if(section){const button=make('button','إدارة القسم','admin-overview-link');button.type='button';button.dataset.adminSection=section;article.append(button);}root.append(article);return body;
  }
  function list(target,rows,render){if(!rows.length){target.append(make('p','لا توجد عناصر حاليًا.','admin-muted'));return;}const ul=make('ul');rows.forEach(row=>{const li=make('li');render(li,row);ul.append(li);});target.append(ul);}
  async function load(){
    if(busy||!core.can('overview'))return;busy=true;retry.hidden=true;status.textContent='جارٍ تحميل النظرة العامة…';
    try{
      const r=await core.request('api/admin/overview');if(!r.ok)throw new Error();const data=await r.json();root.replaceChildren();
      for(const item of data.cards){
        const target=card(item.kind==='notices'?item.section:item.kind==='status'?'header-content':item.kind,item.section);
        if(item.kind==='status'){
          if(!item.value){target.append(make('p','لم تُسجل حالة المؤسسة.'));continue;}
          const line=make('p',undefined,'admin-overview-current'),dot=make('span',undefined,'admin-overview-status-dot is-'+item.value.color);line.append(dot,make('strong',item.name||'حالة المؤسسة'));target.append(line,make('small','آخر تحديث: '+AdminChanges.date(item.value.lastUpdated)));
        }else if(item.kind==='magazine'){
          if(item.value)target.append(make('h3',item.value.magazineName),make('p','العدد '+item.value.issueNumber),make('small',item.value.issueDate.slice(0,10)),make('p','للعرض فقط','admin-muted'));else target.append(make('p','لا يوجد عدد منشور.'));
        }else if(item.kind==='notices'){
          target.append(make('p',item.count+' معروض الآن','admin-overview-count'));list(target,item.titles,(li,title)=>li.textContent=title);
        }else if(item.kind==='media')list(target,item.items,(li,row)=>{li.append(make('strong',row.mediaName),make('small',row.mediaType==='video'?'فيديو':'صورة'));});
      }
      const history=card('changes');history.parentElement.classList.add('admin-overview-history');
      list(history,data.changes,(li,row)=>{
        const button=make('button',row.itemTitle||row.itemType);button.type='button';button.dataset.adminSection=row.section;
        li.append(button,make('small',(actions[row.action]||row.action)+' · '+row.displayName+' · '+AdminChanges.date(row.changedAt)));
      });status.textContent='البيانات الحالية من قاعدة البيانات؛ تُحدّث عند فتح النظرة العامة.';
    }catch{root.replaceChildren();status.textContent='تعذر تحميل النظرة العامة. تحقق من الاتصال وأعد المحاولة.';retry.hidden=false;}
    finally{busy=false;}
  }
  retry.onclick=()=>void load();core.whenSection('overview',()=>void load());
  document.addEventListener('admin:access',()=>{root.replaceChildren();});
})();
