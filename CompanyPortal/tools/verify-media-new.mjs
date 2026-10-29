import assert from 'node:assert/strict';import vm from 'node:vm';import {readFile} from 'node:fs/promises';
for(const simulation of [false,true]){
 const listeners={},clicks={};const link={addEventListener:(k,f)=>clicks[k]=f};const badge={hidden:true,closest:()=>link};let requests=[],complete;
 const document={querySelector:s=>s==='[data-media-new]'?badge:{content:'http://api.test/'},getElementById:()=>simulation?{}:null,addEventListener:(k,f)=>listeners[k]=f};
 vm.runInContext(await readFile(new URL('../Frontend/CompanyPortal.Web/wwwroot/js/media-new.js',import.meta.url),'utf8'),vm.createContext({document,URL,location:{href:'http://portal.test/'},AbortSignal,fetch:async(url,options)=>{requests.push({url,options});return new Promise(resolve=>complete=resolve);}}));
 const catalog=ids=>listeners['portal:media-catalog']({detail:ids===null?null:{unreadMediaIds:ids}}),tick=()=>new Promise(setImmediate);
 assert.equal(requests.length,0,'Badge must reuse existing catalog');catalog(['1','2']);assert.equal(badge.hidden,false);
 clicks.click();clicks.click();assert.equal(requests.length,1,'Repeat click duplicated acknowledgement');assert.deepEqual(JSON.parse(requests[0].options.body).mediaIds,[1,2]);assert.equal(badge.hidden,true);
 complete({ok:true});await tick();catalog(['1','2']);assert.equal(badge.hidden,true,'Stale catalog resurrected acknowledged badge');catalog(['1','2','3']);assert.equal(badge.hidden,false,'New photo/video not noticed');
 clicks.click();complete({ok:false});await tick();assert.equal(badge.hidden,false,'Failed save must restore badge');clicks.click();complete({ok:true});await tick();assert.equal(badge.hidden,true);
 catalog(['4']);
 if(simulation){const count=requests.length;listeners['portal:simulate']({detail:{kind:'media-photo'}});assert.equal(badge.hidden,false);clicks.click();await tick();assert.equal(badge.hidden,true);assert.equal(requests.length,count,'Simulation wrote real read state');listeners['portal:simulate']({detail:{kind:'reset'}});assert.equal(badge.hidden,false,'Reset lost real unread state');}else assert.equal(listeners['portal:simulate'],undefined);
 catalog(null);assert.equal(badge.hidden,true);clicks.click();const count=requests.length;catalog(['5']);assert.equal(requests.length,count+1,'Early click did not acknowledge loaded snapshot');complete({ok:true});await tick();assert.equal(badge.hidden,true);
 assert.ok(requests.every(r=>r.options.method==='POST'&&r.options.headers['X-CompanyPortal-Request']==='media-read'));
}
console.log('PASS: media unread badge, single batch/click coalescing, stale response protection, new IDs, failed save retry, early click, no extra catalog request and memory-only simulation/reset.');
