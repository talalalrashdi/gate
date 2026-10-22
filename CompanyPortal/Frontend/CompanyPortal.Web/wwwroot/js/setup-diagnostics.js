(() => {
  const base=document.querySelector('meta[name="companyportal-api-base"]')?.content;
  const run=document.getElementById('setup-run'),copy=document.getElementById('setup-copy'),status=document.getElementById('setup-status'),results=document.getElementById('setup-results'),summary=document.getElementById('setup-summary');
  let report=null;
  const labels={pass:'نجح',fail:'فشل',warn:'يحتاج إعدادًا',skip:'لم يُفحص',manual:'اختبار يدوي'};
  function show(check){const card=document.createElement('section');card.className='setup-check';card.dataset.status=check.status;const title=document.createElement('h2');title.textContent=`${labels[check.status]||check.status} · ${check.title}`;const code=document.createElement('code');code.textContent=check.code;card.append(title,code);for(const text of [check.detail,check.nextStep&&`الخطوة التالية: ${check.nextStep}`])if(text){const p=document.createElement('p');p.textContent=text;card.append(p);}results.append(card);}
  run.addEventListener('click',async()=>{
    results.replaceChildren();summary.textContent='';report=null;copy.disabled=true;run.disabled=true;status.textContent='جارٍ الفحص… قد يستغرق نحو دقيقة.';
    try{
      if(!base)throw new Error('API_BASE_MISSING');
      const root=new URL(base.replace(/\/?$/,'/'),location.href);
      const health=await fetch(new URL('health',root),{credentials:'include',cache:'no-store',signal:AbortSignal.timeout(10000)});
      if(!health.ok){show({code:`API_HTTP_${health.status}`,status:'fail',title:'الوصول إلى API',detail:'لم ينجح طلب health.',nextStep:health.status===401?'فعّل مصادقة Windows في IIS وثقة المتصفح بعنوان الشبكة الداخلية.':'تحقق من مسار /backend وتطبيق IIS وحزمة استضافة .NET 10 وسجل Windows.'});return;}
      show({code:'API_HTTP',status:'pass',title:'الوصول إلى API',detail:'وصل المتصفح إلى API. هذا وحده لا يثبت اتصال SQL أو Exchange.'});
      const response=await fetch(new URL('api/admin/diagnostics/run',root),{method:'POST',credentials:'include',cache:'no-store',headers:{'X-CompanyPortal-Request':'diagnostics'},signal:AbortSignal.timeout(65000)});
      if(!response.ok){let detail='';if(response.status===503){try{detail=(await response.json()).detail||'';}catch{}}
        const messages={401:'تعذر التحقق من حساب Windows. راجع إعدادات مصادقة IIS وثقة المتصفح.',403:'الحساب لا يملك صلاحية التشخيص، أو أصل الطلب غير مسموح. استخدم مدير البوابة أو أضف حساب Windows المعتمد إلى Diagnostics:BootstrapAccounts في API.',404:'التشخيص معطّل أو ملفات API قديمة أو عنوان Api:BaseUrl غير صحيح.',503:detail||'تعذر التحقق من صلاحية المدير عبر SQL. أضف حساب Windows المعتمد إلى Diagnostics:BootstrapAccounts في API مؤقتًا.'};
        show({code:`DIAGNOSTICS_HTTP_${response.status}`,status:'fail',title:'صلاحية وتشغيل التشخيص',detail:messages[response.status]||'تعذر تنفيذ الطلب. راجع سجل API.',nextStep:'عدّل الإعدادات على الخادم ثم أعد تشغيل تطبيق API وأعد الفحص.'});return;
      }
      report=await response.json();if(!Array.isArray(report.checks))throw new Error('INVALID_RESPONSE');report.checks.forEach(show);copy.disabled=false;
      const failures=report.checks.filter(x=>x.status==='fail').length;
      summary.textContent=`${failures?'توجد خطوات فاشلة: '+failures:'اكتمل الفحص؛ راجع التحذيرات والخطوات اليدوية.'} · مرجع السجل: ${report.reference}`;
    }catch(error){show({code:error.name==='TimeoutError'?'BROWSER_TIMEOUT':'API_UNREACHABLE',status:'fail',title:'اتصال المتصفح',detail:'تعذر الاتصال أو انتهت المهلة. قد يكون السبب عنوان API أو DNS أو HTTPS أو CORS أو توقف التطبيق.',nextStep:'افتح عنوان API/health من نفس المتصفح. تحقق من الشهادة وApi:BaseUrl وIIS، ومن Cors:AllowedOrigins إذا كان الأصل مختلفًا. لا تتجاوز أخطاء الشهادة.'});}
    finally{run.disabled=false;status.textContent='انتهى الفحص. يمكنك تصحيح الإعدادات وإعادة المحاولة.';}
  });
  copy.addEventListener('click',async()=>{if(!report)return;try{await navigator.clipboard.writeText(JSON.stringify(report,null,2));status.textContent='نُسخ التقرير؛ راجعه قبل مشاركته لأنه يتضمن أسماء حسابات Windows.';}catch{status.textContent='تعذر النسخ؛ حدد النتائج وانسخها يدويًا.';}});
})();
