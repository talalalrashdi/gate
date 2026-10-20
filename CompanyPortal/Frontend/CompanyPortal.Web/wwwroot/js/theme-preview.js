(() => {
  // This page intentionally loads no employee persistence or business-action scripts.
  const api=new URL(document.querySelector('meta[name="companyportal-api-base"]').content.replace(/\/?$/,'/'),location.href);
  let allowed=false,signature=null;
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
    const nextSignature=JSON.stringify([theme.layoutKey,theme.imageGroupId,settings,images]);
    if(signature!==nextSignature)window.CompanyPortalTheme.setImages(null);
    window.CompanyPortalTheme.previewLayout(theme.layoutKey,typeof theme.themeName==='string'?theme.themeName:'');
    window.CompanyPortalTheme.apply(theme);
    const valid=Array.isArray(images)&&images.length<=100&&images.every(image=>Number.isInteger(image.imageId)&&image.imageId>0);
    if(signature!==nextSignature&&valid&&images.length&&settings)window.CompanyPortalTheme.setImages({...settings,images:images.map(image=>({imageId:image.imageId,url:new URL(`api/images/${image.imageId}/content`,api).href}))});
    signature=nextSignature;
    shell.hidden=false;message.hidden=true;
  });
  fetch(new URL('api/access',api),{credentials:'include',cache:'no-store',signal:AbortSignal.timeout(10000)})
    .then(async response=>{if(!response.ok||!(await response.json()).isAdmin)throw new Error();allowed=true;parent.postMessage({type:'companyportal:preview-ready'},location.origin);})
    .catch(()=>{message.textContent='المعاينة متاحة فقط لحساب إدارة البوابة.';});
})();
