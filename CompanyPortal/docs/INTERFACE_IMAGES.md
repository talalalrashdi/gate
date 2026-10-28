# Interface images and theme groups

Implemented 19 October 2026. Open **صور الواجهة** in administration, or `/admin/images`.

For recommended dimensions, export formats, compression, cropping and SVG specifications, see [IMAGE_SPECIFICATIONS.md](IMAGE_SPECIFICATIONS.md).

## What administrators can do

- Upload one or several JPEG, PNG, WebP or passive SVG files and preview them in the shared library.
- Create or edit an Arabic-named group and select existing images; an image can belong to several groups.
- Move selected images up/down, remove memberships, enable/disable individual members and choose an active default image.
- Enable automatic rotation, set a 3–3600 second interval, or show only the default image. Disable a group without deleting it.
- Assign an active group to any existing theme, or select the theme's original images. Several themes may share a group.

Uploads are saved immediately. Group edits are saved using **حفظ المجموعة**; theme assignments have their own **حفظ الربط** buttons. Removing an image from a group keeps it in the library. There is no library-delete endpoint in this version. Group edits use last-save-wins; no concurrent-edit locking UI or audit history is included.

Image groups are global administrator content, not employee-owned custom cards. Employee ThemeId preferences are unchanged. Theme creation is now implemented: see [THEME_ADMINISTRATION.md](THEME_ADMINISTRATION.md). Themes reference ImageGroupId without duplicating image data or requiring an English display name. LayoutKey still selects an implemented layout.

## Database

Apply `Backend/Database/Scripts/015_InterfaceImages.sql` after 014. It is safe to rerun and does not seed images or change existing theme assignments.

| Table | Data |
| --- | --- |
| `Master.Images` | Identity ImageId, ImageName nvarchar(200), ContentType nvarchar(100), ImageData varbinary(max), dimensions, Active and LastChangeAt |
| `Master.ImageGroups` | Identity ImageGroupId, GroupName nvarchar(200), RotateImages, RotationSeconds, nullable DefaultImageId, Active and LastChangeAt |
| `Master.ImageGroupItems` | Identity ImageGroupItemId, group/image foreign keys, DisplayOrder, Active and LastChangeAt |
| `Master.Themes` | New nullable ImageGroupId foreign key |

All three new tables have Active bit default 1 and LastChangeAt datetime default GETDATE(). Actual group-property/membership changes advance the group timestamp; no-op saves preserve it. Existing item IDs remain stable when updating a membership. Removing a membership deletes only that relationship. Images are stored once in CompanyPortal, so normal database backup/restore includes their binary content.

Procedures: `Master.Images_getAll`, `Images_add`, `Images_getContent`, `ImageGroups_getAll`, `ImageGroups_save`, `Themes_getImages`. A theme chooses its group only in the theme editor (`Master.Themes_save`); migration 048 dropped `Themes_setImageGroup` and the images-page assignment box, which duplicated it. The images page shows which non-deleted themes use the selected group. A group used by a non-deleted theme cannot be deactivated (SQL error 50013, API 409). Group save uses the `Master.ImageSelection` table type in one transaction. Default images must be active selected members. Duplicate images/positions and inactive/missing images are rejected. Theme assignment accepts only an active group. Empty groups fall back to the original theme images at runtime.

## API and access

| Method/path | Purpose |
| --- | --- |
| GET `/api/admin/images` | Admin metadata library, groups, memberships and the group used by each non-deleted theme; no BLOBs in JSON |
| POST `/api/admin/images` | One multipart `file`; browser uploads multi-selection sequentially |
| POST `/api/admin/images/groups` | Create a group |
| PUT `/api/admin/images/groups/{id}` | Save group properties and full membership/order |
| GET `/api/themes/{id}/images` | Registered active portal user's current published image settings |
| GET `/api/images/{id}/content` | Binary image; admin preview, or registered portal-user access only when actively assigned through an active group to an active theme |

All writes and admin reads recheck external `CompanyPortal.Admin` through the existing NTName → UserId/role source. Writes require `X-CompanyPortal-Request: admin-images`; JSON writes reject unknown fields. Credentialed CORS and exact-origin checks apply to uploads as well as JSON. Images/groups/roles are never selected by a browser-supplied user ID. JSON responses are private/no-store. Image content (`/api/images/{id}/content`) is `private, max-age=31536000, immutable`: an ImageId's bytes never change (there is no update path; a new upload gets a new ID), so the portal downloads each rotating image once instead of on every turn. Access is still checked on each request that reaches the API; a browser that already has an image keeps it after the theme is hidden. Image responses include nosniff and sandboxed restrictive Content-Security-Policy, and are used as images, never inline SVG markup.

Default upload limit is 10 MB per raster image, configurable through `InterfaceImages:MaximumUploadMb` (1–10). SVG has an additional fixed 1 MB limit. Dimensions are limited to 12000 per side and 40 megapixels. Raster extensions/signatures/container structure/dimensions are checked without adding an imaging library; this is not a full pixel decode or malware scanner. Unrenderable images fall back to original theme images in the portal.

SVG is parsed with DTD/entity resolution disabled and serialized again. Only supported passive shapes, text, groups, gradients, clipping and masks are accepted. Scripts, event handlers, styles/style sheets, foreignObject, embedded/external images, links, animation and other unsupported elements/attributes are rejected. Local `url(#id)` references are permitted. Export unsupported artwork as a plain SVG with presentation attributes, or upload a PNG/WebP. Validation never downloads linked resources.

## Portal display

Existing official/work photograph surfaces use the selected group; the national-day scene uses a tinted image background that preserves text contrast. The initial image is the selected default (otherwise first active ordered member). Rotation advances in saved order and wraps; disabling it freezes the default. Hidden pages, open announcement dialogs and reduced-motion preferences pause rotation. Managed raster decoding is limited by releasing earlier inactive sources after their fade.

Theme-image settings are fetched on theme selection/page load, not polled. A stale response cannot replace the newly selected theme's images. No group, unavailable API, empty/inactive group or image-load failure restores original images. Existing static assets and the original dist baseline remain retained. The admin footer accurately indicates that employees reload the portal to receive new settings.

## Deployment and verification

The API runtime SQL identity needs EXECUTE on the seven procedures above plus existing identity/role lookups, and REFERENCES on TYPE::Master.ImageSelection for group writes. Use object-specific grants; no db_owner or direct employee SQL access is required. Include migration015 in air-gapped deployment. IIS/request-proxy limits must allow the API's 12 MB total upload request limit; no upload folder, external asset service or additional packages are needed. Plan database/storage and backup capacity for image BLOBs.

`Backend/tools/Test-InterfaceImages.ps1` uses the local development API/database, creates uniquely identified temporary fixtures, restores the original theme assignment, and removes only its own unreferenced fixtures. `-KeepFixtures` keeps test images/groups for browser verification but still restores the original theme assignment; clean those IDs deliberately afterward. Never run these fixture tests against production.


Verified locally: migration application/rerun and foreign-key/check constraints; both Release builds with zero warnings/errors; integration checks for JPEG, PNG and three WebP container variants, passive/unsafe SVG, false signatures, anonymous denial, required write header, rejected origin/unknown JSON/null members, no-op timestamps, group order/removal/default/rotation/activation, theme assignment and image serving. Desktop browser uploaded an SVG, saved/reordered a group, selected a static default, observed automatic rotation and checked all three theme surfaces. The editor was checked at 390px with no document overflow. Frontend parity passed: 328 original files unchanged, six routes and 313 original resources checked. All temporary fixture images/groups were removed; three theme assignments remain null and the original employee ThemeId 1 was restored. Real internal IIS/SQL identities and deployment remain environment acceptance checks.

Swagger compatibility: the upload action uses inferred IFormFile binding. Do not apply [FromForm] directly to IFormFile; it prevents Swashbuckle from generating the document. The integration script now checks Swagger JSON and the multipart upload schema before exercising uploads. Swagger generation and upload regression checks passed after this fix.


## Import the existing frontend theme images

On 20 October 2026, the three landscape photographs, national-day portrait and flag artwork were imported into the local image library with Arabic names. They remain selectable in administration; no group was created and no theme assignment changed. Original static assets remain available as fallbacks. Avatars, logos and decorative SVG textures are not part of this theme-photo import.

To populate a new internal database after migration015, start the API and run `powershell -NoProfile -File Backend/tools/Import-FrontendImages.ps1 -BaseUrl https://YOUR-API` from CompanyPortal. This uses the current Windows account's existing admin access and normal validated upload endpoint. Use a trusted HTTPS certificate internally. The default API address is local http://localhost:5081. The script compares SHA-256 content of same-sized active PNG/JPEG entries and skips existing images even if renamed, preserving their metadata. Partial imports can be rerun; already uploaded images are retained. It never creates groups, changes existing metadata or assigns themes. Once imported, choose images, save the group, save the theme link, and reload the portal.


## Combined national-day artwork

The complete calligraphy, Sultan portrait and flag composition is now available as **اليوم الوطني - التصميم الكامل.jpg** in the image library (local ImageId 32). Its source asset is `Frontend/CompanyPortal.Web/wwwroot/assets/national-day-complete.jpg`: 2560 × 1440, 212,103 bytes. It was rendered deterministically from the existing SVG paths, portrait and flag artwork, with animations frozen. The browser export is JPEG; it is stored and served as image/jpeg.

`tools/export-national-day-artwork.py` prepares a standalone HTML composition under the ignored `Backend/artifacts/national-day-export` directory. Render that page at 2560 × 1440 to re-export the static artwork. The importer includes the combined JPEG alongside the five original assets, with byte-content duplicate detection. Import/readback/rerun checks passed, preserving group/theme assignments. This adds one selectable library image; it does not assign a group automatically. Theme administration now offers complete-artwork presentation to hide the original decorative layers when this composition is selected.


## Animated national-day SVG

The user's requested version is **اليوم الوطني - التصميم المتحرك.svg**, stored locally as ImageId 41. `Frontend/CompanyPortal.Web/wwwroot/assets/national-day-complete.svg` is a self-contained 2560 × 1440 SVG: original vector calligraphy paths retain their drawing/fill animation, flag layers retain their entrance animation, and the portrait/flag PNGs are embedded in the file. Reduced-motion rules show the final artwork without animation. It needs no scripts, network resources or installed fonts. The static JPEG remains available; no group assignments changed.

Ordinary uploaded SVG files retain the existing passive-element rules and 1 MiB limit. This exact bundled asset is an explicit exception, accepted by a compiled SHA-256 fingerprint in `Data/BundledArtwork.cs`, within the existing 10 MiB overall limit. Neither its filename nor client metadata grants trust. Its response alone allows inline styles and data images under a sandbox/default-deny CSP; scripts and external resources remain blocked. The general SVG response policy stays unchanged. The `.gitattributes` entry preserves the reviewed SVG bytes across checkouts.

Build/deploy the updated API before importing this asset with `Import-FrontendImages.ps1`. The generator now writes the animated SVG deterministically and prints its fingerprint; intentional artwork updates require review and updating the compiled fingerprint. The SVG is not serialized or modified during its approved upload, preserving its bytes and animation rules. Imports deduplicate the approved SVG by exact content as well as raster assets.

Verified: Release API build with zero warnings/errors; Swagger/upload/group regressions; successful approved SVG upload; rejection of a modified SVG under the same filename; data-image policy only for the approved asset; browser loading from the real database endpoint with 36 animated calligraphy paths and flag animation; image-context preview showing the initial phase and final composition. Temporary test uploads were removed.

## Image deletion

Apply migration `017_ImageDeletion.sql` after 016. `DELETE /api/admin/images/{id}` requires the current admin role and the existing admin-images request header/origin checks. Grant the runtime account EXECUTE on `Master.Images_delete`.

The library offers **حذف الصورة** with confirmation. Deletion marks an unused image inactive and updates LastChangeAt; binary content is retained for controlled recovery, but is no longer listed or served. Missing/deleted images return 404. Images referenced by any saved group (including inactive memberships or a group default) return 409. Remove the image from those groups and save first, so deletion never silently changes published artwork. Unsaved group edits are preserved during library deletion.

## Smaller copies (migration 050, 28 October 2026)

- **Upload:** the admin browser shrinks large photos before sending them: long side over 2560 px or file over 1.5 MB → JPEG stays JPEG, other formats become WebP, quality 0.86, kept only when smaller. Re-encoding also drops camera metadata (for example GPS). SVG is sent unchanged.
- **Preview copy:** every upload also sends a 480 px WebP preview (`thumbnail` form field, at most 512 KB / 640 px, raster only, checked by `ImageValidation.ReadThumbnail`). It is stored in `Master.Images.ThumbnailData/ThumbnailType`.
- **Existing images:** «إنشاء نسخ معاينة صغيرة (n)» in the library makes previews in the browser and sends them with `PUT /api/admin/images/{id}/thumbnail`. That can be done once per image (409 afterwards), which keeps the cache safe. It is not recorded in the change history (the snapshot has no bytes).
- `GET /api/images/{id}/thumbnail` uses the same access rule as `/content` and is cached the same way; 404 when there is no preview. `Images_getAll` returns `HasThumbnail`. The admin library, group list and theme cards use the preview; the portal always uses the full image.
- Procedures: `Images_add` (optional `@ThumbnailData/@ThumbnailType`, history lines kept), `Images_setThumbnail`, `Images_getThumbnail`.


## مساحة تحرير المجموعات — 28 أكتوبر 2026

أصبحت إعدادات المجموعة يمينًا ومكتبة الصور يسارًا في مساحة عمل واحدة لسطح المكتب، بدل وضع المكتبة فوق النموذج. محدد المجموعة وزر الحفظ يبقيان خارج منطقة التمرير الداخلية؛ الإعدادات والترتيب داخل منطقة قابلة للتمرير، وقائمة الصور المختارة لها حد ارتفاع مستقل. المكتبة تتمرر بصورة مستقلة. يظهر اسم المجموعة الجاري تحريرها فوق المكتبة، وتُميّز الصور المختارة بحد أخضر، ويظهر الاختيار فورًا في قائمة المجموعة. أزرار الإزالة مسماة «إزالة من المجموعة» مقابل «حذف من المكتبة».

لا تغيير في طلبات الحفظ/الرفع/الحذف، أو الترتيب والصورة الافتراضية، أو حراسة التعديلات غير المحفوظة. في النوافذ الأضيق يعود التخطيط إلى الترتيب الرأسي. بقيت معلومات الأنواع والحجم والاستخدام والتعديل الأخير ظاهرة.
