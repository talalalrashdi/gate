import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import vm from 'node:vm';

class Node {
  children = []; dataset = {}; attributes = {}; listeners = {}; disabled = false; value = '';
  constructor(tag) { this.tagName = tag; }
  set textContent(value) { this.value = value; this.children = []; }
  get textContent() { return this.value + this.children.map(node => node.textContent).join(''); }
  append(...nodes) { for (const node of nodes) { if (node.fragment) this.children.push(...node.children); else this.children.push(node); } }
  replaceChildren(...nodes) { this.value = ''; this.children = []; this.append(...nodes); }
  setAttribute(name, value) { this.attributes[name] = value; }
  addEventListener(name, listener) { this.listeners[name] = listener; }
  contains(node) { return this.children.includes(node); }
  dispatchEvent() {}
}
const card = new Node('article'), list = new Node('div'), badge = new Node('span'), status = new Node('p'), open = new Node('button');
card.querySelector = selector => ({ '.portal-email-list':list, '[data-count-source="exchange"]':badge, '[data-mail-status]':status, '[data-mail-open]':open })[selector];
const streams = [], timers = new Map(), events = {}, opened = [];
class EventSource {
  listeners = {}; closed = false;
  constructor(url, options) { this.url = url; this.options = options; streams.push(this); }
  addEventListener(name, listener) { this.listeners[name] = listener; }
  close() { this.closed = true; }
  emit(data) { this.listeners.inbox({ data:JSON.stringify(data) }); }
}
const simulationEvents={},previews=[];
const context = vm.createContext({
  document: { querySelector: selector => selector === '[data-work-system="email"]' ? card : {content:'https://api.test/portal/'},
    getElementById:()=>({}),addEventListener:(name,fn)=>simulationEvents[name]=fn,dispatchEvent:event=>previews.push(event),createElement: tag => new Node(tag), createDocumentFragment: () => Object.assign(new Node('fragment'), {fragment:true}), activeElement:null },
  window: { addEventListener: (name, listener) => { events[name] = listener; }, open: (...args) => opened.push(args) },
  location:{href:'https://portal.test/'}, URL, EventSource, Intl, Date, Number, JSON, Error, encodeURIComponent,
  setTimeout:(callback, delay) => { const id = timers.size + 1; timers.set(id,{callback,delay}); return id; }, clearTimeout: id => timers.delete(id),
  CustomEvent: class {constructor(type,options){this.type=type;this.detail=options?.detail;}}, localStorage:new Proxy({}, {get(){throw new Error('Mailbox data must not use browser storage.');}})
});
vm.runInContext(await readFile(new URL('../Frontend/CompanyPortal.Web/wwwroot/js/email.js',import.meta.url),'utf8'),context);
assert.equal(streams.length,1); assert.equal(streams[0].options.withCredentials,true); assert.equal(timers.size,0,'No inbox polling timer');
assert.equal(badge.textContent,'—'); assert.equal(open.disabled,true);
const item = {itemId:'A+/=',subject:'<img src=x onerror=alert(1)>',sender:'Sender <b>name</b>',receivedAt:'2026-10-19T08:00:00Z',isRead:false};
streams[0].emit({unreadCount:27,items:[item]});
assert.equal(badge.textContent,'27','Authoritative unread count must exceed visible-row count'); assert.equal(list.children.length,1);
assert.equal(list.children[0].children[1].children[0].textContent,item.subject,'Subject must remain text');
assert.equal(list.children[0].href,'https://api.test/portal/api/mail/open?itemId=A%2B%2F%3D'); assert.equal(list.children[0].target,'_blank');
assert.equal(timers.size,0,'Live updates must not schedule inbox reads');
streams[0].emit({unreadCount:26,items:[{...item,isRead:true}]});
assert.equal(badge.textContent,'26'); assert.equal(list.children[0].dataset.state,'read');
open.listeners.click(); assert.equal(opened[0][0],'https://api.test/portal/api/mail/inbox/open');
streams[0].onerror(); assert.equal(streams[0].closed,true); assert.equal(badge.textContent,'—'); assert.equal(list.children.length,0); assert.equal(open.disabled,true);
assert.equal([...timers.values()][0].delay,5000,'Retry should reconnect the stream, not fetch inbox data');
events.pagehide(); assert.equal(timers.size,0); events.pageshow({persisted:true}); assert.equal(streams.length,2);
streams[1].emit({unreadCount:-1,items:[]}); assert.equal(streams[1].closed,true,'Invalid stream data must fail closed');
const simulate=action=>simulationEvents['portal:outlook-simulate']({detail:{action}});
simulate('outlook-start');assert.equal(badge.textContent,'3');assert.equal(list.children.length,5);assert.equal(timers.size,0);
const streamCount=streams.length;simulate('mail-new');assert.equal(badge.textContent,'4');assert.equal(list.children.length,6);assert.equal(list.children[0].href,'#');
let prevented=false;list.children[0].listeners.click({preventDefault(){prevented=true;}});assert.ok(prevented);assert.equal(badge.textContent,'3');assert.equal(previews.at(-1).type,'portal:simulation-open');
simulate('mail-read');assert.equal(badge.textContent,'2');simulate('mail-delete');assert.equal(list.children.length,5);
streams.at(-1).emit({unreadCount:999,items:[item]});streams.at(-1).onerror();assert.equal(badge.textContent,'2');assert.equal(timers.size,0);
open.listeners.click();assert.equal(opened.length,1,'Sample inbox must not open OWA');
simulate('outlook-disconnect');assert.equal(badge.textContent,'—');assert.equal(list.children.length,0);simulate('mail-new');assert.equal(list.children.length,0);simulate('outlook-reconnect');assert.equal(list.children.length,6);
simulate('mail-empty');assert.equal(badge.textContent,'0');assert.equal(list.children.length,0);assert.equal(streams.length,streamCount,'Simulation must not connect to EWS');
simulate('outlook-exit');assert.equal(streams.length,streamCount+1);assert.equal(badge.textContent,'—');
events.pagehide();
context.document.getElementById=()=>null;delete simulationEvents['portal:outlook-simulate'];vm.runInContext(await readFile(new URL('../Frontend/CompanyPortal.Web/wwwroot/js/email.js',import.meta.url),'utf8'),context);assert.equal(simulationEvents['portal:outlook-simulate'],undefined,'Disabled simulation must not register handlers');events.pagehide();
console.log('PASS: live email rendering, authoritative unread badge, safe text/links, credentialed event stream, no inbox polling/storage, disconnect clearing reconnect lifecycle, one-click mail simulation, read/delete/empty states, local preview, disconnect/reconnect and zero simulation streams/storage.');
