# IIS and offline deployment

## What to transfer

For development, copy the `CompanyPortal` folder with its `Frontend`, `docs` and optional verification tools. The future `Backend` solution does not exist yet. The frontend solution builds independently of the original Vite project, `dist`, Node.js and npm.

Prepare a .NET 10.0.4xx SDK installer matching `Frontend/global.json`. Visual Studio development needs Visual Studio 2026 with the ASP.NET and web development workload; an offline workstation needs the complete Visual Studio offline layout, not only the small bootstrapper. Building/running via the CLI does not require Visual Studio.

The current web project has no additional NuGet package references. Restore was tested against an empty local feed using the installed SDK/reference packs. Future package additions must bring their full dependency set and a local package source into the isolated network; do not assume a developer's cache is portable.

For deployment only, transfer the **complete publish output**. It contains compiled views/application files, `wwwroot`, configuration and the generated IIS `web.config`. Do not copy source folders into the IIS website or omit generated files.

## Publish

Stop local/debugging instances before rebuilding. From `CompanyPortal/Frontend`:

```powershell
dotnet restore CompanyPortal.Frontend.slnx
dotnet publish CompanyPortal.Web --configuration Release --output ../artifacts/publish
```

Use a fresh publish directory for release delivery so retired assets do not survive an overlay copy. `artifacts` is ignored by Git. The verified output is a framework-dependent Windows development-machine publish; select matching architecture when deploying. For the current x64 publish, use an x64 app pool/runtime.

## Prepare the IIS server

1. Confirm the exact Windows Server version against Microsoft's .NET 10 supported OS list.
2. Enable IIS and the required web-server features using the organization's installation media/process.
3. Install the current supported .NET 10 **Hosting Bundle**, which supplies IIS integration and the ASP.NET Core runtime. If it was installed before IIS, repair/reinstall it after IIS is enabled. Restart IIS as required by the installer.
4. Create a dedicated application pool with **No Managed Code** and Integrated pipeline. Disable 32-bit applications for the verified x64 deployment. Give the pool identity read/execute access to the published folder; grant write access only to specific future directories that need it.
5. Create a website pointing at the publish folder, or an IIS application under an existing website. Use a separate app pool for this ASP.NET Core application. An ordinary virtual directory is not an application.
6. Configure the approved internal DNS/host binding and HTTPS certificate. Employee machines must trust the internal issuing CA. Configure any HTTP-to-HTTPS policy in the approved hosting setup.
7. Run with `ASPNETCORE_ENVIRONMENT=Production`. Keep detailed diagnostics disabled. `launchSettings.json` only controls local development; it is not the server's deployment configuration.

The generated `web.config` uses `AspNetCoreModuleV2` with in-process hosting. Keep it with the publish output. A self-contained publish would still require the IIS module; this project currently uses the simpler framework-dependent model.

## Hosting paths and local resources

Both site-root hosting and a `/companyportal/` IIS sub-application were checked using IIS Express and the ASP.NET Core module. MVC generates application-relative asset/navigation URLs. The shared layout's base URL also keeps JavaScript-generated image and magazine URLs within the application path.

Iconsax CSS and all referenced font formats are local under `wwwroot/vendor/iconsax`, with the original notice and source/terms links retained. Arabic fonts, photos, magazine content and PDF assets are local. The previous external news thumbnail now uses an existing, explicitly illustrative local image. Original photographic backgrounds were not replaced.

External news/source hyperlinks remain outbound links; they are not background API/feed calls and cannot open without access to their destinations. No business Web API, database or authentication has been added. Employee and institutional content remains illustrative, and service requests are local drafts.

## Acceptance and troubleshooting

Complete `FRONTEND_ACCEPTANCE.md` on the target environment. Local IIS Express checks do not replace real-server/browser acceptance.

- If Visual Studio cannot copy the executable, stop its debugger and any terminal-run instance before rebuilding.
- If IIS returns a startup/module error, first check the Hosting Bundle, architecture, generated `web.config`, application pool and Windows event logs. Enable temporary diagnostic logging only while troubleshooting, then disable it.
- Changing scheme, hostname or port changes the browser-storage origin. Deployment does not automatically import tasks/preferences from localhost. Preserve the original browser data; do not clear all localStorage to resolve differences.
- Keep the previous release and an approved rollback procedure. Bring SDK/runtime/Hosting Bundle patches into the isolated network through the organization's update process.

References: [IIS hosting](https://learn.microsoft.com/en-us/aspnet/core/host-and-deploy/iis/?view=aspnetcore-10.0), [Hosting Bundle](https://learn.microsoft.com/en-us/aspnet/core/host-and-deploy/iis/hosting-bundle?view=aspnetcore-10.0), [supported OS versions](https://github.com/dotnet/core/blob/main/release-notes/10.0/supported-os.md), [Visual Studio offline layout](https://learn.microsoft.com/en-us/visualstudio/install/create-an-offline-installation-of-visual-studio).
