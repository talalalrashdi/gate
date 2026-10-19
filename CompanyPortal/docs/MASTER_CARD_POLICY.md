# Master cards, fixed positions and future personal cards

19 October 2026. This supersedes the 22-active-card catalog described in CARD_ORDER.md. Migration 009 was applied locally on 19 October 2026 and rerun while a temporary fixed setting was present; that setting survived the rerun. All five are now restored to movable, in the requested default order. The first migration attempt rolled back because sqlcmd required explicit session settings for a filtered index; the completed script includes those settings.

## Current master set

| Initial order | CardKey | CardName |
| --- | --- | --- |
| 1 | library | القرارات |
| 2 | inbox | مرسالات |
| 3 | email | البريد الالكتروني |
| 4 | requests | نظام الاستمارات |
| 5 | electronic-services | الخدمات الالكترونية |

All five start movable, as explicitly selected by the user. Migration 009 adds `Master.Cards.IsFixed bit NOT NULL DEFAULT (0)`, sets these five active and deactivates the other 17 definitions. Existing CardId values, employee rows, historical card references and local group definitions are retained. Migration reruns preserve subsequent administrator choices.

`DisplayOrder` is one-based. When IsFixed is 1 it reserves that exact position; otherwise it is the default order that employee preferences can override. A filtered unique index prevents two active fixed cards sharing a position. Fixed positions must be within the active master count in the current five-master-only implementation. Reads resolve saved movable order into the unreserved slots and put fixed cards in their administrator-assigned slots. The employee write procedure rejects any complete order that moves a fixed card, including when another card is inserted before it.

`Master.Cards_setPosition(@CardId, @IsFixed, @DisplayOrder)` provides the database operation for later administration: it validates the card, bounds and fixed-position conflicts and changes LastChangeAt only on a real change. No admin portal, admin role mapping or admin HTTP endpoint exists yet. Grant this procedure only to the approved administration/deployment identity, never the employee API runtime identity; avoid broad schema-wide execution grants. The runtime only needs its previously documented read/employee-setting procedures and table type permissions.

GET `/api/user-settings/card-order` now also returns `cards`: cardKey, cardName, isFixed and displayOrder. The normal cardKeys list is the effective order. PUT still accepts only cardKeys; extra policy/identity fields are rejected. Fixed settings are never trusted from a browser request.

The frontend renders five master cards and no longer auto-creates a workspace card for every illustrative app. Master cards stay available; old local pin records no longer hide them. Fixed grip controls are disabled, keyboard moves skip fixed cards, and pointer/drop/storage restoration normalize the whole order to preserve reserved slots. Until a valid master policy is loaded or cached, reordering is disabled. A cached policy permits local-only offline movement while preserving its fixed slots; current server policy is always enforced when saving. Metadata labels use textContent. A delayed read applies current policy without discarding a newer local choice.

## Custom cards are per user

Custom cards are a separate future feature, not shared master definitions. Each card must have an owner UserId resolved from authenticated NTName. Reads, edits, deletion, ordering and app membership must filter by that owner on the server; request JSON must never choose the owner.

Only applications authorized for that employee may be listed, added to a card or launched. Enforce authorization on both reads and writes, and check it again after permission changes. A client-side filter, the current illustrative app directory, localStorage or knowing an AppId does not establish access. The real app authorization source and its lookup contract have not yet been supplied; do not invent grants from sample data. Future custom-card positions must join the workspace order and respect the same fixed global slots.

The old local-only custom-card editor is gated off until account-owned storage and an authorized app catalog are connected. Its source and stored definitions are retained; no old local groups are silently imported, deleted or presented as account-owned cards.

## Deployment and acceptance

Apply pending migration 009 after 008 using the deployment account, with UTF-8 input for Arabic names:

```powershell
sqlcmd -S localhost -E -b -f 65001 -i Database/Scripts/009_MasterCardPolicy.sql
```

Code checks cover fixed-slot normalization, conflicting policy validation, delayed reads, local fallback and latest-order writes. Live acceptance must verify five active definitions/all initially movable, policy-aware GET, normal saves, temporary fixed-card read placement, rejected forged PUT, disabled browser controls, movement around fixed slots, restoration of all-movable policy, and no-op timestamps/constraints. Restore temporary policy and employee-order changes after testing. Internal IIS and permission grants require destination-environment acceptance.

Local acceptance: both Release builds passed with zero warnings/errors; policy/synchronization checks and offline asset checks passed. Authenticated API tests passed with all cards movable and with القرارات temporarily fixed at position 2, including rejection of a forged fixed-position change and timestamp/no-op behavior. Browser tests verified five labels, no custom-card editor, a disabled fixed grip, movement of another card around the reserved slot, saved order after refresh, and restoration of the all-movable policy. Migration parity verification passed for 328 unchanged baseline files, 6 routes and 22 ordered scripts. Final SQL confirmed five active definitions with IsFixed=0, the requested default order, restored employee positions 0–4, 17 retained inactive definitions, unchanged ThemeId 2 and no constraints violations. Browser reload with the API stopped retained five cards and enabled movable grips from the cached policy, with a local-only status. Both test servers were stopped. Full touch-drag and internal IIS acceptance remain separate.
