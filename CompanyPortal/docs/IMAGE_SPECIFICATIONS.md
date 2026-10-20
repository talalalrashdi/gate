# Portal image specifications

Prepared 20 October 2026 for the current **صور الواجهة** feature. Recommendations below are export guidelines; the enforced upload limits are listed separately.

## Recommended background-photo export

For a new image intended to work across the three themes, start with:

| Setting | Recommended value |
| --- | --- |
| Dimensions | **2560 × 1440 pixels** |
| Aspect ratio | **16:9**, landscape |
| Practical minimum for a new desktop background | **1920 × 1080 pixels**, preferably from an original at least this large |
| Format | **WebP** or **JPEG** for photographs |
| File-size target | **300–800 KB**; aim below **1 MB** when image detail permits |
| Starting export quality | Approximately **80–85%**, then visually check the exported file; quality scales differ between tools |
| Colour | **sRGB** |
| Orientation | Bake the correct rotation into the pixels before exporting |
| Resolution metadata | DPI/PPI is not a sizing requirement for this portal; pixel dimensions matter |

Use 2560 × 1440 as a practical starting point, not a fixed required canvas. Do not enlarge a small image just to reach this size. If a photograph needs more than 1 MB to remain clean, a modestly larger file is preferable to visible compression artifacts. The upload maximum is not the target file size.

For an intentionally panoramic desktop image, **2560 × 960** is also suitable and is close to the proportions of the existing landscape assets. It gives less vertical flexibility when the same image is cropped for mobile. Prefer 16:9 for a shared desktop/mobile group unless the panorama has been checked in both views.

## Cropping and composition

The portal fills its image surfaces using `cover`: the image keeps its proportions but parts can be cropped. Surface height changes with layout, content and screen width; no single image size guarantees that every edge will remain visible.

- Keep important subjects away from the outer edges. As a starting composition guide, leave roughly 15–20% breathing room; this is not a guaranteed safe area.
- Keep the subject near the centre and check the centre-right area on mobile. Official/work photos currently use `center 56%` positioning, changing to `65% center` on small screens.
- Leave quiet areas behind navigation, news and other text. Avoid photographs whose only important detail sits behind a card.
- Do not bake headings, dates, buttons, logos or essential information into background photographs. Backgrounds are decorative and may be cropped or covered.
- Keep some extra space around subjects because the existing photo layouts apply a small zoom/pan effect.
- Use consistent proportions and visual brightness within a rotating group. The portal does not crop or colour-correct the uploaded files for you.

Official and work layouts place dark overlays over photographs. The national-day layout applies a light tint over its assigned group image, so that image will appear lighter and less saturated. Check the actual theme before increasing brightness or contrast in the source artwork.

## Choosing a format

| Image type | Format and preparation |
| --- | --- |
| Landscape photograph | WebP or JPEG; flatten unnecessary transparency |
| Cutout, flag artwork or image requiring transparency | PNG, or WebP with transparency; crop excess empty canvas while leaving useful breathing room |
| Flat illustration or geometric artwork | Plain, passive SVG when supported by the validator; otherwise PNG/WebP |
| Portrait intended to fill the background | Use a landscape composition around the portrait; a narrow cutout alone will be heavily cropped or enlarged |

The current group feature controls **background imagery**. Selecting the imported Sultan cutout or flag artwork as a group image uses it as a background. It does **not** replace the separate foreground portrait or decorative flag layers already built into the national-day layout. Editing those individual theme layers would be a separate feature.

## SVG requirements

These restrictions apply to ordinary uploads. The shipped **اليوم الوطني - التصميم المتحرك.svg** is a reviewed, fingerprint-approved exception with embedded images and CSS animation; see [INTERFACE_IMAGES.md](INTERFACE_IMAGES.md#animated-national-day-svg).

- Use a valid `<svg xmlns="http://www.w3.org/2000/svg">` root.
- Provide positive pixel `width`/`height`, or a valid `viewBox` with positive dimensions. A landscape viewBox such as `0 0 2560 1440` is appropriate for background artwork; this defines proportions, not a raster resolution.
- Export as a **plain/static SVG**, using presentation attributes such as `fill` and `stroke` rather than stylesheets or `style` attributes.
- Supported artwork includes basic shapes, paths, groups, text, gradients, clipping and masks. Local `url(#id)` references are accepted.
- Scripts, event handlers, animation, links, external resources, embedded images, foreignObject, filters and other unsupported elements/attributes are rejected. XML DTDs and processing instructions are also rejected.
- Convert lettering to paths when its appearance must not depend on locally installed fonts. Avoid essential background text even when converted to paths.
- Prefer a simple file below **200 KB** when practical; the enforced SVG maximum is **1 MiB**.

## Enforced upload limits

These are acceptance limits, not recommended export sizes:

| Rule | Current limit |
| --- | --- |
| Accepted extensions | `.jpg`, `.jpeg`, `.png`, `.webp`, `.svg` |
| Raster file size | **10 MiB** maximum by default (10,485,760 bytes) |
| SVG file size | **1 MiB** maximum (1,048,576 bytes), plus XML/complexity validation |
| Dimensions | Each dimension must be **1–12,000 pixels** |
| Total dimensions | At most **40,000,000 pixels**: width × height |
| Images selected per group | **100** maximum |
| Rotation interval | **3–3600 seconds**; **8 seconds** is a useful starting point |

The API's `InterfaceImages:MaximumUploadMb` setting can lower the per-file limit to 1–10 MiB. Raster files must match their extensions and pass the current container/dimension checks. SVG dimensions follow the same dimension limits. Raster validation is not a full pixel decode; a file that cannot be rendered falls back to the theme's original images.

For most rotating groups, start with **3–6 images** rather than the maximum. Images are stored in SQL Server and served to employees from the API. Smaller, well-compressed images reduce transfer time and database/backup growth even inside an air-gapped network.

## Existing imported assets

These are the actual source dimensions and approximate binary sizes, measured from the frontend files. They are available in the admin library with Arabic names; their original proportions are retained.

| Library name | Dimensions | File size | Original purpose |
| --- | --- | --- | --- |
| قلعة عُمانية.png | 2048 × 768 | 2.25 MiB | Panoramic photograph |
| جامع عُماني.png | 2172 × 724 | 1.80 MiB | Panoramic photograph |
| كثبان عُمان.png | 2048 × 768 | 1.80 MiB | Panoramic photograph |
| السلطان هيثم بن طارق.png | 875 × 1798 | 1.14 MiB | Foreground portrait cutout |
| زخرفة العلم العُماني.png | 1254 × 1254 | 1.16 MiB | Decorative flag artwork |
| اليوم الوطني - التصميم الكامل.jpg | 2560 × 1440 | 207 KiB | Static combined calligraphy, portrait and flag composition |
| اليوم الوطني - التصميم المتحرك.svg | 2560 × 1440 viewBox | Approximately 3.08 MiB | Self-contained animated calligraphy, portrait and flag composition |

The landscape PNGs remain usable; they do not have to be re-exported before selecting them. For future uploads, JPEG/WebP usually offers a smaller photograph file. Keep the original masters if preparing additional exports.

## Before publishing a group

1. Preview the selected images and choose their order and default image.
2. Save the group, then save its link to the intended theme.
3. Reload the portal and inspect a wide desktop view and a narrow/mobile view, including text readability and subject cropping.
4. Check both static display and rotation if rotation will be enabled. Reduced-motion preferences and hidden pages pause rotation.

For database storage, permissions, deployment and the import script, see [INTERFACE_IMAGES.md](INTERFACE_IMAGES.md).

## Current desktop hero behaviour

The portal is intended for desktop use; the theme editor no longer has a mobile preview. Both image modes fill the hero width with proportional cover cropping. Panoramic photographs such as 2560 × 960 reduce vertical cropping compared with 16:9; keep important details away from the top/bottom edges and inspect the current desktop preview. Complete-design mode replaces the original decoration; it no longer adds a separate contained image block or side gaps. See THEME_PUBLICATION.md for the current display rules.
