# Temporary UI diagnostics

Open the portal and click **فحص الاتصال (مؤقت)**, or visit `/admin/diagnostics`. Click **بدء الفحص**. The page shows the failed step, an error code, a next step and a log reference. **نسخ التقرير** copies the authorized results, without mailbox contents, connection strings or raw exceptions.

It checks browser→API reachability, employee Windows identity vs API process identity, SQL connection, selected required objects, external identity/role lookup, PubsInfo roots, Exchange flags/URLs/timezone, mailbox mapping and (when configured/enabled/registered) EWS Inbox/Calendar/Tasks folder metadata. Individual API steps time out after eight seconds. There is no automatic background diagnostic polling.

## Allow diagnostics before SQL works

Normally the API authorizes through the existing CompanyPortal.Admin role. If SQL is broken or the destination test account is not yet registered, configure an **explicit approved Windows account** in the API's `appsettings.Production.json`:

```json
"Diagnostics": {
  "Enabled": true,
  "BootstrapAccounts": ["MYDOMAIN\\my-test-admin"]
}
```

Use the actual authenticated account, not the API app-pool account unless that is also the person browsing. The API must already have Windows Authentication working. Recycle the API pool after changing this setting. The list is empty by default. It grants only this read-only diagnostics endpoint, not admin editing, portal registration or mailbox access. Browser-provided usernames cannot grant access. The result includes employee and process NTNames, so review a copied report before sharing it.

The frontend is a public shell. A link being visible does not authorize access to diagnostic results. When SQL-based authorization is unavailable, the page explains how to configure the explicit bootstrap account rather than exposing SQL details to an unverified visitor.

## Interpreting results

- **نجح:** this particular check completed. It does not imply the later checks passed.
- **فشل:** correct the indicated configuration/access problem and rerun.
- **يحتاج إعدادًا:** a disabled/unconfigured option or unavailable news folder needs attention.
- **لم يُفحص:** a prerequisite failed or the feature is disabled.
- **اختبار يدوي:** actual message arrivals, streaming, Outlook Web links, recurring/all-day display and private/delegate permissions still need end-to-end testing.

SQL errors identify login denial, inaccessible databases, missing objects/procedures and permissions where SQL provides those codes. EWS errors retain the EWS response code and suggest checking scoped impersonation/access. HTTP 401/403, common TLS/network failures and timeouts have separate guidance. If the underlying platform only reports a generic error, the page gives the log reference rather than guessing an exact cause. The configured HTTPS URLs are server settings; this endpoint accepts no mailbox or destination URL from the browser. It never changes SQL/Exchange data and does not start streaming subscriptions.

Folder existence is not a complete file-permission test. Configuration format is not proof that OWA login works. Required-object presence is not complete schema or feature acceptance. Use FULL_TEST_CHECKLIST.md after correcting diagnostics.

## Switch it off later

Set `Diagnostics:Enabled` to **false in both the Frontend and Backend** Production settings and recycle both app pools. The frontend links/page and API diagnostics endpoint will return unavailable/404. Empty the BootstrapAccounts list. No SQL migration or data cleanup is needed.

This is implemented in SetupDiagnosticsController.cs, EwsMailSession.Diagnostics.cs, Admin/Diagnostics.cshtml, setup-diagnostics.js/css and the temporary links in the shared portal/admin templates. Those can be removed later without altering the employee theme/card/Exchange data.
