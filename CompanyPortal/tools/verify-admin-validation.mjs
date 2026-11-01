import assert from 'node:assert/strict';import vm from 'node:vm';import {readFile} from 'node:fs/promises';
let active;const handlers=new Map();
class E{
 constructor(tag='div'){this.tagName=tag.toUpperCase();this.children=[];this.dataset={};this.attributes={};this.value='';this.type='text';this.name='';this.id='';this.className='';this.required=false;this.disabled=false;this.hidden=false;this.maxLength=-1;this.min='';this.max='';this.textContent='';}
 get isConnected(){return this.id==='admin-workspace'||!!this.parentElement?.isConnected;}
 append(...nodes){for(const n of nodes){n.remove();n.parentElement=this;this.children.push(n);}}prepend(...nodes){for(const n of nodes.reverse()){n.remove();n.parentElement=this;this.children.unshift(n);}}
 replaceChildren(...nodes){for(const n of this.children)n.parentElement=null;this.children=[];this.append(...nodes);}
 remove(){if(this.parentElement){this.parentElement.children.splice(this.parentElement.children.indexOf(this),1);this.parentElement=null;}}
 insertAdjacentElement(_,n){n.parentElement=this.parentElement;this.parentElement.children.splice(this.parentElement.children.indexOf(this)+1,0,n);}
 setAttribute(k,v){this.attributes[k]=String(v);}getAttribute(k){return this.attributes[k]??null;}removeAttribute(k){delete this.attributes[k];}
 contains(n){return this===n||this.children.some(c=>c.contains(n));}
 closest(s){if(s==='form'&&this.tagName==='FORM'||s==='#admin-workspace'&&this.id==='admin-workspace'||s==='[hidden]'&&this.hidden)return this;return this.parentElement?.closest(s)||null;}
 querySelector(s){if(s===':scope > .admin-validation-summary')return this.children.find(n=>n.className==='admin-validation-summary')||null;return this.querySelectorAll(s)[0]||null;}
 querySelectorAll(s){const all=this.children.flatMap(n=>[n,...n.querySelectorAll('*')]);if(s==='*')return all;return all.filter(n=>s==='input,select,textarea'?['INPUT','SELECT','TEXTAREA'].includes(n.tagName):s==='form'?n.tagName==='FORM':false);}
 getClientRects(){return this.hidden?[]:[{}];}focus(){active=this;}scrollIntoView(){}
 get validity(){return{valueMissing:this.required&&!this.value,rangeUnderflow:this.type==='number'&&this.value!==''&&this.min!==''&&Number(this.value)<Number(this.min),rangeOverflow:this.type==='number'&&this.value!==''&&this.max!==''&&Number(this.value)>Number(this.max)};}
}
const workspace=new E();workspace.id='admin-workspace';const form=new E('form');workspace.append(form);
const field=(name,caption,required=false)=>{const e=new E('input');e.name=name;e.required=required;e.labels=[{childNodes:[{nodeType:3,textContent:caption}]}];form.append(e);return e;};
const title=field('Title','العنوان',true),order=field('order','الترتيب');order.type='number';order.min='1';order.max='10';order.value='1';
const document={getElementById:()=>workspace,createElement:t=>new E(t),querySelectorAll:()=>workspace.querySelectorAll('form'),addEventListener:(k,f)=>handlers.set(k,f)};const window={};
vm.runInNewContext(await readFile(new URL('../Frontend/CompanyPortal.Web/wwwroot/js/admin-validation.js',import.meta.url),'utf8'),{document,window,Map,Object,Number,queueMicrotask,MutationObserver:class{observe(){}}});const v=window.AdminValidation;
assert.equal(form.noValidate,true);assert.equal(v.validate(form),false);assert.equal(active,title);assert.equal(title.getAttribute('aria-invalid'),'true');assert.ok(title.getAttribute('aria-describedby'));assert.ok(form.querySelector(':scope > .admin-validation-summary'));title.value='   ';assert.equal(v.validate(form),false,'Whitespace is not a title');title.value='عنوان';order.value='11';assert.equal(v.validate(form),false);assert.equal(active,order);assert.ok(form.children.some(n=>n.textContent.includes('على 10')));order.value='1';assert.equal(v.validate(form),true);assert.equal(title.getAttribute('aria-invalid'),null);
const start=field('startAt','بداية العرض'),end=field('endAt','نهاية العرض');start.type='datetime-local';end.type='date';start.value='2026-11-01T15:00';end.value='2026-11-01';assert.equal(v.validate(form),true,'An event ending at 23:59 on its start date is valid');end.value='2026-10-31';assert.equal(v.validate(form),false);assert.ok(form.children.some(n=>n.textContent==='يجب أن تكون نهاية العرض بعد البداية.'));
v.reset(form);start.name='from';end.name='to';start.type=end.type='date';start.value='2026-11-01';end.value='';form.id='history-filters';assert.equal(v.validate(form),true,'History permits a one-sided date filter');form.id='';assert.equal(v.validate(form),false,'Notice display windows need both dates');start.value=end.value='';assert.equal(v.validate(form),true);
assert.equal(v.server({errors:{Title:['The Title field is required.']}}),true);assert.ok(form.children.some(n=>n.textContent.includes('راجع «العنوان»')));assert.ok(!form.children.some(n=>n.textContent.includes('The Title')));assert.equal(active,title);v.reset(form);assert.equal(title.getAttribute('aria-invalid'),null);assert.equal(form.querySelector(':scope > .admin-validation-summary'),null);
const hidden=field('hidden','حقل مخفي',true);hidden.hidden=true;const disabled=field('disabled','حقل معطل',true);disabled.disabled=true;assert.equal(v.validate(form),true);
console.log('PASS Arabic validation: required/whitespace/range, first-error focus, accessible errors/reset, scheduling pairs/end-of-day, one-sided history filters, disabled/hidden fields and safe API errors.');
