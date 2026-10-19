# Interface images and theme groups

Implemented 19 October 2026. Open **صور الواجهة** in administration, or `/admin/images`.

## What administrators can do

- Upload one or several JPEG, PNG, WebP or passive SVG files and preview them in the shared library.
- Create or edit an Arabic-named group and select existing images; an image can belong to several groups.
- Move selected images up/down, remove memberships, enable/disable individual members and choose an active default image.
- Enable automatic rotation, set a 3–3600 second interval, or show only the default image. Disable a group without deleting it.
- Assign an active group to any existing theme, or select the theme's original images. Several themes may share a group.

Uploads are saved immediately. Group edits are saved using **حفظ المجموعة**; theme assignments have their own **حفظ الربط** buttons. Removing an image from a group keeps it in the library. There is no library-delete endpoint in this version. Group edits use last-save-wins; no concurrent-edit locking UI or audit history is included.

Image groups are global administrator content, not employee-owned custom cards. Employee ThemeId preferences are unchanged. Creating themes remains a separate upcoming feature; a future theme can reference ImageGroupId without duplicating image data or requiring an English name. LayoutKey still selects an implemented layout.

## Database

Apply `Backend/Database/Scripts/015_InterfaceImages.sql` after 014. It is safe to rerun and does not seed images or change existing theme assignments.

| Table | Data |
| --- | --- |
| `Master.Images` | Identity ImageId, ImageName nvarchar(200), ContentType nvarchar(100), ImageData varbinary(max), dimensions, Active and LastChangeAt |
| `Master.ImageGroups` | Identity ImageGroupId, GroupName nvarchar(200), RotateImages, RotationSeconds, nullable DefaultImageId, Active and LastChangeAt |
| `Master.ImageGroupItems` | Identity ImageGroupItemId, group/image foreign keys, DisplayOrder, Active and LastChangeAt |
| `Master.Themes` | New nullable ImageGroupId foreign key |

All three new tables have Active bit default 1 and LastChangeAt datetime default GETDATE(). Actual group-property/membership changes advance the group timestamp; no-op saves preserve it. Existing item IDs remain stable when updating a membership. Removing a membership deletes only that relationship. Images are stored once in CompanyPortal, so normal database backup/restore includes their binary content.

Procedures: `Master.Images_getAll`, `Images_add`, `Images_getContent`, `ImageGroups_getAll`, `ImageGroups_save`, `Themes_setImageGroup`, `Themes_getImages`. Group save uses the `Master.ImageSelection` table type in one transaction. Default images must be active selected members. Duplicate images/positions and inactive/missing images are rejected. Theme assignment accepts only an active group. Inactive/empty groups fall back to the original theme images at runtime.

## API and access

| Method/path | Purpose |
| --- | --- |
| GET `/api/admin/images` | Admin metadata library, groups, memberships and active theme assignments; no BLOBs in JSON |
| POST `/api/admin/images` | One multipart `file`; browser uploads multi-selection sequentially |
| POST `/api/admin/images/groups` | Create a group |
| PUT `/api/admin/images/groups/{id}` | Save group properties and full membership/order |
| PUT `/api/admin/images/themes/{id}/group` | `{imageGroupId: id}` or explicit null for original images |
| GET `/api/themes/{id}/images` | Registered active portal user's current published image settings |
| GET `/api/images/{id}/content` | Binary image; admin preview, or registered portal-user access only when actively assigned through an active group to an active theme |

All writes and admin reads recheck external `CompanyPortal.Admin` through the existing NTName → UserId/role source. Writes require `X-CompanyPortal-Request: admin-images`; JSON writes reject unknown fields. Credentialed CORS and exact-origin checks apply to uploads as well as JSON. Images/groups/roles are never selected by a browser-supplied user ID. Responses are private/no-store. Image responses include nosniff and sandboxed restrictive Content-Security-Policy, and are used as images, never inline SVG markup.

Default upload limit is 10 MB per raster image, configurable through `InterfaceImages:MaximumUploadMb` (1–10). SVG has an additional fixed 1 MB limit. Dimensions are limited to 12000 per side and 40 megapixels. Raster extensions/signatures/container structure/dimensions are checked without adding an imaging library; this is not a full pixel decode or malware scanner. Unrenderable images fall back to original theme images in the portal.

SVG is parsed with DTD/entity resolution disabled and serialized again. Only supported passive shapes, text, groups, gradients, clipping and masks are accepted. Scripts, event handlers, styles/style sheets, foreignObject, embedded/external images, links, animation and other unsupported elements/attributes are rejected. Local `url(#id)` references are permitted. Export unsupported artwork as a plain SVG with presentation attributes, or upload a PNG/WebP. Validation never downloads linked resources.

## Portal display

Existing official/work photograph surfaces use the selected group; the national-day scene uses a tinted image background that preserves text contrast. The initial image is the selected default (otherwise first active ordered member). Rotation advances in saved order and wraps; disabling it freezes the default. Hidden pages, open announcement dialogs and reduced-motion preferences pause rotation. Managed raster decoding is limited by releasing earlier inactive sources after their fade.

Theme-image settings are fetched on theme selection/page load, not polled. A stale response cannot replace the newly selected theme's images. No group, unavailable API, empty/inactive group or image-load failure restores original images. Existing static assets and the original dist baseline remain retained. The admin footer accurately indicates that employees reload the portal to receive new settings.

## Deployment and verification

The API runtime SQL identity needs EXECUTE on the seven procedures above plus existing identity/role lookups, and REFERENCES on TYPE::Master.ImageSelection for group writes. Use object-specific grants; no db_owner or direct employee SQL access is required. Include migration015 in air-gapped deployment. IIS/request-proxy limits must allow the API's 12 MB total upload request limit; no upload folder, external asset service or additional packages are needed. Plan database/storage and backup capacity for image BLOBs.

`Backend/tools/Test-InterfaceImages.ps1` uses the local development API/database, creates uniquely identified temporary fixtures, restores the original theme assignment, and removes only its own unreferenced fixtures. `-KeepFixtures` keeps test images/groups for browser verification but still restores the original theme assignment; clean those IDs deliberately afterward. Never run these fixture tests against production.


Verified locally: migration application/rerun and foreign-key/check constraints; both Release builds with zero warnings/errors; integration checks for JPEG, PNG and three WebP container variants, passive/unsafe SVG, false signatures, anonymous denial, required write header, rejected origin/unknown JSON/null members, no-op timestamps, group order/removal/default/rotation/activation, theme assignment and image serving. Desktop browser uploaded an SVG, saved/reordered a group, selected a static default, observed automatic rotation and checked all three theme surfaces. The editor was checked at 390px with no document overflow. Frontend parity passed: 328 original files unchanged, six routes and 313 original resources checked. All temporary fixture images/groups were removed; three theme assignments remain null and the original employee ThemeId 1 was restored. Real internal IIS/SQL identities and deployment remain environment acceptance checks.
