# Frontend acceptance

## Browser acceptance update — 18 October 2026

Real browser access now works through isolated headless Microsoft Edge using a temporary Playwright tool outside the application dependencies. **16 interaction scenarios passed**, with no JavaScript/console errors and no automatic external requests while non-local requests were blocked. The earlier browser-unavailable notes below describe the previous verification stage.

Completed scenarios: Arabic title/local fonts/favicon resource; theme switching and reload persistence; pinned header; profile and return; keyboard search; task/note create/edit/complete/delete and persistence; calendar navigation; documents/policies/safety dialogs; workspace view/concealment persistence; group create/edit/delete and persistence; system pin/unpin; local service drafts; gallery navigation/zoom; magazine rendering/page navigation; news section navigation; mobile menus/tasks.

Layout checks covered all three themes at 1920, 1440, 1280, 1024, 768 and 390 CSS pixels. No document horizontal overflow or broken visible images was detected. Screenshots were reviewed at desktop/mobile sizes. Mobile navigation intentionally scrolls horizontally; existing floating notices/calendar can cover underlying controls until the page is scrolled.

Two acceptance fixes were applied: use the shared two-row header at tablet/smaller laptop widths to prevent controls overlapping, and read group choices from the original systems grid so the dialog's cloned cards do not duplicate every option. Background images are unchanged. A final tablet row-height adjustment (80/52 within the same 132px header) was compiled after the captured layout run; its screenshot recheck remains pending.

Evidence is in ignored `artifacts/browser-acceptance/`: `functional-results.json`, `layout-results.json`, theme screenshots and the magazine screenshot. Tests used fresh disposable contexts and synthetic data; existing user browser storage was not accessed.

Still pending: keyboard/pointer card reordering, saved article persistence, organization status/notification actions, local video/PDF file previews, comprehensive focus/touch checks on real devices, and a browser run at the deployed IIS sub-application address. The optional extra Edge launch for reorder/saved-article checks was declined and those tests were not executed. Blocking internet requests verifies local resource use; it does not test an actual disconnected internal workstation.

The final Release publish and theme/offline/HTTP checks passed after the fixes: six routes, 313 retained resources, seven CSS resource references and all 328 unchanged original files. Verification servers were stopped. Actual internal Windows Server/IIS acceptance remains required.

## Completed technical checks — 18 October 2026

- [x] .NET 10 MVC build/publish completed with zero warnings/errors after stopping test processes.
- [x] Restore completed using an empty local NuGet source and an isolated package folder. This project currently has no additional NuGet package references; installed SDK/reference packs are still required.
- [x] Published application served through IIS Express and ASP.NET Core Module V2 in Production, both at `/` and `/companyportal/`.
- [x] Six page/alias routes, redirects with query strings, 313 retained baseline resources, seven CSS asset references, profile CSS and all five local Iconsax font formats passed HTTP/content checks at both hosting paths.
- [x] All 19 application scripts retain their original order and now run after dialog markup exists.
- [x] Theme logic checks cover the default, all three buttons, numeric/semantic saved selections, invalid values, active panels, events and shared-header placement.
- [x] Static offline-resource scan found no automatic external asset requests in application views, CSS or JavaScript. Outbound source links remain intentional user actions.
- [x] Twelve unreferenced files were removed from the new MVC project and fresh publish output; all 328 original baseline files remain unchanged.

The technical checks in this section do not execute a real browser. See the update above for the subsequent Edge results.

## Original browser checklist (superseded by the update above)

Use a test browser/profile. Existing scripts can initialize browser-local sample data; do not clear real user storage for testing.

- [ ] At desktop and mobile widths, the portal has no unexpected horizontal scrolling, clipped navigation, missing icons or broken images.
- [ ] Theme 1 is the default on first use. Themes 1/2/3 switch correctly and the selected theme survives a reload.
- [ ] The default header uses the same fixed layout as the other themes. Its photographs remain continuous behind the transparent header; scrolling uses the shared pinned/glass state.
- [ ] Header menus, employee panel, organization status, search and section navigation work with mouse/touch and keyboard. Dialogs close as expected and focus remains usable.
- [ ] Add, edit, complete and delete test tasks/notes. Check selected dates, calendar navigation, reload persistence and relevant notifications.
- [ ] Pin/unpin systems; create/edit groups; reorder cards; switch workspace views; conceal/reveal cards; reload to confirm persistence.
- [ ] Service forms retain test drafts locally and do not imply a real server workflow was submitted.
- [ ] News details, saved articles, photo gallery, documents/policies/safety dialogs, local magazine pages/PDF links and local media previews work.
- [ ] Profile navigation and return link work. The browser title is `البوابة` and the khanjar favicon is visible.
- [ ] With internet access disconnected, essential rendering, icons/fonts and local content continue to work. Developer tools show no automatic external resource requests or JavaScript errors. Outbound source links are expected to require their destination networks.

## Internal deployment acceptance still required

- [ ] Test on the actual supported Windows Server/IIS installation, with the approved DNS name, HTTPS certificate/trust, app pool identity and bindings.
- [ ] Confirm the actual root/sub-application address and repeat the browser checks at that address.

IIS Express success is a local hosting check, not certification of an untested Windows Server deployment. Keep the original baseline outside this portable folder until browser acceptance is complete. Do not start the API as a substitute for these frontend checks.
