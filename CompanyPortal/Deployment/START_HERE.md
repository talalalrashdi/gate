# CompanyPortal offline IIS test — quick start

**For setup problems:** click **فحص الاتصال (مؤقت)** in the portal. See [TEMPORARY_DIAGNOSTICS.md](TEMPORARY_DIAGNOSTICS.md) to authorize a test administrator even before SQL works.

For your separate Windows 10/SQL Express test machine, follow [FULL_TEST_CHECKLIST.md](FULL_TEST_CHECKLIST.md), including OS/SQL version checks and the supplied read-only Test-Destination.ps1. Install IIS and the .NET 10 x64 Hosting Bundle before starting.

Copy the entire published `artifacts/Airgap` folder to the offline network. Also take the **.NET 10 x64 Hosting Bundle installer** and required internal certificates. No npm, Node, SDK or NuGet feed is needed to run the published files.

**To carry the current sample data, images, themes and settings exactly as saved:** import **CompanyPortal-CurrentData.sql** using [CURRENT_DATA_README.md](CURRENT_DATA_README.md). This replaces step 2 below. Do not also run CompanyPortal-Setup.sql. Copy NewsFiles and outside.pdf too for the existing external news attachments.

1. Install IIS with Windows Authentication, then install/repair the Hosting Bundle.
2. In SSMS, open `Deployment/CompanyPortal-Setup.sql`. Edit the test employee's NTName, API service identity and portal URL at the top. Run it once on a **fresh test installation**. Sample mode creates CompanyPortal, SecurityDB and Pubs_Info_V4 and refuses existing databases. To use real security/news sources, select `TestSources=0` and configure the adapters described in the full guide.
3. Create an HTTPS IIS site pointing at `Frontend`. Add an IIS **Application** named `backend` pointing at `Backend`. Use separate x64 **No Managed Code** app pools.
4. Frontend: Anonymous ON, Windows authentication OFF. Backend: Anonymous OFF, Windows authentication ON. Run the API pool under the approved domain service account with SQL and scoped Exchange permissions.
5. Copy each supplied Production JSON example into the matching published folder as `appsettings.Production.json`. Replace the example SQL host, portal hostname, Exchange/Outlook URLs and employee mailbox mappings. Set frontend API URL to `https://YOUR-PORTAL/backend/`.
6. Once Exchange access is approved/configured, set **Enabled=true** and **ScheduleEnabled=true**. Set the real OutlookWebInboxUrl. Recycle the API pool.
7. Open the portal from a domain employee PC. Test theme save/reload, mail unread counts, today's/month agenda, tasks and updates while the tab stays open. For the initial streaming test disable API compression, use one API worker and set API pool idle timeout to 0.

The service identity authenticates to SQL/Exchange; the browser employee is separately identified by Windows login and mapped to their own mailbox. Shared calendar configuration does not grant delegation. Actual delegate/private access and live notifications must be tested internally.

**Keep current images/themes/settings?** Restore a CompanyPortal SQL backup instead of running the fresh-install script. The script creates the base data, not an export of current uploads/preferences.

See [the full IIS guide](../AIRGAP_IIS_GUIDE.md) in the published handoff, or [the source guide](../docs/AIRGAP_IIS_GUIDE.md), for exact settings, permissions, real-source configuration and troubleshooting. Microsoft reference: [ASP.NET Core on IIS](https://learn.microsoft.com/en-us/aspnet/core/host-and-deploy/iis/?view=aspnetcore-10.0).
