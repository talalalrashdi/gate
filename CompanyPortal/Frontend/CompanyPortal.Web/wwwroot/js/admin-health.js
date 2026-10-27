(() => {
  const by=id=>document.getElementById('health-'+id),base=new URL(document.querySelector('meta[name="companyportal-api-base"]').content.replace(/\/?$/,'/'),location.href),version=document.querySelector('meta[name="frontend-version"]').content;
  by('frontend-version').textContent=version;let report='',busy=false;
  const make=(tag,text,cls)=>{const e=document.createElement(tag);if(text!==undefined)e.textContent=text;if(cls)e.className=cls;return e;};
  const status={ok:'✓ OK',warning:'⚠ Warning',failed:'✗ Failed'};
  async function run(){
    if(busy)return;busy=true;by('run').disabled=by('copy').disabled=true;by('report').hidden=true;by('checks').replaceChildren();by('status').textContent='Running checks. Slow services may take up to one minute…';
    try{
      const response=await fetch(new URL('api/admin/health',base),{credentials:'include',cache:'no-store',signal:AbortSignal.timeout(70000)});
      if(!response.ok){const problem=await response.json().catch(()=>null);report=`CompanyPortal health\nFrontend: ${version}\nHTTP ${response.status}\n`+(problem?.title||'Health checks could not run.')+'\n'+(problem?.detail||'')+'\nReference: '+(problem?.reference||'Unavailable');
        by('status').textContent=response.status===401?'Windows sign-in is required. Reopen the portal using your domain account.':response.status===403?'Access denied. System health is available only to CompanyPortal super admins.':report;by('copy').disabled=false;return;}
      const data=await response.json();report=`CompanyPortal health report\nFrontend: ${version}\nChecked at: ${data.checkedAt}\nReport reference: ${data.reference}\n\n`;
      for(const check of data.checks){const card=make('article',undefined,'admin-health-check is-'+check.status),header=make('header');header.append(make('strong',status[check.status]||'⚠ Warning'),make('h2',check.title));card.append(header,make('p',check.detail));
        if(check.steps.length){card.append(make('h3','How to fix it'));const steps=make('ol');check.steps.forEach(text=>steps.append(make('li',text)));card.append(steps);}
        card.append(make('small','Reference ID: '+check.reference));by('checks').append(card);report+=`${status[check.status]} · ${check.code} · ${check.title}\n${check.detail}\n`+check.steps.map((text,i)=>`${i+1}. ${text}\n`).join('')+`Reference ID: ${check.reference}\n\n`;
      }
      const failed=data.checks.filter(c=>c.status==='failed').length,warnings=data.checks.filter(c=>c.status==='warning').length;by('status').textContent=`Finished: ${failed} failed; ${warnings} warnings. Report reference: ${data.reference}`;by('copy').disabled=false;
    }catch{report='CompanyPortal health\nFrontend: '+version+'\nCannot reach the API or the health request timed out.\n1. Check the API URL configured in the frontend.\n2. Confirm the API app pool is running and Windows authentication is enabled.\n3. Check DNS, HTTPS certificate trust and the allowed CORS origin.\n4. Review the API/IIS logs; no server reference was received.';by('status').textContent=report;by('copy').disabled=false;}
    finally{busy=false;by('run').disabled=false;by('report').value=report;}
  }
  by('run').onclick=()=>void run();by('copy').onclick=async()=>{
    try{await navigator.clipboard.writeText(report);by('status').textContent='Report copied. Paste it into your IT support request.';}
    catch{by('report').hidden=false;by('report').value=report;by('report').focus();by('report').select();by('status').textContent='Clipboard access is unavailable. Press Ctrl+C to copy the selected report.';}
  };void run();
})();
