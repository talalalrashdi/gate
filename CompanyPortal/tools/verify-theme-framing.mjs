import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import vm from 'node:vm';
class Element{
 constructor(){this.dataset={};this.attributes=new Set();this.properties=new Map();this.style={setProperty:(k,v)=>this.properties.set(k,v),removeProperty:k=>this.properties.delete(k)};this.classList={toggle(){}};}
 toggleAttribute(k,on){on?this.attributes.add(k):this.attributes.delete(k);}
 remove(){} removeAttribute(){}
 set src(value){this.url=value;this.onload?.();}
}
const body=new Element(),backdrop=new Element(),listeners=new Map();let mounted=[];
backdrop.querySelectorAll=()=>[];backdrop.append=image=>mounted.push(image);
const document={body,hidden:false,getElementById:id=>id==='systems'?{}:null,querySelector:()=>backdrop,createElement:()=>new Element(),addEventListener:(k,v)=>listeners.set(k,v)};
const window={};
vm.runInNewContext(await readFile(new URL('../Frontend/CompanyPortal.Web/wwwroot/js/theme-appearance.js',import.meta.url),'utf8'),{document,window,matchMedia:()=>({matches:false,addEventListener(){}}),setTimeout:()=>0,clearTimeout(){},CustomEvent:class{}});
const api=window.CompanyPortalTheme;
api.apply({layoutKey:'official',imagePresentation:'background'});
api.setImages({defaultImageId:1,rotateImages:false,images:[{imageId:1,url:'one'},{imageId:2,url:'two',focalX:20,focalY:80}]});
assert.equal(mounted[0].attributes.has('data-positioned'),false,'Existing unpositioned photos must retain template CSS.');
assert.equal(mounted[1].properties.get('--theme-image-position'),'20% 80%');
const count=mounted.length;
api.apply({layoutKey:'official',imagePresentation:'background',imagePositions:[{imageId:1,focalX:15.5,focalY:95}]});
assert.equal(mounted.length,count,'Adjusting position must not reload image elements.');
assert.equal(mounted[0].properties.get('--theme-image-position'),'15.5% 95%');
assert.equal(mounted[1].attributes.has('data-positioned'),false);
api.apply({layoutKey:'official',imagePresentation:'background',imagePositions:[{imageId:1,focalX:101,focalY:50}]});
assert.equal(mounted[0].attributes.has('data-positioned'),false,'Invalid positions cannot become CSS.');
api.apply({layoutKey:'national-day',imagePresentation:'background',imagePositions:[{imageId:1,focalX:25,focalY:75}]});
assert.match(body.properties.get('--portal-national-background'),/25% 75% \/ cover/);
const css=await readFile(new URL('../Frontend/CompanyPortal.Web/wwwroot/css/theme-appearance.css',import.meta.url),'utf8');
assert.match(css,/img\[data-positioned\][^{]*\{[^}]*object-fit:cover!important[^}]*object-position:var\(--theme-image-position\)!important[^}]*animation:none!important/);
console.log('PASS: independent per-image positions, unchanged legacy framing, no image reload while dragging, invalid coordinate rejection, national-day background positioning and stable cover CSS.');
