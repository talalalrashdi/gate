(() => {
  const panel=document.getElementById('intro-option-5');if(!panel)return;
  const backdrop=panel.querySelector('.bn-news-backdrop'),images=[...backdrop.querySelectorAll('img')],button=panel.querySelector('.bn-news-playback');
  const motion=matchMedia('(prefers-reduced-motion: reduce)');
  let index=0,timer,paused=motion.matches,visible=false;
  function sync(){
    clearTimeout(timer);
    const running=!paused&&visible&&!document.hidden&&document.body.dataset.siteTheme==='news';
    backdrop.dataset.paused=String(!running);button.setAttribute('aria-pressed',String(paused));button.textContent=paused?'تشغيل حركة الخلفية':'إيقاف حركة الخلفية';
    if(running)timer=setTimeout(()=>{index=(index+1)%images.length;images.forEach((image,i)=>image.classList.toggle('is-active',i===index));sync();},8000);
  }
  new IntersectionObserver(entries=>{visible=entries[0].isIntersecting;sync();},{threshold:0}).observe(panel);
  button.addEventListener('click',()=>{paused=!paused;sync();});
  document.addEventListener('clerio:theme-change',sync);document.addEventListener('visibilitychange',sync);
  motion.addEventListener('change',()=>{paused=motion.matches;sync();});
  sync();
})();
