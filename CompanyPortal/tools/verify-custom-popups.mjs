import assert from 'node:assert/strict';
import vm from 'node:vm';
import {readFile} from 'node:fs/promises';
class E {
 children=[];attributes={};textContent='';disabled=false;
 append(...nodes){this.children.push(...nodes);}prepend(...nodes){this.children.unshift(...nodes);}
 replaceChildren(...nodes){this.children=nodes;}setAttribute(k,v){this.attributes[k]=v;}
 set innerHTML(value){throw Error('Popup content must remain plain text');}
}
const parent=new E(),body=new E(),events=new Map(),calls=[],timers=[];
const startAt=new Date(Date.now()-60000).toISOString(),endAt=new Date(Date.now()+3600000).toISOString();
let source=[{popupId:1,popupType:'Type <b>',details:'Text <script>',startAt,endAt}],status=200;
const doc={hidden:false,body,querySelector:()=>({content:'http://api.local/'}),getElementById:()=>parent,createElement:()=>new E(),addEventListener:(k,v)=>events.set(k,v)};
const fetch=async(url,options)=>{calls.push({url:String(url),...options});return {ok:status===200,status,json:async()=>structuredClone(source)};};
vm.runInNewContext(await readFile(new URL('../Frontend/CompanyPortal.Web/wwwroot/js/custom-popups.js',import.meta.url),'utf8'),{document:doc,location:{href:'http://portal.local/'},URL,Date,Math,Set,AbortSignal,fetch,setTimeout:(f,n)=>{timers.push({f,n});return timers.length;},clearTimeout(){}});
const tick=()=>new Promise(setImmediate);await tick();const stack=parent.children[0];assert.equal(body.children.length,0,'Use existing popup stack');assert.equal(stack.children.length,1);assert.equal(stack.children[0].children[1].textContent,'Type <b>');assert.equal(stack.children[0].children[3].textContent,'Text <script>');
await stack.children[0].children[0].onclick();assert.equal(stack.children.length,0);assert.match(calls.at(-1).url,/custom-popups\/1\/dismiss$/);assert.equal(calls.at(-1).headers['X-CompanyPortal-Request'],'popup-dismiss');
await events.get('visibilitychange')();await tick();assert.equal(stack.children.length,0,'A stale GET must not resurrect a dismissed popup');
source=[{popupId:2,popupType:'Later',details:'New popup',startAt,endAt}];await events.get('visibilitychange')();await tick();assert.equal(stack.children.length,1);
status=500;await stack.children[0].children[0].onclick();assert.equal(stack.children.length,1);assert.match(stack.children[0].children[4].textContent,/تعذر/);assert.equal(stack.children[0].children[0].disabled,false);
doc.hidden=true;const before=calls.length;await events.get('visibilitychange')();await tick();assert.equal(calls.length,before,'Hidden pages do not poll');
doc.hidden=false;status=403;await events.get('visibilitychange')();await tick();assert.equal(stack.children.length,0,'Revocation clears displayed popups');
console.log('PASS custom popups: plain text, existing stack, dismissal header/persistence/stale-response guard, new arrivals, close failure/retry, hidden-page pause and authorization clearing.');
