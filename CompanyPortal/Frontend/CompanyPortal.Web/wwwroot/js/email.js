(() => {
  const card = document.querySelector('[data-work-system="email"]');
  const base = document.querySelector('meta[name="companyportal-api-base"]')?.content;
  if (!card || !base) return;
  const list = card.querySelector('.portal-email-list'), badge = card.querySelector('[data-count-source="exchange"]');
  const status = card.querySelector('[data-mail-status]'), open = card.querySelector('[data-mail-open]');
  const endpoint = path => new URL(path, new URL(base.replace(/\/?$/, '/'), location.href)).href;
  const make = (tag, text) => { const node = document.createElement(tag); if (text !== undefined) node.textContent = text; return node; };
  let connection, retry, delay = 5000, leaving = false, simulation = null, simulationSequence = 0;
  const simulationEnabled=!!document.getElementById?.('portal-simulation');
  const unavailable = message => {
    list.replaceChildren(); badge.textContent = '—'; badge.setAttribute('aria-label', 'عدد الرسائل غير المقروءة غير متاح');
    status.textContent = message; open.disabled = true;
  };
  const render = data => {
    if (!Number.isInteger(data.unreadCount) || data.unreadCount < 0 || !Array.isArray(data.items) || data.items.length > 20
      || data.items.some(item => typeof item.itemId !== 'string' || !item.itemId || item.itemId.length > 8000
        || typeof item.subject !== 'string' || typeof item.sender !== 'string' || typeof item.isRead !== 'boolean'
        || !Number.isFinite(Date.parse(item.receivedAt)))) throw new Error('Invalid mailbox snapshot');
    const focused = list.contains(document.activeElement) ? document.activeElement?.dataset.mailId : null;
    const fragment = document.createDocumentFragment();
    data.items.forEach(item => {
      const link = make('a'); link.className = 'portal-email-item'; link.dataset.state = item.isRead ? 'read' : 'unread'; link.dataset.mailId = item.itemId;
      if(simulation){
        link.href='#';
        for(const type of ['click','auxclick'])link.addEventListener(type,event=>{
          event.preventDefault();if(type==='auxclick'&&event.button!==1)return;
          if(!simulation?.connected)return;item.isRead=true;renderSimulation();
          document.dispatchEvent(new CustomEvent('portal:simulation-open',{detail:{title:item.subject||'[محاكاة] رسالة بدون موضوع',text:'من: '+item.sender+'\n\n'+(item.body||'هذه معاينة بريد محلي. لم تُفتح رسالة حقيقية ولم تتغير حالة القراءة في Exchange.')}}));
        });
      }else{link.href = endpoint('api/mail/open?itemId=' + encodeURIComponent(item.itemId)); link.target = '_blank'; link.rel = 'noopener noreferrer';}
      link.setAttribute('aria-label', `${item.subject || '(بدون موضوع)'} — ${item.sender}${item.isRead ? '' : ' — غير مقروءة'} — فتح في Outlook Web`);
      const icon = make('span', '✉'); icon.className = 'portal-email-row-icon'; icon.setAttribute('aria-hidden', 'true');
      const text = make('span'); text.append(make('strong', item.subject || '(بدون موضوع)'), make('small', item.sender));
      const time = make('time'); time.dateTime = item.receivedAt;
      time.textContent = new Intl.DateTimeFormat('ar-OM-u-nu-latn', { hour:'2-digit', minute:'2-digit', timeZone:'Asia/Muscat' }).format(new Date(item.receivedAt));
      time.title = new Intl.DateTimeFormat('ar-OM', { dateStyle:'medium', timeStyle:'short', timeZone:'Asia/Muscat' }).format(new Date(item.receivedAt));
      link.append(icon, text, time); fragment.append(link);
    });
    list.replaceChildren(fragment); badge.textContent = String(data.unreadCount);
    badge.setAttribute('aria-label', `${data.unreadCount} رسائل غير مقروءة في صندوق الوارد`);
    status.textContent = simulation?'[محاكاة] '+(data.items.length?'البريد متصل · بيانات محلية':'صندوق الوارد فارغ.'):data.items.length ? 'البريد متصل · تحديث مباشر' : 'لا توجد رسائل في صندوق الوارد.';
    open.disabled = false;
    if (focused) [...list.children].find(node => node.dataset.mailId === focused)?.focus({ preventScroll:true });
    card.dispatchEvent(new CustomEvent('workspace:cards-changed', { bubbles:true }));
  };
  const reconnect = () => {
    if(simulation||leaving)return;
    connection?.close(); connection = null;
    unavailable('اتصال البريد غير متاح حاليًا. جارٍ إعادة الاتصال…');
    if (!leaving && !retry) { retry = setTimeout(() => { retry = null; connect(); }, delay); delay = Math.min(30000, delay * 2); }
  };
  function connect() {
    if (leaving || connection || simulation) return;
    const source=new EventSource(endpoint('api/mail/stream'), { withCredentials:true });connection=source;
    source.addEventListener('inbox', event => {
      if(simulation||connection!==source)return;
      try { render(JSON.parse(event.data)); delay = 5000; } catch { reconnect(); }
    });
    source.addEventListener('unavailable',()=>{if(connection===source)reconnect();});
    source.onerror = ()=>{if(connection===source)reconnect();};
  }
  function renderSimulation(){
    if(!simulation?.connected){unavailable('[محاكاة] اتصال البريد منقطع. اختر إعادة الاتصال من المحاكاة.');return;}
    render({unreadCount:simulation.items.filter(i=>!i.isRead).length,items:simulation.items.slice(0,20)});
  }
  function sample(subject,sender,isRead=false,minutes=0){return {itemId:'simulation-mail-'+(++simulationSequence),subject:'[محاكاة] '+subject,sender,isRead,receivedAt:new Date(Date.now()-minutes*60000).toISOString(),body:'يرجى الاطلاع على التفاصيل ومتابعة الموضوع مع الفريق. هذه رسالة محاكاة محلية جاهزة للاختبار فقط.'};}
  if(simulationEnabled)document.addEventListener('portal:outlook-simulate',event=>{
    const action=event.detail?.action;if(!['outlook-start','mail-new','mail-read','mail-delete','mail-empty','outlook-disconnect','outlook-reconnect','outlook-exit'].includes(action))return;
    connection?.close();connection=null;clearTimeout(retry);retry=null;delay=5000;
    if(action==='outlook-exit'){simulation=null;unavailable('جارٍ الاتصال بالبريد الحقيقي…');connect();return;}
    if(!simulation||action==='outlook-start')simulation={connected:true,items:[sample('دعوة لاجتماع فريق العمل','سالم العبري',false,5),sample('اعتماد طلب الإجازة','الموارد البشرية',false,25),sample('متابعة خطة تطوير الخدمات الإلكترونية','مريم الحارثية',true,70),sample('تقرير العمل الأسبوعي','خالد البلوشي',false,180),sample('','الدعم التقني',true,1440)]};
    if(action==='mail-new'){simulation.items.unshift(sample('رسالة جديدة — تحديث خطة العمل '+simulationSequence,'أحمد العامري'));simulation.items=simulation.items.slice(0,50);if(simulation.connected)window.showToast?.('[محاكاة] وصلت رسالة بريد جديدة.');}
    if(action==='mail-read'){const unread=simulation.items.find(i=>!i.isRead);if(unread)unread.isRead=true;}
    if(action==='mail-delete')simulation.items.shift();
    if(action==='mail-empty')simulation.items=[];
    if(action==='outlook-disconnect')simulation.connected=false;
    if(action==='outlook-reconnect')simulation.connected=true;
    renderSimulation();if(action.startsWith('mail-')||action==='outlook-start')card.scrollIntoView?.({behavior:'smooth',block:'nearest',inline:'nearest'});
  });
  open.addEventListener('click', () => {if(simulation){document.dispatchEvent(new CustomEvent('portal:simulation-open',{detail:{title:'[محاكاة] صندوق الوارد',text:'في التشغيل الحقيقي يفتح هذا الزر صندوق الوارد في Outlook Web الداخلي. عدد الرسائل في المحاكاة: '+simulation.items.length+'. لم يتم الاتصال بـ Outlook.'}}));return;}window.open(endpoint('api/mail/inbox/open'), '_blank', 'noopener,noreferrer');});
  window.addEventListener('pagehide', () => { leaving = true;simulation=null; clearTimeout(retry); retry = null; connection?.close(); connection = null; unavailable('اتصال البريد متوقف.'); });
  window.addEventListener('pageshow', event => { if (event.persisted) { leaving = false; connect(); } });
  unavailable('جارٍ الاتصال بالبريد…'); connect();
})();
