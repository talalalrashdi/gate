(() => {
 const root=document.getElementById('editorial-events'),base=document.querySelector('meta[name="companyportal-api-base"]')?.content,gallery=document.getElementById('editorial-gallery-dialog');if(!root||!base||!gallery)return;
 const endpoint=path=>new URL('api/media'+path,new URL(base.replace(/\/?$/,'/'),location.href)).href;
 const make=(tag,cls,text)=>{const n=document.createElement(tag);if(cls)n.className=cls;if(text!==undefined)n.textContent=text;return n;};
 const track=root.querySelector('.editorial-video-track'),photos=root.querySelector('.editorial-photo-slider'),status=root.querySelector('#portal-media-status'),retry=root.querySelector('#portal-media-retry');
 const image=gallery.querySelector('#editorial-gallery-image'),caption=gallery.querySelector('#editorial-gallery-caption'),thumbs=gallery.querySelector('.editorial-gallery-thumbnails'),range=gallery.querySelector('[data-gallery-range]'),page=gallery.querySelector('[data-gallery-page]'),zoom=gallery.querySelector('[data-gallery-zoom]');
 const stage=gallery.querySelector('.editorial-gallery-stage');image.draggable=false;let pan=null;
 function stopPan(){if(pan&&stage.hasPointerCapture(pan.id))stage.releasePointerCapture(pan.id);pan=null;stage.classList.remove('is-dragging');}
 function resetZoom(){stopPan();gallery.classList.remove('is-zoomed');zoom.setAttribute('aria-pressed','false');zoom.setAttribute('aria-label','تكبير الصورة');stage.scrollTo(0,0);}
 const videoDialog=make('dialog','editorial-dialog editorial-video-dialog');videoDialog.id='editorial-video-dialog';videoDialog.setAttribute('aria-labelledby','portal-video-title');
 const videoToolbar=make('header','editorial-gallery-toolbar'),videoTitle=make('h2'),videoClose=make('button',null,'✕'),player=make('video'),videoError=make('p');videoTitle.id='portal-video-title';videoClose.type='button';videoClose.setAttribute('aria-label','إغلاق الفيديو');player.controls=true;player.playsInline=true;videoError.setAttribute('role','status');videoToolbar.append(videoTitle,videoClose);videoDialog.append(videoToolbar,player,videoError);document.body.append(videoDialog);let videoOpener;
 function outside(dialog,event){const r=dialog.getBoundingClientRect();return event.clientX<r.left||event.clientX>r.right||event.clientY<r.top||event.clientY>r.bottom;}
 function dismissOutside(dialog){let startedOutside=false;dialog.addEventListener('pointerdown',e=>{startedOutside=e.button===0&&e.target===dialog&&outside(dialog,e);});dialog.addEventListener('pointerup',e=>{if(startedOutside&&e.target===dialog&&outside(dialog,e))dialog.close();startedOutside=false;});}
 dismissOutside(gallery);dismissOutside(videoDialog);videoClose.addEventListener('click',()=>videoDialog.close());
 function clearPlayer(){player.pause();player.removeAttribute('src');player.load();videoError.textContent='';}
 videoDialog.addEventListener('close',()=>{clearPlayer();videoOpener?.focus({preventScroll:true});});player.addEventListener('error',()=>{if(player.hasAttribute('src'))videoError.textContent='تعذر تشغيل الفيديو. تحقق من الملف واتصال البوابة أو ترميز الفيديو.';});
 function openVideo(media,button){pause();videoOpener=button;videoTitle.textContent=media.mediaName;videoError.textContent='';player.src=file(media.mediaId);videoDialog.showModal();player.play().catch(()=>{if(videoDialog.open)videoError.textContent='اضغط تشغيل للمشاهدة. إذا تعذر التشغيل، تحقق من الملف واتصال البوابة.';});}
 let albums=[],videoIndex=0,albumIndex=0,currentPhotos=[],photoIndex=0,controller,generation=0,opener;
 let realCatalog={groups:[],items:[]},simulatedItems=[];const simulatedSources=new Map();
 function file(id){return endpoint('/'+(simulatedSources.get(id)??id)+'/file');}
 function renderCurrent(){clear();render({...realCatalog,items:[...simulatedItems,...realCatalog.items]});}
 function pause(){track.querySelectorAll('video').forEach(v=>v.pause());}
 function closeGallery(){image.removeAttribute('src');thumbs.replaceChildren();currentPhotos=[];caption.textContent='';gallery.querySelector('#editorial-gallery-status').textContent='';resetZoom();}
 function clear(){videoDialog.close();clearPlayer();pause();track.querySelectorAll('video').forEach(v=>{v.removeAttribute('src');v.load();});gallery.close();closeGallery();track.replaceChildren();photos.replaceChildren();albums=[];videoIndex=0;albumIndex=0;videoControls();photoControls();}
 function videoControls(){const count=track.children.length;root.querySelector('[data-video-status]').textContent=count?(videoIndex+1)+' / '+count:'0 / 0';root.querySelectorAll('[data-video-prev]').forEach(b=>b.disabled=!count||videoIndex===0);root.querySelectorAll('[data-video-next]').forEach(b=>b.disabled=!count||videoIndex>=count-1);}
 function videoPosition(card){return Math.max(-Math.max(0,track.scrollWidth-track.clientWidth),Math.min(0,card.offsetLeft-track.children[0].offsetLeft));}
 function moveVideo(step,scroll=true){
  videoIndex=Math.max(0,Math.min(track.children.length-1,videoIndex+step));[...track.children].forEach((card,i)=>{const selected=i===videoIndex;card.querySelector('.editorial-video-select').hidden=selected;card.querySelector('.editorial-video-play').hidden=!selected;const video=card.querySelector('video');video.inert=true;if(!selected){video.pause();video.controls=false;}});videoControls();
  if(scroll&&track.children.length){const card=track.children[videoIndex];track.scrollTo({left:videoPosition(card),behavior:matchMedia('(prefers-reduced-motion: reduce)').matches?'instant':'smooth'});}
 }
 function photoControls(){const count=albums.length;root.querySelector('[data-photo-status]').textContent=count?(albumIndex+1)+' / '+count:'0 / 0';root.querySelector('[data-photo-prev]').disabled=count<2;root.querySelector('[data-photo-next]').disabled=count<2;}
 function chooseAlbum(index){
  if(!albums.length)return;albumIndex=(index+albums.length)%albums.length;
  [...photos.children].forEach((card,i)=>{const next=(albumIndex+1)%albums.length,previous=(albumIndex+albums.length-1)%albums.length,selected=i===albumIndex;card.hidden=!(selected||i===next||i===previous);card.classList.toggle('is-selected',selected);card.style.setProperty('--photo-slot',selected?'0':i===next?'-1':'1');card.querySelector('.editorial-photo-select').setAttribute('aria-pressed',String(selected));card.querySelector('.editorial-photo-enlarge').hidden=!selected;});photoControls();
 }
 function renderGallery(){
  const photo=currentPhotos[photoIndex];if(!photo)return;image.src=file(photo.mediaId);image.alt=photo.mediaName;caption.textContent=photo.mediaName;
  gallery.querySelector('#editorial-gallery-status').textContent=(photoIndex+1)+' / '+currentPhotos.length;range.max=String(currentPhotos.length);page.max=String(currentPhotos.length);range.value=page.value=String(photoIndex+1);
  gallery.querySelector('#editorial-gallery-prev').disabled=photoIndex===0;gallery.querySelector('#editorial-gallery-next').disabled=photoIndex===currentPhotos.length-1;
  [...thumbs.children].forEach((n,i)=>n.setAttribute('aria-pressed',String(i===photoIndex)));resetZoom();
 }
 function selectPhoto(index){photoIndex=Math.max(0,Math.min(currentPhotos.length-1,Number(index)||0));renderGallery();}
 function openAlbum(album,button){
  pause();currentPhotos=album.items;photoIndex=0;opener=button;thumbs.replaceChildren(...currentPhotos.map((photo,i)=>{const b=make('button'),img=make('img');b.type='button';b.setAttribute('aria-label','عرض '+photo.mediaName);img.src=file(photo.mediaId);img.alt='';img.loading='lazy';b.append(img);b.addEventListener('click',()=>selectPhoto(i));return b;}));renderGallery();gallery.showModal();stage.focus({preventScroll:true});
 }
 function render(c){
  const items=[...c.items].sort((a,b)=>a.displayOrder-b.displayOrder||a.mediaId-b.mediaId);
  for(const m of items.filter(m=>m.mediaType==='video')){
   const card=make('article','editorial-video-card'),stage=make('div','editorial-video-stage'),v=make('video');v.playsInline=true;v.preload='metadata';v.src=file(m.mediaId);v.setAttribute('aria-label',m.mediaName);
   v.addEventListener('loadedmetadata',()=>{if(v.paused&&v.currentTime===0&&Number.isFinite(v.duration)&&v.duration>0)v.currentTime=Math.min(.1,v.duration/2);},{once:true});
   const play=make('button','editorial-video-play','▶');play.type='button';play.setAttribute('aria-label','تشغيل '+m.mediaName);
   const select=make('button','editorial-video-select');select.type='button';select.setAttribute('aria-label','عرض الفيديو '+m.mediaName);select.addEventListener('click',()=>moveVideo([...track.children].indexOf(card)-videoIndex));
   const copy=make('div','editorial-event-copy'),note=make('small');note.setAttribute('role','status');copy.append(make('h3',null,m.mediaName),note);stage.append(v,play,copy,select);card.append(stage);track.append(card);
   play.addEventListener('click',()=>openVideo(m,play));v.addEventListener('error',()=>{note.textContent='تعذر تشغيل الفيديو؛ قد يكون الملف غير متاح أو ترميزه غير مدعوم.';});
  }
  albums=c.groups.map(g=>({title:g.groupName,order:g.displayOrder,key:'g'+g.mediaGroupId,cover:g.coverMediaId,items:items.filter(m=>m.mediaType==='image'&&m.mediaGroupId===g.mediaGroupId)})).filter(g=>g.items.length);
  albums.push(...items.filter(m=>m.mediaType==='image'&&m.mediaGroupId===null).map(m=>({title:m.mediaName,order:m.displayOrder,key:'m'+m.mediaId,cover:m.mediaId,items:[m]})));albums.sort((a,b)=>a.order-b.order||a.key.localeCompare(b.key));
  for(const album of albums){
   const card=make('article','editorial-photo-slide'),img=make('img');img.src=file(album.cover);img.alt=album.title;img.loading='lazy';
   const select=make('button','editorial-photo-select');select.type='button';select.setAttribute('aria-label','اختيار '+album.title);select.addEventListener('click',()=>chooseAlbum(albums.indexOf(album)));
   const copy=make('div','editorial-photo-copy');copy.append(make('h3',null,album.title),make('p',null,album.items.length===1?'صورة واحدة':album.items.length+' صور'));
   const open=make('button','editorial-photo-enlarge','↗');open.type='button';open.dataset.editorialGallery='';open.setAttribute('aria-label','عرض '+album.title+(album.items.length>1?' — '+album.items.length+' صور':''));open.addEventListener('click',()=>openAlbum(album,open));card.append(img,select,copy,open);photos.append(card);
   img.addEventListener('error',()=>{copy.querySelector('p').textContent='تعذر تحميل صورة الغلاف؛ افتح المجموعة لعرض الصور.';});
  }
  root.querySelector('#portal-videos-empty').hidden=track.children.length>0;root.querySelector('#portal-photos-empty').hidden=albums.length>0;photos.hidden=!albums.length;moveVideo(0,false);chooseAlbum(0);
  status.textContent=track.children.length||albums.length?'':'لا توجد صور أو فيديوهات متاحة حاليًا.';
 }
 async function load(){
  controller?.abort();controller=new AbortController();const current=++generation;clear();retry.hidden=true;status.textContent='جارٍ تحميل الصور والفيديوهات…';root.setAttribute('aria-busy','true');
  try{const response=await fetch(endpoint(''),{credentials:'include',cache:'no-store',signal:AbortSignal.any([controller.signal,AbortSignal.timeout(15000)])});if(!response.ok)throw new Error(String(response.status));const c=await response.json();if(current!==generation)return;realCatalog=c;render({...c,items:[...simulatedItems,...c.items]});document.dispatchEvent(new CustomEvent('portal:media-catalog',{detail:c}));}
  catch(e){if(current!==generation)return;realCatalog={groups:[],items:[]};simulatedItems=[];simulatedSources.clear();document.dispatchEvent(new CustomEvent('portal:media-catalog',{detail:null}));clear();status.textContent=e.message==='401'||e.message==='403'?'حسابك غير مخوّل لعرض الوسائط.':'تعذر تحميل صور وفيديوهات أخبارنا. تحقق من الاتصال وأعد المحاولة.';retry.hidden=false;}
  finally{if(current===generation)root.setAttribute('aria-busy','false');}
 }
 root.querySelectorAll('[data-video-prev]').forEach(b=>b.addEventListener('click',()=>moveVideo(-1)));root.querySelectorAll('[data-video-next]').forEach(b=>b.addEventListener('click',()=>moveVideo(1)));track.addEventListener('keydown',e=>{if(!e.altKey&&!e.ctrlKey&&!e.metaKey&&['ArrowLeft','ArrowRight'].includes(e.key)){e.preventDefault();moveVideo(e.key==='ArrowLeft'?1:-1);}});
 let scrollTimer;track.addEventListener('scroll',()=>{clearTimeout(scrollTimer);scrollTimer=setTimeout(()=>{if(!track.children.length)return;const closest=[...track.children].reduce((best,card,i)=>Math.abs(videoPosition(card)-track.scrollLeft)<Math.abs(videoPosition(track.children[best])-track.scrollLeft)?i:best,0);moveVideo(closest-videoIndex,false);},120);},{passive:true});new ResizeObserver(()=>{if(track.children.length)moveVideo(0);}).observe(track);
 root.querySelector('[data-photo-prev]').addEventListener('click',()=>chooseAlbum(albumIndex-1));root.querySelector('[data-photo-next]').addEventListener('click',()=>chooseAlbum(albumIndex+1));photos.addEventListener('keydown',e=>{if(['ArrowLeft','ArrowRight'].includes(e.key)){e.preventDefault();chooseAlbum(albumIndex+(e.key==='ArrowLeft'?1:-1));}});
 gallery.querySelector('#editorial-gallery-prev').addEventListener('click',()=>selectPhoto(photoIndex-1));gallery.querySelector('#editorial-gallery-next').addEventListener('click',()=>selectPhoto(photoIndex+1));range.addEventListener('input',()=>selectPhoto(Number(range.value)-1));page.addEventListener('change',()=>selectPhoto(Number(page.value)-1));
 function toggleZoom(){stopPan();const value=gallery.classList.toggle('is-zoomed');stage.scrollTo(0,0);zoom.setAttribute('aria-pressed',String(value));zoom.setAttribute('aria-label',value?'إعادة الصورة إلى حجمها الطبيعي':'تكبير الصورة');}
 zoom.addEventListener('click',toggleZoom);stage.addEventListener('dblclick',e=>{e.preventDefault();toggleZoom();});image.addEventListener('error',()=>{caption.textContent='تعذر تحميل الصورة. تحقق من اتصال البوابة أو انتقل للصورة التالية.';});
 gallery.addEventListener('keydown',e=>{if(e.altKey||e.ctrlKey||e.metaKey||e.target.closest('input,select,textarea,[contenteditable=true]'))return;if(e.key==='ArrowLeft'||e.key==='ArrowRight'){e.preventDefault();selectPhoto(photoIndex+(e.key==='ArrowLeft'?1:-1));}else if(e.key==='Home'||e.key==='End'){e.preventDefault();selectPhoto(e.key==='Home'?0:currentPhotos.length-1);}});
 stage.addEventListener('pointerdown',e=>{if(!gallery.classList.contains('is-zoomed')||e.button!==0)return;e.preventDefault();pan={id:e.pointerId,x:e.clientX,y:e.clientY,left:stage.scrollLeft,top:stage.scrollTop};stage.setPointerCapture(e.pointerId);stage.classList.add('is-dragging');});
 stage.addEventListener('pointermove',e=>{if(!pan||pan.id!==e.pointerId)return;stage.scrollLeft=pan.left+pan.x-e.clientX;stage.scrollTop=pan.top+pan.y-e.clientY;});
 ['pointerup','pointercancel','lostpointercapture'].forEach(type=>stage.addEventListener(type,stopPan));
 gallery.querySelector('[data-editorial-close]').addEventListener('click',()=>gallery.close());gallery.addEventListener('close',()=>{closeGallery();opener?.focus({preventScroll:true});});retry.addEventListener('click',load);
 if(document.getElementById('portal-simulation'))document.addEventListener('portal:simulate',e=>{
  const d=e.detail;if(d?.kind==='reset'){simulatedItems=[];simulatedSources.clear();renderCurrent();return;}
  if(!['media-photo','media-video'].includes(d?.kind))return;
  const source=realCatalog.items.find(m=>m.mediaType===(d.kind==='media-photo'?'image':'video'));if(!source)return;
  const id=-Number(d.id);simulatedSources.set(id,source.mediaId);simulatedItems.unshift({...source,mediaId:id,mediaName:d.title,displayOrder:-Number(d.id)});renderCurrent();
 });
 document.addEventListener('visibilitychange',()=>{if(document.hidden){++generation;controller?.abort();clear();}else load();});window.addEventListener('pagehide',()=>{++generation;controller?.abort();clear();});window.addEventListener('pageshow',e=>{if(e.persisted)load();});load();
})();
