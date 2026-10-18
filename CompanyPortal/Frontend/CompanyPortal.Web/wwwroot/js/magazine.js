(() => {
  const reader = document.getElementById('monthly-reader');
  if (!reader) return;
  const stage = reader.querySelector('.editorial-local-stage'), spread = reader.querySelector('.editorial-local-spread');
  const message = reader.querySelector('.editorial-local-message');
  const previous = reader.querySelector('[data-mag-prev]'), next = reader.querySelector('[data-mag-next]');
  const pageInput = reader.querySelector('[data-mag-page]');
  const thumbs = reader.querySelector('.editorial-local-thumbnails'), thumbButton = reader.querySelector('[data-mag-thumbnails]');
  const zoomButton = reader.querySelector('[data-mag-zoom]'), fullButton = reader.querySelector('[data-mag-fullscreen]');
  const zoomOut=reader.querySelector('[data-mag-zoom-out]'),issueSelect=reader.closest('.editorial-magazine').querySelector('[data-mag-issue]'),issueUpload=reader.querySelector('[data-mag-issue-upload]'),pdfLink=reader.querySelector('[data-mag-pdf]');
  // Retain a previously saved issue number when replacing the edit field.
  const currentOption = issueSelect?.querySelector('option[value="current"]');
  try {
    const savedNumber = localStorage.getItem('clerio-monthly-magazine-issue-number');
    if (currentOption && savedNumber !== null) currentOption.textContent = currentOption.textContent.replace('50/2026', savedNumber.trim() || '…');
  } catch {}
  const uploadedIssues=new Map();let activeIssue=null,pdfPage=1,pdfFrame;
  const currentPDF=pdfLink?.href;
  function renderPDF(){
    if(!activeIssue)return;
    if(!pdfFrame){pdfFrame=document.createElement('iframe');pdfFrame.className='editorial-local-pdf-frame';pdfFrame.title='قراءة العدد السابق';stage.append(pdfFrame);}
    pdfFrame.src=activeIssue.url+'#toolbar=0&navpanes=0&page='+pdfPage+'&zoom='+(reader.classList.contains('is-zoomed')?150:100);
    pageInput.value=String(pdfPage);previous.disabled=pdfPage===1;next.disabled=false;message.hidden=true;
  }
  const mobile = matchMedia('(max-width:760px)'), reduced = matchMedia('(prefers-reduced-motion:reduce)');
  let pages = [], current = 0, turning = false, turnTimer, touch;
  const manifestURL = new URL(reader.dataset.pages, document.baseURI);
  const number = value => value.toLocaleString('ar-EG-u-nu-latn');
  const normalize = index => mobile.matches || index === 0 ? index : (index % 2 ? index : index - 1);
  const indexes = () => mobile.matches || current === 0 || current === pages.length - 1 ? [current] : [current, current + 1];
  function imageFor(index, thumbnail = false) {
    const image = document.createElement('img');
    image.src = new URL(pages[index].file, manifestURL).href;
    image.alt = `صفحة ${number(index + 1)} من مجلة الفلق`;
    image.width = 1500; image.height = Math.round(1500 * pages[index].height / pages[index].width);
    image.loading = thumbnail ? 'lazy' : 'eager'; image.decoding = 'async'; image.draggable = false;
    if (!thumbnail) image.addEventListener('error', () => { message.hidden = false; message.textContent = 'تعذّر تحميل الصفحة. يمكنك فتح ملف PDF من المتحكم أسفل المجلة.'; });
    return image;
  }
  function render() {
    if(activeIssue){renderPDF();return;}
    const visible = indexes();
    reader.style.setProperty('--magazine-page-ratio', pages[current].width / pages[current].height);
    spread.replaceChildren(...visible.map(index => {
      const page = document.createElement('div'); page.className = 'editorial-local-page'; page.append(imageFor(index)); return page;
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
    const clone = animate && !mobile.matches && !reduced.matches && !reader.classList.contains('is-zoomed') ? spread.lastElementChild?.cloneNode(true) : null;
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
      button.append(imageFor(index, true), document.createTextNode(number(index + 1)));
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
  function selectIssue(){
    activeIssue=uploadedIssues.get(issueSelect.value)||null;reader.classList.toggle('is-pdf',!!activeIssue);pdfPage=1;
    pdfFrame?.remove();pdfFrame=null;setZoom(false);thumbs.hidden=true;thumbButton.setAttribute('aria-expanded','false');thumbButton.disabled=!!activeIssue;
    pageInput.disabled=!activeIssue&&!pages.length;
    if(activeIssue)pageInput.removeAttribute('max');else pageInput.max=String(pages.length);
    pdfLink.href=activeIssue?activeIssue.url:currentPDF;
    if(activeIssue)renderPDF();else{current=0;render();}
  }
  issueSelect?.addEventListener('change',selectIssue);
  issueUpload?.addEventListener('change',()=>{
    const file=issueUpload.files?.[0];if(!file)return;
    if(file.type!=='application/pdf'&&!/\.pdf$/i.test(file.name)){message.hidden=false;message.textContent='اختر ملف PDF لعدد سابق.';issueUpload.value='';return;}
    const id='uploaded-'+uploadedIssues.size,url=URL.createObjectURL(file),title=file.name.replace(/\.pdf$/i,'');
    uploadedIssues.set(id,{url,title});issueSelect.add(new Option('عدد سابق · '+title,id));issueSelect.value=id;selectIssue();issueUpload.value='';
  });
  window.addEventListener('pagehide',()=>{for(const issue of uploadedIssues.values())URL.revokeObjectURL(issue.url);});
  fullButton.addEventListener('click', async () => {
    try { if (document.fullscreenElement === reader) await document.exitFullscreen(); else await reader.requestFullscreen(); }
    catch { message.hidden = false; message.textContent = 'تعذّر ملء الشاشة في هذا المتصفح. استخدم التكبير أو افتح ملف PDF.'; }
  });
  document.addEventListener('fullscreenchange', () => fullButton.setAttribute('aria-label', document.fullscreenElement === reader ? 'الخروج من ملء الشاشة' : 'ملء الشاشة'));
  mobile.addEventListener('change', () => { if (pages.length) { current = normalize(current); render(); } });
  fetch(manifestURL).then(response => { if (!response.ok) throw new Error('Manifest'); return response.json(); }).then(data => {
    if (!data.pages?.length) throw new Error('Pages'); pages = data.pages;
    if(!activeIssue){pageInput.max=String(pages.length);pageInput.disabled=false;render();}
  }).catch(() => { message.textContent = 'تعذّر تحميل المجلة. يمكنك قراءة ملف PDF من المتحكم أسفل القارئ.'; });
})();
