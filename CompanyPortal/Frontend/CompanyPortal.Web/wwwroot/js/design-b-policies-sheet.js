(() => {
  const trigger=document.getElementById('policies-sheet-trigger'),sheet=document.getElementById('policies-sheet');
  if(!trigger||!sheet)return;
  function open(){if(!sheet.open)sheet.showModal();}
  trigger.addEventListener('click',event=>{event.preventDefault();if(typeof closeSearch==='function')closeSearch(false);open();});
  sheet.querySelector('[data-policies-close]').addEventListener('click',()=>sheet.close());
  sheet.addEventListener('click',event=>{
    const r=sheet.getBoundingClientRect();
    if(event.target===sheet&&(event.clientX<r.left||event.clientX>r.right||event.clientY<r.top||event.clientY>r.bottom))sheet.close();
    if(event.target.closest('a[href="#library"]'))sheet.close();
  });
  sheet.addEventListener('close',()=>{if(!document.querySelector('dialog[open]'))trigger.focus({preventScroll:true});});
  document.addEventListener('sc:reveal',event=>{if(event.detail?.target?.closest('#policies'))open();});
})();
