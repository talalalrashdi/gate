# Central error logging

Both MVC and API use the shared `Shared/CentralLogging/CentralLogging.cs` implementation through the existing ILogger calls. There is no extra service to host. Shared source must accompany both solutions when copying source; published outputs already include it. SQL Client uses the existing API dependency versions and local offline feed.

## Setup

1. Run `Deployment/CentralLog-Setup.sql` in SSMS against the destination SQL Server. It creates CentralLog and its two error tables only when absent, preserving existing tables and records. It creates/updates dbo.ApplicationError_Insert and dbo.DatabaseError_Insert. Compatible with SQL Server 2017; no compatibility-level change. The other three CentralLog tables are not modified.
2. Set ConnectionStrings:CentralLog in **both** applications' environment settings. Set CentralLogging:SystemId (initially 9999), CentralLogging:Enabled and optionally FallbackDirectory. Default fallback is App_Data/Logs under each application's own root. Production examples use localhost as a placeholder: change the server and certificate settings for the actual SQL host. Retain certificate validation when a trusted SQL certificate is installed.
3. Grant each actual Windows application identity SQL login/database user access plus EXECUTE on the two logging procedures. No table SELECT/UPDATE/DELETE permissions are needed by the applications. This is the application/service identity, not the employee.
4. Give the application identity Modify permission on its App_Data/Logs folder. Restrict access to IT: files contain diagnostic data. Logs are outside wwwroot. No logs are exposed through a portal endpoint.
5. Restart both applications. Errors appear in ApplicationError; SQL failures also appear in DatabaseError. ExtraDetails JSON links the SQL record with DatabaseErrorId. Both records are inserted in one transaction to avoid orphaned database-error rows.

## Recorded values

- WorkStation is the evaluated **Environment.MachineName** value, never the literal expression. Under IIS it is the server running the app, as explicitly agreed.
- SystemID is configurable, default9999. Timestamp is inserted using SQL GETDATE(); ExtraDetails.At records UTC capture time.
- NtUserName is the authenticated request identity when available. Never substitute the service account for an employee. API resolves UserId using Security.User_getByUsername; lookup failure leaves it null without preventing logging. MVC may have no employee identity/database lookup and leaves unavailable fields null.
- Namespace/category and endpoint identify the component/action. MethodSignature and FileName are best-effort from exception stack/PDB; published source filenames may be unavailable. StackTrace includes the sanitized exception/inner exceptions.
- ErrorMessage is a bounded summary; ExtraDetails holds Reference, original message, request method/path (no query), application, assembly version, environment, capture time and SQL link/server.
- DatabaseError.DBName is the configured portal execution database. A cross-database procedure may fail in an external database; SQL procedure/message/stack provide additional context. Do not infer a different database from an unknown message.
- All responses carry X-Reference-ID; MVC ProblemDetails responses carry `reference` and MVC error pages display the same ID. API CORS exposes the header. Existing individual feature UI messages are retained. Background/startup logs have generated references.

## Behaviour and limits

Errors and critical events are captured; warnings are captured when they have exceptions (including Exchange/Dalil failures). Normal information, expected validation/authorization outcomes and confirmed cancelled browser requests are not stored as errors. No visits/access/audit tracking is added; existing admin change history is unchanged.

A bounded512-entry in-memory queue writes off the request path. SQL connection/command timeouts are3s, optional identity lookup is bounded separately. After a central write failure, entries go directly to local fallback for30s before another central attempt. A full queue writes locally immediately. Normal shutdown attempts to drain for5s and saves remaining queued entries locally; forced termination can lose in-memory entries.

Fallback is JSON Lines: errors.jsonl, rotated near10MiB with9 archives (approximately100MiB per application). Entries are not automatically replayed into SQL. If folder writing also fails, a minimal Reference ID/type message goes to standard error; ensure IIS/server log collection exists for that case. No recursive logger calls or logging of logging exceptions. Persistent retention/archiving of CentralLog records is an operational database policy; no automatic database purge is installed.

Request bodies, query strings, cookies, headers and SQL parameter values are not collected. Common password/token assignment patterns are redacted from exception text, but do not put secrets or mailbox/document contents in application exception messages. Do not expose CentralLog or fallback files to employees.

## Verification

Run on Windows with local SQL access:

```powershell
dotnet run --project CompanyPortal/Backend/tools/CentralLoggingChecks -c Release
```

Requires CentralLog setup and permission to insert/select/delete its uniquely labelled test records. Tests verify evaluated machine/NT account/SystemId, SQL record linkage, redaction, warning exceptions, cancellation filtering, disabled logging and unavailable-central fallback. Test rows and the unique temporary fallback file are removed afterward; existing errors are untouched. Application runtime needs only procedure EXECUTE, not the test runner's inspection/cleanup permissions.

CentralLog-Setup.sql is a separate deployment script copied by Publish-Airgap.ps1 with the other deployment files. CompanyPortal-Setup.sql and the historical current-data snapshot are unchanged; they do not create or export CentralLog.
