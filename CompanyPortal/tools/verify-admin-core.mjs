// Shared admin behavior tests. No browser, database or network; uses an isolated DOM adapter.
import {readFile} from 'node:fs/promises';
import vm from 'node:vm';
import assert from 'node:assert/strict';
class Element {
 constructor(tag='div'){this.tagName=tag;this.children=[];this.dataset={};this.attributes={};this.hidden=false;this.disabled=false;this.isConnected=true;this.open=false;this.controls=[];this.textContent='';this.className='';this.parent=null;this.classList={toggle:(name,on)=>{const set=new Set(this.className.split(' ').filter(Boolean));on?set.add(name):set.delete(name);this.className=[...set].join(' ');}};}
 setAttribute(k,v){this.attributes[k]=v;} removeAttribute(k){delete this.attributes[k];}
 append(...items){for(const x of items){x.parent=this;this.children.push(x);}} prepend(x){x.parent=this;this.children.unshift(x);}
 remove(){if(this.parent)this.parent.children=this.parent.children.filter(x=>x!==this);this.isConnected=false;}
 querySelector(selector){if(selector===':scope > .admin-unsaved-badge')return this.children.find(c=>c.className==='admin-unsaved-badge');if(selector==='p')return this.p;if(selector==='h2')return this.heading;if(selector==='[data-confirm-yes]')return this.yes;if(selector==='[data-confirm-no]')return this.no;return null;}
 querySelectorAll(){return this.controls;} contains(e){return this===e||this.children.some(c=>c.contains(e));} focus(){document.activeElement=this;} close(){this.open=false;} showModal(){this.open=true;}
}
const dialog=new Element('dialog');dialog.heading=new Element('h2');dialog.p=new Element('p');dialog.yes=new Element('button');dialog.no=new Element('button');
const toasts=new Element(),workspace=new Element(),message=new Element();message.p=new Element('p');
const ids={'admin-confirm':dialog,'admin-toasts':toasts,'admin-workspace':workspace,'admin-access-message':message,'admin-status':new Element(),'admin-retry':new Element()};
const buttons=['overview','cards','media','themes'].flatMap(key=>[false,true].map(feature=>{const e=new Element('button');e.dataset.adminSection=key;e.feature=feature;return e;}));
const handlers=new Map(),windowHandlers=new Map(),timers=[];
const document={body:{dataset:{}},activeElement:new Element('button'),createElement:tag=>new Element(tag),getElementById:id=>ids[id],querySelector:()=>({content:'http://localhost:5091/'}),querySelectorAll:selector=>selector==='[data-admin-requires]'?[]:selector.startsWith('.admin-nav')?buttons.filter(b=>!b.feature):buttons,addEventListener:(name,cb)=>{if(!handlers.has(name))handlers.set(name,[]);handlers.get(name).push(cb);},dispatchEvent:event=>{for(const cb of handlers.get(event.type)||[])cb(event);}};
const window={addEventListener:(name,cb)=>windowHandlers.set(name,cb)};
let access={isAdmin:true,isSuperAdmin:false,sections:['media']},nextResponse,networkFailure;
const calls=[];
const fetch=async(url,options)=>{calls.push({url:url.href,options});if(url.pathname==='/api/access')return new Response(JSON.stringify(access),{status:200});if(networkFailure)throw networkFailure;return nextResponse||new Response(null,{status:204});};
vm.runInNewContext(await readFile(new URL('../Frontend/CompanyPortal.Web/wwwroot/js/admin-core.js',import.meta.url),'utf8'),{document,window,location:{href:'http://localhost:5082/admin',assign(){}},URL,Date,Map,Set,Promise,Response,AbortSignal,FormData,fetch,CustomEvent,MutationObserver:class{observe(){}},queueMicrotask,setTimeout:(cb,ms)=>{timers.push({cb,ms});return timers.length;}});
const core=window.AdminCore;await core.loadAccess();
assert(core.can('media'));assert(!core.can('cards'));assert(core.can('overview'));assert(!workspace.hidden);
assert(buttons.filter(b=>!['overview','media'].includes(b.dataset.adminSection)).every(b=>b.hidden&&b.disabled));
access={isAdmin:true,isSuperAdmin:true,sections:['cards','media','themes']};await core.loadAccess();assert(buttons.every(b=>!b.hidden&&!b.disabled));
await core.request('api/admin/media',{method:'PUT',body:{name:'فحص'},header:'media'});
let c=calls.at(-1);assert.equal(c.options.credentials,'include');assert.equal(c.options.cache,'no-store');assert.equal(c.options.headers['X-CompanyPortal-Request'],'media');assert.equal(c.options.headers['Content-Type'],'application/json');assert.equal(JSON.parse(c.options.body).name,'فحص');assert(c.options.signal);
const upload=new FormData();upload.append('file',new Blob(['svg']),'sample.svg');await core.request('api/admin/images',{method:'POST',body:upload,header:'admin-images',timeout:60000});c=calls.at(-1);assert.equal(c.options.body,upload);assert(!c.options.headers['Content-Type']);
await assert.rejects(()=>core.request('https://elsewhere.test/api/admin/media'),/غير صالح/);await assert.rejects(()=>core.request('api/admin/media',{method:'DELETE'}),/مطلوبة/);
const previous=new Element('input');document.activeElement=previous;
let answer=core.confirm('هل تريد حذف الصورة؟',{title:'حذف الصورة',accept:'حذف',danger:true});assert(dialog.open);assert.equal(dialog.yes.textContent,'حذف');assert(dialog.yes.className.includes('is-danger'));assert.equal(document.activeElement,dialog.no);dialog.no.onclick();assert.equal(await answer,false);assert.equal(document.activeElement,previous);
answer=core.confirm('متابعة؟');let canceled=false;dialog.oncancel({preventDefault(){canceled=true;}});assert(canceled);assert.equal(await answer,false);
answer=core.confirm('متابعة؟');assert.equal(await core.confirm('مكرر؟'),false);dialog.yes.onclick();assert.equal(await answer,true);
const form=new Element('form'),input={type:'text',value:'قبل'};form.controls=[input];const tracker=core.trackForm('media',form);await Promise.resolve();assert(!tracker.dirty());input.value='بعد';core.refresh();assert(tracker.dirty());assert.equal(form.dataset.adminDirty,'true');assert(form.querySelector(':scope > .admin-unsaved-badge'));assert(buttons.filter(b=>b.dataset.adminSection==='media'&&!b.feature).every(b=>b.dataset.unsaved==='true'));
let prevented=false;windowHandlers.get('beforeunload')({preventDefault(){prevented=true;},returnValue:null});assert(prevented);
answer=core.mayLeave('media');assert(dialog.open);dialog.no.onclick();assert.equal(await answer,false);assert(tracker.dirty());tracker.saved();assert(!tracker.dirty());assert.equal(form.dataset.adminDirty,'false');
const second=new Element('form');second.controls=[{type:'text',value:'آخر'}];const another=core.trackForm('media',second);await Promise.resolve();second.controls[0].value='مسودة مستقلة';tracker.saved();assert(another.dirty()); // saving one form never commits another
const status=new Element();core.feedback(status,'تم الحفظ.');let success=toasts.children.find(e=>e.className.includes('is-success'));assert(success);assert.equal(status.textContent,'');timers.find(t=>t.ms===4500).cb();assert(!success.isConnected);
core.feedback(status,'أدخل الاسم والرقم.',true);let error=toasts.children.find(e=>e.className.includes('is-error'));assert(error);for(const timer of timers)timer.cb();assert(error.isConnected);error.children.at(-1).onclick();assert(!error.isConnected);
nextResponse=new Response(null,{status:401});await core.request('api/admin/media');assert(workspace.hidden);assert(buttons.every(b=>b.hidden));assert(toasts.children.some(e=>e.children[0]?.textContent.includes('انتهت صلاحية الجلسة')));
access={isAdmin:true,isSuperAdmin:false,sections:['media']};await core.loadAccess();nextResponse=new Response(null,{status:403});await core.request('api/admin/themes');await core.loadAccess();assert(toasts.children.some(e=>e.children[0]?.textContent.includes('لا تملك صلاحية هذا القسم')));assert(!core.can('themes'));
const successesBefore=toasts.children.filter(e=>e.className.includes('is-success')).length;core.feedback(status,'تم رفع 0 صورة. تعذر الاتصال.',true);assert.equal(toasts.children.filter(e=>e.className.includes('is-success')).length,successesBefore);assert(status.textContent);
networkFailure=Object.assign(new Error(),{name:'TimeoutError'});await assert.rejects(()=>core.request('api/admin/media'));assert(toasts.children.some(e=>e.children[0]?.textContent.includes('انتهت مهلة الاتصال')));
console.log('PASS: restricted/super-admin visibility; transport/header/JSON/upload; unsafe destination rejection; modal cancel/Escape/reentry/focus; independent draft baselines; native unload guard; persistent errors/timed success;401/403/timeout messages. No external writes.');
