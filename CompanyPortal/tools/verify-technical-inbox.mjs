import assert from 'node:assert/strict';
import vm from 'node:vm';
import {readFile} from 'node:fs/promises';
class Element{children=[];dataset={};attributes={};listeners={};_text='';hidden=false;
set textContent(v){this._text=String(v);this.children=[];}get textContent(){return this._text+this.children.map(n=>n.textContent).join('');}
append(...n){this.children.push(...n);}prepend(...n){this.children.unshift(...n);}replaceChildren(...n){this._text='';this.children=n;}
setAttribute(k,v){this.attributes[k]=v;}removeAttribute(k){delete this.attributes[k];if(k==='href')delete this.href;}addEventListener(k,f){this.listeners[k]=f;}dispatchEvent(){}querySelectorAll(s){return s==='[data-inbox-id]'?this.children:[];}querySelector(){return null;}}
const source=await readFile(new URL('../Frontend/CompanyPortal.Web/wwwroot/js/technical-inbox.js',import.meta.url),'utf8');
for(const deferred of [false,true]){
 const list=new Element(),status=new Element(),badge=new Element(),total=new Element(),app=new Element(),card=new Element();card.querySelector=s=>({'#technical-inbox-list':list,'#technical-inbox-status':status,'[data-count-source]':badge,'[data-inbox-total]':total,'[data-inbox-app]':app})[s];
 const events={},win={},requests=[];let ready=!deferred,pending,code=200;
 const lazy={get ready(){return ready;},run(f){if(ready)f();else pending=f;},activate(){ready=true;pending?.();pending=null;}};
 let data={unreadCount:3,appUrl:'https://isnad.test/',items:Array.from({length:7},(_,i)=>({inboxId:String(i+1),requestType:'دعم تقني',documentNumber:i===0?'2026/1':null,officeNumber:i===1?'1312':null,details:i===0?'<b>طلب</b>':'طلب '+i,hasAttachment:i===0,isOpened:i>2,receivedAt:'2026-11-01T08:00:00Z'}))};
 const document={hidden:false,querySelector:s=>s.startsWith('meta')?{content:'http://api.test/'}:card,createElement:()=>new Element(),createTextNode:t=>Object.assign(new Element(),{textContent:t}),addEventListener:(k,f)=>events[k]=f};
 vm.runInNewContext(source,{document,window:{CompanyPortalLazy:{gate:()=>lazy},addEventListener:(k,f)=>win[k]=f},location:{href:'http://portal.test/'},URL,Intl,Date,AbortController,AbortSignal,CustomEvent:class{},setTimeout:()=>1,clearTimeout(){},fetch:async(url,opts)=>{requests.push({url:String(url),opts});return {ok:code===200,status:code,json:async()=>structuredClone(data)};}});
 const settle=()=>new Promise(setImmediate);await settle();assert.equal(badge.textContent,'3');if(deferred){assert.equal(list.children.length,0);assert.ok(requests[0].url.endsWith('/count'));lazy.activate();await settle();}
 assert.equal(list.children.length,7);assert.equal(total.textContent,'7');assert.equal(app.href,'https://isnad.test/');assert.equal(list.children[0].dataset.state,'unopened');assert.ok(list.children[0].textContent.includes('<b>طلب</b>'));assert.ok(list.children[0].textContent.includes('مرفق'));assert.ok(!list.children[2].textContent.includes('المستند:'));assert.ok(!list.children[2].textContent.includes('المكتب:'));
 data.items[0].isOpened=true;data.unreadCount=2;win.online();await settle();assert.equal(badge.textContent,'2');assert.equal(list.children[0].dataset.state,'opened');
 code=403;win.online();await settle();assert.equal(list.children.length,0);assert.equal(app.href,undefined);assert.equal(badge.textContent,'—');
 assert.ok(requests.every(r=>!r.opts.method),'Inbox must not write read state');win.pagehide();
}
console.log('PASS technical inbox: lazy counts/full rows, seven source records, optional fields/attachment, safe text, source-owned read count, 403 cleanup and no writes.');

assert.match(await readFile(new URL('../Frontend/CompanyPortal.Web/wwwroot/js/workspace-pagination.js',import.meta.url),'utf8'),/\['exchange','forms','correspondence','technical-inbox'\]/,'Shared pager must leave technical source count alone');
assert.match(await readFile(new URL('../Frontend/CompanyPortal.Web/Views/Home/_Workspace.cshtml',import.meta.url),'utf8'),/id="technical-inbox-list" data-widget-preview data-page-size="5"/,'Shared five-row paging contract');
