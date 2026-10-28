(() => {
  // This page intentionally loads no employee persistence or business-action scripts.
  const api=new URL(document.querySelector('meta[name="companyportal-api-base"]').content.replace(/\/?$/,'/'),location.href);
  let allowed=false,signature=null,positioning=false,selectedImageId=null,currentPosition={x:50,y:56},drag=null;
  // Representative content only: preview never fetches or changes employee news/preferences.
  const headlines=document.querySelector('.theme-official-headlines');
  ['أخبار المؤسسة وآخر المستجدات','تطوير الخدمات الإلكترونية للموظفين','الفعاليات والمبادرات القادمة'].forEach((title,index)=>{
    const item=document.createElement('li'),surface=document.createElement('div'),copy=document.createElement('span'),heading=document.createElement('strong'),credit=document.createElement('small');
    item.classList.toggle('is-featured',index===0);surface.className='news-headline-surface';
    heading.textContent=title;credit.textContent='خبر توضيحي للمعاينة';copy.append(heading,credit);surface.append(copy);item.append(surface);headlines.append(item);
  });
  // Match personal-workspace.js placement so #systems-scoped calendar styles apply.
  const calendar=document.getElementById('portal-floating-calendar');
  document.getElementById('systems').append(calendar);
  const summary=document.getElementById('portal-calendar-summary'),empty=document.createElement('p');
  empty.textContent='لا توجد مواعيد أو تذكيرات قادمة.';summary.append(empty);
  const today=document.getElementById('theme-official-today');
  today.firstElementChild.textContent=new Intl.DateTimeFormat('ar-OM',{dateStyle:'full'}).format(new Date());
  today.lastElementChild.textContent='معاينة تصميم البوابة';
  const message=document.getElementById('preview-message'),shell=document.getElementById('preview-shell');
  document.querySelectorAll('input,select,textarea,button').forEach(node=>{node.disabled=true;});
  document.addEventListener('submit',event=>event.preventDefault());document.addEventListener('click',event=>event.preventDefault());
  window.addEventListener('message',event=>{
    if(!allowed||event.source!==parent||event.origin!==location.origin||event.data?.type!=='companyportal:theme-preview')return;
    const {theme,settings,images}=event.data;
    if(!['official','work','national-day'].includes(theme?.layoutKey))return;
    positioning=event.data.positioning===true;selectedImageId=settings?.defaultImageId??images?.[0]?.imageId;
    document.body.toggleAttribute('data-focus-editing',positioning);
    const point=theme.imagePositions?.find(p=>p.imageId===selectedImageId);
    currentPosition={x:point?.focalX??50,y:point?.focalY??(theme.imagePresentation==='artwork'?50:56)};
    const nextSignature=JSON.stringify([theme.layoutKey,theme.imageGroupId,settings,images?.map(i=>i.imageId)]);
    if(signature!==nextSignature)window.CompanyPortalTheme.setImages(null);
    window.CompanyPortalTheme.previewLayout(theme.layoutKey,typeof theme.themeName==='string'?theme.themeName:'');
    window.CompanyPortalTheme.apply(theme);
    const valid=Array.isArray(images)&&images.length<=100&&images.every(image=>Number.isInteger(image.imageId)&&image.imageId>0);
    if(signature!==nextSignature&&valid&&images.length&&settings)window.CompanyPortalTheme.setImages({...settings,images:images.map(image=>({imageId:image.imageId,url:new URL(`api/images/${image.imageId}/content`,api).href}))});
    signature=nextSignature;
    shell.hidden=false;message.hidden=true;
  });
  shell.addEventListener('pointerdown',event=>{
    if(!allowed||!positioning||event.button!==0||!Number.isInteger(selectedImageId))return;
    const image=document.querySelector('.theme-managed-image.is-active'),backdrop=document.querySelector('.theme-official-backdrop');
    if(!image?.naturalWidth||!backdrop)return;
    const rect=backdrop.getBoundingClientRect();if(event.clientX<rect.left||event.clientX>rect.right||event.clientY<rect.top||event.clientY>rect.bottom)return;
    const scale=Math.max(rect.width/image.naturalWidth,rect.height/image.naturalHeight);
    drag={pointer:event.pointerId,startX:event.clientX,startY:event.clientY,x:currentPosition.x,y:currentPosition.y,overflowX:image.naturalWidth*scale-rect.width,overflowY:image.naturalHeight*scale-rect.height,imageId:selectedImageId};
    shell.setPointerCapture(event.pointerId);document.body.setAttribute('data-focus-dragging','');event.preventDefault();
  });
  shell.addEventListener('pointermove',event=>{
    if(!drag||event.pointerId!==drag.pointer||drag.imageId!==selectedImageId||!positioning)return;
    const clamp=value=>Math.round(Math.max(0,Math.min(100,value))*100)/100;
    const x=drag.overflowX>1?clamp(drag.x-(event.clientX-drag.startX)*100/drag.overflowX):drag.x;
    const y=drag.overflowY>1?clamp(drag.y-(event.clientY-drag.startY)*100/drag.overflowY):drag.y;
    parent.postMessage({type:'companyportal:image-position',imageId:drag.imageId,focalX:x,focalY:y},location.origin);event.preventDefault();
  });
  const endDrag=()=>{drag=null;document.body.removeAttribute('data-focus-dragging');};
  shell.addEventListener('pointerup',endDrag);shell.addEventListener('pointercancel',endDrag);shell.addEventListener('lostpointercapture',endDrag);
  fetch(new URL('api/access',api),{credentials:'include',cache:'no-store',signal:AbortSignal.timeout(10000)})
    .then(async response=>{if(!response.ok||!(await response.json()).isAdmin)throw new Error();allowed=true;parent.postMessage({type:'companyportal:preview-ready'},location.origin);})
    .catch(()=>{message.textContent='المعاينة متاحة فقط لحساب إدارة البوابة.';});
})();
