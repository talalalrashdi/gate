(() => {
  const reader = document.getElementById('monthly-reader');
  if (!reader) return;
  // Pages are drawn from the issue PDF with the bundled PDF.js (wwwroot/vendor/pdfjs, offline).
  const pdfjsBase = new URL('../vendor/pdfjs/', document.currentScript?.src || location.href);
  let pdfjs, pdfDoc = null, loadingTask = null;
  const mainTasks = new Set(), thumbTasks = new Set();
  const stage = reader.querySelector('.editorial-local-stage'), spread = reader.querySelector('.editorial-local-spread');
  const message = reader.querySelector('.editorial-local-message');
  const previous = reader.querySelector('[data-mag-prev]'), next = reader.querySelector('[data-mag-next]');
  const pageInput = reader.querySelector('[data-mag-page]');
  const thumbs = reader.querySelector('.editorial-local-thumbnails'), thumbButton = reader.querySelector('[data-mag-thumbnails]');
  const zoomButton = reader.querySelector('[data-mag-zoom]'), fullButton = reader.querySelector('[data-mag-fullscreen]');
  const zoomOut=reader.querySelector('[data-mag-zoom-out]'),issueSelect=reader.closest('.editorial-magazine').querySelector('[data-mag-issue]'),pdfLink=reader.querySelector('[data-mag-pdf]');
  const base=document.querySelector('meta[name="companyportal-api-base"]')?.content;if(!base)return;
  const endpoint=path=>new URL('api/magazines'+path,new URL(base.replace(/\/?$/,'/'),location.href)).href;
  const name=reader.closest('.editorial-magazine').querySelector('[data-mag-name]'),retry=reader.querySelector('[data-mag-retry]');
  let activeIssue=null,pdfPage=1,pdfFrame,issues=[],selectedIssue=null,controller,generation=0;
  const newBadge=document.querySelector('[data-mag-new]'),attemptedReads=new Set(),confirmedReads=new Set(),readyIssues=new Set();
  let readerVisible=false;
  function updateBadge(){if(newBadge)newBadge.hidden=!issues.length||issues[0].hasRead!==false||confirmedReads.has(issues[0].magazineId);}
  async function markRead(id){
    const issue=issues.find(row=>row.magazineId===id);
    if(!issue||issue.hasRead!==false||confirmedReads.has(id)||attemptedReads.has(id))return;
    // Set before starting the request: scroll, load, zoom and visibility events cannot duplicate it.
    attemptedReads.add(id);
    try{
      const response=await fetch(endpoint(`/${id}/read`),{method:'POST',credentials:'include',cache:'no-store',headers:{'X-CompanyPortal-Request':'magazine-read'},signal:AbortSignal.timeout(15000)});
      if(!response.ok)return;confirmedReads.add(id);issue.hasRead=true;updateBadge();
    }catch{/* Keep the badge on failure; do not retry automatically or poll. A page reload can retry. */}
  }
  function maybeMarkRead(){if(!document.hidden&&readerVisible&&selectedIssue&&readyIssues.has(selectedIssue.magazineId))markRead(selectedIssue.magazineId);}
  const readObserver=new IntersectionObserver(entries=>{readerVisible=entries[0].isIntersecting&&entries[0].intersectionRatio>=.25;maybeMarkRead();},{threshold:[0,.25]});readObserver.observe(stage);
  pdfLink.addEventListener('click',e=>{if(!e.defaultPrevented&&selectedIssue&&pdfLink.hasAttribute('href'))markRead(selectedIssue.magazineId);});
  pdfLink.addEventListener('auxclick',e=>{if(e.button===1&&selectedIssue&&pdfLink.hasAttribute('href'))markRead(selectedIssue.magazineId);});
  function renderPDF(){
    if(!activeIssue)return;
    if(!pdfFrame){pdfFrame=document.createElement('iframe');pdfFrame.className='editorial-local-pdf-frame';pdfFrame.title='قراءة '+selectedIssue.magazineName;const issueId=selectedIssue.magazineId;pdfFrame.addEventListener('load',()=>{if(selectedIssue?.magazineId===issueId){readyIssues.add(issueId);maybeMarkRead();}});stage.append(pdfFrame);}
    pdfFrame.src=activeIssue.url+'#toolbar=1&navpanes=0&page='+pdfPage+'&zoom='+(reader.classList.contains('is-zoomed')?150:100);
    pageInput.value=String(pdfPage);previous.disabled=next.disabled=true;message.hidden=true;
  }
  const mobile = matchMedia('(max-width:760px)'), reduced = matchMedia('(prefers-reduced-motion:reduce)');
  let pages = [], current = 0, turning = false, turnTimer, touch;

  const number = value => value.toLocaleString('ar-EG-u-nu-latn');
  const normalize = index => mobile.matches || index === 0 ? index : (index % 2 ? index : index - 1);
  const indexes = () => mobile.matches || current === 0 || current === pages.length - 1 ? [current] : [current, current + 1];
  function loadPdfjs() {
    pdfjs ??= import(new URL('pdf.min.mjs', pdfjsBase).href).then(lib => { lib.GlobalWorkerOptions.workerSrc = new URL('pdf.worker.min.mjs', pdfjsBase).href; return lib; });
    return pdfjs;
  }
  async function paint(canvas, index, width, main) {
    const doc = pdfDoc, issueId = selectedIssue?.magazineId, tasks = main ? mainTasks : thumbTasks;
    try {
      const page = await doc.getPage(index + 1);
      if (doc !== pdfDoc || !canvas.isConnected) return;
      const size = page.getViewport({ scale: 1 }); pages[index] = { width: size.width, height: size.height };
      if (main && index === current) reader.style.setProperty('--magazine-page-ratio', size.width / size.height);
      const viewport = page.getViewport({ scale: width / size.width });
      canvas.width = Math.round(viewport.width); canvas.height = Math.round(viewport.height);
      const task = page.render({ canvasContext: canvas.getContext('2d', { alpha: false }), viewport }); tasks.add(task);
      try { await task.promise; } finally { tasks.delete(task); }
      if (main && doc === pdfDoc && selectedIssue?.magazineId === issueId) { readyIssues.add(issueId); maybeMarkRead(); }
    } catch (error) {
      if (error?.name === 'RenderingCancelledException' || doc !== pdfDoc || !canvas.isConnected || !main) return;
      message.hidden = false; message.textContent = 'تعذّر عرض الصفحة. يمكنك فتح ملف PDF من المتحكم أسفل المجلة.';
    }
  }
  function canvasFor(index, thumbnail = false) {
    const canvas = document.createElement('canvas'), width = thumbnail ? 180 : 1500;
    canvas.width = width; canvas.height = Math.round(width * pages[index].height / pages[index].width);
    canvas.setAttribute('role', 'img'); canvas.setAttribute('aria-label', `صفحة ${number(index + 1)} من ${selectedIssue.magazineName}`);
    canvas.dataset.page = String(index);
    if (!thumbnail) void paint(canvas, index, width, true);
    return canvas;
  }
  // The turning page is a clone of the outgoing spread; canvas pixels are not cloned, so copy them.
  function cloneSpreadPage(source) {
    const clone = source.cloneNode(true), from = source.querySelectorAll('canvas');
    clone.querySelectorAll('canvas').forEach((canvas, i) => { canvas.width = from[i].width; canvas.height = from[i].height; canvas.getContext('2d').drawImage(from[i], 0, 0); });
    return clone;
  }
  const thumbObserver = new IntersectionObserver(entries => entries.forEach(entry => {
    if (!entry.isIntersecting || !pdfDoc) return;
    thumbObserver.unobserve(entry.target); void paint(entry.target, Number(entry.target.dataset.page), 180, false);
  }), { root: thumbs, rootMargin: '200px' });
  function render() {
    if(activeIssue){renderPDF();return;}
    const visible = indexes();
    reader.style.setProperty('--magazine-page-ratio', pages[current].width / pages[current].height);
    mainTasks.forEach(task => task.cancel()); mainTasks.clear();
    spread.replaceChildren(...visible.map(index => {
      const page = document.createElement('div'); page.className = 'editorial-local-page'; page.append(canvasFor(index)); return page;
    }));
    spread.classList.toggle('is-single', visible.length === 1);
    pageInput.value = String(current + 1);
    previous.disabled = current === 0; next.disabled = visible.at(-1) >= pages.length - 1;
    [...thumbs.children].forEach((button, index) => button.setAttribute('aria-pressed', String(visible.includes(index))));
    stage.scrollTop = stage.scrollLeft = 0;
    message.hidden = true;
  }
  function goTo(index, animate = true) {
    if(activeIssue){pdfPage=Math.max(1,index+1);renderPDF();return;}
    if (!pages.length) return;
    if (turning) { clearTimeout(turnTimer); stage.querySelector('.editorial-local-turn')?.remove(); turning = false; }
    index = normalize(Math.max(0, Math.min(pages.length - 1, index)));
    if (index === current) { pageInput.value = String(current + 1); return; }
    const forward = index > current;
    const clone = animate && !mobile.matches && !reduced.matches && !reader.classList.contains('is-zoomed') && spread.lastElementChild ? cloneSpreadPage(spread.lastElementChild) : null;
    current = index; render();
    if (clone) {
      turning = true; clone.classList.add('editorial-local-turn', forward ? 'is-forward' : 'is-backward'); clone.setAttribute('aria-hidden', 'true'); stage.append(clone);
      const finish = () => { clearTimeout(turnTimer); clone.remove(); turning = false; };
      clone.addEventListener('animationend', finish, {once: true}); turnTimer = setTimeout(finish, 600);
    }
  }
  const advance = () => activeIssue?goTo(pdfPage):goTo(indexes().at(-1) + 1);
  const retreat = () => activeIssue?goTo(pdfPage-2):goTo(current - (mobile.matches || current <= 1 ? 1 : 2));
  previous.addEventListener('click', retreat); next.addEventListener('click', advance);
  pageInput.addEventListener('change', () => goTo((Number(pageInput.value) || 1) - 1, false));
  pageInput.addEventListener('keydown', event => { if (event.key === 'Enter') { event.preventDefault(); goTo((Number(pageInput.value) || 1) - 1, false); } });
  stage.addEventListener('keydown', event => {
    if (event.key === 'ArrowLeft' || event.key === 'ArrowRight') { event.preventDefault(); event.key === 'ArrowLeft' ? advance() : retreat(); }
  });
  stage.addEventListener('touchstart', event => { touch = {x: event.touches[0].clientX, y: event.touches[0].clientY}; }, {passive: true});
  stage.addEventListener('touchend', event => {
    if (!touch || reader.classList.contains('is-zoomed')) return;
    const dx = event.changedTouches[0].clientX - touch.x, dy = event.changedTouches[0].clientY - touch.y; touch = null;
    if (Math.abs(dx) > 55 && Math.abs(dx) > Math.abs(dy) * 1.5) dx > 0 ? advance() : retreat();
  }, {passive: true});
  thumbButton.addEventListener('click', () => {
    if (!pages.length) return;
    if (!thumbs.children.length) pages.forEach((page, index) => {
      const button = document.createElement('button'); button.type = 'button'; button.setAttribute('aria-label', `الانتقال إلى الصفحة ${number(index + 1)}`);
      const canvas = canvasFor(index, true); thumbObserver.observe(canvas);
      button.append(canvas, document.createTextNode(number(index + 1)));
      button.addEventListener('click', () => { goTo(index, false); thumbs.hidden = true; thumbButton.setAttribute('aria-expanded', 'false'); stage.focus({preventScroll: true}); }); thumbs.append(button);
    });
    thumbs.hidden = !thumbs.hidden; thumbButton.setAttribute('aria-expanded', String(!thumbs.hidden));
    [...thumbs.children].forEach((button, index) => button.setAttribute('aria-pressed', String(indexes().includes(index))));
  });
  function setZoom(zoomed){
    reader.classList.toggle('is-zoomed',zoomed);zoomButton.setAttribute('aria-pressed',String(zoomed));
    if(zoomOut){zoomButton.disabled=zoomed;zoomOut.disabled=!zoomed;}
    else {zoomButton.setAttribute('aria-label',zoomed?'تصغير الصفحات':'تكبير الصفحات');zoomButton.textContent=zoomed?'−':'＋';}
    if(activeIssue)renderPDF();
  }
  zoomButton.addEventListener('click',()=>setZoom(zoomOut?true:!reader.classList.contains('is-zoomed')));
  zoomOut?.addEventListener('click',()=>setZoom(false));
  function clearReader(){
    clearTimeout(turnTimer);turning=false;stage.querySelector('.editorial-local-turn')?.remove();
    mainTasks.forEach(task=>task.cancel());thumbTasks.forEach(task=>task.cancel());mainTasks.clear();thumbTasks.clear();thumbObserver.disconnect();
    loadingTask?.destroy();loadingTask=null;pdfDoc=null;
    pages=[];current=0;activeIssue=null;selectedIssue=null;pdfFrame?.remove();pdfFrame=null;spread.replaceChildren();thumbs.replaceChildren();thumbs.hidden=true;
    reader.classList.remove('is-pdf','is-zoomed');zoomButton.setAttribute('aria-pressed','false');thumbButton.setAttribute('aria-expanded','false');
    [previous,next,pageInput,thumbButton,zoomButton,fullButton,zoomOut].filter(Boolean).forEach(n=>n.disabled=true);pageInput.value='1';pageInput.removeAttribute('max');
    pdfLink.removeAttribute('href');pdfLink.setAttribute('aria-disabled','true');name.textContent='—';message.hidden=false;
  }
  async function selectIssue(){
    controller?.abort();controller=new AbortController();const signal=controller.signal,stamp=++generation;
    const selected=issues.find(row=>String(row.magazineId)===issueSelect.value);clearReader();retry.hidden=true;
    if(!selected){message.textContent='لا توجد أعداد منشورة حاليًا.';return;}
    selectedIssue=selected;name.textContent=selected.magazineName;reader.setAttribute('aria-label','قارئ '+selected.magazineName);message.textContent='جارٍ تجهيز المجلة…';reader.setAttribute('aria-busy','true');
    try{
      const url=endpoint(`/${selected.magazineId}/pdf`),lib=await loadPdfjs().catch(()=>null);
      if(stamp!==generation||signal.aborted)return;
      if(!lib){activeIssue={url};reader.classList.add('is-pdf');renderPDF();}
      else{
        const task=loadingTask=lib.getDocument({url,withCredentials:true,isEvalSupported:false,disableFontFace:true,cMapPacked:true,
          cMapUrl:new URL('cmaps/',pdfjsBase).href,standardFontDataUrl:new URL('standard_fonts/',pdfjsBase).href});
        signal.addEventListener('abort',()=>task.destroy(),{once:true});
        const doc=await task.promise;if(stamp!==generation||signal.aborted)return;
        const size=(await doc.getPage(1)).getViewport({scale:1});if(stamp!==generation||signal.aborted)return;
        pdfDoc=doc;pages=Array.from({length:doc.numPages},()=>({width:size.width,height:size.height}));
        pageInput.max=String(pages.length);pageInput.disabled=false;thumbButton.disabled=false;render();
      }
      pdfLink.href=endpoint(`/${selected.magazineId}/pdf`);pdfLink.removeAttribute('aria-disabled');zoomButton.disabled=false;fullButton.disabled=false;
    }catch(e){if(stamp!==generation||signal.aborted)return;clearReader();message.textContent='تعذّر تحميل المجلة. تحقق من الاتصال وأعد المحاولة.';retry.hidden=false;}
    finally{if(stamp===generation)reader.setAttribute('aria-busy','false');}
  }
  async function loadCatalog(){
    controller?.abort();controller=new AbortController();const signal=controller.signal,stamp=++generation;clearReader();issues=[];updateBadge();issueSelect.replaceChildren(new Option('جارٍ تحميل الأعداد…',''));issueSelect.disabled=true;retry.hidden=true;message.textContent='جارٍ تحميل أعداد المجلة…';
    try{
      const response=await fetch(endpoint(''),{credentials:'include',cache:'no-store',signal:AbortSignal.any([signal,AbortSignal.timeout(15000)])});if(!response.ok)throw new Error('Magazine catalog unavailable');const data=await response.json();if(stamp!==generation||signal.aborted)return;
      if(!Array.isArray(data))throw new Error('Invalid magazine catalog');issues=data;issues.forEach(row=>{if(confirmedReads.has(row.magazineId))row.hasRead=true;});updateBadge();
      issueSelect.replaceChildren(...issues.map(row=>new Option(`${row.magazineName} · العدد ${row.issueNumber} · ${row.issueDate}`,String(row.magazineId))));
      if(!issues.length){issueSelect.add(new Option('لا توجد أعداد منشورة',''));message.textContent='لا توجد أعداد منشورة حاليًا.';return;}
      issueSelect.disabled=false;await selectIssue();
    }catch(e){if(stamp!==generation||signal.aborted)return;issueSelect.replaceChildren(new Option('تعذّر تحميل الأعداد',''));message.textContent='تعذّر تحميل أعداد المجلة. تحقق من الاتصال وأعد المحاولة.';retry.hidden=false;}
  }
  issueSelect.addEventListener('change',selectIssue);retry.addEventListener('click',loadCatalog);
  function suspend(){++generation;controller?.abort();clearReader();issues=[];updateBadge();issueSelect.replaceChildren();issueSelect.disabled=true;}
  document.addEventListener('visibilitychange',()=>{if(!document.hidden)maybeMarkRead();});window.addEventListener('pagehide',suspend);window.addEventListener('pageshow',e=>{if(e.persisted)loadCatalog();});
  fullButton.addEventListener('click', async () => {
    try { if (document.fullscreenElement === reader) await document.exitFullscreen(); else await reader.requestFullscreen(); }
    catch { message.hidden = false; message.textContent = 'تعذّر ملء الشاشة في هذا المتصفح. استخدم التكبير أو افتح ملف PDF.'; }
  });
  // Entering fullscreen focuses the pages so the arrow keys turn pages immediately.
  document.addEventListener('fullscreenchange', () => {
    const full = document.fullscreenElement === reader;
    fullButton.setAttribute('aria-label', full ? 'الخروج من ملء الشاشة' : 'ملء الشاشة');
    if (full) stage.focus({ preventScroll: true });
  });
  document.addEventListener('keydown', event => {
    if (document.fullscreenElement !== reader || event.defaultPrevented || stage.contains(event.target) || event.target.closest?.('input,select,textarea')) return;
    if (event.key === 'ArrowLeft' || event.key === 'ArrowRight') { event.preventDefault(); event.key === 'ArrowLeft' ? advance() : retreat(); }
  });
  mobile.addEventListener('change', () => { if (pages.length) { current = normalize(current); render(); } });
  loadCatalog();
})();
