import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import vm from 'node:vm';
const source=await readFile(new URL('../Frontend/CompanyPortal.Web/wwwroot/js/authorized-search.js',import.meta.url),'utf8');
class Node{
 constructor(tag){this.tag=tag;this.children=[];this.attributes={};this.listeners={};this.dataset={};this.value='';this.hidden=false;this._text='';this.clicks=0;}
 set textContent(value){this._text=String(value);this.children=[];}
 get textContent(){return this._text+this.children.map(child=>child.textContent).join('');}
 set innerHTML(value){throw Error('Database text must not be parsed as HTML.');}
 append(...nodes){this.children.push(...nodes);}
 replaceChildren(...nodes){this.children=nodes;this._text='';}
 setAttribute(key,value){this.attributes[key]=value;}
 removeAttribute(key){delete this.attributes[key];}
 addEventListener(type,handler){this.listeners[type]=handler;}
 querySelectorAll(tag){return this.children.filter(child=>child.tag===tag);}
 scrollIntoView(){}
 click(){this.clicks++;this.listeners.click?.();}
}
const settle=async()=>{for(let i=0;i<8;i++)await new Promise(resolve=>setImmediate(resolve));};
const doc=(suffix,extra={})=>({documentId:'d0250000-0000-0000-0000-'+suffix.padStart(12,'0'),documentName:'دليل أمن المعلومات',fileName:'دليل.pdf',folderName:'التقنية',folderPath:'التقنية',isPdf:true,...extra});
const app=(id,extra={})=>({appId:id,appName:'نظام الموارد البشرية',description:'خدمات الموظفين',categoryName:'خدمات إدارية',...extra});
async function fixture(data,{held=false}={}){
 const ids=new Map(['portal-search-panel','portal-search-input','portal-search-results','portal-search-status','authorized-search-filters','authorized-search-error','authorized-search-retry'].map(id=>[id,new Node('div')]));
 const filters=ids.get('authorized-search-filters');for(const scope of ['all','documents','apps']){const button=new Node('button');button.dataset.searchSource=scope;filters.append(button);}
 const document={baseURI:'https://portal.test/portal/',hidden:false,listeners:{},getElementById:id=>ids.get(id),querySelector:()=>({content:'/backend/'}),createElement:tag=>new Node(tag),addEventListener(type,handler){this.listeners[type]=handler;}};
 const window={listeners:{},addEventListener(type,handler){this.listeners[type]=handler;}};
 const requests=[],timers=new Map();let serial=0,release;const gate=held?new Promise(resolve=>{release=resolve;}):Promise.resolve();
 vm.runInNewContext(source,{window,document,URL,Set,AbortSignal,AbortController,location:{href:'https://portal.test/portal/'},setTimeout:callback=>{timers.set(++serial,callback);return serial;},clearTimeout:id=>timers.delete(id),fetch:async(url,options)=>{
  requests.push(url);assert.equal(options.credentials,'include');assert.equal(options.cache,'no-store');assert.equal(options.method,undefined);assert.equal(options.body,undefined);
  const key=url.endsWith('/api/documents')?'documents':'apps';assert.equal(url,'https://portal.test/backend/api/'+(key==='apps'?'applications':'documents'));
  await gate;const value=data[key];if(value instanceof Error)throw value;
  return{ok:true,json:async()=>value};
 }});
 const service=window.CompanyPortalAuthorizedSearch;
 assert.equal(requests.length,0,'Must not prefetch closed search');service.open();await settle();
 return{ids,window,document,service,requests,release,query(value){ids.get('portal-search-input').value=value;service.search();for(const [id,callback] of timers){timers.delete(id);callback();}},scope(value){filters.listeners.click({target:{closest:()=>filters.children.find(button=>button.dataset.searchSource===value)}});}};
}
const links=f=>f.ids.get('portal-search-results').children.flatMap(group=>group.children.filter(node=>node.tag==='a'));
const data={documents:[doc('1',{documentName:'دليل <b>أمن</b>'}),doc('2',{documentName:'طلب إجازة',fileName:'طلب.docx',isPdf:false})],apps:[app(3)]};
const f=await fixture(data);
assert.equal(f.requests.length,2);assert.equal(links(f).length,0,'Empty query shows instructions only');
f.query('دليل');assert.equal(links(f).length,1);assert.match(links(f)[0].textContent,/<b>أمن<\/b>/);assert.equal(links(f)[0].target,'_blank');
assert.equal(links(f)[0].children[0].src,'https://portal.test/portal/assets/icons/file-pdf.svg');assert.doesNotMatch(links(f)[0].textContent,/التقنية/,'Folder paths must not be displayed');
assert.equal(links(f)[0].href,'https://portal.test/backend/api/documents/d0250000-0000-0000-0000-000000000001/file');
f.query('اجازة');assert.equal(links(f).length,1);assert.equal(links(f)[0].target,undefined);assert.match(links(f)[0].textContent,/تنزيل الملف/);
assert.equal(links(f)[0].children[0].src,'https://portal.test/portal/assets/icons/file-docx.svg');
f.query('خدمات ادارية');assert.equal(links(f).length,1);assert.equal(links(f)[0].href,'https://portal.test/backend/api/applications/3/launch');assert.equal(links(f)[0].target,'_blank');
f.query('ا');assert.equal(links(f).length,3);assert.equal(f.ids.get('portal-search-results').children.length,2,'Results grouped by source');
f.scope('apps');assert.equal(links(f).length,1);f.scope('documents');assert.equal(links(f).length,2);
const event=key=>({key,preventDefault(){}});
f.service.key(event('ArrowUp'));assert.equal(f.ids.get('portal-search-input').attributes['aria-activedescendant'],links(f)[1].id);f.service.key(event('Enter'));assert.equal(links(f)[1].clicks,1);
f.service.close();assert.equal(links(f).length,0);assert.equal(f.ids.get('authorized-search-filters').hidden,true);
f.window.listeners.pageshow({persisted:true});await settle();assert.equal(f.requests.length,4,'Browser history restore must reread permissions');f.service.close();
data.documents=[doc('9')];data.apps=[];f.service.open();await settle();f.query('اجازة');assert.equal(links(f).length,0,'Closed catalog cannot reappear');
f.document.hidden=true;f.document.listeners.visibilitychange();assert.equal(links(f).length,0);data.apps=[app(5)];f.document.hidden=false;f.document.listeners.visibilitychange();await settle();f.scope('all');f.query('الموارد');assert.equal(links(f).length,1);
const partial=await fixture({documents:new Error('network'),apps:[app(1)]});partial.query('الموارد');assert.equal(links(partial).length,1);assert.equal(partial.ids.get('authorized-search-error').hidden,false);assert.match(partial.ids.get('portal-search-status').textContent,/المصادر المتاحة/);
const invalid=await fixture({documents:[doc('1',{documentId:'../secret'})],apps:[app(1,{appId:'javascript:1'})]});invalid.query('ا');assert.equal(links(invalid).length,0);assert.equal(invalid.ids.get('authorized-search-retry').hidden,false);
const delayed=await fixture({documents:[doc('1')],apps:[app(1)]},{held:true});delayed.service.close();delayed.release();await settle();assert.equal(links(delayed).length,0,'Late responses must not restore a closed catalog');
console.log('PASS: authorized-only sources, read-only/no-store requests, Arabic multi-term search, grouping/filters, PDF/download/app routes, text safety, keyboard, retry/partial failure, clear/reload and stale response rejection.');
