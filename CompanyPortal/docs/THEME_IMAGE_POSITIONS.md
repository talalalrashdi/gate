# Theme image framing

Admins can adjust the crop of every image in a theme's selected image group. The image fills the hero with its proportions preserved. This does not promise that the entire photograph is visible: a tall photo in a wide hero still needs cropping, and news cards may cover part of it.

## Use

1. Open **الثيمات والمظهر**, edit a theme and choose **الصور**.
2. Select an image group, then select the photo under **موضع الصورة**.
3. Drag the photo in the live portal preview, or use **الموضع الأفقي** / **الموضع الرأسي**. The preview includes the actual header, news layout and overlays with illustrative news text.
4. **توسيط الصورة** sets both positions to50%. Switch images to frame each separately, then save the theme.

Preview rotation pauses while editing, so the chosen image stays visible. This does not change the group's rotation settings. Gallery/employee rendering retains the group's selected default and rotation. An axis cannot visibly move when the scaled image has no overflow in that direction. Keyboard range controls are available. Selecting an image for editing alone does not dirty/save the theme.

Positions belong to the **theme/image pair**, so two themes may frame the same image differently. Theme copying includes positions and clears the default status as before. Changing image groups removes positions for images outside the new group from that draft. Original template artwork is unchanged; select a database image group to configure per-image positions.

Images without a saved override retain their previous template framing and movement. Explicitly positioned images use stable `cover` rendering without the template's drifting/zooming animation, so the crop matches the chosen position. Embedded SVG animation is unaffected. A full-width crop can differ at other viewport proportions; the preview matches the current desktop viewport.

## Data/API

Migration **047_ThemeImagePositions.sql** adds `Master.ThemeImagePositions`: identity ID, ThemeId/ImageId foreign keys and unique pair, FocalX/FocalY decimal(5,2) constrained to0–100, LastChangeAt/default GETDATE and Active/default1. It seeds nothing and does not alter existing theme timestamps/preferences.

`Master.ThemeImagePositions_Get` reads active positions. The admin catalog adds `imagePositions: [{imageId,focalX,focalY}]`; employee theme-image responses include nullable `focalX` / `focalY` on each authorized image. Metadata is attached only to the image rows returned by the existing authorization-aware source. Employee theme preferences still store only ThemeId.

The existing `Master.Themes_save` accepts optional `@ImagePositionsJson` and saves positions transactionally with theme details/default/roles and history. Its server-internal JSON uses PascalCase keys matching the .NET serializer; HTTP uses the usual camelCase names. Omission/null preserves positions for older clients; explicit `[]` clears overrides. At most100 distinct images are accepted, all members of the selected group. Bounds, missing fields and duplicate/unknown IDs are rejected. True no-op saves preserve LastChangeAt and do not add audit entries. History snapshots include positions.

Preview updates use same-origin, frame-source-checked messages. Dragging/sliders send no preference/business writes and do not reload the image on every movement. Positions are validated before becoming CSS; no arbitrary CSS/HTML/JavaScript is accepted.

## Deployment and verification

Apply047 after046 on an existing database, then republish API and MVC. Fresh-install Setup.sql includes047; do not replay it on an existing database. Runtime SQL permissions must include EXECUTE on `Master.ThemeImagePositions_Get` (existing schema-level EXECUTE grants already cover it). System health includes the new reader. Historical current-data exports were not regenerated.

Verified28 October2026: API save/read, two themes framing the same image independently, employee image DTO, no-op timestamp, invalid-coordinate/duplicate/missing-field/unknown-image rejection and atomic rollback, legacy omission, clear/reset and Swagger. Browser: drag changes the crop without reloading the image, image selection preserves independent positions, keyboard sliders, centre reset, save/reload and live framing with the header/news visible. Temporary fixture themes were removed; original themes and employee preferences were retained.

`node tools/verify-theme-framing.mjs` covers shared rendering, defaults and national-day positioning. `Backend/tools/Test-ThemeImagePositions.ps1` uses local, clearly named temporary themes and cleans them in finally; `-KeepFixtures` is only for local browser checks and requires manual cleanup afterward. Existing theme catalog, history, shared-admin and offline-asset checks also pass.
