(() => {
  const trigger=document.getElementById('policies-sheet-trigger'),sheet=document.getElementById('policies-sheet');
  const base=document.querySelector('meta[name="companyportal-api-base"]')?.content;
  if(!trigger||!sheet||!base)return;
  const status=document.getElementById('fixed-orders-status'),retry=document.getElementById('fixed-orders-retry');
  const years=document.getElementById('fixed-orders-years'),timeline=document.getElementById('fixed-orders-timeline');
  const endpoint=new URL('api/fixed-orders',new URL(base.replace(/\/?$/,'/'),location.href));
  const make=(tag,cls,text)=>{const node=document.createElement(tag);if(cls)node.className=cls;if(text!==undefined)node.textContent=text;return node;};
  let controller=null,generation=0;
  // Split only exact markers in the template. Replacement values are inserted
  // as text once, never parsed as HTML, formatting instructions or more markers.
  function appendTemplate(paragraph,row){
    (row.contentText??'').split(/(ds\{0\}de|ss\{1\}se)/g).forEach(part=>{
      if(part==='ds{0}de')paragraph.append(make('span','portal-policy-previous',row.contentBefor??''));
      else if(part==='ss{1}se')paragraph.append(make('span','portal-policy-preferred',row.contentAfter??''));
      else paragraph.append(document.createTextNode(part));
    });
  }
  function clear(){years.replaceChildren();timeline.replaceChildren();years.hidden=true;timeline.hidden=true;}
  function valid(rows){
    const date=value=>value===null||(typeof value==='string'&&/^\d{4}-\d{2}-\d{2}$/.test(value));
    return Array.isArray(rows)&&new Set(rows.map(row=>row?.fixedOrderId)).size===rows.length&&rows.every(row=>
      row&&typeof row.fixedOrderId==='string'&&/^[1-9]\d{0,18}$/.test(row.fixedOrderId)
      &&date(row.timestamp)&&date(row.timestamp2)&&Number.isInteger(row.timestampType)
      &&['contentBefor','contentAfter','contentText'].every(key=>row[key]===null||typeof row[key]==='string')
      &&(row.timestamp===null?row.year===null:Number.isInteger(row.year)&&row.year===Number(row.timestamp.slice(0,4))));
  }
  function render(rows){
    clear();
    if(!rows.length){status.textContent='لا توجد توجيهات متاحة حاليًا.';return;}
    const seen=new Set();
    rows.forEach(row=>{
      const group=row.year===null?'undated':String(row.year),yearLabel=row.year===null?'غير محدد السنة':String(row.year);
      const first=!seen.has(group),li=make('li'),article=make('article','portal-policy-entry');
      article.id='fixed-order-'+row.fixedOrderId;
      if(first){
        li.id='policy-year-'+group;
        const link=make('a',null,yearLabel);link.href='#'+li.id;years.append(link);seen.add(group);
      }
      const year=make('span','portal-policy-year',first?yearLabel:'');year.setAttribute('aria-hidden','true');li.append(year);
      const header=make('header');header.append(make('span','portal-policy-kind','توجيه سامٍ'));
      if(row.timestamp){const date=make('time',null,row.timestamp.split('-').reverse().join('/'));date.dateTime=row.timestamp;header.append(date);}
      else header.append(make('span',null,'التاريخ غير محدد'));
      const heading=make('h3',null,row.contentAfter?.trim()?row.contentAfter:'توجيه سامٍ');heading.id='fixed-order-title-'+row.fixedOrderId;
      article.setAttribute('aria-labelledby',heading.id);
      const content=make('div','portal-policy-example'),paragraph=make('p');appendTemplate(paragraph,row);content.append(paragraph);
      article.append(header,heading,content);li.append(article);timeline.append(li);
    });
    status.hidden=true;years.hidden=false;timeline.hidden=false;
  }
  async function load(){
    controller?.abort();controller=new AbortController();const current=++generation;
    clear();status.hidden=false;status.textContent='جارٍ تحميل التوجيهات السامية…';retry.hidden=true;timeline.setAttribute('aria-busy','true');
    try{
      const response=await fetch(endpoint,{credentials:'include',cache:'no-store',signal:AbortSignal.any([controller.signal,AbortSignal.timeout(10000)])});
      if(current!==generation||!sheet.open)return;
      if(!response.ok)throw new Error(response.status===401?'تعذر التحقق من تسجيل الدخول. افتح البوابة بحساب Windows الخاص بك.'
        :response.status===403?'الحساب غير مسجل أو غير نشط في البوابة.':'تعذر تحميل التوجيهات السامية. تحقق من الاتصال ثم أعد المحاولة.');
      const rows=await response.json();
      if(current!==generation||!sheet.open)return;
      if(!valid(rows))throw new Error('تعذر قراءة بيانات التوجيهات السامية. أعد المحاولة.');
      render(rows);
    }catch(error){
      if(current!==generation||!sheet.open)return;
      clear();status.hidden=false;status.textContent=error.name==='Error'?error.message:'تعذر الاتصال بخدمة التوجيهات السامية. أعد المحاولة.';retry.hidden=false;
    }finally{if(current===generation)timeline.setAttribute('aria-busy','false');}
  }
  function open(){
    if(sheet.open)return;
    sheet.showModal();trigger.setAttribute('aria-expanded','true');load();
  }
  trigger.setAttribute('aria-expanded','false');
  trigger.addEventListener('click',event=>{event.preventDefault();if(typeof closeSearch==='function')closeSearch(false);open();});
  retry.addEventListener('click',load);
  sheet.querySelector('[data-policies-close]').addEventListener('click',()=>sheet.close());
  years.addEventListener('click',event=>{
    const link=event.target.closest('a');if(!link)return;
    const target=document.getElementById(link.hash.slice(1));if(!target)return;
    event.preventDefault();target.scrollIntoView({behavior:matchMedia('(prefers-reduced-motion: reduce)').matches?'instant':'smooth',block:'start'});
    const heading=target.querySelector('h3');heading.tabIndex=-1;heading.focus({preventScroll:true});
  });
  sheet.addEventListener('click',event=>{
    const r=sheet.getBoundingClientRect();
    if(event.target===sheet&&(event.clientX<r.left||event.clientX>r.right||event.clientY<r.top||event.clientY>r.bottom))sheet.close();
    if(event.target.closest('a[href="#library"]'))sheet.close();
  });
  sheet.addEventListener('close',()=>{generation++;controller?.abort();clear();trigger.setAttribute('aria-expanded','false');if(!document.querySelector('dialog[open]'))trigger.focus({preventScroll:true});});
  document.addEventListener('systems:reveal',event=>{if(event.detail?.target?.closest('#policies'))open();});
  window.addEventListener('pagehide',()=>{generation++;controller?.abort();});
})();
