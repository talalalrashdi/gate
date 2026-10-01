(() => {
  const workspace=document.getElementById('workspace-cards');if(!workspace)return;
  const storageKey='clerio-workspace-groups-v1';
  const systems=[...document.querySelectorAll('.sc-card[data-system-id]')].map(card=>({id:card.dataset.systemId,title:card.querySelector('h3').textContent}));
  const byId=new Map(systems.map(system=>[system.id,system]));
  const make=(tag,cls,text)=>{const node=document.createElement(tag);if(cls)node.className=cls;if(text)node.textContent=text;return node;};
  function decode(raw){
    try{const value=JSON.parse(raw);if(!Array.isArray(value))return [];const seen=new Set();
      return value.filter(group=>group&&typeof group.id==='string'&&/^group-[a-zA-Z0-9-]+$/.test(group.id)&&typeof group.name==='string'&&group.name.trim()&&Array.isArray(group.systems)).filter(group=>{if(seen.has(group.id))return false;seen.add(group.id);return true;}).map(group=>({id:group.id,name:group.name.trim().slice(0,60),systems:[...new Set(group.systems)].filter(id=>byId.has(id))}));
    }catch{return [];}
  }
  let groups=[];try{groups=decode(localStorage.getItem(storageKey));}catch{}
  const add=make('button','b-work-card b-workspace-add-group');add.type='button';add.setAttribute('aria-label','إضافة بطاقة مجموعة أنظمة');
  const plus=make('span','b-group-plus','+');plus.setAttribute('aria-hidden','true');add.append(plus,make('strong',null,'بطاقة جديدة'),make('small',null,'اجمع أنظمتك في مكان واحد'));workspace.append(add);
  const dialog=make('dialog','b-group-dialog');dialog.setAttribute('aria-labelledby','group-dialog-title');
  dialog.innerHTML='<form><header><h2 id="group-dialog-title">بطاقة جديدة</h2><button type="button" data-group-close aria-label="إغلاق">×</button></header><label class="b-group-name-label" for="group-name">اسم البطاقة</label><input id="group-name" name="name" maxlength="60" required placeholder="مثلاً: أنظمتي اليومية" autocomplete="off"><fieldset><legend>اختر الأنظمة</legend><input type="search" id="group-system-search" aria-label="البحث عن نظام" placeholder="ابحث عن نظام…"><div class="b-group-choices"></div><p class="b-group-no-results" hidden>لا توجد أنظمة مطابقة.</p></fieldset><p class="b-group-count" aria-live="polite"></p><p class="b-group-error" role="alert" hidden></p><footer><button type="button" class="b-group-delete" hidden>حذف البطاقة</button><button type="button" data-group-close>إلغاء</button><button type="submit" class="b-group-save">حفظ البطاقة</button></footer></form>';
  document.body.append(dialog);
  const form=dialog.querySelector('form'),name=dialog.querySelector('#group-name'),search=dialog.querySelector('#group-system-search'),choices=dialog.querySelector('.b-group-choices'),error=dialog.querySelector('.b-group-error'),remove=dialog.querySelector('.b-group-delete');
  let editing=null,selected=new Set();
  function announce(text){if(typeof showToast==='function')showToast(text);}
  function persist(){try{localStorage.setItem(storageKey,JSON.stringify(groups));return true;}catch{return false;}}
  function changed(){workspace.dispatchEvent(new CustomEvent('workspace:cards-changed'));if(typeof updateWorkspaceNavigation==='function')updateWorkspaceNavigation();}
  function render(){
    workspace.querySelectorAll('[data-work-group]').forEach(card=>card.remove());
    groups.forEach(group=>{
      const card=make('article','b-work-card b-system-group');card.dataset.workSystem=group.id;card.dataset.workGroup=group.id;
      const heading=make('header','b-work-heading'),icon=make('div','b-work-icon');icon.innerHTML='<i class="iconsax" icon-name="folder-2" aria-hidden="true"></i>';
      const copy=make('div'),title=make('h2',null,group.name);title.id=group.id+'-title';card.setAttribute('aria-labelledby',title.id);copy.append(title);heading.append(icon,copy);
      const actions=make('div','sc-work-label'),edit=make('button','b-group-edit','✎');edit.type='button';edit.setAttribute('aria-label',`تعديل ${group.name}`);edit.title=`تعديل ${group.name}`;edit.addEventListener('click',()=>open(group.id));actions.append(edit);heading.append(actions);
      const list=make('ul','b-group-system-list');
      group.systems.forEach(id=>{const system=byId.get(id);if(!system)return;const row=make('li'),title=make('span',null,system.title),button=make('button',null,'فتح النظام ↗');button.type='button';button.dataset.scDetails=id;button.setAttribute('aria-label',`فتح نظام ${system.title}`);row.append(title,button);list.append(row);});
      card.append(heading,list);if(!list.children.length)card.append(make('p','b-group-empty','أضف أنظمة من زر تعديل البطاقة.'));
      workspace.insertBefore(card,add);
    });changed();
  }
  function count(){dialog.querySelector('.b-group-count').textContent=`${selected.size.toLocaleString('ar-EG')} أنظمة محددة`;}
  function filter(){
    const normalize=value=>value.replace(/[أإآ]/g,'ا').replace(/[\u064B-\u065F\u0670]/g,'').toLowerCase();const query=normalize(search.value.trim());let visible=0;
    choices.querySelectorAll('label').forEach(label=>{label.hidden=!normalize(label.textContent).includes(query);if(!label.hidden)visible++;});dialog.querySelector('.b-group-no-results').hidden=visible!==0;
  }
  function open(id=null){
    editing=id;const group=groups.find(item=>item.id===id);selected=new Set(group?.systems||[]);name.value=group?.name||'';search.value='';error.hidden=true;remove.hidden=!group;
    dialog.querySelector('h2').textContent=group?'تعديل البطاقة':'بطاقة جديدة';choices.replaceChildren();
    systems.forEach(system=>{const label=make('label'),input=make('input');input.type='checkbox';input.value=system.id;input.checked=selected.has(system.id);input.addEventListener('change',()=>{if(input.checked)selected.add(system.id);else selected.delete(system.id);count();error.hidden=true;});label.append(input,make('span',null,system.title));choices.append(label);});
    count();filter();dialog.showModal();name.focus();
  }
  add.addEventListener('click',()=>open());search.addEventListener('input',filter);name.addEventListener('input',()=>name.setCustomValidity(''));
  dialog.querySelectorAll('[data-group-close]').forEach(button=>button.addEventListener('click',()=>dialog.close()));
  form.addEventListener('submit',event=>{
    event.preventDefault();const title=name.value.trim();if(!title){name.setCustomValidity('اكتب اسمًا للبطاقة');name.reportValidity();return;}
    if(!selected.size){error.textContent='اختر نظامًا واحدًا على الأقل.';error.hidden=false;return;}
    const id=editing||'group-'+crypto.randomUUID(),group={id,name:title,systems:[...selected]};
    if(editing)groups=groups.map(item=>item.id===editing?group:item);else groups.push(group);
    const saved=persist();dialog.close();render();
    const card=[...workspace.querySelectorAll('[data-work-group]')].find(card=>card.dataset.workGroup===id);
    card?.querySelector('.b-group-edit')?.focus({preventScroll:true});card?.scrollIntoView({behavior:'instant',block:'nearest',inline:'nearest'});
    announce(saved?'تم حفظ بطاقة الأنظمة':'تمت إضافة البطاقة لهذه الجلسة؛ تعذّر الحفظ في المتصفح');
  });
  remove.addEventListener('click',()=>{groups=groups.filter(group=>group.id!==editing);const saved=persist();dialog.close();render();add.focus({preventScroll:true});announce(saved?'تم حذف البطاقة':'تم حذف البطاقة لهذه الجلسة؛ تعذّر حفظ التغيير');});
  window.addEventListener('storage',event=>{if(event.key===storageKey||event.key===null){if(dialog.open)dialog.close();groups=decode(event.newValue);render();}});
  render();
})();
