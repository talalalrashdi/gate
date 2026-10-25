import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import vm from 'node:vm';
const source=await readFile(new URL('../Frontend/CompanyPortal.Web/wwwroot/js/documents-dialog.js',import.meta.url),'utf8');
class Node{
 constructor(tag){this.tag=tag;this.children=[];this.dataset={};this.listeners={};this.attributes={};this._text='';this.value='';}
 set textContent(value){this._text=String(value);this.children=[];}
 get textContent(){return this._text+this.children.map(child=>child.textContent).join('');}
 set innerHTML(value){throw Error('Database content must be rendered as text.');}
 get firstElementChild(){return this.children[0];}
 append(...nodes){this.children.push(...nodes);}
 replaceChildren(...nodes){this.children=nodes;this._text='';this.value='';}
 setAttribute(key,value){this.attributes[key]=value;}
 addEventListener(type,handler){this.listeners[type]=handler;}
 focus(){this.focused=true;}
}
const settle=async()=>{for(let i=0;i<6;i++)await new Promise(resolve=>setImmediate(resolve));};
async function fixture(initial){
 const ids=new Map(['documents-sheet-trigger','documents-sheet','document-search','document-folder','documents-list','document-status','document-retry'].map(id=>[id,new Node('div')]));
 const sheet=ids.get('documents-sheet'),trigger=ids.get('documents-sheet-trigger'),close=new Node('button');
 const formats=['all','pdf','download'].map(value=>{const node=new Node('button');node.dataset.documentFormat=value;return node;});
 sheet.querySelector=selector=>selector.startsWith('#')?ids.get(selector.slice(1)):close;sheet.querySelectorAll=()=>formats;
 sheet.showModal=()=>{sheet.open=true;};sheet.close=()=>{sheet.open=false;sheet.listeners.close();};
 const document={hidden:false,listeners:{},getElementById:id=>ids.get(id),querySelector:selector=>selector.startsWith('meta')?{content:'/backend/'}:null,
  createElement:tag=>new Node(tag),addEventListener(type,handler){this.listeners[type]=handler;}};
 let data=initial,code=200,calls=0;
 vm.runInNewContext(source,{document,window:{addEventListener(){}},URL,Set,AbortController,AbortSignal,location:{href:'https://portal.test/portal/'},fetch:async(url,options)=>{
  calls++;assert.equal(url,'https://portal.test/backend/api/documents');assert.equal(options.credentials,'include');assert.equal(options.cache,'no-store');assert.equal(options.method,undefined);assert.equal(options.body,undefined);
  return{ok:code===200,status:code,json:async()=>data};
 }});
 const open=()=>trigger.listeners.click({preventDefault(){}});open();await settle();
 return {ids,sheet,trigger,formats,document,open,get calls(){return calls;},setResponse(value,status=200){data=value;code=status;}};
}
const row=(suffix,extra={})=>({documentId:'d0250000-0000-0000-0000-'+suffix.padStart(12,'0'),documentName:'دليل أمن المعلومات',fileName:'دليل.pdf',folderId:20,parentId:null,folderName:'التقنية',folderPath:'التقنية',isPdf:true,...extra});
const f=await fixture([row('1',{documentName:'<b>أمن المعلومات</b>'}),row('2',{documentName:'طلب إجازة',fileName:'طلب إجازة.docx',folderId:11,parentId:10,folderName:'الاستمارات',folderPath:'الموارد البشرية \\ الاستمارات',isPdf:false})]);
const list=f.ids.get('documents-list'),folder=f.ids.get('document-folder'),search=f.ids.get('document-search'),status=f.ids.get('document-status');
assert.equal(list.children.length,2);assert.equal(folder.children.length,3);assert.match(list.textContent,/<b>أمن المعلومات<\/b>/);
const pdf=list.children[0].children[0],download=list.children[1].children[0];
assert.equal(pdf.target,'_blank');assert.equal(download.target,undefined);assert.equal(pdf.href,'https://portal.test/backend/api/documents/d0250000-0000-0000-0000-000000000001/file');
assert.equal(download.rel,'noopener noreferrer');assert.match(download.attributes['aria-label'],/تنزيل/);
search.value='امن';search.listeners.input();assert.equal(list.children.length,1);
search.value='الموارد';search.listeners.input();assert.equal(list.children.length,1);assert.match(list.textContent,/إجازة/);
search.value='';folder.value='20';folder.listeners.change();assert.equal(list.children.length,1);
folder.value='';f.formats[2].listeners.click();assert.equal(list.children.length,1);assert.match(list.textContent,/docx/);
search.value='غير موجود';search.listeners.input();assert.equal(list.children.length,0);assert.match(status.textContent,/مطابقة/);
f.sheet.close();assert.equal(list.children.length,0);assert.equal(folder.children.length,1);assert.equal(f.trigger.focused,true);
search.value='';f.formats[0].listeners.click();f.setResponse([row('3')]);f.open();await settle();assert.equal(f.calls,2);assert.equal(list.children.length,1);
f.document.hidden=true;f.document.listeners.visibilitychange();assert.equal(list.children.length,0);
f.setResponse([],403);f.document.hidden=false;f.document.listeners.visibilitychange();await settle();assert.equal(list.children.length,0);assert.equal(folder.children.length,1);assert.equal(f.ids.get('document-retry').hidden,false);
f.setResponse([]);await f.ids.get('document-retry').listeners.click();assert.match(status.textContent,/لا توجد ملفات متاحة/);
f.setResponse([row('1',{documentId:'../other-file'})]);await f.ids.get('document-retry').listeners.click();assert.equal(list.children.length,0);assert.match(status.textContent,/تعذر قراءة/);
console.log('PASS: documents Arabic search/folders/format filters, GUID URLs, PDF display vs download, literal HTML, close/visibility clearing, empty/error/retry and invalid IDs.');
