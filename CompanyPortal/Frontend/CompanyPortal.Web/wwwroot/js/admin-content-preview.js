(() => {
  const dialog=document.getElementById('admin-content-preview');if(!dialog)return;
  const frame=dialog.querySelector('iframe'),core=window.AdminCore;let draft=null,ready=false,previous=null;
  const send=()=>{if(ready&&draft&&dialog.open)frame.contentWindow.postMessage({type:'companyportal:content-draft',...draft},location.origin);};
  window.addEventListener('message',event=>{if(event.origin!==location.origin||event.source!==frame.contentWindow||event.data?.type!=='companyportal:content-ready')return;ready=true;send();});
  dialog.querySelector('button').onclick=()=>dialog.close();dialog.addEventListener('close',()=>{draft=null;ready=false;frame.src='about:blank';previous?.focus({preventScroll:true});});
  window.AdminPreview={open(section,value){if(!core.can(section))return;previous=document.activeElement;draft={section,value:structuredClone(value)};ready=false;dialog.showModal();frame.src=new URL('admin/content-preview',document.baseURI).href;},
    button(parent,section,read){const button=document.createElement('button');button.type='button';button.className='admin-preview-button';button.textContent='معاينة';button.addEventListener('click',async()=>{if(core.busyIn(section))return;try{const value=await read();if(value!==undefined)window.AdminPreview.open(section,value);}catch{core.notify('تعذر تجهيز المعاينة. تحقق من المدخلات والملف.','error');}});parent.append(button);return button;}};
})();
