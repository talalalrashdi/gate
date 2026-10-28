import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import vm from 'node:vm';
class Element {
  constructor(tag){this.tag=tag;this.children=[];this.listeners={};this.dataset={};this.attributes={};this.value='';this.checked=false;this.disabled=false;this._text='';this.classes=new Set();this.classList={contains:c=>this.classes.has(c),remove:c=>this.classes.delete(c),toggle:(c,on)=>on?this.classes.add(c):this.classes.delete(c)};}
  set className(value){this.classes=new Set(value.split(' '));}
  set textContent(value){this._text=String(value);this.children=[];}
  get textContent(){return this._text+this.children.map(n=>n.textContent).join('');}
  set innerHTML(_){throw Error('Use literal text.');}
  append(...nodes){this.children.push(...nodes);}
  replaceChildren(...nodes){this.children=nodes;this._text='';}
  setAttribute(k,v){this.attributes[k]=v;}
  addEventListener(k,fn){this.listeners[k]=fn;}
  dispatchEvent(e){this.listeners[e.type]?.(e);}
  querySelectorAll(selector){const all=this.children.flatMap(n=>[n,...n.querySelectorAll('*')]);return all.filter(n=>selector==='*'||selector.split(',').some(s=>s.startsWith('.')?n.classes.has(s.slice(1)):s==='input[type="checkbox"]'?n.tag==='input'&&n.type==='checkbox':n.tag===s));}
  querySelector(s){return this.querySelectorAll(s)[0];}
}
const list=new Element('div'),status=new Element('p'),retry=new Element('button'),add=new Element('button'),root=new Element('section');root.dataset.pdfLibraryAdmin='documents';root.append(list,status,retry,add);
const targets={'[data-library-list]':list,'[data-library-status]':status,'[data-library-retry]':retry,'[data-library-add]':add};
const lookup=root.querySelector.bind(root);root.querySelector=s=>targets[s]??lookup(s);
const documents=Array.from({length:501},(_,i)=>({documentId:`pdf-${i}`,documentName:`وثيقة ${i}`,folderId:101,folderName:'القوانين'}));
const tabs=Array.from({length:20},(_,i)=>({documentTabId:i+1,tabName:`قسم ${i+1}`,folderId:101,displayOrder:i,active:true}));
const catalog={documents,tabs,items:tabs.flatMap(t=>documents.slice(0,499).map(d=>({documentTabId:t.documentTabId,documentId:d.documentId})))};
const core={request:async()=>({ok:true,json:async()=>catalog}),feedback(){},watch(){},whenSection(section,fn){fn();}};
const document={querySelector:()=>({content:'http://localhost:5092/'}),querySelectorAll:()=>[root],createElement:tag=>new Element(tag)};
vm.runInNewContext(await readFile(new URL('../Frontend/CompanyPortal.Web/wwwroot/js/admin-documents.js',import.meta.url),'utf8'),{document,window:{AdminCore:core},AdminChanges:{tag(){}},URL,location:{href:'http://localhost:5093/admin/documents'},Event});
for(let i=0;i<8;i++)await new Promise(r=>setImmediate(r));
assert.equal(list.children.length,20);assert.equal(list.querySelectorAll('input[type="checkbox"]').length,20,'Only active flags render before expanding large lists.');
const form=list.children[0],picker=form.querySelector('.admin-document-picker');
picker.open=true;picker.listeners.toggle();
let inputs=picker.querySelectorAll('input');assert.equal(inputs.length,501);assert.equal(inputs.filter(n=>n.checked).length,499);
inputs[499].checked=true;inputs[499].listeners.change();assert.equal(inputs[500].disabled,true);assert.match(form.textContent,/500 \/ 500/);
inputs[499].checked=false;inputs[499].listeners.change();assert.equal(inputs[500].disabled,false);
picker.open=false;picker.listeners.toggle();assert.equal(picker.querySelectorAll('input').length,0);
picker.open=true;picker.listeners.toggle();inputs=picker.querySelectorAll('input');assert.equal(inputs.filter(n=>n.checked).length,499);
assert.equal(list.children[1].querySelector('.admin-document-picker').querySelectorAll('input').length,0,'Opening one tab must not expand every editor.');
console.log('PASS: 20 admin tabs/501 choices; lazy file lists, 499 selections preserved, 500-file cap/re-enable, independent editors and collapse/reopen.');
