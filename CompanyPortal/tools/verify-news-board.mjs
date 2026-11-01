import assert from 'node:assert/strict';
import vm from 'node:vm';
import {readFile} from 'node:fs/promises';
const source=await readFile(new URL('../Frontend/CompanyPortal.Web/wwwroot/js/news-headlines.js',import.meta.url),'utf8');
class Node{
 children=[];dataset={};listeners={};hidden=false;classes=new Set();_text='';
 constructor(){this.classList={add:(...v)=>v.forEach(x=>this.classes.add(x)),remove:(...v)=>v.forEach(x=>this.classes.delete(x)),toggle:(v,on)=>on?this.classes.add(v):this.classes.delete(v)};}
 set className(v){this.classes=new Set(v.split(' '));}set textContent(v){this._text=String(v);this.children=[];}get textContent(){return this._text+this.children.map(n=>typeof n==='string'?n:n.textContent).join('');}
 get firstElementChild(){return this.children[0];}get lastElementChild(){return this.children.at(-1);}
 append(...v){v.forEach(n=>{if(typeof n!=='string')n.parentElement=this;});this.children.push(...v);}replaceChildren(...v){this._text='';this.children=[];this.append(...v);}before(n){this.status=n;}
 setAttribute(){}addEventListener(k,f){this.listeners[k]=f;}querySelectorAll(selector){return this.children.flatMap(n=>typeof n==='string'?[]:[...(selector==='button'&&n.tag==='button'||selector.startsWith('.')&&n.classes.has(selector.slice(1))?[n]:[]),...n.querySelectorAll(selector)]);}querySelector(s){return this.querySelectorAll(s)[0];}closest(){return this.panel;}scrollIntoView(){}
}
async function fixture(items){
 const more=new Node();more.hidden=true;const board=new Node(),headlines=new Node(),panel=new Node(),group=new Node(),prev=new Node(),next=new Node(),events={};prev.tag=next.tag='button';group.append(prev,next);headlines.panel=panel;panel.querySelector=s=>s.includes('controls')?group:s.includes('prev')?prev:next;
 const document={hidden:false,body:{dataset:{siteTheme:'official'}},querySelector:s=>s==='.theme-official-headlines'?headlines:s==='.theme-official-story-action'?more:{content:'http://api.test/'},getElementById:id=>id==='editorial-agency-news'?board:id==='portal-simulation'?new Node():null,createElement:tag=>Object.assign(new Node(),{tag}),createTextNode:text=>text,addEventListener:(k,f)=>events[k]=f};
 vm.runInNewContext(source,{document,window:{},location:{href:'http://portal.test/'},URL,Intl,Date,AbortSignal,fetch:async()=>({ok:true,json:async()=>({items,totalCount:items.length,headlines:items})}),setTimeout(){return 1;},setInterval(){return 1;},clearTimeout(){},requestAnimationFrame:f=>f(),matchMedia:()=>({matches:false,addEventListener(){}}),IntersectionObserver:class{observe(){}}});
 await new Promise(setImmediate);return {board,events,more};
}
const empty=await fixture([]);assert.equal(empty.board.hidden,true,'Empty news board remains visible');empty.events['portal:simulate']({detail:{kind:'news',id:'new',title:'خبر جديد'}});assert.equal(empty.board.hidden,false,'First arriving news did not restore board');empty.events['portal:simulate']({detail:{kind:'reset'}});assert.equal(empty.board.hidden,true,'Reset to empty source left board visible');
const populated=await fixture([{newsId:'1',subject:'خبر اليوم',hasPdf:false,hasPicture:false,publishedAt:'2026-11-01T10:00:00',isImportant:false}]);assert.equal(populated.board.hidden,false,'Non-empty news board is hidden');
console.log('PASS: empty news board hidden, first simulation arrival restores it, reset hides it, populated source remains visible.');

for(const count of [0,1,4,5]){const f=await fixture(Array.from({length:count},(_,i)=>({newsId:String(i+1),subject:'خبر '+i,hasPdf:false,hasPicture:false,publishedAt:'2026-11-01T10:00:00',isImportant:false})));assert.equal(f.more.hidden,count<5,'More news threshold '+count);if(count===4){f.events['portal:simulate']({detail:{kind:'news',id:'fifth',title:'خبر جديد'}});assert.equal(f.more.hidden,false);f.events['portal:simulate']({detail:{kind:'reset'}});assert.equal(f.more.hidden,true);}}
console.log('PASS more-news threshold: hidden below five, visible at five, simulation arrival/reset.');
