"""Prepare a deterministic browser export of the existing national-day artwork.
Run from any directory. Open the generated HTML at 2560 x 1440 and save its
viewport as national-day-complete.jpg. Original source assets are unchanged.
"""
from pathlib import Path
import base64
import re
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
web = root / "Frontend/CompanyPortal.Web"
source = (web / "Views/Home/_PersonalWorkspace.cshtml").read_text(encoding="utf-8")
match = re.search(r'<svg[^>]*class="theme-national-day-calligraphy"[\s\S]*?</svg>', source)
if not match:
    raise RuntimeError("National-day calligraphy was not found")
ET.register_namespace("", "http://www.w3.org/2000/svg")
svg = ET.fromstring(match.group())
for parent in svg.iter():
    for child in list(parent):
        if child.tag.endswith("}style"):
            parent.remove(child)
    for key in ("style", "class", "aria-hidden", "focusable"):
        parent.attrib.pop(key, None)
    if parent.tag.endswith("}path"):
        parent.set("fill-opacity", "1")
        parent.set("stroke", "none")

def data_image(name):
    return "data:image/png;base64," + base64.b64encode((web / "wwwroot/assets" / name).read_bytes()).decode("ascii")

calligraphy = "data:image/svg+xml;base64," + base64.b64encode(ET.tostring(svg, encoding="utf-8")).decode("ascii")
portrait = data_image("sultan-haitham-cutout.png")
flag = data_image("oman-national-silk-v2.png")
html = """<!doctype html><html lang="ar"><meta charset="utf-8"><title>اليوم الوطني — صورة موحدة</title>
<style>
*{box-sizing:border-box}html,body{margin:0;width:2560px;height:1440px;overflow:hidden}
body{position:relative;background:radial-gradient(ellipse 58% 100% at 0% 65%,#b4ddc7 0%,transparent 78%),radial-gradient(ellipse 40% 65% at 14% 0%,#f0c9c8 0%,transparent 80%),linear-gradient(115deg,#dceee3 0%,#f5f9f3 52%,#fffaf4 100%)}
img{display:block;position:absolute;object-fit:contain}
.portrait{z-index:1;left:175px;bottom:0;width:665px;height:1366px;filter:drop-shadow(0 20px 28px #17412c16)}
.title{z-index:3;right:110px;top:430px;width:1360px;height:auto}
.flag-front{z-index:2;left:-435px;bottom:-705px;width:1740px;height:1740px;filter:blur(3px) drop-shadow(0 20px 30px #173b2714)}
.flag-left{z-index:0;left:-920px;top:-940px;width:1600px;height:1600px;transform:rotate(-25deg);opacity:.55;filter:blur(20px)}
.flag-right{z-index:0;right:-850px;top:-640px;width:1280px;height:1280px;transform:rotate(155deg);opacity:.4;filter:blur(24px)}
</style><img class="flag-left" src="FLAG" alt=""><img class="flag-right" src="FLAG" alt=""><img class="portrait" src="PORTRAIT" alt="السلطان هيثم بن طارق"><img class="flag-front" src="FLAG" alt="العلم العماني"><img class="title" src="CALLIGRAPHY" alt="اليوم الوطني العماني"></html>"""
html = html.replace("FLAG", flag).replace("PORTRAIT", portrait).replace("CALLIGRAPHY", calligraphy)
out = root / "Backend/artifacts/national-day-export"
out.mkdir(parents=True, exist_ok=True)
(out / "national-day-artwork.html").write_text(html, encoding="utf-8")
print(out / "national-day-artwork.html")

# Self-contained SVG keeps the original path drawing/fill animation and flag motion.
animated = ET.fromstring(match.group().replace("@@", "@"))
for key in ("class", "aria-hidden", "focusable"):
    animated.attrib.pop(key, None)
animated.set("x", "1090"); animated.set("y", "430")
animated.set("width", "1360"); animated.set("height", "454")
animation_svg = """<svg xmlns="http://www.w3.org/2000/svg" width="2560" height="1440" viewBox="0 0 2560 1440">
<title>اليوم الوطني العماني</title>
<desc>تصميم اليوم الوطني: الخط العربي المتحرك مع السلطان هيثم بن طارق والعلم العماني</desc>
<defs>
 <linearGradient id="base" x1="0" y1="0" x2="1" y2=".5"><stop stop-color="#dceee3"/><stop offset=".52" stop-color="#f5f9f3"/><stop offset="1" stop-color="#fffaf4"/></linearGradient>
 <radialGradient id="green"><stop stop-color="#b4ddc7"/><stop offset="1" stop-color="#b4ddc7" stop-opacity="0"/></radialGradient>
 <radialGradient id="pink"><stop stop-color="#f0c9c8"/><stop offset="1" stop-color="#f0c9c8" stop-opacity="0"/></radialGradient>
 <filter id="soft"><feGaussianBlur stdDeviation="20"/></filter>
 <filter id="front-soft"><feGaussianBlur stdDeviation="3"/></filter>
 <image id="flag" width="1254" height="1254" href="FLAG"/>
</defs>
<style>
.flag-motion{transform-box:fill-box;transform-origin:60% 65%;animation:flag-unfurl 5s ease-out both}
@keyframes flag-unfurl{0%{opacity:0;transform:translate(-25px,18px) rotate(-5deg) scale(.96)}40%{opacity:1;transform:translate(0,-9px) rotate(1deg) scale(1.01)}75%{transform:translate(0,4px) rotate(-.7deg)}100%{opacity:1;transform:none}}
@media(prefers-reduced-motion:reduce){.flag-motion{animation:none}}
</style>
<rect width="2560" height="1440" fill="url(#base)"/>
<ellipse cx="0" cy="936" rx="1485" ry="1440" fill="url(#green)"/>
<ellipse cx="358" cy="0" rx="1024" ry="936" fill="url(#pink)"/>
<g opacity=".55" filter="url(#soft)" transform="translate(-920,-940) rotate(-25,800,800)"><g class="flag-motion"><use href="#flag" width="1600" height="1600" transform="scale(1.276)"/></g></g>
<g opacity=".4" filter="url(#soft)" transform="translate(2130,-640) rotate(155,640,640)"><g class="flag-motion"><use href="#flag" transform="scale(1.021)"/></g></g>
<image x="175" y="74" width="665" height="1366" href="PORTRAIT"/>
<g transform="translate(-435,405)" filter="url(#front-soft)"><g class="flag-motion"><use href="#flag" transform="scale(1.388)"/></g></g>
CALLIGRAPHY
</svg>"""
animation_svg = animation_svg.replace("FLAG", flag).replace("PORTRAIT", portrait).replace("CALLIGRAPHY", ET.tostring(animated, encoding="unicode"))
svg_path = web / "wwwroot/assets/national-day-complete.svg"
svg_path.write_bytes(animation_svg.encode("utf-8"))
# Preview in image context, as the portal will display it.
(out / "national-day-animated.html").write_text('<!doctype html><html><meta charset="utf-8"><title>Animated national-day artwork</title><style>body{margin:0}img{display:block;width:100vw;height:auto}</style><img src="data:image/svg+xml;base64,' + base64.b64encode(animation_svg.encode("utf-8")).decode("ascii") + '" alt="اليوم الوطني العماني"></html>', encoding="utf-8")
import hashlib
print(svg_path)
print("SHA256:", hashlib.sha256(svg_path.read_bytes()).hexdigest().upper())
