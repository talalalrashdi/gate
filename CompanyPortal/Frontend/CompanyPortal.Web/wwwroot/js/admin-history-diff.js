/* Pure comparison helpers. No HTML interpretation, network or writes. */
(() => {
  const names={eventtype:'نوع الفعالية',eventtarget:'الرابط أو مسار الملف',appurl:'رابط التطبيق',startat:'بداية العرض',endat:'نهاية العرض',imagepositions:'مواضع صور الثيم',focalx:'الموضع الأفقي',focaly:'الموضع الرأسي',cardname:'اسم البطاقة',cardtype:'نوع البطاقة',displayorder:'ترتيب العرض',isfixed:'موضع ثابت',isdisplayed:'إظهار الفعالية',active:'نشط',audience:'الجمهور',apps:'التطبيقات',roles:'الأدوار',categoryname:'اسم التصنيف',description:'الوصف',categoryid:'معرّف التصنيف',category:'التصنيف',tabname:'اسم التبويب',sectionkey:'القسم',folderid:'معرّف المجلد',documents:'الوثائق',documentid:'معرّف الوثيقة',documentname:'اسم الوثيقة',timestamp:'التاريخ الرئيسي',timestamp2:'التاريخ الثاني',timestamptype:'نوع التاريخ',contentbefor:'النص السابق',contentafter:'النص الجديد والعنوان',contenttext:'الصياغة',durationdays:'مدة العرض بالأيام',decisiontypes:'أنواع القرارات',decisionid:'معرّف القرار',fromat:'من',toat:'إلى',ishidden:'مخفي',medianame:'اسم الوسيط',mediatype:'نوع الوسيط',mediapath:'مسار الملف',mediagroupid:'معرّف الألبوم',groupname:'اسم المجموعة',covermediaid:'صورة الغلاف',imagename:'اسم الصورة',contenttype:'نوع الملف',pixelwidth:'عرض الصورة',pixelheight:'ارتفاع الصورة',rotateimages:'تدوير الصور',rotationseconds:'فترة التدوير بالثواني',defaultimageid:'الصورة الافتراضية',items:'الصور والترتيب',imageid:'معرّف الصورة',themename:'اسم الثيم',layoutkey:'قالب التصميم',isdefault:'افتراضي',visibility:'الإتاحة',deleted:'محذوف',primarycolor:'اللون الرئيسي',accentcolor:'لون التمييز',backgroundcolor:'لون الخلفية',overlayopacity:'قوة طبقة التباين',foregroundpreset:'لون النص فوق الصورة',imagepresentation:'طريقة عرض الصورة',imagegroupid:'معرّف مجموعة الصور',previewroles:'أدوار المعاينة',title:'العنوان',number:'الرقم',sortorder:'الترتيب',colorname:'اسم اللون',summary:'الوصف المختصر',guidetext:'نص الدليل',actions:'الخطوات',usersupdated:'عدد المستخدمين الذين طُبّق عليهم',id:'المعرّف'};
  const label=k=>names[k.toLowerCase()]||'حقل إضافي ('+k+')';
  const canonical=v=>JSON.stringify(v&&typeof v==='object'&&!Array.isArray(v)?Object.fromEntries(Object.keys(v).sort().map(k=>[k,JSON.parse(canonical(v[k]))])):v??null);
  const identity=v=>v&&typeof v==='object'?String(v.ImageId??v.DocumentID??v.AppId??canonical(v)):canonical(v);
  const text=v=>v===undefined||v===null?'—':typeof v==='boolean'?(v?'نعم':'لا'):Array.isArray(v)?v.map(text).join('\n'):typeof v==='object'?Object.entries(v).map(([k,x])=>label(k)+': '+text(x)).join(' · '):String(v);
  function compare(before,after){
    const a=before||{},b=after||{};
    return [...new Set([...Object.keys(a),...Object.keys(b)])].map(key=>{
      const old=a[key],next=b[key],left=Array.isArray(old)?old:[],right=Array.isArray(next)?next:[];
      return {key,label:label(key),before:text(old),after:text(next),changed:canonical(old)!==canonical(next),
        added:right.filter(v=>!left.some(x=>identity(x)===identity(v))).map(text),removed:left.filter(v=>!right.some(x=>identity(x)===identity(v))).map(text)};
    });
  }
  window.AdminHistoryDiff={compare,label};
})();
