/* One-shot visibility gates. Metadata/live connections stay under their existing owners. */
(() => {
 const gates=new Set();
 function gate(element,{margin='300px 0px'}={}){
  let ready=!element||typeof IntersectionObserver==='undefined',pending=null,observer;
  const activate=()=>{if(ready&&!pending)return;ready=true;observer?.disconnect();gates.delete(result);if(element)element.dataset.lazyState='ready';const work=pending;pending=null;work?.();};
  if(element){element.dataset.lazyState=ready?'ready':'waiting';if(!ready){observer=new IntersectionObserver(entries=>{if(entries.some(e=>e.isIntersecting))activate();},{rootMargin:margin,threshold:0});observer.observe(element);}}
  const result={get ready(){return ready;},run(work){if(ready)work();else pending=work;},activate,clear(){pending=null;},dispose(){pending=null;observer?.disconnect();gates.delete(result);},element};if(!ready)gates.add(result);return result;
 }
 // Hash links trigger preparation before smooth scrolling reaches the target.
 document.addEventListener('click',event=>{
  if(event.defaultPrevented)return;const link=event.target.closest?.('a[href^="#"]');if(!link)return;const hash=link.getAttribute('href');if(!hash||hash==='#')return;
  let target;try{target=document.querySelector(hash);}catch{return;}
  if(target)for(const g of gates)if(g.element&&(target===g.element||target.contains(g.element)))g.activate();
 });
 window.CompanyPortalLazy={gate};
 const home=document.querySelector('.portal-nav a[href="#systems"]');
 home?.addEventListener('click',event=>{
  if(event.button!==0||event.ctrlKey||event.metaKey||event.shiftKey||event.altKey)return;
  event.preventDefault();history.replaceState(null,'',location.pathname+location.search);
  window.scrollTo({top:0,left:0,behavior:matchMedia('(prefers-reduced-motion: reduce)').matches?'instant':'smooth'});
 });
})();
