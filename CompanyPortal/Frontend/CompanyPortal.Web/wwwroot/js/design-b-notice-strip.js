(() => {
  const root=document.getElementById('b-alerts-section');if(!root)return;
  // Retain the source cards for the floating notices; the upper strip is removed.
  root.hidden=true;
  const cards=[...root.querySelectorAll('.b-alert')];
  const active=()=>cards.filter(card=>!card.hidden);
  const floatingAll=document.querySelector('.b-floating-notice-all');
  const dialog=document.createElement('dialog');dialog.className='bn-dialog';dialog.setAttribute('aria-labelledby','bn-dialog-title');
  dialog.innerHTML='<header><div><span>مساحة العمل</span><h2 id="bn-dialog-title">التنويهات</h2></div><button type="button" class="bn-close" aria-label="إغلاق قائمة التنبيهات">×</button></header><p class="bn-dialog-intro">كل التحديثات في مكان واحد. افتح التنويه للاطلاع على تفاصيله.</p><div class="bn-list"></div>';
  const recovery=document.createElement('button');recovery.type='button';recovery.className='bn-restore';dialog.append(recovery);
  document.body.append(dialog);
  let returnToList=false;
  function renderList(){
    const list=dialog.querySelector('.bn-list');list.replaceChildren();
    active().forEach(card=>{
      const row=document.createElement('div');row.className='bn-list-row';
      const open=document.createElement('button');open.type='button';open.className='bn-list-open';
      const tag=document.createElement('span'),title=document.createElement('strong'),meta=document.createElement('small');
      tag.className='bn-list-tag';tag.textContent=card.querySelector('.b-alert-badge').textContent;
      title.textContent=card.querySelector('h3').textContent;meta.textContent=card.querySelector('p').textContent;
      open.setAttribute('aria-label',`عرض تفاصيل ${title.textContent}`);open.append(tag,title,meta);
      open.addEventListener('click',()=>{returnToList=true;dialog.close();card.querySelector('.b-alert-open').click();});
      const dismiss=document.createElement('button');dismiss.type='button';dismiss.className='bn-dismiss';dismiss.textContent='×';dismiss.setAttribute('aria-label',`إخفاء ${title.textContent}`);
      dismiss.addEventListener('click',()=>{card.hidden=true;renderList();(dialog.querySelector('.bn-list-open')||dialog.querySelector('.bn-close')).focus();});
      row.append(open,dismiss);list.append(row);
    });
    if(!active().length){const empty=document.createElement('p');empty.className='bn-empty';empty.textContent='لا توجد تنويهات متبقية.';list.append(empty);}
    const dismissed=cards.length-active().length;recovery.hidden=!dismissed;recovery.textContent=`استعادة التنويهات المخفية (${dismissed.toLocaleString('ar-EG-u-nu-latn')})`;
  }
  root.addEventListener('notices:show-all',()=>{renderList();dialog.showModal();});
  dialog.querySelector('.bn-close').addEventListener('click',()=>dialog.close());
  dialog.addEventListener('click',event=>{
    if(event.target!==dialog)return;
    const bounds=dialog.getBoundingClientRect();
    if(event.clientX<bounds.left||event.clientX>bounds.right||event.clientY<bounds.top||event.clientY>bounds.bottom)dialog.close();
  });
  recovery.addEventListener('click',()=>{cards.forEach(card=>card.hidden=false);renderList();dialog.querySelector('.bn-list-open')?.focus();});
  const observer=new MutationObserver(()=>{if(dialog.open)renderList();});cards.forEach(card=>observer.observe(card,{attributes:true,attributeFilter:['hidden']}));
  document.querySelector('.b-alert-sheet')?.addEventListener('close',()=>{if(returnToList){returnToList=false;renderList();dialog.showModal();}else floatingAll?.focus({preventScroll:true});});
  document.addEventListener('sc:reveal',event=>{const card=event.detail?.target?.closest('.b-alert');if(!card)return;card.hidden=false;event.detail.target=floatingAll;});
})();
