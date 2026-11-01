import assert from 'node:assert/strict';import vm from 'node:vm';import {readFile} from 'node:fs/promises';
let jobs=new Map(),number=0,mounted=[],requests=[];const listeners=new Map();
class Image {
 dataset={};style={setProperty(){},removeProperty(){}};classList={toggle(){}};url=null;complete=false;naturalWidth=0;
 toggleAttribute(){}remove(){}removeAttribute(k){if(k==='src'){this.url=null;this.complete=false;this.naturalWidth=0;}}
 getAttribute(k){return k==='src'?this.url:null;}
 set src(value){this.url=value;this.complete=true;this.naturalWidth=100;requests.push(value);this.onload?.();}
}
const body=new Image(),backdrop=new Image(),reduced={matches:false,addEventListener(){}};const fallback=new Image();fallback.dataset.src='fallback';backdrop.querySelectorAll=()=>[fallback];backdrop.append=i=>mounted.push(i);
const document={body,hidden:false,getElementById:id=>id==='systems'?{}:null,querySelector:()=>backdrop,createElement:()=>new Image(),addEventListener:(k,v)=>listeners.set(k,v)};const window={};
vm.runInNewContext(await readFile(new URL('../Frontend/CompanyPortal.Web/wwwroot/js/theme-appearance.js',import.meta.url),'utf8'),{document,window,matchMedia:()=>reduced,setTimeout:(f,n)=>{jobs.set(++number,{f,n});return number;},clearTimeout:n=>jobs.delete(n),CustomEvent:class{}});
const run=delay=>{const pair=[...jobs].find(([,j])=>j.n===delay);assert.ok(pair,'Expected timer '+delay);jobs.delete(pair[0]);pair[1].f();};
window.CompanyPortalTheme.apply({layoutKey:'official',imagePresentation:'background'});window.CompanyPortalTheme.setImages({defaultImageId:1,rotateImages:true,rotationSeconds:8,images:[{imageId:1,url:'one'},{imageId:2,url:'two'},{imageId:3,url:'three'}]});
assert.deepEqual(requests,['one'],'Only visible image loads initially');run(6000);assert.deepEqual(requests,['one','two'],'Next image preloads two seconds before rotation');run(8000);assert.deepEqual(requests,['one','two'],'Rotation reuses the prepared image');document.hidden=true;listeners.get('visibilitychange')();assert.ok(![...jobs.values()].some(j=>j.n===6000),'Hidden page cancels preload');
window.CompanyPortalTheme.setImages(null);assert.equal(backdrop.dataset.managed,undefined);run(0);assert.equal(requests.at(-1),'fallback','Preview reset restores the deferred built-in image');
const razor=await readFile(new URL('../Frontend/CompanyPortal.Web/Views/Home/_PersonalWorkspace.cshtml',import.meta.url),'utf8');assert.match(razor,/<img data-src="[^>]*hero-oman-fort/);assert.doesNotMatch(razor,/<img src="[^>]*hero-oman-fort/);
console.log('PASS hero loading: deferred fallback markup, selected image only, next-image preload, cached rotation, hidden-page cancellation and fallback reset.');
