/* Section visits and PDF reads are different acknowledgements, both saved per employee. */
window.CompanyPortalLibraryReads=(section,endpoint)=>{
 const badge=document.querySelector('[data-library-new="'+section+'"]'),link=badge?.closest('a');
 let documents=[],render=()=>{},loaded=false,visitPending=false,visiting=false;
 const opening=new Set(),read=new Set(),seen=new Set();
 const update=()=>{if(badge)badge.hidden=visiting||!documents.some(d=>!d.hasRead&&!d.hasSeen&&!read.has(d.documentId)&&!seen.has(d.documentId));};
 async function post(path,body){
  const response=await fetch(endpoint(path),{method:'POST',credentials:'include',cache:'no-store',headers:{'Content-Type':'application/json','X-CompanyPortal-Request':'library-read'},body:JSON.stringify(body),signal:AbortSignal.timeout(15000)});
  if(!response.ok)throw new Error('Library acknowledgement failed');
 }
 async function visit(){
  if(!loaded){visitPending=true;return;}if(visiting)return;
  const ids=[...new Set(documents.filter(d=>!d.hasSeen&&!d.hasRead&&!seen.has(d.documentId)&&!read.has(d.documentId)).map(d=>d.documentId))];
  if(!ids.length)return;visiting=true;if(badge)badge.hidden=true;
  try{for(let i=0;i<ids.length;i+=500){const batch=ids.slice(i,i+500);await post('/seen',{documentIds:batch});batch.forEach(id=>seen.add(id));}}
  catch{/* A failed save leaves unseen entries available to retry on the next click. */}
  finally{visiting=false;update();}
 }
 link?.addEventListener('click',()=>void visit());
 document.addEventListener('portal:library-read',event=>{const id=event.detail?.documentId;if(!id)return;read.add(id);documents.filter(d=>d.documentId===id).forEach(d=>d.hasRead=true);render(id);update();});
 return {
  clear(){documents=[];loaded=false;update();},
  catalog(tabs,changed){documents=tabs.flatMap(t=>t.documents);render=changed;documents.forEach(d=>{if(read.has(d.documentId))d.hasRead=true;});loaded=true;update();if(visitPending){visitPending=false;void visit();}},
  async open(doc){
   if(doc.hasRead||read.has(doc.documentId)||opening.has(doc.documentId))return;
   opening.add(doc.documentId);
   try{await post('/'+doc.documentId+'/read',{});seen.add(doc.documentId);document.dispatchEvent(new CustomEvent('portal:library-read',{detail:{documentId:doc.documentId}}));}
   catch{window.showToast?.('تعذر حفظ حالة قراءة الملف. أعد فتحه للمحاولة.');}
   finally{opening.delete(doc.documentId);}
  }
 };
};
