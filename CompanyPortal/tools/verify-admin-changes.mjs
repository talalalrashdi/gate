import vm from 'node:vm';
import fs from 'node:fs';
import assert from 'node:assert/strict';
const source=fs.readFileSync(new URL('../Frontend/CompanyPortal.Web/wwwroot/js/admin-changes.js',import.meta.url),'utf8');
const listeners=new Map(),elements=[],calls=[],timers=new Map(),allowed=new Set(['applications','media']);let nextTimer=0,version=0;
class Element {
 constructor(){this.dataset={};this.children=[];this.textContent='';this.className='';}
 querySelector(){return this.children.find(e=>e.className==='admin-last-change');}
 append(e){this.children.push(e);e.parent=this;}
 remove(){this.parent.children=this.parent.children.filter(e=>e!==this);}
}
const document={body:{dataset:{adminCurrent:'applications'}},createElement:()=>new Element(),
 addEventListener:(name,fn)=>{if(!listeners.has(name))listeners.set(name,[]);listeners.get(name).push(fn);},
 querySelectorAll:selector=>{
  const section=selector.match(/data-admin-item-section="([^"]+)"/)?.[1];
  const matches=elements.filter(e=>e.dataset.adminItemSection&&(!section||e.dataset.adminItemSection===section));
  return selector.includes(' > ')?matches.flatMap(e=>e.children):matches;
 }};
const core={can:section=>allowed.has(section)||section==='overview',request:async path=>{calls.push(path);return {ok:true,json:async()=>[
 {itemType:'category',itemId:'1',displayName:'Category author '+version,changedAt:'2026-10-27T12:00:00'},
 {itemType:'application',itemId:'1',displayName:'App author '+version,changedAt:'2026-10-27T12:01:00'}]};}};
const context={window:{AdminCore:core},document,Intl,Date,Map,JSON,String,queueMicrotask,
 setTimeout:fn=>{timers.set(++nextTimer,fn);return nextTimer;},clearTimeout:id=>timers.delete(id)};
vm.runInNewContext(source,context);const changes=context.window.AdminChanges;
const flush=()=>new Promise(resolve=>setImmediate(resolve));
const event=async(name,detail)=>{for(const fn of listeners.get(name)||[])fn({detail});await flush();};
function tag(type,id,section='applications'){const e=new Element();elements.push(e);changes.tag(e,section,type,id);return e;}
const category=tag('category',1),app=tag('application',1),seed=tag('category',2),fresh=tag('category',null);await flush();
assert.equal(calls.length,1,'Initial/current section must load once');
assert.match(category.children[0].textContent,/Category author 0/);assert.match(app.children[0].textContent,/App author 0/);
assert.equal(seed.children[0].textContent,'لا يوجد تعديل مسجل');assert.equal(fresh.children.length,0);
await event('admin:section',{section:'applications'});assert.equal(calls.length,1,'Revisit must use the batch cache');
await event('admin:section',{section:'overview'});assert.equal(calls.length,1,'Overview must not call item history');
version=1;await event('admin:saved',{header:'application-directory',path:'/api/admin/application-directory/categories/1'});
await event('admin:saved',{header:'application-directory',path:'/api/admin/application-directory/applications/1'});
assert.equal(timers.size,1,'Burst of writes must coalesce');for(const fn of timers.values())fn();timers.clear();await flush();
assert.equal(calls.length,2);assert.match(app.children[0].textContent,/App author 1/);
allowed.delete('applications');await event('admin:access',{});assert.equal(app.children.length,0);
await event('admin:section',{section:'applications'});assert.equal(calls.length,2,'Denied section must not fetch');
console.log('PASS: initial section, one batch/cache, composite item keys, seed/new labels, coalesced save refresh, overview exclusion and revoked access.');
