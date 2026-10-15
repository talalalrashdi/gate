"""Trace the two-color calligraphy into self-contained, animated SVG paths."""
from collections import defaultdict
from pathlib import Path
import math
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
pixels = np.array(Image.open(ROOT / 'dist/assets/oman-national-calligraphy.png').convert('RGBA'))
height, width = pixels.shape[:2]
rgba = pixels.astype(np.int16)


def simplify(points, tolerance=1.15):
    if len(points) < 3:
        return points
    a, b = points[0], points[-1]
    dx, dy = b[0] - a[0], b[1] - a[1]
    denom = math.hypot(dx, dy)
    distances = [abs(dy * (p[0] - a[0]) - dx * (p[1] - a[1])) / denom if denom else math.dist(p, a) for p in points[1:-1]]
    if not distances or max(distances) <= tolerance:
        return [a, b]
    split = distances.index(max(distances)) + 1
    return simplify(points[:split + 1], tolerance)[:-1] + simplify(points[split:], tolerance)


def trace(mask):
    seen = np.zeros(mask.shape, dtype=bool)
    components = []
    for y, x in zip(*np.where(mask)):
        if seen[y, x]:
            continue
        stack, coords = [(int(x), int(y))], []
        seen[y, x] = True
        while stack:
            px, py = stack.pop()
            coords.append((px, py))
            for nx, ny in ((px - 1, py), (px + 1, py), (px, py - 1), (px, py + 1)):
                if 0 <= nx < width and 0 <= ny < height and mask[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    stack.append((nx, ny))
        # Remove isolated compression/cleanup specks, retaining the original dots.
        if len(coords) < 55:
            continue
        edges = defaultdict(list)
        for px, py in coords:
            if py == 0 or not mask[py - 1, px]:
                edges[(px, py)].append((px + 1, py))
            if px == width - 1 or not mask[py, px + 1]:
                edges[(px + 1, py)].append((px + 1, py + 1))
            if py == height - 1 or not mask[py + 1, px]:
                edges[(px + 1, py + 1)].append((px, py + 1))
            if px == 0 or not mask[py, px - 1]:
                edges[(px, py + 1)].append((px, py))
        loops = []
        while edges:
            first = next(iter(edges))
            current, points = first, [first]
            while True:
                following = edges[current].pop()
                if not edges[current]:
                    del edges[current]
                current = following
                points.append(current)
                if current == first:
                    break
            if len(points) < 5:
                continue
            mid = max(range(len(points)), key=lambda i: math.dist(points[i], first))
            reduced = simplify(points[:mid + 1])[:-1] + simplify(points[mid:])[:-1]
            if len(reduced) >= 3:
                loops.append('M' + ' '.join(f'{x},{y}' for x, y in reduced) + 'Z')
        if loops:
            components.append((max(x for x, _ in coords), len(coords), ''.join(loops)))
    return sorted(components, reverse=True)


paths = []
for channel, color, start in ((0, '#e60000', 0.15), (1, '#008000', 1.5)):
    other = 1 - channel
    mask = (rgba[:, :, 3] > 95) & (rgba[:, :, channel] > 50) & (rgba[:, :, channel] > rgba[:, :, other] * 1.25)
    for right, area, data in trace(mask):
        delay = start + (1 - right / width) * 1.3
        duration = 2.5 if area > 15000 else 1.2
        paths.append(f'<path class="bt-vector-ink" fill="{color}" stroke="{color}" fill-rule="evenodd" pathLength="1" style="--draw-delay:{delay:.2f}s;--draw-duration:{duration:.2f}s;--fill-delay:{delay + duration * .65:.2f}s" d="{data}"/>')

style = '''.bt-vector-ink{fill-opacity:0;stroke-width:2;stroke-linecap:round;stroke-linejoin:round;stroke-dasharray:1;stroke-dashoffset:1;animation:bt-vector-draw var(--draw-duration) cubic-bezier(.35,0,.2,1) var(--draw-delay) both,bt-vector-fill .85s ease var(--fill-delay) both}@keyframes bt-vector-draw{0%{stroke-dashoffset:1;stroke-opacity:.8}80%{stroke-opacity:1}100%{stroke-dashoffset:0;stroke-opacity:0}}@keyframes bt-vector-fill{to{fill-opacity:1}}@media(prefers-reduced-motion:reduce){.bt-vector-ink{animation:none;fill-opacity:1;stroke:none}}'''
svg = f'<svg xmlns="http://www.w3.org/2000/svg" class="bt-national-calligraphy" viewBox="0 0 {width} {height}" width="{width}" height="{height}" role="img" aria-label="اليوم الوطني العماني"><style>{style}</style>' + ''.join(paths) + '</svg>'
output = ROOT / 'dist/assets/oman-national-calligraphy.svg'
output.write_text(svg, encoding='utf-8')
print(f'{len(paths)} vector paths, {len(svg.encode())} bytes, no embedded raster images')
