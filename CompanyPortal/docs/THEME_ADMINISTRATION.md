# Theme creation and administration

Updated 20 October 2026; publication, role preview, deletion and global-default behaviour are documented in [THEME_PUBLICATION.md](THEME_PUBLICATION.md). Open **الثيمات والمظهر** or `/admin/themes`.

## Administrator workflow

The gallery lists active and inactive themes, their publication status, template, colour swatches and default badge. Use **إضافة ثيم**, or **نسخ** on a theme to start from its settings. New/copied themes start inactive, with default status cleared. Copies receive a new ThemeId only when saved. **تعديل** opens the existing record; **معاينة** opens a read-only dialog.

The editor has three keyboard-accessible tabs:

- **التفاصيل**: Arabic name, visual template selector, display order, hidden/role-preview/public publication status, allowed role names and default status.
- **الألوان**: main/accent/background colour pickers and hexadecimal fields, per-colour reset to the original template, foreground light/dark preset and image overlay strength (0–85%).
- **الصور**: existing image group, rotation/default summary, link to group management, and background versus complete-artwork presentation.

Colour overrides affect shared portal headings, navigation accents, selected buttons and page backgrounds. Readable neutral card surfaces and semantic status/notification colours remain independent. Button text is derived from contrast against the chosen main colour. The preview warns about an identical main/background colour; administrators should inspect text and photographs in the desktop preview.

**خلفية** fills/crops the existing photograph surface. **تصميم كامل** fills the existing hero backdrop edge to edge with `object-fit: cover` and no extra zoom; proportions stay correct, and height may be cropped to avoid empty side areas; it hides the built-in national-day illustration/copy layers so a combined SVG does not duplicate the portrait, flag or calligraphy. Functional news/workspace controls remain. The uploaded SVG's own artwork colours are not recoloured by the three portal colour controls.

Rotation, interval, ordering, member activation and the initial image belong to the image group, not the theme. Sharing a group intentionally shares those settings. With no available group/images, the original template artwork is restored. Image-load errors also restore original images. Rotation pauses on hidden pages, reduced-motion preference and open announcement dialogs. SVG animations additionally respect their own reduced-motion rules.

Save as hidden, make available to selected roles, or publish for all users. The button text states the chosen action. Publishing makes a theme selectable without replacing employee choices. Setting a new default or using **افتراضي وتطبيق للجميع** also replaces all active saved theme selections on next load. A user can choose another theme later. Hidden/deleted/no-longer-authorized selections fall back without erasing their stored ID. Deletion is soft; the current default must be replaced before hiding/deleting it.

## Data and interfaces

Apply `Backend/Database/Scripts/016_ThemeAdministration.sql` after 015. It adds nullable `PrimaryColor`, `AccentColor`, `BackgroundColor` (`nvarchar(7)`), `OverlayOpacity` (`int`), `ForegroundPreset` (`nvarchar(10)`), and `ImagePresentation` (`nvarchar(20)`, default `background`) to `Master.Themes`. Existing rows keep null appearance overrides, so their original CSS is preserved. Existing identity, names, default/active flags, image-group links and employee preferences are not seeded or reset.

`Master.Themes_getForAdministration` lists all definitions. `Master.Themes_save` validates and saves one definition; an application lock serializes catalog/default changes. Default replacement is transactional, and exactly one active default is required. Actual changes update LastChangeAt, including case-only names; no-op saves preserve it. Nullable colours/presets preserve template settings. Only active image groups can be assigned. Concurrent editing remains last-save-wins.

`Master.Themes_getAll` and GET `/api/themes` now include appearance settings and ImageGroupId. GET `/api/user-settings/theme` and employee PUT `{themeId}` retain their existing contracts. Multiple definitions can reuse one LayoutKey and still have independent colours/images and stable identity. A new layout still requires implemented markup/styles and validation; admins choose Arabic template labels rather than entering keys.

| Endpoint | Purpose |
| --- | --- |
| GET `/api/admin/themes` | All theme definitions, including inactive entries |
| GET `/api/admin/themes/templates` | Three supported Arabic template labels, thumbnails and starting colour/preset values |
| POST `/api/admin/themes` | Create a theme; returns `{themeId}` |
| PUT `/api/admin/themes/{id}` | Update an existing theme; returns `{themeId}` |

Writes accept only themeName, layoutKey, displayOrder, active, isDefault, primaryColor, accentColor, backgroundColor, overlayOpacity, foregroundPreset, imagePresentation and imageGroupId. Colours must be `#RRGGBB` or null; presets are light/dark/null and presentation is background/artwork. Names are trimmed and limited to 200 characters. No arbitrary HTML, CSS, JavaScript, user ID or role is accepted.

Every admin API request resolves Windows NTName and checks the current external CompanyPortal.Admin role. JSON writes require `X-CompanyPortal-Request: admin-themes`, with existing exact-origin checks and credentialed CORS. Responses use no-store. Unknown fields, missing flags and invalid appearance values are rejected. The browser's capabilities are not an authorization boundary.

## Preview isolation

`/admin/theme-preview` is a public MVC shell with static sample portal markup, shared theme styles and the shared appearance/image renderer. It loads only `theme-appearance.js` and `theme-preview.js`: employee persistence, localStorage, news/mail connections and business-action scripts are omitted. Form controls are disabled and interactions cannot submit or navigate. No real employee data is loaded into the sample.

The iframe confirms current admin capability through GET `/api/access` before showing a draft. Parent/frame messages require the exact frontend origin and expected window source. Image URLs are constructed by ID against the configured API, never accepted from a draft URL. Changes remain in memory; preview performs no preference/business writes. Desktop uses the current browser viewport dimensions scaled to its panel, preserving the live portal header breakpoint in both editor and gallery previews. There is no mobile preview. Representative news headlines are supplied locally; the floating calendar is mounted under #systems, as in the portal, so it stays at the bottom left with its summary. Saved-theme dialog previews use the same renderer.

The employee portal uses the same validated appearance variables and managed image renderer. Legacy template layout selection remains, while catalog records and the local cached definition retain ThemeId. Delayed image responses cannot replace a newer selection. Existing static assets remain fallback sources; no original dist files were changed.

## Deployment

1. Apply migrations016, 017 and 018 in order using the SQL deployment identity; it is safe to rerun.
2. Grant the API runtime identity EXECUTE on `Master.Themes_getForAdministration` and `Master.Themes_save`, `Master.Themes_delete` and `Master.Themes_applyToAll`, alongside existing theme/image and external identity/role procedures. No employee SQL grants or db_owner are required.
3. Deploy both updated API and frontend, including the new shared renderer/styles and preview view. Restart the processes. No new packages or external assets are required.
4. Verify Windows authentication, configured API address/CORS origins and IIS virtual-path behaviour in the internal environment. Existing image/blob and approved animated-SVG requirements still apply.

`Backend/tools/Test-ThemeAdministration.ps1` is local-development only. It temporarily creates themes/groups, changes defaults and (when already saved) the current sample employee preference, then restores original choices and removes its own unreferenced fixtures. Do not run it against production or concurrent editing.

## Verification

- Both Release builds passed with zero warnings/errors; migration application and rerun were checked.
- Integration checks passed for Swagger/templates, required header/origin, unknown fields/invalid appearance, independent shared-layout themes, roundtrip settings, no-op timestamps, active-default enforcement, inactive-selection fallback without preference loss, and anonymous denial.
- Browser checks covered gallery/copy/edit/save/reload, colour fields, image group/complete artwork, saved-theme dialog, actual employee selection/persistence, and 390px admin layout without page overflow.
- Preview-only editing left the employee ThemeId and LastChangeAt unchanged. The static preview script list was verified to omit employee save/business-action scripts.
- The complete animated SVG displayed once, with original foreground layers hidden. Existing themes with null overrides retained their original rendering; original dist parity checks passed.

See [INTERFACE_IMAGES.md](INTERFACE_IMAGES.md) for groups/uploads and [IMAGE_SPECIFICATIONS.md](IMAGE_SPECIFICATIONS.md) for artwork preparation.

Earlier verification used contained complete artwork and fallback-only defaults. Those behaviours are superseded by the current full-width hero and publication/global-default controls in [THEME_PUBLICATION.md](THEME_PUBLICATION.md). The newer integration suite rolls back global/default tests; the legacy appearance suite now snapshots/restores all saved settings during its deliberate default tests. Existing user-created themes, image assignments and current default are preserved.
# Per-image crop positions

Migration047 adds **موضع الصورة** in the images tab: drag in the live preview, keyboard-accessible sliders and centre reset, saved separately for each photo/theme. See [theme image framing](THEME_IMAGE_POSITIONS.md) for persistence, deployment and verification. Existing themes retain their framing until an override is saved.


## مساحة محرر مستقلة — 28 أكتوبر 2026

عند إضافة/نسخ/تعديل ثيم تُخفى المعرض وعنوانه أثناء التحرير. إعدادات الثيم يمينًا والمعاينة الحقيقية يسارًا، مع ترويسة المحرر والتبويبات والحفظ/الإلغاء خارج منطقة تمرير الحقول. تبويب الصور يعرض مصغرات المجموعة النشطة وملخص التدوير الموجود أصلًا. الصور المصغرة تستخدم نسخة thumbnail إن وجدت مع تحميل كسول، ولا تُعاد بناؤها عند تحريك أشرطة الموضع أو تغيير حقل لا يتعلق بالصور. الإلغاء يعيد المعرض، مع حراسة التعديلات الحالية؛ الحفظ يبقي المحرر مفتوحًا كما كان. بقيت صلاحيات النشر والافتراضي والحفظ بلا تغيير.

تحقق سطح المكتب: إخفاء/إظهار المعرض، مصغرات المجموعة، ثبات موضع المعاينة والحفظ عند تمرير الحقول، حراسة الإلغاء والاحتفاظ بالمسودة، واستعادة المسودة دون أي حفظ. ملفا الإثبات .local/admin-workspace-layout/images.png وthemes.png. لا ترحيل SQL أو تعديل API لهذه الواجهة.
