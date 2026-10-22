# Update for SQL Server 2017 and EWS HTTP500

## SQL already imported

Do not import the snapshot again. Run **SqlServer2017-Compatibility.sql** in SSMS against the offline instance. It changes the three database compatibility levels to **140**, without rebuilding tables or changing saved rows. Level100 can hide problems until a feature uses OPENJSON; that feature needs level130 or higher.

The current snapshot and export generator now target SQL Server2017/level140 and omit SQL2019-only OPTIMIZE_FOR_SEQUENTIAL_KEY=OFF. Snapshot INSERT statements/image bytes are unchanged. Compatibility-mode tests on the local SQL2019 engine are not a substitute for testing on an actual SQL2017 engine.

## API update only

1. Stop the API's PowerShell window with Ctrl+C.
2. Copy the **Backend/CompanyPortal.Api.dll** from CompanyPortal-EwsFix.zip over the same DLL in your existing offline Backend folder. The PDB is optional for server logs. This patch uses the existing dependencies; there are no new packages. **Keep your current appsettings files and environment configuration.**
3. Start the API again with the same localhost commands/settings you used successfully. Restarting a PowerShell window loses process-only `$env:` settings, so repeat those commands if needed.
4. Open the existing diagnostics UI and click بدء الفحص. Send back the three EWS result codes and next-step text. The frontend files do not need replacing for this patch.

Previously, an EWS HTTP500 was thrown before its SOAP response could be inspected. The updated client safely reads a bounded, DTD-disabled error envelope, extracts only an EWS error identifier, and keeps raw SOAP/fault messages out of the UI. The same handling applies to streaming HTTP errors. HTML/empty/non-SOAP failures retain HTTP500 and point to Exchange's EWS/HTTP Proxy logs; we do not infer a permissions failure from HTTP500 alone.

If the code is **ErrorImpersonateUserDenied / ErrorImpersonationDenied**, ask the Exchange administrator to check the actual Windows account running the API and its scoped ApplicationImpersonation permission for the mapped mailbox. For localhost, this is the account running `dotnet`, not a future IIS identity. Your other harness accesses Exchange directly as the employee; it did not test this EWS impersonation permission. Do not change scopes or switch authentication models based on a generic HTTP500.

No Exchange account/permission changes were made by this patch. Actual Exchange access still needs to be confirmed on the offline machine.
