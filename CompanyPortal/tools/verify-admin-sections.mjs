import assert from 'node:assert/strict';
import vm from 'node:vm';
import {readFile} from 'node:fs/promises';
class E{children=[];dataset={};attributes={};hidden=false;classList={add(){}};append(...e){this.children.push(...e);}prepend(e){this.children.unshift(e);}replaceChildren(...e){this.children=e;}setAttribute(k,v){this.attributes[k]=v;}remove(){this.removed=true;}querySelector(s){return s.includes('freshness')?label:s==='button'?refresh:s.includes('admin-list-more')?this.children.find(n=>n.className==='admin-list-more'&&!n.removed):null;}}
const shell=new E(),tools=new E(),label=new E(),refresh=new E(),head=new E(),events={},requested=[];let fail=false,ready=true,permitted=true;
head.append=e=>{requested.push(e);queueMicrotask(()=>{if(fail){fail=false;e.onerror();}else e.onload();});};
const document={baseURI:'http://portal.test/sub/',body:{dataset:{adminAssets:'v1',adminCurrent:'images'}},getElementById:id=>id==='admin-section-loading'?shell:tools,createElement:()=>new E(),head,querySelector:()=>null,addEventListener:(k,f)=>events[k]=f};
const window={AdminCore:{busyIn:()=>false,can:()=>permitted}};
vm.runInNewContext(await readFile(new URL('../Frontend/CompanyPortal.Web/wwwroot/js/admin-sections.js',import.meta.url),'utf8'),{window,document,URL,Intl,Date,Map,Set,Promise,requestAnimationFrame:fn=>fn()});
let opens=0;await window.AdminSections.open('images',()=>opens++);assert.equal(opens,1);assert.equal(requested.length,2);assert.equal(requested[0].rel,'stylesheet');assert.ok(requested[1].src.includes('/sub/js/admin-images.js?v=v1'));await window.AdminSections.open('images',()=>opens++);assert.equal(requested.length,2,'Assets duplicated on revisit');
fail=true;await window.AdminSections.open('events',()=>opens++);assert.equal(opens,2,'Failed assets opened editor');assert.equal(shell.hidden,false);assert.ok(shell.children.at(-1).onclick,'Missing retry');await shell.children.at(-1).onclick();await new Promise(setImmediate);assert.equal(opens,3);assert.ok(shell.hidden);
const host=new E();let clicked=0;window.AdminLists.more(host,24,100,()=>clicked++);host.children[0].onclick();assert.equal(clicked,1);window.AdminLists.more(host,100,100,()=>{});assert.ok(host.children[0].removed,'Old load-more remained after final page');
const form=new E();window.AdminLists.compact(form,'Documents');assert.equal(form.dataset.expanded,'false');form.children[0].onclick();assert.equal(form.dataset.expanded,'true');assert.equal(form.children[0].attributes['aria-expanded'],'true');
permitted=false;await window.AdminSections.open('themes',()=>opens++);assert.equal(opens,3,'Revoked editor revealed');
console.log('PASS section assets: scoped paths, once-only ordered load, failure/retry, revocation, incremental controls and compact editors.');
