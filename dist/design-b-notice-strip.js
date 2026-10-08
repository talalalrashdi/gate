(() => {
  const root=document.getElementById('b-alerts-section');if(!root)return;
  const cards=[...root.querySelectorAll('.b-alert')];
  const source=document.createElement('div');source.className='bn-source';
  while(root.firstChild)source.append(root.firstChild);
  root.append(source);root.classList.add('bn-root');
  const strip=document.createElement('div');strip.className='bn-strip';
  strip.innerHTML='<div class="bn-identity"><span class="bn-bell" aria-hidden="true"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9M10 21h4M12 2V1"/></svg></span><div><strong>تنوية</strong><small class="bn-count"></small></div></div><button type="button" class="bn-feature" aria-haspopup="dialog"><span class="bn-type"></span><strong class="bn-title"></strong><small class="bn-meta"></small></button><div class="bn-actions"><div class="bn-paging"><button type="button" class="bn-prev" aria-label="التنبيه السابق">→</button><span class="bn-position"></span><button type="button" class="bn-next" aria-label="التنبيه التالي">←</button></div><button type="button" class="bn-all" aria-haspopup="dialog">عرض الكل <span aria-hidden="true">↙</span></button><button type="button" class="bn-hide" aria-label="إغلاق التنوية" title="إغلاق التنوية">×</button></div>';
  root.append(strip);
  strip.querySelector('.bn-hide').addEventListener('click',()=>{
    const toggle=document.getElementById('b-alert-visibility');
    toggle?.click();toggle?.focus({preventScroll:true});
  });
  const recovery=document.createElement('button');recovery.type='button';recovery.className='bn-restore';recovery.hidden=true;root.append(recovery);
  const dialog=document.createElement('dialog');dialog.className='bn-dialog';dialog.setAttribute('aria-labelledby','bn-dialog-title');
  dialog.innerHTML='<header><div><span>مساحة العمل</span><h2 id="bn-dialog-title">تنوية</h2></div><button type="button" class="bn-close" aria-label="إغلاق قائمة التنبيهات">×</button></header><p class="bn-dialog-intro">كل التحديثات في مكان واحد. افتح التنبيه للاطلاع على تفاصيله.</p><div class="bn-list"></div>';
  document.body.append(dialog);
  let index=0,returnToList=false,renderedVisibility="";
  const active=()=>cards.filter(card=>!card.hidden);
  const label=card=>({title:card.querySelector('h3').textContent,type:card.querySelector('.b-alert-badge').textContent,meta:card.querySelector('p').textContent});
  const feature=strip.querySelector('.bn-feature'),all=strip.querySelector('.bn-all'),prev=strip.querySelector('.bn-prev'),next=strip.querySelector('.bn-next');
  function openCard(card,fromList=false){returnToList=fromList;if(dialog.open)dialog.close();card.querySelector('.b-alert-open').click();}
  function renderList(){
    const list=dialog.querySelector('.bn-list');list.replaceChildren();
    active().forEach(card=>{
      const data=label(card),row=document.createElement('div');row.className='bn-list-row';
      const open=document.createElement('button');open.type='button';open.className='bn-list-open';open.setAttribute('aria-label',`عرض تفاصيل ${data.title}`);
      const tag=document.createElement('span'),title=document.createElement('strong'),meta=document.createElement('small');tag.className='bn-list-tag';tag.textContent=data.type;title.textContent=data.title;meta.textContent=data.meta;open.append(tag,title,meta);open.addEventListener('click',()=>openCard(card,true));
      const dismiss=document.createElement('button');dismiss.type='button';dismiss.className='bn-dismiss';dismiss.textContent='×';dismiss.setAttribute('aria-label',`إخفاء ${data.title}`);dismiss.addEventListener('click',()=>{card.hidden=true;render();if(active().length)dialog.querySelector('.bn-list-open').focus();else dialog.querySelector('.bn-close').focus();});
      row.append(open,dismiss);list.append(row);
    });
    if(!active().length){const empty=document.createElement('p');empty.className='bn-empty';empty.textContent='لا توجد تنبيهات متبقية. يمكنك استعادتها من الشريط.';list.append(empty);}
  }
  function render(){
    renderedVisibility=cards.map(card=>card.hidden).join();const remaining=active();index=Math.min(index,Math.max(0,remaining.length-1));
    strip.querySelector('.bn-count').textContent=remaining.length?`${remaining.length.toLocaleString('ar-EG-u-nu-latn')} تحديثات`:'أنت على اطّلاع';
    feature.hidden=!remaining.length;all.disabled=!remaining.length;strip.querySelector('.bn-paging').hidden=remaining.length<2;
    if(remaining.length){const data=label(remaining[index]);strip.querySelector('.bn-type').textContent=data.type;strip.querySelector('.bn-title').textContent=data.title;strip.querySelector('.bn-meta').textContent=data.meta;feature.setAttribute('aria-label',`عرض تفاصيل ${data.title}`);strip.querySelector('.bn-position').textContent=`${(index+1).toLocaleString('ar-EG-u-nu-latn')} / ${remaining.length.toLocaleString('ar-EG-u-nu-latn')}`;}
    prev.disabled=index===0;next.disabled=index>=remaining.length-1;
    const dismissed=cards.length-remaining.length;recovery.hidden=!dismissed;recovery.textContent=`استعادة التنبيهات المخفية (${dismissed.toLocaleString('ar-EG-u-nu-latn')})`;
    if(dialog.open)renderList();
  }
  feature.addEventListener('click',()=>{const card=active()[index];if(card)openCard(card);});
  prev.addEventListener('click',()=>{index=Math.max(0,index-1);render();});next.addEventListener('click',()=>{index=Math.min(active().length-1,index+1);render();});
  all.addEventListener('click',()=>{renderList();dialog.showModal();});dialog.querySelector('.bn-close').addEventListener('click',()=>dialog.close());
  recovery.addEventListener('click',()=>{cards.forEach(card=>card.hidden=false);index=0;render();feature.focus();});
  const observer=new MutationObserver(()=>{if(cards.map(card=>card.hidden).join()!==renderedVisibility)render();});cards.forEach(card=>observer.observe(card,{attributes:true,attributeFilter:['hidden']}));
  document.querySelector('.b-alert-sheet')?.addEventListener('close',()=>{if(returnToList){returnToList=false;renderList();dialog.showModal();}else if(!root.hidden)feature.focus({preventScroll:true});});
  document.addEventListener('sc:reveal',event=>{const card=event.detail?.target?.closest('.b-alert');if(!card)return;card.hidden=false;index=active().indexOf(card);render();event.detail.target=feature;});
  render();
})();

