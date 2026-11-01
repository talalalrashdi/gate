/* Shared creation dialogs. Editors own their draft/busy rules; successful saves close directly. */
(() => {
 let sequence=0;
 window.AdminEditorModal={open({title,content,status,mount=document.body,section,busy=()=>false,onCancel=async()=>true,onClosed=()=>{}}){
  const dialog=document.createElement('dialog'),header=document.createElement('header'),heading=document.createElement('h2'),close=document.createElement('button'),body=document.createElement('div');
  dialog.className='admin-editor-modal';heading.id='admin-editor-modal-title-'+(++sequence);heading.textContent=title;dialog.setAttribute('aria-labelledby',heading.id);close.type='button';close.textContent='×';close.setAttribute('aria-label','إغلاق '+title);body.className='admin-editor-modal-body';header.append(heading,close);body.append(content);dialog.append(header,body);mount.append(dialog);
  const statusHome=status?.parentNode,statusNext=status?.nextSibling;if(status)body.prepend(status);
  let asking=false,closed=false;
  const finish=()=>{if(closed)return;closed=true;window.AdminValidation?.reset(content);dialog.close();document.removeEventListener('admin:access',accessChanged);onClosed();if(statusHome)statusHome.insertBefore(status,statusNext?.parentNode===statusHome?statusNext:null);dialog.remove();window.AdminCore.refresh();};
  const requestClose=async()=>{if(asking||busy())return;asking=true;try{if(await onCancel())finish();}finally{asking=false;}};
  const accessChanged=()=>{if(section&&!window.AdminCore.can(section))finish();};document.addEventListener('admin:access',accessChanged);
  close.onclick=()=>void requestClose();dialog.addEventListener('cancel',e=>{e.preventDefault();void requestClose();});dialog.addEventListener('click',e=>{if(e.target===dialog){const r=dialog.getBoundingClientRect();if(e.clientX<r.left||e.clientX>r.right||e.clientY<r.top||e.clientY>r.bottom)void requestClose();}});
  dialog.showModal();return{close:finish,requestClose};
 }};
})();
