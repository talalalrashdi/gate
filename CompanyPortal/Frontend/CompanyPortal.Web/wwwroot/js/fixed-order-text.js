// Shared portal/admin preview renderer. Database text is never parsed as HTML.
window.CompanyPortalFixedOrderText=Object.freeze({append(paragraph,row){
  (row.contentText??'').split(/(ds\{0\}de|ss\{1\}se)/g).forEach(part=>{
    if(part==='ds{0}de'||part==='ss{1}se'){
      const before=part==='ds{0}de',span=document.createElement('span');
      span.className=before?'portal-policy-previous':'portal-policy-preferred';span.textContent=(before?row.contentBefor:row.contentAfter)??'';paragraph.append(span);
    }else paragraph.append(document.createTextNode(part));
  });
}});
