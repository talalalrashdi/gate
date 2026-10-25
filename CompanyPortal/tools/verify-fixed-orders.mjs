// Executes the real dialog renderer against a minimal DOM; no dependencies.
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import vm from 'node:vm';
const shared=await readFile(new URL('../Frontend/CompanyPortal.Web/wwwroot/js/fixed-order-text.js',import.meta.url),'utf8');
const source=await readFile(new URL('../Frontend/CompanyPortal.Web/wwwroot/js/policies-dialog.js',import.meta.url),'utf8');
class Node {
  constructor(tag){this.tag=tag;this.children=[];this.hidden=false;this.listeners=new Map();this.attributes={};this._text='';}
  set textContent(value){this._text=String(value);this.children=[];}
  get textContent(){return this._text+this.children.map(child=>child.textContent).join('');}
  set innerHTML(value){throw new Error('HTML parsing is forbidden for database content.');}
  append(...children){this.children.push(...children);}
  replaceChildren(...children){this.children=children;this._text='';}
  setAttribute(name,value){this.attributes[name]=value;}
  addEventListener(type,handler){this.listeners.set(type,handler);}
  focus(){}
}
const descend=(node,predicate)=>[...(predicate(node)?[node]:[]),...node.children.flatMap(child=>descend(child,predicate))];
const settle=async()=>{for(let i=0;i<8;i++)await new Promise(resolve=>setImmediate(resolve));};
async function fixture(rows,{fail=false,held=false}={}){
  const ids=new Map(['policies-sheet-trigger','policies-sheet','fixed-orders-status','fixed-orders-retry','fixed-orders-years','fixed-orders-timeline'].map(id=>[id,new Node('div')]));
  const sheet=ids.get('policies-sheet'),trigger=ids.get('policies-sheet-trigger'),close=new Node('button');
  sheet.querySelector=()=>close;sheet.showModal=()=>{sheet.open=true;};sheet.close=()=>{sheet.open=false;sheet.listeners.get('close')();};
  let calls=0,release;const gate=held?new Promise(resolve=>{release=resolve;}):Promise.resolve();
  vm.runInNewContext(shared+'\n'+source,{
    URL,AbortController,AbortSignal,Set,window:{addEventListener(){}},location:{href:'http://portal.test/portal/'},
    document:{getElementById:id=>ids.get(id),querySelector:selector=>selector.startsWith('meta')?{content:'http://api.test/backend/'}:null,
      createElement:tag=>new Node(tag),createTextNode:text=>{const node=new Node('#text');node.textContent=text;return node;},addEventListener(){}},
    fetch:async(url,options)=>{calls++;assert.equal(url.pathname,'/backend/api/fixed-orders');assert.equal(options.credentials,'include');assert.equal(options.cache,'no-store');assert.equal(options.body,undefined);assert.equal(options.method,undefined);await gate;return{ok:!fail,status:fail?403:200,json:async()=>rows};}
  });
  const open=()=>trigger.listeners.get('click')({preventDefault(){}});
  open();await settle();
  return{ids,sheet,open,release,get calls(){return calls;},timeline:ids.get('fixed-orders-timeline'),years:ids.get('fixed-orders-years'),status:ids.get('fixed-orders-status'),retry:ids.get('fixed-orders-retry')};
}
const row=(id,extra={})=>({fixedOrderId:id,timestamp:'2026-10-20',timestamp2:'2030-01-01',year:2026,timestampType:98765,contentBefor:'قديم',contentAfter:'جديد',contentText:'بتغيير ds{0}de إلى ss{1}se',...extra});
const full=await fixture([
 row('9007199254740992',{contentBefor:'<b>قديم</b> ss{1}se',contentText:'ds{0}de إلى ss{1}se ثم ds{0}de'}),
 row('9007199254740993',{contentText:'اعتماد ds{0}de فقط.'}),
 row('3',{timestamp:'2025-01-02',year:2025,contentAfter:null,contentBefor:null,contentText:'ds{0}de / ss{1}se'}),
 row('4',{timestamp:null,year:null,timestamp2:'2001-01-01',contentAfter:null,contentText:null})
]);
assert.equal(full.timeline.children.length,4);
assert.deepEqual(full.years.children.map(node=>node.textContent),['2026','2025','غير محدد السنة']);
const articles=descend(full.timeline,node=>node.tag==='article');
assert.equal(articles[0].id,'fixed-order-9007199254740992');assert.equal(articles[1].id,'fixed-order-9007199254740993');
assert.equal(descend(articles[0],node=>node.className==='portal-policy-previous').length,2);
assert.equal(descend(articles[0],node=>node.className==='portal-policy-preferred').length,1);
assert.equal(descend(articles[0],node=>node.tag==='p')[0].textContent,'<b>قديم</b> ss{1}se إلى جديد ثم <b>قديم</b> ss{1}se');
assert.equal(descend(articles[1],node=>node.className==='portal-policy-preferred').length,0,'Only-before templates must not invent an after value');
assert.equal(descend(articles[1],node=>node.tag==='h3')[0].textContent,'جديد');
assert.equal(descend(articles[2],node=>node.tag==='h3')[0].textContent,'توجيه سامٍ');
assert.equal(descend(articles[2],node=>node.tag==='p')[0].textContent,' / ');
assert.equal(descend(articles[3],node=>node.tag==='p')[0].textContent,'');
assert.equal(articles[3].textContent.includes('2001'),false,'Timestamp2 is not a fallback display date');
assert.equal(full.timeline.textContent.includes('98765'),false,'Unknown TimestampType must not be interpreted/displayed');
full.sheet.close();assert.equal(full.timeline.children.length,0);full.open();await settle();assert.equal(full.calls,2,'Every reopening must re-read');
const empty=await fixture([]);assert.equal(empty.timeline.hidden,true);assert.match(empty.status.textContent,/لا توجد/);assert.equal(empty.retry.hidden,true);
const denied=await fixture([row('1')],{fail:true});assert.equal(denied.timeline.children.length,0);assert.equal(denied.retry.hidden,false);assert.match(denied.status.textContent,/غير مسجل/);
const invalid=await fixture([row('1',{fixedOrderId:1})]);assert.equal(invalid.retry.hidden,false,'Numeric bigint IDs must not lose precision');
const mismatch=await fixture([row('1',{year:2027})]);assert.equal(mismatch.retry.hidden,false);
const delayed=await fixture([row('1')],{held:true});delayed.sheet.close();delayed.release();await settle();assert.equal(delayed.timeline.children.length,0,'Closed dialogs must ignore late responses');
console.log('Fixed-order renderer passed: exact/repeated/only-before markers, literal HTML, nonrecursive values, nulls, bigint strings, year groups, read-only requests, reload/close/error/late-response behavior.');
