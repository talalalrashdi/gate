import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import vm from 'node:vm';
const source=await readFile(new URL('../Frontend/CompanyPortal.Web/wwwroot/js/floating-notices.js',import.meta.url),'utf8');
class Element{
 children=[];dataset={};attributes={};listeners={};hidden=false;open=false;_text='';nodes=new Map();
 set textContent(v){this._text=String(v);this.children=[];}get textContent(){return this._text+this.children.map(n=>n.textContent).join('');}get childNodes(){return this.children;}
 append(...n){this.children.push(...n);}replaceChildren(...n){this._text='';this.children=n;}replaceWith(n){this.replacement=n;}
 querySelector(s){if(!this.nodes.has(s))this.nodes.set(s,new Element());return this.nodes.get(s);}
 setAttribute(k,v){this.attributes[k]=v;}removeAttribute(k){delete this.attributes[k];}addEventListener(k,fn){this.listeners[k]=fn;}matches(){return false;}focus(){}showModal(){this.open=true;}close(){this.open=false;this.listeners.close?.();}
}
function fixture(rows){
 const notice=new Element(),alert=new Element(),toggle=new Element(),dialog=new Element(),events={},timers=new Map();let timer=0,requests=0;
 const ids={'portal-floating-alert':notice,'portal-floating-notice':alert,'portal-notices-visibility':toggle,'decision-notices-dialog':dialog,'portal-simulation':new Element()};
 const document={hidden:false,getElementById:id=>ids[id],querySelector:()=>({content:'https://api.test/'}),createElement:()=>new Element(),addEventListener:(type,fn)=>events[type]=fn};
 vm.runInNewContext(source,{document,window:{addEventListener(){}},URL,Date,Intl,AbortSignal,location:{href:"https://portal.test/"},setTimeout:(fn,delay)=>{timers.set(++timer,{fn,delay});return timer;},clearTimeout:id=>timers.delete(id),fetch:()=>{requests++;throw Error('Reading must not send dismissal or duplicate read requests');}});
 const emit=(name,detail)=>events[name]({detail});const catalog=data=>emit('portal:decisions',{rows:data,loaded:true,origin:'api'});
 catalog(rows);return {notice,alert,toggle,dialog,rows,catalog,emit,get requests(){return requests;},read(id){rows.filter(r=>r.decisionId===id).forEach(r=>r.hasRead=true);emit('portal:decision-read',id);},show(){toggle.listeners.click();},reveal(id,channels){emit('portal:simulation-reveal',{decisionId:id,channels});},get noticeId(){return notice.querySelector('[data-notice-link]').dataset.decisionId;},get alertId(){return alert.querySelector('.portal-floating-notice-content').replacement.dataset.decisionId;}};
}
const row=(id,channels,hasRead=false)=>({decisionId:id,title:'Decision '+id,decisionType:'تعميم',publishedAt:new Date().toISOString(),hasRead,notices:channels.map(channelId=>({channelId,fromAt:new Date(Date.now()-60000).toISOString(),toAt:new Date(Date.now()+86400000).toISOString()}))});
let f=fixture([row('1',[1]),row('2',[1]),row('3',[2]),row('4',[2])]);assert.ok(f.notice.hidden&&f.alert.hidden);f.show();assert.equal(f.noticeId,'1');assert.equal(f.alertId,'3');
f.read('2');assert.equal(f.notice.hidden,false,'Reading another notice must not close current notice');assert.equal(f.alert.hidden,false);
f.read('1');assert.equal(f.notice.hidden,true,'Reading displayed notice must close it');assert.equal(f.alert.hidden,false,'Unrelated alert must stay open');assert.equal(f.toggle.attributes['aria-expanded'],'true');
f.read('1');assert.equal(f.alert.hidden,false,'Repeated read must not close unrelated channel');
const added=row('5',[1]);f.rows.push(added);f.catalog(f.rows);assert.equal(f.notice.hidden,false);assert.equal(f.noticeId,'5');f.read('3');assert.equal(f.alert.hidden,true);assert.equal(f.notice.hidden,false);assert.equal(f.rows.length,5,'Read decision must remain in catalog');assert.equal(f.requests,0);
f=fixture([row('10',[1]),row('11',[1]),row('12',[2])]);f.show();f.rows[0].hasRead=true;f.catalog(f.rows);assert.equal(f.notice.hidden,true,'Read discovered on refresh must close displayed popup rather than switch to another');assert.equal(f.alert.hidden,false);
f=fixture([row('20',[1],true),row('21',[1]),row('22',[2],true)]);f.show();assert.equal(f.noticeId,'21');assert.equal(f.alert.hidden,true,'Already-read alert must not appear');f.read('21');assert.equal(f.notice.hidden,true);assert.equal(f.toggle.attributes['aria-expanded'],'false','Empty channels must not leave header toggle expanded');
f=fixture([row('simulation-1',[1,2]),row('simulation-2',[1]),row('simulation-3',[2])]);f.reveal('simulation-1',[1,2]);assert.ok(!f.notice.hidden&&!f.alert.hidden);f.read('simulation-1');assert.ok(f.notice.hidden&&f.alert.hidden,'Same decision in both channels must close both, without replacing it');assert.equal(f.toggle.attributes['aria-expanded'],'false');assert.equal(f.requests,0);f.show();assert.equal(f.noticeId,'simulation-2');assert.equal(f.alertId,'simulation-3');
f.alert.querySelector('.portal-floating-notice-all').listeners.click();const list=f.dialog.querySelector('[data-notices-list]');assert.ok(!list.children.some(n=>n.dataset.decisionId==='simulation-1'),'Read item must not return in floating list');
console.log('PASS: both read popups close, independent channels/unrelated reads, no replacement, shared row mutation, refresh/initial read filtering, header state, retained main catalog and no extra requests.');
