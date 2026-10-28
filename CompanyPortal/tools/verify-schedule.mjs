import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import vm from 'node:vm';
const all=[],events={},timers=new Map(),streams=[],requests=[],notices=[];
let document;const simulationEvents={};
class Node {
 children=[];dataset={};attributes={};listeners={};disabled=false;hidden=false;value='';_text='';classes=new Set();
 constructor(tag){this.tagName=tag;all.push(this);this.classList={add:(...names)=>names.forEach(n=>this.classes.add(n)),toggle:(name,on)=>{if(on)this.classes.add(name);else this.classes.delete(name);}};}
 set className(value){this.classes=new Set(value.split(' '));}get className(){return [...this.classes].join(' ');}
 set textContent(value){this._text=String(value);this.children=[];}get textContent(){return this._text+this.children.map(n=>n.textContent).join('');}
 set innerHTML(_){throw new Error('Exchange content must never use innerHTML');}
 append(...nodes){this.children.push(...nodes);if(this.tagName==='select'&&!this.value&&nodes[0])this.value=nodes[0].value;}
 replaceChildren(...nodes){this._text='';this.children=[];if(this.tagName==='select')this.value='';this.append(...nodes);}
 setAttribute(name,value){this.attributes[name]=String(value);if(name==='hidden')this.hidden=true;}
 addEventListener(name,listener){this.listeners[name]=listener;}
 contains(node){return this.children.some(n=>n===node||n.contains(node));}
 querySelectorAll(selector){return this.children.flatMap(n=>[...(selector==='button'&&n.tagName==='button'?[n]:[]),...n.querySelectorAll(selector)]);}
 closest(){return null;}
 focus(){document.activeElement=this;}
}
const planner=new Node('div'),summary=new Node('div'),float=new Node('aside'),body=new Node('div'),toggle=new Node('button'),oldAdd=new Node('button');
const ids={'portal-simulation':new Node('details'),'portal-calendar-summary':summary,'portal-floating-calendar':float,'portal-floating-calendar-body':body,'portal-calendar-toggle':toggle,'planner-task-add-toggle':oldAdd};
class Source{
 listeners={};closed=false;
 constructor(url,options){this.url=url;this.options=options;streams.push(this);}
 addEventListener(name,fn){this.listeners[name]=fn;}close(){this.closed=true;}
 emit(data){this.listeners.schedule({data:JSON.stringify(data)});}
}
const RealDate=Date;
class Clock extends RealDate{constructor(...args){super(...(args.length?args:['2026-10-20T06:00:00Z']));}static now(){return RealDate.parse('2026-10-20T06:00:00Z');}}
document={querySelector:s=>s==='[data-schedule-source="exchange"]'?planner:{content:'https://api.test/portal/'},getElementById:id=>ids[id]||null,createElement:tag=>new Node(tag),activeElement:null,dispatchEvent(){},addEventListener:(name,fn)=>simulationEvents[name]=fn};
const context=vm.createContext({document,window:{addEventListener:(name,fn)=>events[name]=fn,showToast:text=>notices.push(text)},location:{href:'https://portal.test/'},Intl,Date:Clock,URL,URLSearchParams,AbortSignal,EventSource:Source,CustomEvent:class{},
 fetch:async(url,options)=>{requests.push({url,options});return {ok:true,json:async()=>({timeZone:'Asia/Muscat',calendars:[{key:'own',name:'My calendar',isOwn:true},{key:'manager',name:'Manager',isOwn:false}]})};},
 setTimeout:(callback,delay)=>{const id=timers.size+1;timers.set(id,{callback,delay});return id;},clearTimeout:id=>timers.delete(id),localStorage:new Proxy({},{get(){throw new Error('Do not read or store Exchange/local task data in browser storage');}})});
vm.runInContext(await readFile(new URL('../Frontend/CompanyPortal.Web/wwwroot/js/exchange-schedule.js',import.meta.url),'utf8'),context);
await new Promise(setImmediate);
assert.equal(requests.length,1);assert.equal(requests[0].options.credentials,'include');assert.equal(streams.length,1);assert.equal(streams[0].options.withCredentials,true);assert.equal(timers.size,0,'No folder polling timers');assert.equal(oldAdd.hidden,true);
const params=source=>new URL(source.url).searchParams;
const snapshot=source=>({calendarKey:params(source).get('calendar'),calendarName:'My calendar',timeZone:'Asia/Muscat',calendarLive:true,from:params(source).get('from'),to:params(source).get('to'),
 calendar:{truncated:false,items:[{itemId:'event1',subject:'<img onerror=bad()>',start:'2026-10-20T06:00:00Z',end:'2026-10-20T07:00:00Z',isAllDay:false,isCancelled:false,location:'Room',organizer:'Boss',responseStatus:'Accept'},{itemId:'all-day',subject:'All day',start:'2026-10-19T20:00:00Z',end:'2026-10-20T20:00:00Z',isAllDay:true,isCancelled:false,location:'',organizer:'',responseStatus:''}]},
 tasks:{truncated:false,items:[{itemId:'t1',subject:'Overdue',dueDate:'2026-10-19',startDate:null,status:'InProgress',importance:'High',percentComplete:20},{itemId:'t2',subject:'Due today',dueDate:'2026-10-20',startDate:null,status:'NotStarted',importance:'Normal',percentComplete:0},{itemId:'t3',subject:'Upcoming',dueDate:'2026-10-21',startDate:null,status:'NotStarted',importance:'Normal',percentComplete:0},{itemId:'t4',subject:'No due date',dueDate:null,startDate:null,status:'NotStarted',importance:'Normal',percentComplete:0}]}});
const first=snapshot(streams[0]);streams[0].emit(first);
const byClass=name=>all.find(n=>n.classes.has(name)),byLabel=name=>all.find(n=>n.attributes['aria-label']===name);
assert.equal(notices.length,0,'Initial snapshot should not notify about old items');assert.ok(planner.textContent.includes('<img onerror=bad()>'),'Subjects should remain literal text');assert.ok(planner.textContent.includes('طوال اليوم'));
const grid=byClass('personal-month-grid');assert.equal(grid.children.filter(n=>n.tagName==='button').length,42);assert.ok(grid.children.find(n=>n.dataset.date==='2026-10-20').classes.has('has-tasks'));assert.equal(grid.children.find(n=>n.dataset.date==='2026-10-21').classes.has('has-tasks'),false,'All-day end must be exclusive');
all.find(n=>n.dataset.filter==='overdue').listeners.click();assert.equal(byClass('exchange-task-items').children.length,1);assert.ok(byClass('exchange-task-items').textContent.includes('Overdue'));
streams[0].emit({...first,tasks:{...first.tasks,items:[...first.tasks.items,{...first.tasks.items[0],itemId:'new-task',subject:'New task'}]}});assert.equal(notices.length,1,'New task did not notify');assert.equal(timers.size,0);
const stale=streams[0];byLabel('الشهر التالي').listeners.click();assert.equal(stale.closed,true);assert.equal(streams.length,2);assert.notEqual(params(streams[1]).get('from'),first.from);stale.emit(first);assert.ok(!planner.textContent.includes('<img onerror=bad()>'),'Stale snapshot replaced new month');
streams[1].emit({...snapshot(streams[1]),calendar:{items:[],truncated:false}});const picker=byLabel('اختيار تقويم Outlook');picker.value='manager';picker.listeners.change();assert.equal(streams.length,3);assert.equal(params(streams[2]).get('calendar'),'manager');
streams[2].emit({...snapshot(streams[2]),calendarLive:false});assert.ok(planner.textContent.includes('تحديثًا يدويًا'));
byLabel('إعادة الاتصال بتقويم Outlook').listeners.click();await new Promise(setImmediate);assert.equal(picker.value,'manager','Manual refresh changed selected shared calendar');assert.equal(params(streams.at(-1)).get('from'),params(streams[2]).get('from'),'Manual refresh changed viewed month');
const active=streams.at(-1);active.emit({...snapshot(active),timeZone:'invalid-zone'});assert.equal(active.closed,true,'Invalid timezone must fail closed');assert.ok(!planner.textContent.includes('<img onerror=bad()>'));assert.equal(timers.size,1);assert.equal([...timers.values()][0].delay,5000,'Retry must reconnect SSE, not poll folders');
events.pagehide();assert.equal(timers.size,0);assert.ok(!summary.textContent.includes('All day'));events.pageshow({persisted:true});await new Promise(setImmediate);assert.equal(requests.length,3);assert.equal(streams.at(-1).closed,false);events.pagehide();
events.pageshow({persisted:true});await new Promise(setImmediate);
const simulate=action=>simulationEvents['portal:outlook-simulate']({detail:{action}});
simulate('outlook-start');assert.equal(picker.value,'own');assert.equal(byClass('exchange-task-items').children.length,5);assert.ok(planner.textContent.includes('[محاكاة]'));
const counts=[requests.length,streams.length];simulate('calendar-new');assert.ok(byClass('exchange-agenda-items').textContent.includes('موعد جديد'));assert.ok(notices.at(-1).includes('موعد جديد'));
simulate('calendar-update');assert.ok(byClass('exchange-agenda-items').textContent.includes('تم تعديل الموعد'));simulate('calendar-cancel');assert.ok(byClass('exchange-agenda-items').children.some(n=>n.classes.has('is-cancelled')));
simulate('calendar-all-day');assert.ok(byClass('exchange-agenda-items').textContent.includes('طوال اليوم'));
simulate('calendar-shared');assert.equal(picker.value,'simulation-manager');assert.ok(byClass('exchange-agenda-items').textContent.includes('موعد خاص'));assert.ok(!byClass('exchange-agenda-items').children.find(n=>n.textContent.includes('موعد خاص')).textContent.includes('مكتب المدير'),'Private appointment details leaked');
simulate('calendar-shared-manual');assert.ok(planner.textContent.includes('يدويًا'));byLabel('إعادة الاتصال بتقويم Outlook').listeners.click();assert.equal(picker.value,'simulation-manager');
byLabel('الشهر التالي').listeners.click();byLabel('العودة إلى اليوم').listeners.click();assert.equal(picker.value,'simulation-manager');
picker.value='own';picker.listeners.change();assert.ok(byClass('exchange-agenda-items').textContent.includes('تم تعديل الموعد'));
simulate('calendar-revoke');assert.equal(picker.children.length,1);assert.equal(picker.value,'own');
simulate('task-new');assert.equal(byClass('exchange-task-items').children.length,6);simulate('task-complete');assert.equal(byClass('exchange-task-items').children.length,5);
all.find(n=>n.dataset.filter==='overdue').listeners.click();assert.equal(byClass('exchange-task-items').children.length,1);simulate('task-examples');assert.equal(byClass('exchange-task-items').children.length,5);
simulate('outlook-disconnect');assert.ok(!planner.textContent.includes('مراجعة التقرير'));assert.equal(context.window.CompanyPortalSchedule.notifications.length,0);simulate('outlook-reconnect');assert.equal(byClass('exchange-task-items').children.length,5);
simulate('calendar-empty');assert.ok(byClass('exchange-agenda-items').textContent.includes('لا توجد مواعيد'));assert.deepEqual([requests.length,streams.length],counts,'Simulation navigation must make no requests/streams');
simulate('outlook-exit');await new Promise(setImmediate);assert.equal(requests.length,counts[0]+1);assert.equal(streams.length,counts[1]+1);events.pagehide();
console.log('PASS: calendar month/day/all-day rendering, task filters, literal text, new-item notifications, credentialed SSE, stale-range rejection, manual shared refresh, invalid-data/disconnect clearing, reconnect and no polling/storage.');
