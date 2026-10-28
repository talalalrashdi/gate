import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import vm from 'node:vm';
const markup=await readFile(new URL('../Frontend/CompanyPortal.Web/Views/Home/_Simulation.cshtml',import.meta.url),'utf8');
assert.ok(!/<(?:input|select|textarea)\b/.test(markup),'Simulation must require no entry');
class Element{
 listeners={};attributes={};style={setProperty(){}};open=false;value='';
 setAttribute(k,v){this.attributes[k]=v;}addEventListener(k,fn){this.listeners[k]=fn;}
 getBoundingClientRect(){return {left:80,bottom:50};}contains(){return true;}focus(){}matches(){return false;}showPopover(){}hidePopover(){}
}
const panel=new Element(),status=new Element(),dialog=new Element(),close=new Element(),title=new Element(),body=new Element(),summary=new Element();
const buttons=[...markup.matchAll(/<button\b([^>]*)>([\s\S]*?)<\/button>/g)].map(m=>{const b=new Element();b.textContent=m[2];b.dataset={};for(const a of m[1].matchAll(/data-([\w-]+)="([^"]*)"/g))b.dataset[a[1].replace(/-([a-z])/g,(_,c)=>c.toUpperCase())]=a[2];b.markup=m[1];b.closest=s=>s.split(',').some(part=>{const a=part.match(/\[data-([\w-]+)(?:="([^"]*)")?\]/);return a&&b.markup.includes('data-'+a[1]+(a[2]!==undefined?'="'+a[2]+'"':''));})?b:null;return b;});
const rulesButton=buttons.find(b=>b.markup.includes('data-simulation-rules'));
const root=new Element();root.querySelector=s=>{if(s==='section')return panel;if(s==='summary')return summary;if(s==='[data-simulation-status]')return status;if(s==='[data-simulation-rules]')return rulesButton;throw Error('Unexpected selector, removed inputs must not be queried: '+s);};root.querySelectorAll=s=>buttons.filter(b=>b.closest(s));
dialog.querySelector=s=>({'h2':title,'p':body,'[data-simulation-dialog-close]':close})[s];
const emitted=[],documentEvents={};let requests=0;
const context=vm.createContext({document:{getElementById:id=>id==='portal-simulation'?root:dialog,querySelector:()=>({content:'https://api.test/'}),addEventListener:(k,fn)=>documentEvents[k]=fn,dispatchEvent:e=>emitted.push(e)},window:{addEventListener(){}},innerWidth:1200,location:{href:'https://portal.test/'},URL,AbortSignal,Date,CustomEvent:class{constructor(type,o){this.type=type;this.detail=o.detail;}},fetch:async(url,options)=>{requests++;assert.equal(options.credentials,'include');assert.ok(!options.method||options.method==='GET');return {ok:true,json:async()=>[{channelId:1,decisionTypes:['تعميم'],active:true,durationDays:7},{channelId:2,decisionTypes:['إعلان'],active:true,durationDays:4}]};}});
vm.runInContext(await readFile(new URL('../Frontend/CompanyPortal.Web/wwwroot/js/portal-simulation.js',import.meta.url),'utf8'),context);
const click=(attr,value)=>root.listeners.click({target:buttons.find(b=>b.dataset[attr]===value)});
root.open=true;root.listeners.toggle();await new Promise(setImmediate);
assert.equal(requests,1);root.listeners.toggle();assert.equal(requests,1,'Reopening must reuse rules');
click('simulate','decision');assert.equal(emitted.at(-1).detail.decisionType,'تعميم');assert.deepEqual(Array.from(emitted.at(-1).detail.notices,n=>n.channelId),[1]);
click('simulate','alert');assert.equal(emitted.at(-1).detail.decisionType,'إعلان');assert.deepEqual(Array.from(emitted.at(-1).detail.notices,n=>n.channelId),[2]);
click('simulate','notice');assert.equal(emitted.at(-1).detail.decisionType,'تعميم');
click('simulate','correspondence');assert.equal(emitted.at(-1).detail.correspondencePurpose,'للعلم');const first=emitted.at(-1).detail.title;
click('simulate','news');click('simulate','correspondence');assert.equal(emitted.at(-1).detail.correspondencePurpose,'للإجراء');assert.notEqual(emitted.at(-1).detail.title,first);assert.ok(emitted.at(-1).detail.correspondenceSender);
click('simulate','phone');assert.equal(emitted.at(-1).detail.length,6);
click('simulate','reset');assert.ok(emitted.some(e=>e.type==='portal:outlook-simulate'&&e.detail.action==='outlook-exit'));click('simulate','correspondence');assert.equal(emitted.at(-1).detail.correspondencePurpose,'للعلم');
for(const b of buttons.filter(b=>b.dataset.outlookSimulate)){root.listeners.click({target:b});assert.equal(emitted.at(-1).detail.action,b.dataset.outlookSimulate);}
assert.equal(requests,1,'Button tests must not write or fetch new business data');
console.log('PASS: no fields, ready titles/senders, alternating correspondence, admin-controlled decision channels, existing phone/Outlook/reset events and one read-only rules request.');
