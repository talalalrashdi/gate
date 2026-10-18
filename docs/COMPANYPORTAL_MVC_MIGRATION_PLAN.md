# CompanyPortal — Frontend Migration Plan

Agreed: 18 October 2026.

Status: implementation started after subsequent user authorization. The initial MVC project now lives in `CompanyPortal/Frontend/`. See [current migration status](../CompanyPortal/docs/MIGRATION_STATUS.md) for completed checks and pending gates. This document was originally created as a plan; file/code cleanup remains the final implementation step after verification.

## 1. Agreed objective

Migrate the existing portal frontend into a clean, working **ASP.NET Core MVC application targeting .NET 10**. The project name is **CompanyPortal**.

Milestone 1 establishes the frontend base project and preserves the current design and interactions. A separate Web API will be connected in a later milestone.

Use established practices with the simplest structure that is easy to understand and maintain. Add layers, dependencies, and abstractions only when they address a concrete requirement.

## 2. Two independent solutions in one parent folder

The frontend and future backend have separate solution files. Keep both under one parent folder so they can be copied together to the internal air-gapped network.

```text
CompanyPortal/
  Frontend/
    CompanyPortal.Frontend.slnx
    CompanyPortal.Web/
      Controllers/
      Models/
      Views/
        Home/
        Profile/
        Shared/
          _Layout.cshtml
      wwwroot/
        css/
        js/
        assets/
      Properties/
        launchSettings.json
      CompanyPortal.Web.csproj
      Program.cs
      appsettings.json
  Backend/                          # Future milestone only
    CompanyPortal.Backend.slnx
    CompanyPortal.Api/
  docs/
```

Create only the frontend solution during this milestone. The backend tree above describes the future arrangement; it is not a request to scaffold an API now. Each solution must be independently buildable. Do not nest the API project inside the web project or put both projects into one solution.

The tree describes the target structure, not a requirement to rename or move the current workspace immediately. Decide the actual migration location before implementation and keep the original source available until verification and final cleanup.

## 3. Technology and frontend approach

- Use ASP.NET Core MVC on .NET 10, with controllers and Razor views. Do not use Razor Pages.
- Reuse the current HTML, CSS, and vanilla JavaScript.
- Convert portal and profile HTML into MVC views.
- Introduce a shared layout and useful partial views after the initial migration works.
- Put public frontend assets under `wwwroot` and preserve working relative paths or update them consistently.
- Preserve stylesheet and classic JavaScript loading order, selectors, global helpers, custom events, and shared page dependencies.
- Keep the Arabic interface, RTL layout, local GT America Arabic font, existing themes, and current interactions.
- The CompanyPortal name applies to the solution/project structure and documentation. It does not itself request a visual rebrand or changes to existing storage key names.
- Keep existing local functionality working until a later API integration replaces it deliberately.

## 4. Milestone 1 scope and exclusions

Included:

- A working .NET 10 MVC frontend solution.
- Portal and profile routes/views with the existing appearance and behavior.
- A simple, understandable project structure.
- Verification after each migration step.
- Final removal of files and code proven unnecessary.
- Local run instructions and preparation notes for the air-gapped environment.

Deferred to later milestones:

- The separate Web API solution and API contracts.
- Authentication, employee identity mapping, and authorization infrastructure.
- SQL Server, Entity Framework Core, database schemas, and migrations.
- Server persistence and bulk browser-data imports.
- HR, correspondence, workflow, document, or other enterprise integrations.
- New business features and visual redesign.

Do not add speculative service layers, empty repositories, or placeholder API implementations to anticipate these later features. Record future data integration points without redesigning the existing data flow during this milestone.

## 5. Incremental implementation sequence

Complete and verify each step before proceeding. Keep changes small enough to identify the cause of a regression.

### Step 1 — Establish the baseline

- Read applicable project instructions and relevant reference material.
- Map the portal and profile entry pages, loaded styles/scripts, assets, and interactions.
- Record shared dependencies and script/style order.
- Capture representative desktop and mobile views and record what behavior has actually been checked.
- Record current working-tree changes and preserve unrelated edits.

Exit check: a clear inventory and verification checklist exist. No cleanup or source deletion has occurred.

### Step 2 — Create the MVC foundation

- Confirm/install the .NET 10 SDK as needed. The planning inspection found SDKs 6, 8, and 9, but no .NET 10 SDK; recheck before implementation.
- Create the frontend solution and MVC web project alongside the retained original source.
- Configure predictable local launch settings and a minimal working route/view.
- Keep generated project code minimal; do not add backend functionality.

Exit check: `dotnet build` succeeds and `dotnet run` starts the MVC application.

### Step 3 — Migrate the initial frontend

- Copy the required assets into `wwwroot` without deleting their original sources.
- Convert the portal and profile pages into MVC views, making only the changes needed for MVC routing, asset references, and Razor syntax compatibility.
- Retain current CSS/script loading order and frontend behavior.
- Keep the original implementation available for comparison.

Exit check: both pages render, navigation works, and required resources load without missing files or JavaScript errors.

### Step 4 — Verify existing behavior

Check the migrated application against the baseline:

- Desktop and mobile layout.
- Available themes 2, 3, and 4.
- Calendar, task creation/editing/deletion/completion, and notes.
- Search, notices, and section navigation.
- Workspace cards, pinned systems, groups, ordering, and concealment.
- Existing service-form draft behavior.
- Documents, library, magazine, and media interactions where present.
- Profile page and its shared styles.
- Browser preference and task persistence across reloads.

Exit check: relevant behavior matches the baseline, or any limitation is explicitly recorded and resolved before dependent work continues. Source inspection alone does not count as visual or runtime verification.

### Step 5 — Organize MVC views and code

- Extract the common page shell into `Views/Shared/_Layout.cshtml`.
- Extract coherent sections into partial views where this makes the files easier to understand.
- Keep controllers thin and add models only where the views actually need them.
- Preserve DOM contracts and avoid unrelated JavaScript/CSS rewrites.
- Verify affected routes and interactions after each organizational change.

Exit check: the organized MVC application still matches the verified migrated behavior.

### Step 6 — Clean up last

Cleanup is the final migration step. Do not combine initial migration, structural refactoring, and deletion into one change.

- Classify files as runtime dependencies, useful development/documentation resources, or removal candidates.
- Check references and runtime use before deleting files or code.
- Review previews, image-generation outputs, old helpers, duplicate assets, and unused code individually; names alone do not prove they are unnecessary.
- Remove superseded Vite/npm tooling only after .NET hosting is working and nothing retained needs it.
- Retire the original frontend source only after its migrated replacement is verified.
- Update README/run instructions, appropriate .NET ignore rules, and relevant project guidance to reflect the new structure.
- Run the final build, startup, resource, and behavior checks.

Exit check: the cleaned frontend solution runs independently, required assets remain, and the documented checks pass.

## 6. Data and source preservation

- The current `gate/dist` contains editable source; it is not disposable build output. Never run cleanup commands that treat it as generated output before migration is complete.
- Preserve existing `localStorage` keys and values. Do not clear storage, reset initialization flags, or silently replace user data.
- Browser storage belongs to its origin. A change in scheme, hostname, or port can make existing values unavailable to the new address even though they were not deleted. Document this and provide an explicit preservation/transfer approach if needed; do not claim automatic migration.
- Preserve current themes and profile-page dependencies. Do not restore the removed Design C or previously removed UI elements.
- Keep unrelated edits intact throughout the migration.

## 7. Air-gapped network preparation

The common parent folder simplifies copying both future solutions together, but source files alone are not an offline build environment.

Document:

- The required .NET 10 SDK and supported deployment runtime/hosting prerequisites.
- The NuGet packages and an offline restore source needed for the selected dependency set.
- Separate instructions for building from source and running a published deployment.
- Current external frontend dependencies, including Iconsax CSS and externally hosted imagery.
- How required frontend resources will be made available locally, subject to their licensing, or how optional external content behaves without internet access.

Verify essential rendering without internet access before declaring the frontend ready for the internal environment. Choose the production hosting/publishing approach when the internal target is known; do not assume that it is already configured.

## 8. Definition of done

- The CompanyPortal frontend uses ASP.NET Core MVC on .NET 10.
- Its frontend solution builds and runs independently.
- Portal and profile views retain the agreed design and working interactions.
- Required assets resolve; relevant runtime checks show no migration-related JavaScript errors.
- Existing browser data has not been deleted or silently replaced, and origin limitations are documented.
- Shared layout/partials improve readability without unnecessary architectural layers.
- Cleanup occurs only after migration and verification, with dependencies checked before deletion.
- Run instructions and offline prerequisites reflect the actual implementation.
- No API, database, authentication, or business-feature expansion is included in this milestone.

## 9. Relationship to the earlier architecture plan

`ENTERPRISE_ARCHITECTURE_PLAN.md` remains a reference for potential later backend work and the existing frontend/storage inventory.

This document supersedes its backend-first recommendation for the immediate milestone. The agreed next work is frontend MVC migration first, with two separate solutions under one parent folder. The earlier identity/database decisions are not prerequisites for this frontend-only milestone.

The earlier architecture report records Vite 8.0.13 as its assessment baseline. The dependency remediation completed before this discussion updated the working project to Vite 8.3.4 and source-map-js 1.2.2. Do not revert those changes while preparing the migration.
