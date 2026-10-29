import assert from 'node:assert/strict';
import vm from 'node:vm';
import {readFile} from 'node:fs/promises';
class Element {
 children=[];dataset={};listeners={};attributes={};_text='';
 set textContent(v){this._text=v;this.children=[];}get textContent(){return this._text+this.children.map(n=>n.textContent).join('');}
 append(...nodes){this.children.push(...nodes);for(const n of nodes)n.parentElement=this;}
 after(node){const p=this.parentElement;p.children.splice(p.children.indexOf(this)+1,0,node);node.parentElement=p;}
 remove(){const p=this.parentElement;p.children.splice(p.children.indexOf(this),1);}
 querySelector(){return this.children.find(n=>n.className==='portal-header-event-new');}
 querySelectorAll(){return this.children.filter(n=>n.dataset.headerEvent);}
 addEventListener(k,f){this.listeners[k]=f;}
 setAttribute(k,v){this.attributes[k]=v;}
}
for(const simulation of [false,true]){
 let now=Date.now();class FakeDate extends Date{static now(){return now;}}const timers=new Map();let serial=0;
 const parent=new Element(),marker=new Element();parent.append(marker);const events={};let calls=0,resolve;
 const rows=[{eventId:1,title:'فعالية المؤسسة',eventType:1,eventTarget:'https://events.test/one',startAt:new Date(now).toISOString()},{eventId:2,title:'Unsafe',appUrl:'javascript:bad()'}];
 const document={getElementById:id=>id==='portal-header-events'?marker:id==='portal-simulation'&&simulation?{}:null,querySelector:()=>({content:'http://api.test/'}),createElement:()=>new Element(),addEventListener:(k,f)=>events[k]=f};
 const context=vm.createContext({Date:FakeDate,window:{addEventListener(){}},setTimeout:(fn,ms)=>{const id=++serial;timers.set(id,{fn,ms});return id;},clearTimeout:id=>timers.delete(id),document,URL,location:{href:'http://portal.test/'},AbortSignal,fetch:async()=>{calls++;return new Promise(r=>resolve=()=>r({ok:true,json:async()=>rows}));}});
 vm.runInContext(await readFile(new URL('../Frontend/CompanyPortal.Web/wwwroot/js/header-events.js',import.meta.url),'utf8'),context);
 if(simulation){events['portal:simulate']({detail:{kind:'event',id:9,title:'محاكاة فعالية'}});assert.equal(parent.children.length,2);}
 resolve();await new Promise(setImmediate);
 assert.equal(parent.children[1].textContent,'فعالية المؤسسةجديد');assert.equal(parent.children[1].children[0].textContent,'جديد');assert.equal(parent.children[1].target,'_blank');assert.equal(parent.children[1].rel,'noopener noreferrer');
 assert.equal(parent.children.some(n=>n.textContent==='Unsafe'),false);
 if(simulation){assert.equal(parent.children.length,3);events['portal:simulate']({detail:{kind:'reset'}});assert.equal(parent.children.length,2);assert.equal(parent.children[1].textContent,'فعالية المؤسسةجديد');}else assert.equal(events['portal:simulate'],undefined);
 now+=60001;for(const {fn} of [...timers.values()])fn();assert.equal(parent.children[1].children[0].hidden,true,'Badge should expire');assert.equal(parent.children[1].href,'https://events.test/one','Expiry must retain link');
 assert.equal(calls,1,'Events must load once without polling or simulation requests');
 // Re-running the page after the original minute must not create another minute.
 vm.runInContext(await readFile(new URL('../Frontend/CompanyPortal.Web/wwwroot/js/header-events.js',import.meta.url),'utf8'),context);
 resolve();await new Promise(setImmediate);
 assert.equal(parent.children[1].children[0].hidden,true,'Reload must not renew an existing event badge');
 assert.equal(calls,2,'Each page load fetches once');
}
console.log('PASS: event links, safe new-tab URLs, single fetch/no polling, simulation and reset, load-race preservation, disabled simulation guard and no badge renewal after refresh.');
