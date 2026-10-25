(() => {
  const section=document.getElementById('safety'),sheet=document.getElementById('safety-book-sheet'),base=document.querySelector('meta[name="companyportal-api-base"]')?.content;
  if(!section||!sheet||!base)return;
  const endpoint=path=>new URL('api/safety-library'+path,new URL(base.replace(/\/?$/,'/'),location.href)).href;
  const list=section.querySelector('.portal-safety-booklets'),status=section.querySelector('#safety-status'),retry=section.querySelector('#safety-retry'),frame=section.querySelector('#safety-pdf-frame'),link=section.querySelector('#safety-pdf-link');
  const icons=section.querySelector('#safety-cover-icons').content.querySelectorAll('svg');
  const make=(tag,cls,text)=>{const n=document.createElement(tag);if(cls)n.className=cls;if(text!==undefined)n.textContent=text;return n;};
  let controller,generation=0,trigger;
  function clear(){sheet.close();frame.removeAttribute('src');link.removeAttribute('href');list.replaceChildren();trigger=null;}
  function open(book,doc,button){
    trigger=button;section.querySelector('#safety-book-title').textContent=book.tabName;
    const url=endpoint('/'+doc.documentId+'/file');link.href=url;frame.src=url;frame.title=book.tabName;sheet.showModal();
  }
  function render(books){
    list.replaceChildren(...books.filter(b=>b.documents.length===1).map((book,index)=>{
      const button=make('button','portal-safety-booklet');button.type='button';button.setAttribute('aria-haspopup','dialog');button.setAttribute('aria-controls','safety-book-sheet');
      const cover=make('span','portal-safety-book-cover');cover.append(make('span','portal-safety-book-number','كتيب '+String(index+1).padStart(2,'0')),icons[index%icons.length].cloneNode(true),make('strong',null,book.tabName),make('small',null,'دليل مبسّط'));
      const action=make('span','portal-safety-book-action','استعراض الكتيب '),arrow=make('span',null,'←');arrow.setAttribute('aria-hidden','true');action.append(arrow);button.append(cover,action);
      button.addEventListener('click',()=>open(book,book.documents[0],button));return button;
    }));
    status.textContent=list.children.length?'':'لا توجد كتيبات سلامة متاحة حاليًا.';
  }
  async function load(){
    controller?.abort();controller=new AbortController();const current=++generation;clear();retry.hidden=true;status.textContent='جارٍ تحميل كتيبات السلامة…';list.setAttribute('aria-busy','true');
    try{
      const response=await fetch(endpoint(''),{credentials:'include',cache:'no-store',signal:AbortSignal.any([controller.signal,AbortSignal.timeout(15000)])});
      if(current!==generation)return;if(!response.ok)throw new Error(String(response.status));const books=await response.json();if(current!==generation)return;render(books);
    }catch(e){if(current!==generation)return;clear();status.textContent=e.message==='401'||e.message==='403'?'حسابك غير مخوّل لعرض كتيبات السلامة.':'تعذر تحميل كتيبات السلامة. تحقق من الاتصال وأعد المحاولة.';retry.hidden=false;}
    finally{if(current===generation)list.setAttribute('aria-busy','false');}
  }
  sheet.querySelector('[data-safety-close]').addEventListener('click',()=>sheet.close());
  sheet.addEventListener('click',event=>{const r=sheet.getBoundingClientRect();if(event.target===sheet&&(event.clientX<r.left||event.clientX>r.right||event.clientY<r.top||event.clientY>r.bottom))sheet.close();});
  sheet.addEventListener('close',()=>{frame.removeAttribute('src');link.removeAttribute('href');trigger?.focus({preventScroll:true});});retry.addEventListener('click',load);
  document.addEventListener('visibilitychange',()=>{if(document.hidden){++generation;controller?.abort();clear();}else load();});window.addEventListener('pagehide',()=>{++generation;controller?.abort();clear();});window.addEventListener('pageshow',e=>{if(e.persisted)load();});load();
})();
