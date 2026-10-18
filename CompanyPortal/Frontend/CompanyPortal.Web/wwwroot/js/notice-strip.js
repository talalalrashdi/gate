(() => {
  const root=document.getElementById('portal-alerts-section');if(!root)return;
  // Retain the source cards for the floating notices; the upper strip is removed.
  root.hidden=true;
  const cards=[...root.querySelectorAll('.portal-alert')];
  const active=()=>cards.filter(card=>!card.hidden);
  const floatingAll=document.querySelector('.portal-floating-notice-all');
  const dialog=document.createElement('dialog');dialog.className='news-dialog';dialog.setAttribute('aria-labelledby','news-dialog-title');
  dialog.innerHTML='<header><div><span>مساحة العمل</span><h2 id="news-dialog-title">التنويهات</h2></div><button type="button" class="news-close" aria-label="إغلاق قائمة التنبيهات">×</button></header><p class="news-dialog-intro">كل التحديثات في مكان واحد. افتح التنويه للاطلاع على تفاصيله.</p><div class="news-list"></div>';
  const recovery=document.createElement('button');recovery.type='button';recovery.className='news-restore';dialog.append(recovery);
  document.body.append(dialog);
  let returnToList=false;
  function renderList(){
    const list=dialog.querySelector('.news-list');list.replaceChildren();
    active().forEach(card=>{
      const row=document.createElement('div');row.className='news-list-row';
      const open=document.createElement('button');open.type='button';open.className='news-list-open';
      const tag=document.createElement('span'),title=document.createElement('strong'),meta=document.createElement('small');
      tag.className='news-list-tag';tag.textContent=card.querySelector('.portal-alert-badge').textContent;
      title.textContent=card.querySelector('h3').textContent;meta.textContent=card.querySelector('p').textContent;
      open.setAttribute('aria-label',`عرض تفاصيل ${title.textContent}`);open.append(tag,title,meta);
      open.addEventListener('click',()=>{returnToList=true;dialog.close();card.querySelector('.portal-alert-open').click();});
      const dismiss=document.createElement('button');dismiss.type='button';dismiss.className='news-dismiss';dismiss.textContent='×';dismiss.setAttribute('aria-label',`إخفاء ${title.textContent}`);
      dismiss.addEventListener('click',()=>{card.hidden=true;renderList();(dialog.querySelector('.news-list-open')||dialog.querySelector('.news-close')).focus();});
      row.append(open,dismiss);list.append(row);
    });
    if(!active().length){const empty=document.createElement('p');empty.className='news-empty';empty.textContent='لا توجد تنويهات متبقية.';list.append(empty);}
    const dismissed=cards.length-active().length;recovery.hidden=!dismissed;recovery.textContent=`استعادة التنويهات المخفية (${dismissed.toLocaleString('ar-EG-u-nu-latn')})`;
  }
  root.addEventListener('notices:show-all',()=>{renderList();dialog.showModal();});
  dialog.querySelector('.news-close').addEventListener('click',()=>dialog.close());
  dialog.addEventListener('click',event=>{
    if(event.target!==dialog)return;
    const bounds=dialog.getBoundingClientRect();
    if(event.clientX<bounds.left||event.clientX>bounds.right||event.clientY<bounds.top||event.clientY>bounds.bottom)dialog.close();
  });
  recovery.addEventListener('click',()=>{cards.forEach(card=>card.hidden=false);renderList();dialog.querySelector('.news-list-open')?.focus();});
  const observer=new MutationObserver(()=>{if(dialog.open)renderList();});cards.forEach(card=>observer.observe(card,{attributes:true,attributeFilter:['hidden']}));
  document.querySelector('.portal-alert-sheet')?.addEventListener('close',()=>{if(returnToList){returnToList=false;renderList();dialog.showModal();}else floatingAll?.focus({preventScroll:true});});
  document.addEventListener('systems:reveal',event=>{const card=event.detail?.target?.closest('.portal-alert');if(!card)return;card.hidden=false;event.detail.target=floatingAll;});
})();
