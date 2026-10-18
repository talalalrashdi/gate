# Frontend acceptance

## Completed technical checks — 18 October 2026

- [x] .NET 10 MVC build/publish completed with zero warnings/errors after stopping test processes.
- [x] Restore completed using an empty local NuGet source and an isolated package folder. This project currently has no additional NuGet package references; installed SDK/reference packs are still required.
- [x] Published application served through IIS Express and ASP.NET Core Module V2 in Production, both at `/` and `/companyportal/`.
- [x] Six page/alias routes, redirects with query strings, 313 retained baseline resources, seven CSS asset references, profile CSS and all five local Iconsax font formats passed HTTP/content checks at both hosting paths.
- [x] All 19 application scripts retain their original order and now run after dialog markup exists.
- [x] Theme logic checks cover the default, all three buttons, numeric/semantic saved selections, invalid values, active panels, events and shared-header placement.
- [x] Static offline-resource scan found no automatic external asset requests in application views, CSS or JavaScript. Outbound source links remain intentional user actions.
- [x] Twelve unreferenced files were removed from the new MVC project and fresh publish output; all 328 original baseline files remain unchanged.

These checks do not execute a real browser. The browser tool reports no available browser, so the following visual/interaction checks remain open.

## Browser checks still required

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
