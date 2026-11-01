/* Align section anchors with the actual sticky header, including after smooth scroll. */
(() => {
 let cleanup=()=>{};
 const offset=()=>Math.max(0,...['.portal-header','.portal-media-subnav'].map(s=>document.querySelector(s)?.getBoundingClientRect().bottom||0))+12;
 function go(target,hash){
  cleanup();let timer,settle,frame;const stop=()=>{clearTimeout(timer);cancelAnimationFrame(frame);window.removeEventListener('scrollend',settle);window.removeEventListener('wheel',stop);window.removeEventListener('touchstart',stop);window.removeEventListener('keydown',stop);};cleanup=stop;
  const top=()=>Math.max(0,window.scrollY+target.getBoundingClientRect().top-offset());
  settle=()=>{stop();window.scrollTo({top:top(),behavior:'instant'});};
  history.pushState(null,'',hash);
  frame=requestAnimationFrame(()=>{window.scrollTo({top:top(),behavior:matchMedia('(prefers-reduced-motion: reduce)').matches?'instant':'smooth'});window.addEventListener('scrollend',settle,{once:true});timer=setTimeout(settle,1400);});
  window.addEventListener('wheel',stop,{passive:true});window.addEventListener('touchstart',stop,{passive:true});window.addEventListener('keydown',stop);
 }
 window.addEventListener('popstate',()=>cleanup());window.addEventListener('pagehide',()=>cleanup());
 document.addEventListener('click',event=>{
  if(event.target.closest?.('.portal-nav a[href="#systems"]'))cleanup();
  if(event.defaultPrevented||event.button!==0||event.ctrlKey||event.metaKey||event.shiftKey||event.altKey)return;
  const link=event.target.closest?.('.portal-media-subnav-links a[href^="#"],.theme-official-story-action[href^="#"]');if(!link)return;
  const hash=link.getAttribute('href');let target;try{target=document.querySelector(hash);}catch{return;}if(!target)return;
  event.preventDefault();go(hash==='#editorial-news'?document.querySelector('.editorial-masthead')||target:target,hash);
 });
})();
