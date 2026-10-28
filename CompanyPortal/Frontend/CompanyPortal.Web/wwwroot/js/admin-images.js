(() => {
  const panel = document.querySelector('[data-admin-panel="images"]');
  const base = document.querySelector('meta[name="companyportal-api-base"]')?.content;
  if (!panel || !base) return;
  const api = new URL(base.replace(/\/?$/, '/'),location.href), byId = id => document.getElementById(id);
  const status = byId('images-status'), content = byId('images-content'), retry = byId('images-retry');
  const picker = byId('image-group-picker'), library = byId('image-library'), itemsRoot = byId('image-group-items');
  const form = byId('image-group-form'), name = byId('image-group-name'), rotate = byId('image-group-rotate'), seconds = byId('image-group-seconds'), active = byId('image-group-active');
  let data = {images:[],groups:[],items:[],themes:[]}, selection = [], groupId = null, defaultId = null, busy = false, loaded = false, dirty = false;
  const url = path => new URL(path,api);
  const core=window.AdminCore;
  const say = (text,error=false) => { core.feedback(status,text,error); };
  const node = (tag,text,className) => { const n=document.createElement(tag); if(text!==undefined)n.textContent=text; if(className)n.className=className; return n; };
  const option = (value,text) => {const n=node('option',text);n.value=String(value ?? '');return n;};
  let groupSnapshot='';
  const groupValues=()=>JSON.stringify({name:name.value,rotate:rotate.checked,seconds:seconds.value,active:active.checked,defaultId,selection});
  const groupDirty=()=>loaded&&groupValues()!==groupSnapshot;
  const mark = () => {dirty=groupDirty();byId('image-group-dirty').textContent=dirty?'تغييرات غير محفوظة':'';core.refresh();};
  async function request(path,method='GET',body) {
    const response=await core.request(path,{method,body,header:'admin-images',timeout:method==='POST'?60000:15000});
    if(!response.ok){
      if(response.status===401||response.status===403){content.hidden=true;loaded=false;throw new Error('ليس لديك صلاحية إدارة الصور.');}
      if(response.status===409)throw new Error(path.includes('/groups')?'لا يمكن إيقاف مجموعة يستخدمها ثيم. اختر لها صورًا أخرى من محرر الثيم أولًا.':'الصورة مستخدمة في مجموعة محفوظة. أزلها من المجموعات واحفظ التغييرات أولًا، ثم احذفها.');
      throw new Error(response.status===400||response.status===413?'تعذر الحفظ. تحقق من الاسم والصور والأحجام والصيغة. SVG يجب أن يكون ثابتًا بدون سكربتات أو أنماط أو روابط خارجية.':'تعذر الاتصال بخدمة الصور. أعد المحاولة.');
    }
    return response.status===204?null:response.json();
  }
  async function run(action) {
    if(busy)return;busy=true;panel.querySelectorAll('button,input,select').forEach(n=>{n.disabled=true;});
    try{await action();}catch(error){say(error.message,true);retry.hidden=loaded;}
    finally{busy=false;panel.querySelectorAll('button,input,select').forEach(n=>{n.disabled=false;});refreshConstraints();}
  }
  function refreshConstraints(){seconds.disabled=!rotate.checked;itemsRoot.querySelectorAll('input[type=radio]').forEach((n,i)=>{n.disabled=!selection[i]?.active;});itemsRoot.querySelectorAll('[data-up]').forEach((n,i)=>{n.disabled=i===0;});itemsRoot.querySelectorAll('[data-down]').forEach((n,i)=>{n.disabled=i===selection.length-1;});}
  const preview = image => { const img=node('img');img.src=url(`api/images/${image.imageId}/content`);img.alt='';img.loading='lazy';return img; };
  function renderLibrary(){
    library.replaceChildren();byId('images-count').textContent=`(${data.images.length})`;
    byId('images-selected-count').textContent=`${selection.length} صورة مختارة`;
    if(!data.images.length)library.append(node('p','المكتبة فارغة. ارفع الصور للبدء.'));
    data.images.forEach(image=>{
      const tile=node('article',undefined,'image-tile'),check=node('input');AdminChanges.tag(tile,'images','image',image.imageId);check.type='checkbox';check.checked=selection.some(i=>i.imageId===image.imageId);
      check.setAttribute('aria-label','اختيار '+image.imageName);
      check.addEventListener('change',()=>{
        if(check.checked) {if(selection.length>=100){check.checked=false;say('يمكن اختيار 100 صورة كحد أقصى للمجموعة.',true);return;}selection.push({imageId:image.imageId,active:true});}
        else {selection=selection.filter(i=>i.imageId!==image.imageId);if(defaultId===image.imageId)defaultId=null;}
        mark();renderSelection();
      });
      const line=node('label');line.append(check,node('span','اختيار الصورة'));
      const remove=node('button','حذف الصورة','image-delete');remove.type='button';remove.setAttribute('aria-label','حذف '+image.imageName);
      remove.addEventListener('click',async()=>{
        if(busy||!await core.confirm('حذف الصورة «'+image.imageName+'» من المكتبة؟ لا يمكن حذف صورة مستخدمة في مجموعة محفوظة.',{title:'حذف الصورة',accept:'حذف',danger:true}))return;
        run(async()=>{
          await request(`api/admin/images/${image.imageId}`,'DELETE');
          selection=selection.filter(item=>item.imageId!==image.imageId);if(defaultId===image.imageId)defaultId=null;
          data=await request('api/admin/images');renderLibrary();renderSelection();say('تم حذف الصورة من المكتبة.');
        });
      });
      tile.append(preview(image),node('strong',image.imageName),node('small',`${image.pixelWidth} × ${image.pixelHeight} · ${Math.ceil(image.byteLength/1024)} KB`),line,remove);library.append(tile);
    });
  }
  function renderSelection(){
    itemsRoot.replaceChildren();byId('images-selected-count').textContent=`${selection.length} صورة مختارة`;
    if(defaultId===null||!selection.some(i=>i.imageId===defaultId&&i.active))defaultId=selection.find(i=>i.active)?.imageId??null;
    if(!selection.length)itemsRoot.append(node('p','اختر الصور من المكتبة أعلاه. يمكنك حفظ مجموعة فارغة وتجهيزها لاحقًا.'));
    selection.forEach((item,index)=>{
      const image=data.images.find(i=>i.imageId===item.imageId);if(!image)return;
      const row=node('div',undefined,'image-item'),heading=node('div',undefined,'image-item-heading'),tools=node('div',undefined,'image-item-tools');
      heading.append(preview(image),node('strong',`${index+1}. ${image.imageName}`));
      const toggle=node('input');toggle.type='checkbox';toggle.checked=item.active;
      const toggleLabel=node('label');toggleLabel.append(toggle,node('span','نشطة'));
      toggle.addEventListener('change',()=>{item.active=toggle.checked;mark();renderSelection();});
      const radio=node('input');radio.type='radio';radio.name='default-image';radio.checked=defaultId===item.imageId;radio.disabled=!item.active;
      const radioLabel=node('label');radioLabel.append(radio,node('span','افتراضية'));radio.addEventListener('change',()=>{defaultId=item.imageId;mark();});
      const up=node('button','↑'),down=node('button','↓'),remove=node('button','إزالة');
      [up,down,remove].forEach(n=>{n.type='button';});up.dataset.up='';down.dataset.down='';
      up.setAttribute('aria-label','تقديم '+image.imageName);down.setAttribute('aria-label','تأخير '+image.imageName);
      const move=delta=>{[selection[index],selection[index+delta]]=[selection[index+delta],selection[index]];mark();renderSelection();};
      up.addEventListener('click',()=>move(-1));down.addEventListener('click',()=>move(1));
      remove.addEventListener('click',()=>{selection.splice(index,1);mark();renderLibrary();renderSelection();});
      tools.append(toggleLabel,radioLabel,up,down,remove);row.append(heading,tools);itemsRoot.append(row);
    });
    refreshConstraints();
  }
  function renderPicker(){
    picker.replaceChildren(option('','مجموعة جديدة'));
    data.groups.forEach(g=>picker.append(option(g.imageGroupId,g.groupName+(g.active?'':' (غير نشطة)'))));picker.value=String(groupId??'');
  }
  // Themes pick their group in the theme editor; this page only shows the usage.
  const usedBy=()=>groupId?data.themes.filter(t=>t.imageGroupId===groupId):[];
  function renderUsage(){
    const themes=usedBy();
    byId('image-group-usage').textContent=themes.length?'يستخدمها: '+themes.map(t=>t.themeName).join('، '):groupId?'لا يستخدمها أي ثيم. اختر المجموعة من محرر الثيم.':'بعد الحفظ، اختر المجموعة من محرر الثيم.';
  }
  function editGroup(id){
    groupId=id;AdminChanges.tag(form,'images','image-group',id);const group=data.groups.find(g=>g.imageGroupId===id);
    name.value=group?.groupName??'';rotate.checked=group?.rotateImages??true;seconds.value=group?.rotationSeconds??8;active.checked=group?.active??true;defaultId=group?.defaultImageId??null;
    selection=data.items.filter(i=>i.imageGroupId===id).sort((a,b)=>a.displayOrder-b.displayOrder).map(i=>({imageId:i.imageId,active:i.active}));
    dirty=false;byId('image-group-dirty').textContent='';renderPicker();renderLibrary();renderSelection();renderUsage();groupSnapshot=groupValues();core.refresh();
  }
  async function load(){
    await run(async()=>{say('جارٍ تحميل مكتبة الصور…');data=await request('api/admin/images');loaded=true;content.hidden=false;retry.hidden=true;editGroup(null);say('المكتبة جاهزة. اختر مجموعة أو أنشئ مجموعة جديدة.');});
  }
  picker.addEventListener('change',async()=>{if(busy||groupDirty()&&!await core.discard('توجد تغييرات غير محفوظة. هل تريد الانتقال إلى مجموعة أخرى؟')){picker.value=String(groupId??'');return;}editGroup(picker.value?Number(picker.value):null);});
  active.addEventListener('change',()=>{if(active.checked||!usedBy().length)return;active.checked=true;say('لا يمكن إيقاف مجموعة يستخدمها ثيم ('+usedBy().map(t=>t.themeName).join('، ')+'). اختر لها صورًا أخرى من محرر الثيم أولًا.',true);});
  form.addEventListener('input',mark);form.addEventListener('change',mark);rotate.addEventListener('change',refreshConstraints);
  form.addEventListener('submit',event=>{event.preventDefault();if(!name.value.trim()){name.focus();return;}run(async()=>{
    say('جارٍ حفظ المجموعة…');
    const result=await request('api/admin/images/groups'+(groupId?'/'+groupId:''),groupId?'PUT':'POST',{groupName:name.value.trim(),rotateImages:rotate.checked,rotationSeconds:Number(seconds.value),defaultImageId:defaultId,active:active.checked,items:selection.map((i,index)=>({...i,displayOrder:index+1}))});
    groupId=result.imageGroupId;
    data=await request('api/admin/images');editGroup(groupId);say('تم حفظ المجموعة وترتيب الصور وإعدادات العرض.');
  });});
  byId('image-upload').addEventListener('submit',event=>{event.preventDefault();const files=[...byId('image-files').files];if(!files.length)return;run(async()=>{
    const added=[];let failure;
    for(const file of files){
      if(file.size>(file.name.toLowerCase().endsWith('.svg')?1024*1024:10*1024*1024)){failure=new Error('تجاوزت إحدى الصور الحجم المسموح.');break;}
      say(`جارٍ رفع ${file.name}…`);const body=new FormData();body.append('file',file);
      try{const result=await request('api/admin/images','POST',body);added.push(result.imageId);}catch(error){failure=error;break;}
    }
    if(added.length){data=await request('api/admin/images');renderLibrary();}
    byId('image-files').value='';
    if(failure){say(`تم رفع ${added.length} صورة. ${failure.message}`,true);return;}
    say(`تم رفع ${added.length} صورة. اختر الصور لإضافتها إلى المجموعة.`);
  });});
  retry.addEventListener('click',async()=>{if(!busy&&(!core.dirtyIn('images')||await core.discard()))load();});
  core.watch('images',form,groupDirty,()=>busy);
  core.trackForm('images',byId('image-upload'),{busy:()=>busy});
  core.whenSection('images',()=>{if(!loaded&&!busy)load();});
})();
