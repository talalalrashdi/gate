import assert from 'node:assert/strict';
import vm from 'node:vm';
import {readFile} from 'node:fs/promises';
for(const kind of ['forms','correspondence']){
 const isForms=kind==='forms',idKey=isForms?'formId':'correspondenceId',css=isForms?'portal-form-item':'portal-correspondence-item';
 class Element{
  children=[];dataset={};listeners={};attributes={};_text='';open=false;hidden=false;
  set textContent(v){this._text=String(v);this.children=[];}get textContent(){return this._text+this.children.map(n=>n.textContent).join('');}
  append(...nodes){this.children.push(...nodes);}prepend(...nodes){this.children.unshift(...nodes);}replaceChildren(...nodes){this._text='';this.children=[...nodes];}
  setAttribute(k,v){this.attributes[k]=v;}removeAttribute(k){delete this.attributes[k];}
  addEventListener(k,fn){this.listeners[k]=fn;}contains(n){return this.children.includes(n);}focus(){}
  querySelector(s){if(s.startsWith('.'))return this.children.find(n=>n.className?.split(' ').includes(s.slice(1)))||null;return null;}
  querySelectorAll(s){if(s==='time[datetime]')return this.children.flatMap(n=>n.children.filter(t=>t.dateTime));if(s.startsWith('[data-'))return this.children;return [];}
  showModal(){this.open=true;}close(){this.open=false;}
 }
 const list=new Element(),badge=new Element(),status=new Element(),dialog=new Element(),total=new Element(),app=new Element(),filter=new Element(),button=new Element(),h2=new Element(),meta=new Element(),heading=new Element(),p=new Element(),card=new Element();
 dialog.querySelector=s=>({'button':button,'h2':h2,'[data-forms-sample-sender]':meta,'[data-correspondence-sample-meta]':meta,'header strong':heading,'p:last-child':p})[s];
 const nodes={['#'+kind+'-inbox-list']:list,['#'+kind+'-inbox-status']:status,['#'+kind+'-sample-dialog']:dialog,['[data-count-source="'+kind+'"]']:badge,'[data-inbox-total]':total,'[data-inbox-app]':app,'#correspondence-purpose-filter':filter};card.querySelector=s=>nodes[s];
 let data={unreadCount:3,items:[{[idKey]:'1',title:'First',senderName:'Sender',purpose:'للعلم',docNo:'2026/1',sentAt:'2026-10-28T06:00:00Z',receivedAt:'2026-10-28T06:00:00Z',isOpened:false,isSamplePreview:true,canOpen:false},{[idKey]:'2',title:'Second',senderName:'Sender',purpose:'للإجراء',docNo:'2026/2',sentAt:'2026-10-28T06:00:00Z',receivedAt:'2026-10-28T06:00:00Z',isOpened:false,isSamplePreview:true,canOpen:false}]};
 const events={},windowEvents={},timers=new Map(),requests=[];let responseStatus=200,nextTimer=0;
 const document={hidden:false,activeElement:null,querySelector:s=>s.startsWith('[data-work-system=')?card:{content:'http://api.test/'},getElementById:()=>null,createElement:()=>new Element(),createTextNode:t=>Object.assign(new Element(),{textContent:t,nodeType:3}),addEventListener:(k,fn)=>events[k]=fn};
 const context=vm.createContext({document,window:{addEventListener:(k,fn)=>windowEvents[k]=fn},location:{href:'http://portal.test/'},URL,Intl,Date,Math,AbortController,AbortSignal,fetch:async(url,opts)=>{requests.push({url,opts});return {status:responseStatus,ok:responseStatus===200,json:async()=>structuredClone(data)};},setTimeout:(fn,ms)=>{const id=++nextTimer;timers.set(id,{fn,ms});return id;},clearTimeout:id=>timers.delete(id)});
 vm.runInContext(await readFile(new URL('../Frontend/CompanyPortal.Web/wwwroot/js/'+(isForms?'forms':'correspondence')+'-inbox.js',import.meta.url),'utf8'),context);await new Promise(setImmediate);
 assert.equal(badge.textContent,'3');assert.equal(list.children[0].dataset.state,'unopened');
 list.children[0].listeners.click();assert.equal(dialog.open,true);assert.equal(badge.textContent,'2');assert.equal(list.children[0].dataset.state,'opened');assert.equal(data.items[0].isOpened,false,'Sample source was mutated');
 dialog.close();list.children[0].listeners.click();assert.equal(badge.textContent,'2','Repeated preview double-decremented');dialog.close();
 const refresh=async()=>{await windowEvents.online();await new Promise(setImmediate);};
 await refresh();assert.equal(badge.textContent,'2');assert.equal(list.children[0].dataset.state,'opened','Source refresh undid preview state');
 data.items[0].isOpened=true;data.unreadCount=2;await refresh();assert.equal(badge.textContent,'2','Source acknowledgement deducted twice');
 data.items[1].canOpen=true;await refresh();assert.equal(list.children[1].listeners.click,undefined,'Real link must leave read tracking to source');
 responseStatus=403;await refresh();assert.equal(list.children.length,0);responseStatus=200;data.items[0].isOpened=false;data.unreadCount=3;await refresh();assert.equal(badge.textContent,'3','Authorization loss must clear local preview state');
 assert.ok(requests.every(r=>!r.opts.method||r.opts.method==='GET'),'Preview must never write to source');windowEvents.pagehide();
 console.log('PASS '+kind+': preview read appearance/count, duplicate click, refresh, source acknowledgement, real-link source authority, 403 reset and no writes.');
}
