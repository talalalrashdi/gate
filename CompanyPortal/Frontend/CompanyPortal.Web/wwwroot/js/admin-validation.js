/* Arabic, accessible validation for static and lazily-created administration editors. */
(() => {
 const errors=new Map();let sequence=0,lastForm=null,queued=false;
 const make=(tag,text)=>{const n=document.createElement(tag);if(text)n.textContent=text;return n;};
 const scope=field=>field.closest('form')||field.closest('[role="row"]')||field.parentElement;
 const visible=field=>!field.disabled&&field.type!=='hidden'&&!field.closest('[hidden]')&&field.getClientRects().length>0;
 const label=field=>{
  if(field.dataset.validationLabel)return field.dataset.validationLabel;
  if(field.getAttribute('aria-label'))return field.getAttribute('aria-label');
  const l=field.labels?.[0]||field.closest('label');
  if(l){const texts=[...l.childNodes].filter(n=>n.nodeType===3).map(n=>n.textContent.trim()).filter(Boolean);if(texts.length)return texts.join(' ').replace(/[:：]$/,'');const span=l.querySelector('span:not(.admin-field-error)');if(span)return span.textContent.trim();}
  return field.type==='number'?'القيمة الرقمية':field.type==='date'||field.type==='datetime-local'?'التاريخ':'هذا الحقل';
 };
 function message(field){
  const v=field.validity,n=label(field);if(!v)return'';
  if(v.valueMissing||(field.required&&typeof field.value==='string'&&!field.value.trim()))return field.tagName==='SELECT'?'اختر '+n+'.':field.type==='file'?'اختر الملف المطلوب.':'أدخل '+n+'.';
  if(v.badInput||v.typeMismatch)return field.type==='number'?'أدخل رقمًا صحيحًا في «'+n+'».':field.type==='url'?'أدخل رابطًا صحيحًا يبدأ بـ http:// أو https://.':field.type==='email'?'أدخل بريدًا إلكترونيًا صحيحًا.':'أدخل قيمة صحيحة في «'+n+'».';
  if(v.rangeUnderflow)return 'يجب ألا تقل قيمة «'+n+'» عن '+field.min+'.';
  if(v.rangeOverflow)return 'يجب ألا تزيد قيمة «'+n+'» على '+field.max+'.';
  if(v.tooLong||field.maxLength>0&&field.value.length>field.maxLength)return 'الحد الأقصى لحقل «'+n+'» هو '+field.maxLength+' حرفًا.';
  if(v.tooShort)return 'أدخل '+field.minLength+' أحرف على الأقل في «'+n+'».';
  if(v.stepMismatch)return 'أدخل قيمة ضمن الخطوة المسموحة ('+(field.step||1)+') في «'+n+'».';
  if(v.patternMismatch)return field.dataset.validationPattern||'راجع صيغة «'+n+'».';
  if(v.customError)return /[\u0600-\u06ff]/.test(field.validationMessage)?field.validationMessage:'راجع قيمة «'+n+'».';
  return'';
 }
 function summary(form){
  if(!form)return;let box=form.querySelector(':scope > .admin-validation-summary');const rows=[...errors].filter(([field])=>field.isConnected&&form.contains(field));
  if(!rows.length){box?.remove();return;}
  if(!box){box=make('div');box.className='admin-validation-summary';box.setAttribute('role','alert');form.prepend(box);}
  box.replaceChildren(make('strong','راجع الحقول التالية:'));const list=make('ul');for(const [,row]of rows)list.append(make('li',row.text));box.append(list);
 }
 function clear(field){const row=errors.get(field);if(!row)return;row.node.remove();errors.delete(field);field.removeAttribute('aria-invalid');const ids=(field.getAttribute('aria-describedby')||'').split(/\s+/).filter(x=>x&&x!==row.id);if(ids.length)field.setAttribute('aria-describedby',ids.join(' '));else field.removeAttribute('aria-describedby');summary(scope(field));}
 function error(field,text,{focus=true}={}){
  if(!field)return;clear(field);const node=make('small',text),id='admin-field-error-'+(++sequence);node.id=id;node.className='admin-field-error';field.insertAdjacentElement('afterend',node);field.setAttribute('aria-invalid','true');field.setAttribute('aria-describedby',((field.getAttribute('aria-describedby')||'')+' '+id).trim());errors.set(field,{node,id,text});summary(scope(field));if(focus){field.focus();field.scrollIntoView({block:'center',behavior:'smooth'});}
 }
 function reset(form){for(const [field]of errors)if(form.contains(field))clear(field);form.querySelector(':scope > .admin-validation-summary')?.remove();}
 function validate(form,{focus=true}={}){
  lastForm=form;form.querySelector(':scope > .admin-validation-summary')?.remove();for(const [field]of errors)if(form.contains(field))clear(field);let first=null;const controls=[...form.querySelectorAll('input,select,textarea')].filter(visible);
  for(const field of controls){clear(field);const text=message(field);if(text){error(field,text,{focus:false});first??=field;}}
  for(const [a,b]of [['startAt','endAt'],['from','to']]){if(form.id==='history-filters')continue;const start=controls.find(f=>f.name===a),end=controls.find(f=>f.name===b);if(!start||!end)continue;if(Boolean(start.value)!==Boolean(end.value)){const field=start.value?end:start;error(field,'أدخل تاريخ البداية والنهاية معًا.',{focus:false});first??=field;}else if(start.value&&(end.type==='date'?end.value+'T23:59:59':end.value)<=(start.type==='date'?start.value+'T00:00:00':start.value)){error(end,'يجب أن تكون نهاية العرض بعد البداية.',{focus:false});first??=end;}}
  if(first&&focus){first.focus();first.scrollIntoView({block:'center',behavior:'smooth'});}return!first;
 }
 const serverNames={Title:'العنوان',PopupType:'النوع',Details:'التفاصيل',Name:'الاسم',RoleName:'اسم الدور',CardName:'اسم البطاقة',CategoryName:'اسم التصنيف',ThemeName:'اسم الثيم',GroupName:'اسم المجموعة',TabName:'اسم التبويب',ContentAfter:'العنوان / النص الجديد',ContentBefor:'النص السابق',ContentText:'النص المحيط بالعبارات المميزة',TimestampType:'نوع التاريخ',StartAt:'بداية العرض',EndAt:'نهاية العرض',DisplayOrder:'الترتيب',Number:'الرقم',DocumentIds:'ملفات PDF',AppIds:'التطبيقات',RoleNames:'الأدوار',EventTarget:'مسار الملف أو رابط التطبيق',Target:'مسار الملف أو رابط التطبيق'};
 function server(problem){
  const form=lastForm;if(!form?.isConnected||!problem?.errors)return false;let first=null,matched=false;const notes=[];
  for(const [key]of Object.entries(problem.errors)){const name=key.split('.').at(-1),caption=serverNames[name]||'القيمة المطلوبة';const field=[...form.querySelectorAll('input,select,textarea')].find(f=>visible(f)&&(f.name?.toLowerCase()===name.toLowerCase()||f.id?.toLowerCase()===name.toLowerCase()||label(f)===caption));const text='راجع «'+caption+'»: القيمة مفقودة أو غير صحيحة أو تتجاوز الحد المسموح.';if(field){error(field,text,{focus:false});first??=field;matched=true;}else notes.push(text);}
  if(notes.length){let box=form.querySelector(':scope > .admin-validation-summary');if(!box){box=make('div');box.className='admin-validation-summary';box.setAttribute('role','alert');form.prepend(box);}for(const text of notes)box.append(make('p',text));matched=true;}
  first?.focus();return matched;
 }
 function prepare(){queued=false;document.querySelectorAll('#admin-workspace form').forEach(f=>f.noValidate=true);for(const [field,row]of errors)if(!field.isConnected){row.node.remove();errors.delete(field);}}
 document.addEventListener('submit',event=>{if(!event.target.closest('#admin-workspace'))return;if(!validate(event.target)){event.preventDefault();event.stopImmediatePropagation();}},true);
 document.addEventListener('invalid',event=>{if(!event.target.closest('#admin-workspace'))return;event.preventDefault();error(event.target,message(event.target)||'راجع قيمة هذا الحقل.',{focus:false});},true);
 for(const kind of ['input','change'])document.addEventListener(kind,event=>{const field=event.target,form=scope(field);if(!errors.has(field)&&!['startAt','endAt','from','to'].includes(field.name))return;queueMicrotask(()=>{if(['startAt','endAt','from','to'].includes(field.name)&&[...errors].some(([f])=>form.contains(f))){validate(form,{focus:false});return;}clear(field);const text=visible(field)?message(field):'';if(text)error(field,text,{focus:false});});},true);
 document.addEventListener('reset',event=>queueMicrotask(()=>reset(event.target)),true);
 document.addEventListener('click',event=>{const form=event.target.closest('form')||event.target.closest('[role="row"]');if(form?.closest('#admin-workspace'))lastForm=form;},true);
 new MutationObserver(()=>{if(!queued){queued=true;queueMicrotask(prepare);}}).observe(document.getElementById('admin-workspace'),{subtree:true,childList:true});prepare();
 window.AdminValidation={validate,error,clear,reset,server};
})();
