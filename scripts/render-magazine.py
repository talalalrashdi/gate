"""Render the source PDF into local page assets for the monthly reader."""
import json
from pathlib import Path
import pypdfium2 as pdfium

root = Path(__file__).resolve().parents[1]
source = root / 'dist/assets/magazines/39.pdf'
output = source.parent / '39-pages'
output.mkdir(parents=True, exist_ok=True)
pdf = pdfium.PdfDocument(str(source))
pages = []
for index in range(len(pdf)):
    page = pdf[index]
    width, height = page.get_size()
    bitmap = page.render(scale=1500 / width)
    filename = f'{index + 1:03}.webp'
    bitmap.to_pil().convert('RGB').save(output / filename, 'WEBP', quality=86)
    pages.append({'file': filename, 'width': width, 'height': height})
    bitmap.close()
    page.close()
    if (index + 1) % 30 == 0:
        print(f'Rendered {index + 1}/{len(pdf)}', flush=True)
(output / 'manifest.json').write_text(json.dumps({'title': 'وُجهات', 'pages': pages}, ensure_ascii=False), encoding='utf-8')
pdf.close()
print(f'Completed {len(pages)} pages', flush=True)
