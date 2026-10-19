# Database folder paths

Folder locations are now read from **CompanyPortal.Mstr.Utls**, through **Mstr.Utls_GetFolderPaths**. This replaces the previous News:AllowedRoots appsettings configuration.

## Table and procedure

Migration `014_UtilityFolderPaths.sql` creates the Mstr schema/table if missing and creates or updates the procedure. Existing table rows are preserved on rerun. Mstr is the schema explicitly requested for utilities; existing Master theme/card tables are not renamed.

| Column | Definition |
| --- | --- |
| UtlsId | First column; int identity primary key |
| Key | nvarchar(200); identifies the feature using the folder |
| strVal | nvarchar(4000); fully qualified folder path |
| Active | bit, default 1; inactive rows are excluded |
| LastChangeAt | datetime, default GETDATE(); update it when maintaining a changed value |

The procedure takes no parameters and returns active rows with exactly these columns:

```sql
SELECT [Key], strVal AS [Path]
FROM Mstr.Utls
WHERE Active = 1;
```

Use it with:

```sql
USE CompanyPortal;
EXEC Mstr.Utls_GetFolderPaths;
```

## News: PubsInfo

The API selects the returned rows whose Key is `PubsInfo`, case-insensitively. Other keys do not authorize news files. Multiple rows may share the same key, allowing PDFs and pictures to use separate folders. Example configuration only:

```sql
INSERT Mstr.Utls ([Key], strVal)
VALUES (N'PubsInfo', N'D:\PublishedNews\PDF'),
       (N'PubsInfo', N'D:\PublishedNews\Pictures');
```

Choose the real folders before running configuration SQL internally. The numbered migration deliberately seeds no machine-specific paths. Runtime reads do not modify settings. Maintain LastChangeAt with GETDATE() when changing a row; its insertion default does not automatically track later updates.

For each PDF/picture request, the API reads the procedure, selects PubsInfo roots and confirms the source file path from dbo.VNews lies within one of those folders. Paths are not exposed to the browser. The folder values do not rewrite source file paths or replace their filenames.

There is no appsettings fallback or path cache. Folder changes apply to the next file request without restarting; an already-started download may finish. Missing/inactive/blank/relative PubsInfo roots or database failures make files unavailable. News summaries can still load independently. Full absolute paths are required; the old relative appsettings-root behavior is removed.

Filesystem boundary, file signature and reparse-point checks remain in place. The API IIS identity needs read access to the folders, and employees must not be able to write arbitrary files into them. These settings are trusted server configuration, maintained by authorized database/deployment administrators; there is no new folder-management API or admin page.

## Local and internal deployment

- Apply migration 014 after 013.
- Locally, `Initialize-NewsFixture.ps1` also runs development script 005 to insert the fixture folder under PubsInfo only if that key has no rows. It never overwrites existing paths or reactivates inactive configuration. The script requires the marked development news view.
- Internally, do not run the development initializer or development scripts. Populate Mstr.Utls with the actual server-accessible paths and use the real news view. If Mstr.Utls already exists there, check that its columns match the procedure before deployment.
- Grant the API SQL identity EXECUTE on Mstr.Utls_GetFolderPaths in addition to existing news/identity procedure permissions. Do not grant runtime table-write rights or db_owner for this lookup.

Local verification passed: Release build, migration application, sample PDF/picture/range checks, unrelated-key isolation, inactive/missing roots, invalid relative roots and changed paths taking effect without restart. The test restored the PubsInfo path/active state and removed its own temporary test-key row. Migration rerun checks are recorded with the news setup.

Run the fixture-only integration checks against an isolated local environment:

```powershell
powershell -NoProfile -File Backend/tools/Test-News.ps1 -TestSampleData -TestFolderPaths
```

These tests temporarily modify sample publication/folder settings and restore them. Do not run the fixture switches against production or while other users are editing those settings.
