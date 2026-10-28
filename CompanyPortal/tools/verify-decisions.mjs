import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import vm from 'node:vm';
const source=await readFile(new URL('../Frontend/CompanyPortal.Web/wwwroot/js/decisions.js',import.meta.url),'utf8');
class Node{
  constructor(tag){this.tag=tag;this.children=[];this.listeners={};this.attributes={};this.dataset={};this.value='';this.hidden=false;this._text='';}
  set textContent(value){this._text=String(value);this.children=[];}
  get textContent(){return this._text+this.children.map(child=>child.textContent).join('');}
  set innerHTML(value){throw Error('Database content must never be parsed as HTML.');}
  append(...nodes){this.children.push(...nodes);}
  replaceChildren(...nodes){this._text='';this.children=nodes;}
  setAttribute(key,value){this.attributes[key]=value;}
  addEventListener(type,callback){this.listeners[type]=callback;}
  querySelectorAll(tag){return this.children.filter(node=>node.tag===tag);}
  closest(){return this;}
  focus(){}
}
const settle=async()=>{for(let i=0;i<6;i++)await new Promise(resolve=>setImmediate(resolve));};
async function fixture(data){
 const ids=new Map(['decisions-list','decision-types','decisions-status','decision-search-clear','work-library-search'].map(id=>[id,new Node('div')]));
 const card={querySelector:selector=>ids.get(selector.slice(1))},document={hidden:false,listeners:{},getElementById(){return null;},dispatchEvent(){},querySelector:selector=>selector.startsWith('meta')?{content:'/backend/'}:card,createElement:tag=>new Node(tag),addEventListener(type,callback){this.listeners[type]=callback;}};
 const window={listeners:{},addEventListener(type,callback){this.listeners[type]=callback;}};
 let result=data,code=200,calls=0;const timers=new Map();let timerId=0;
 vm.runInNewContext(source,{document,window,URL,AbortController,AbortSignal,Intl,Date,Set,CustomEvent:class {constructor(type,options){this.type=type;this.detail=options?.detail;}},setTimeout(fn,delay){const id=++timerId;timers.set(id,{fn,delay});return id;},clearTimeout(id){timers.delete(id);},location:{href:'https://portal.test/portal/'},fetch:async(url,options)=>{
  calls++;assert.equal(url,'https://portal.test/backend/api/decisions');assert.equal(options.credentials,'include');assert.equal(options.cache,'no-store');assert.equal(options.method,undefined);assert.equal(options.body,undefined);
  return {ok:code===200,status:code,json:async()=>result};
 }});
 await settle();return {ids,document,window,search(){ids.get('work-library-search').listeners.input();for(const [id,timer] of timers){if(timer.delay===150){timers.delete(id);timer.fn();}}},async reload(){window.listeners.online();await settle();},setResponse(value,status=200){result=value;code=status;},get calls(){return calls;}};
}
const row=(id,title,type='قرارات إدارية')=>({decisionId:id,title,decisionType:type,publishedAt:'2026-10-21T09:00:00',hasRead:false,decisionNumber:'2026/66'});
const f=await fixture([row('9007199254740992','<b>قرار</b>'),row('9007199254740993','اعتماد التدريب','تعاميم')]);
const list=f.ids.get('decisions-list'),types=f.ids.get('decision-types'),status=f.ids.get('decisions-status'),search=f.ids.get('work-library-search');
assert.equal(list.children.length,2);assert.equal(types.children.length,3);assert.equal(status.hidden,true);
assert.equal(list.children[0].href,'https://portal.test/backend/api/decisions/9007199254740992/pdf');
assert.equal(list.children[0].target,'_blank');assert.equal(list.children[0].rel,'noopener noreferrer');
assert.match(list.children[0].textContent,/<b>قرار<\/b>/);assert.equal(list.children[1].dataset.decisionId,'9007199254740993');
assert.match(list.children[0].textContent,/\[2026\/66\]/);
search.value='اعتماد';f.search();assert.equal(list.children.length,1);
search.value='';f.search();
types.value='قرارات إدارية';types.listeners.change();assert.equal(list.children.length,1);assert.match(list.textContent,/<b>/);
search.value='غير موجود';f.search();assert.equal(list.children.length,0);assert.equal(status.hidden,false);
f.document.hidden=true;f.document.listeners.visibilitychange();assert.equal(list.children.length,0);assert.equal(types.children.length,0);
f.setResponse([row('2','تحديث الصلاحيات')]);f.document.hidden=false;f.document.listeners.visibilitychange();await settle();assert.equal(f.calls,2);
search.value='';f.search();assert.equal(list.children.length,1);assert.doesNotMatch(list.textContent,/<b>قرار/);
f.setResponse([],403);await f.reload();assert.equal(list.children.length,0);assert.equal(types.children.length,0);assert.equal(status.hidden,false);
f.setResponse([]);await f.reload();assert.equal(list.children.length,0);assert.match(status.textContent,/لا توجد قرارات متاحة/);
f.setResponse([row(123,'invalid numeric ID')]);await f.reload();assert.equal(list.children.length,0);assert.match(status.textContent,/تعذر قراءة/);
f.setResponse([row('2','restored')]);await f.reload();assert.equal(list.children.length,1);
f.window.listeners.pagehide();assert.equal(list.children.length,0);assert.equal(types.children.length,0);
console.log('PASS: permission-filtered read-only rendering, Arabic search/type filters, literal HTML, bigint IDs, PDF links, clear-on-hide/failure, empty/retry and invalid data.');
