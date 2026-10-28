import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import vm from 'node:vm';

const source=await readFile(new URL('../Frontend/CompanyPortal.Web/wwwroot/js/library.js',import.meta.url),'utf8');
class Element {
  constructor(tag='div'){this.tag=tag;this.children=[];this.listeners={};this.attributes={};this._text='';this.hidden=false;this.open=false;}
  set textContent(value){this._text=String(value);this.children=[];}
  get textContent(){return this._text+this.children.map(n=>n.textContent).join('');}
  set innerHTML(_){throw new Error('PDF titles must render as text.');}
  append(...nodes){this.children.push(...nodes);}
  replaceChildren(...nodes){this._text='';this.children=nodes;}
  setAttribute(key,value){this.attributes[key]=value;}
  addEventListener(name,fn){this.listeners[name]=fn;}
  querySelector(selector){return selector==='[aria-pressed="true"]'?this.children.find(n=>n.attributes['aria-pressed']==='true'):undefined;}
  focus(){this.focused=true;}
  showModal(){this.open=true;}
  close(){this.open=false;this.listeners.close?.();}
}
const ids=new Map(['documents-results','documents-status','documents-retry','documents-dialog','documents-dialog-body','documents-count','documents-current-title','documents-dialog-title','documents-dialog-category','documents-dialog-description','documents-close'].map(id=>[id,new Element()]));
const categories=new Element(),section=new Element();
section.querySelector=selector=>selector==='.documents-categories'?categories:ids.get(selector.slice(1));
const document={hidden:false,listeners:{},getElementById:id=>id==='digital-library'?section:undefined,querySelector:()=>({content:'/backend/'}),createElement:tag=>new Element(tag),addEventListener(name,fn){this.listeners[name]=fn;}};
const window={listeners:{},addEventListener(name,fn){this.listeners[name]=fn;}};
const doc=n=>({documentId:`d0250000-0000-0000-0000-${String(n).padStart(12,'0')}`,documentName:`وثيقة ${n} <b>نص</b>`});
let data=Array.from({length:50},(_,i)=>({documentTabId:i+1,tabName:`قسم ${i+1}`,documents:Array.from({length:i===0?500:3},(_,j)=>doc(i*500+j+1))}));
let status=200,calls=0;
vm.runInNewContext(source,{document,window,URL,AbortController,AbortSignal,location:{href:'https://portal.test/portal/'},fetch:async(url,options)=>{
  calls++;assert.equal(url,'https://portal.test/backend/api/document-library');assert.equal(options.credentials,'include');assert.equal(options.cache,'no-store');assert.equal(options.method,undefined);
  return {ok:status===200,status,json:async()=>data};
}});
const settle=async()=>{for(let i=0;i<8;i++)await new Promise(resolve=>setImmediate(resolve));};
await settle();
const rows=ids.get('documents-results'),dialog=ids.get('documents-dialog'),body=ids.get('documents-dialog-body');
assert.equal(categories.children.length,50);assert.equal(rows.children.length,500);assert.match(ids.get('documents-count').textContent,/500/);
for(let i=0;i<500;i++){
  rows.children[i].children[2].listeners.click();
  assert.equal(dialog.open,true);
  assert.equal(body.children[1].src,`https://portal.test/backend/api/document-library/${doc(i+1).documentId}/file`);
  assert.equal(body.children[1].title,doc(i+1).documentName);
  assert.equal(body.children[0].href,body.children[1].src);
  ids.get('documents-close').listeners.click();assert.equal(body.children.length,0);
}
for(let i=1;i<50;i++){
  categories.children[i].listeners.click();assert.equal(rows.children.length,3);assert.equal(ids.get('documents-current-title').textContent,`قسم ${i+1}`);
  assert.equal(categories.children[i].attributes['aria-pressed'],'true');
}
assert.equal(calls,1,'Switching tabs/opening PDF readers must not reload the catalog.');
document.hidden=true;document.listeners.visibilitychange();assert.equal(rows.children.length,0);assert.equal(categories.children.length,0);
data=[data[49]];document.hidden=false;document.listeners.visibilitychange();await settle();assert.equal(rows.children.length,3);assert.equal(categories.children.length,1);
status=403;await ids.get('documents-retry').listeners.click();assert.equal(rows.children.length,0);assert.equal(categories.children.length,0);assert.match(ids.get('documents-status').textContent,/غير مخوّل/);
status=200;data=[];await ids.get('documents-retry').listeners.click();assert.match(ids.get('documents-status').textContent,/لا توجد وثائق/);
data=[{documentTabId:99,tabName:'جديد',documents:[doc(1),doc(2)]}];await ids.get('documents-retry').listeners.click();assert.equal(rows.children.length,2);
window.listeners.pagehide();assert.equal(rows.children.length,0);assert.equal(dialog.open,false);
console.log('PASS: 50 dynamic tabs, 500 PDFs in one tab, every reader URL, literal titles, counts, selection/reload, no catalog refetch on tab switch, revocation/empty/retry and cleanup.');
