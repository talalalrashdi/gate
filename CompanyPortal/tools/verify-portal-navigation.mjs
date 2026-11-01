import assert from 'node:assert/strict';
import vm from 'node:vm';
import {readFile} from 'node:fs/promises';
const source=await readFile(new URL('../Frontend/CompanyPortal.Web/wwwroot/js/portal-navigation.js',import.meta.url),'utf8');
for(const hash of ['#editorial-news','#editorial-events','#editorial-magazine','#safety','#digital-library']){
 const handlers={},win={},timers=new Map(),frames=[],scrolls=[],pushes=[];let y=0,header=140,n=0;
 const target={getBoundingClientRect:()=>({top:(hash==='#editorial-news'?980:900)-y})},masthead={getBoundingClientRect:()=>({top:900-y})};
 const document={addEventListener:(k,fn)=>handlers[k]=fn,querySelector:s=>s===hash?target:s==='.editorial-masthead'?masthead:s==='.portal-header'?{getBoundingClientRect:()=>({bottom:header-52})}:s==='.portal-media-subnav'?{getBoundingClientRect:()=>({bottom:header})}:null};
 const window={get scrollY(){return y;},addEventListener:(k,fn)=>win[k]=fn,removeEventListener:(k,fn)=>{if(win[k]===fn)delete win[k];},scrollTo:opts=>{y=opts.top;scrolls.push(opts);}};
 vm.runInNewContext(source,{window,document,history:{pushState:(...a)=>pushes.push(a)},matchMedia:()=>({matches:false}),requestAnimationFrame:fn=>(frames.push(fn),1),cancelAnimationFrame(){},setTimeout:fn=>(timers.set(++n,fn),n),clearTimeout:id=>timers.delete(id)});
 const event={button:0,target:{closest:s=>s.startsWith('.portal-nav ')?null:({getAttribute:()=>hash})},preventDefault(){this.prevented=true;}};handlers.click(event);assert.equal(event.prevented,true);frames.shift()();assert.equal(y,748);assert.equal(pushes[0][2],hash);
 header=122;win.scrollend();assert.equal(y,766,'Final alignment must account for changed pinned header');assert.equal((hash==='#editorial-news'?masthead:target).getBoundingClientRect().top,134);assert.equal(timers.size,0);
 handlers.click({...event,ctrlKey:true,prevented:false});assert.equal(pushes.length,1,'Modified click intercepted');
 handlers.click(event);frames.shift()();const before=scrolls.length;win.wheel();assert.equal(timers.size,0);assert.equal(win.scrollend,undefined);assert.equal(scrolls.length,before,'User scroll caused a late snap');
}
console.log('PASS all five secondary anchors: actual header offset, settled alignment, modifiers, user cancellation.');
