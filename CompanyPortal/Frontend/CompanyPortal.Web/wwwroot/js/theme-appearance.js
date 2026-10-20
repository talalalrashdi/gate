(() => {
  const body=document.body, section=document.getElementById('systems'), backdrop=document.querySelector('.theme-official-backdrop');
  if(!section||!backdrop)return;
  const original=[...backdrop.querySelectorAll('[data-official-image]')], reduced=matchMedia('(prefers-reduced-motion: reduce)');
  let theme={},config=null,images=[],index=0,timer,generation=0;
  const colour=value=>typeof value==='string'&&/^#[\da-f]{6}$/i.test(value)?value:null;
  const contrastInk=value=>{
    const values=value.slice(1).match(/../g).map(v=>{const c=parseInt(v,16)/255;return c<=.04045?c/12.92:((c+.055)/1.055)**2.4;});
    const luminance=values[0]*.2126+values[1]*.7152+values[2]*.0722;
    return (luminance+.05)/.05 > 1.05/(luminance+.05)?'#14251E':'#FFFFFF';
  };
  function apply(value){
    const previousPresentation=theme.imagePresentation,previousLayout=theme.layoutKey;
    theme=value||{};
    for(const [key,css] of [['primaryColor','primary'],['accentColor','accent'],['backgroundColor','background']]){
      const selected=colour(theme[key]);
      body.toggleAttribute('data-theme-'+css,!!selected);
      if(selected)body.style.setProperty('--theme-'+css,selected);else body.style.removeProperty('--theme-'+css);
      if(key==='primaryColor'){
        if(selected)body.style.setProperty('--theme-button-ink',contrastInk(selected));else body.style.removeProperty('--theme-button-ink');
      }
    }
    const foreground=['light','dark'].includes(theme.foregroundPreset)?theme.foregroundPreset:null;
    if(foreground)body.dataset.themeForeground=foreground;else delete body.dataset.themeForeground;
    const overlay=Number.isInteger(theme.overlayOpacity)&&theme.overlayOpacity>=0&&theme.overlayOpacity<=85;
    body.toggleAttribute('data-theme-overlay',overlay);
    if(overlay)body.style.setProperty('--theme-overlay-opacity',String(theme.overlayOpacity/100));else body.style.removeProperty('--theme-overlay-opacity');
    body.style.setProperty('--theme-overlay-rgb',foreground==='dark'?'255 255 255':'0 0 0');
    if(config){if(previousPresentation!==theme.imagePresentation||previousLayout!==theme.layoutKey)mount();else images[index]?.onload?.();}
  }
  function reset(){
    ++generation;clearTimeout(timer);images.forEach(image=>image.remove());images=[];config=null;
    delete body.dataset.themeImageMode;delete backdrop.dataset.managed;
    body.style.removeProperty('--portal-national-background');original.forEach(image=>{image.hidden=false;});
  }
  function setImages(value){
    reset();
    if(!value?.images?.length)return;
    config=value;mount();
  }
  function mount(){
    ++generation;clearTimeout(timer);images.forEach(image=>image.remove());
    body.style.removeProperty('--portal-national-background');
    const full=theme.imagePresentation==='artwork';
    body.dataset.themeImageMode=full?'artwork':'background';backdrop.dataset.managed='true';
    original.forEach(image=>{image.hidden=true;});
    images=config.images.map(()=>{const image=document.createElement('img');image.alt='';image.decoding='async';image.className='theme-managed-image';backdrop.append(image);return image;});
    index=Math.max(0,config.images.findIndex(image=>image.imageId===config.defaultImageId));show(index);schedule();
  }
  function show(next){
    index=next;const current=images[index],currentGeneration=generation;
    current.onload=()=>{
      if(currentGeneration!==generation||index!==next)return;
      images.forEach(image=>image.classList.toggle('is-active',image===current));
      if(theme.layoutKey==='national-day'&&theme.imagePresentation!=='artwork'){
        const opacity=Number.isInteger(theme.overlayOpacity)?theme.overlayOpacity/100:.8;
        const tint=theme.foregroundPreset==='light'?'0 0 0':'245 249 243';
        body.style.setProperty('--portal-national-background',`linear-gradient(rgb(${tint} / ${opacity}),rgb(${tint} / ${opacity})),url("${config.images[index].url}") center / cover no-repeat`);
      }
      schedule();
      setTimeout(()=>{if(currentGeneration===generation)images.forEach(image=>{if(image!==images[index])image.removeAttribute('src');});},2500);
    };
    current.onerror=()=>{if(currentGeneration===generation&&images[index]===current)document.dispatchEvent(new CustomEvent('companyportal:theme-images',{detail:null}));};
    current.src=config.images[index].url;
  }
  function schedule(){
    clearTimeout(timer);
    const playing=config?.rotateImages&&images.length>1&&images[index]?.complete&&images[index]?.naturalWidth>0&&!document.hidden&&!reduced.matches&&!document.getElementById('personal-announcement-dialog')?.open;
    backdrop.dataset.paused=String(!playing);
    if(playing)timer=setTimeout(()=>{if(document.getElementById('personal-announcement-dialog')?.open){schedule();return;}show((index+1)%images.length);},Math.max(3,Math.min(3600,config.rotationSeconds||8))*1000);
  }
  function previewLayout(layout,name){
    if(!['official','work','national-day'].includes(layout))return;
    body.dataset.siteTheme=layout;section.dataset.theme=layout;
    section.querySelectorAll('.portal-theme-panel').forEach(panel=>{panel.hidden=panel.id!=='theme-'+layout;});
    const news=document.querySelector('.theme-official-news');document.getElementById(layout==='work'?'theme-work':'theme-official')?.append(news);
    document.getElementById('portal-floating-calendar')?.showPopover?.();
    const label=document.getElementById('personal-theme-name');if(label)label.textContent=name||'';
    const planner=document.querySelector('.personal-calendar-main')?.closest('.personal-planner');
    (document.getElementById(layout==='work'?'theme-work-calendar':'portal-floating-calendar-body'))?.append(...(planner?[planner]:[]));
  }
  document.addEventListener('companyportal:theme-images',event=>setImages(event.detail));
  document.addEventListener('visibilitychange',schedule);reduced.addEventListener('change',schedule);
  document.getElementById('personal-announcement-dialog')?.addEventListener('close',schedule);
  window.CompanyPortalTheme={apply,setImages,previewLayout};
})();
