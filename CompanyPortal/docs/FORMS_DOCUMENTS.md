# الاستمارات والوثائق

The header dialog now reads authorized documents from CompanyPortal. Search matches DocumentName, the filename and the logical folder path. Folder and PDF/other filters use only the permitted results. The separate bottom section **وثائق تهمك** remains unchanged.

## Table

Migration `Backend/Database/Scripts/023_Documents.sql` creates `Mng.Document` if absent:

| Column | Definition |
|---|---|
| DocumentID | uniqueidentifier NOT NULL, primary key; DF_Document_DocumentID default NEWID() |
| DocumentName | nvarchar(100) NOT NULL |
| DocumentPath | nvarchar(150) NOT NULL; filename and extension only, Arabic supported |
| FolderID | int NOT NULL |
| Timestamp | datetime NOT NULL; EForm_EFormUploadedDate default GETDATE() |
| Active | bit NOT NULL; DF_Document_Active default 1 |

Timestamp uses the confirmed corrected spelling. DocumentID is a GUID rather than an identity column, as explicitly requested. There is no upload/editor or write API in this version.

Migration `024_FolderAndDocsRoot.sql` replaces the former development folder table with `Mng.Folder`, preserving existing FolderIDs, parent links, names, display/activity flags and identity seed. Its physical column order is:

| Column | Definition |
|---|---|
| FolderID | int IDENTITY(1,1), primary key |
| ParentID | int NULL |
| FolderName | nvarchar(200) NOT NULL |
| UnitMstID | int NULL, immediately after FolderName |
| IsForDisplay | bit NOT NULL, default 1 |
| Timestamp | datetime NOT NULL, default GETDATE() |
| Active | bit NOT NULL, default 1; last column |

UnitMstID's type/nullability were not supplied, so nullable int is used without inventing unit assignments. Existing rows receive NULL for UnitMstID and migration time for Timestamp. New rows receive their insert time. Timestamp is not an automatic last-modified field. The marked local VFolder view now selects from Mng.Folder, including its new columns; real external views are not overwritten by migration 024.

The migration uses a transaction and verifies copied values. It refuses table-name collisions, custom dependencies on the old development table and conflicting Documents/docs keys. Rerunning it preserves rows/timestamps and does not modify an already-renamed key. The existing path, activity flag and UtlsId survive the key rename; LastChangeAt records the actual rename.

## Source views, function and manual access list

`Backend/Database/Integration/ConfigureDocumentLookup.sql` installs `App.CreateFolderPath` and `Portal.Document_GetAll @UserId`. It requires these view columns:

- `dbo.VFolder`: FolderID, ParentID, FolderName, Active, IsForDisplay.
- `dbo.VJobMainPeriod`: UserID, ID. This mapping is inferred for local development and must be checked against the real view before deployment.

The procedure maps the supplied portal UserId to VJobMainPeriod.ID and tests it against an explicit manually maintained `@FullAccessIds` list in the procedure. Add authorized **view IDs**, not blindly portal UserIds:

```sql
DECLARE @FullAccessIds TABLE(ID int NOT NULL PRIMARY KEY);
INSERT @FullAccessIds(ID) VALUES(12345),(23456); -- replace with actual authorized view IDs
```

The integration template defaults to an empty list. The local initializer writes the current test employee's actual sample view ID into a generated development copy. That generated copy is not for internal deployment. Administrator status alone does not bypass the list.

All employees receive active documents in active, displayable folders with valid active ancestors. Employees outside the list cannot see folder **74 or its descendants**, as assumed and stated before implementation. A missing employee mapping gives ordinary folder access, never full access; the API still requires an active registered portal employee.

The procedure returns `DocumentID, DocumentName, DocumentPath, FolderID, ParentID, FolderName, FolderPath`. FolderPath is `App.CreateFolderPath(FolderID) + FolderName`. The function preserves the supplied `name + ' \ '` ancestor convention. Missing/inactive/duplicate parents, cycles, excessive depth (128 parents) and overlong paths fail closed instead of looping or returning partial paths. Invalid hierarchies are excluded. Filename/path safety is checked again before any file is opened.

Migration 023 initially installs a fail-closed procedure stub if absent; rerunning it preserves a configured procedure. Install the integration script **after** the views exist. Applying an unedited integration template resets the manual full-access list to empty, so maintain the intended list in your reviewed deployment copy.

## File roots and behaviour

Configure active `CompanyPortal.Mstr.Utls` rows with key **docs**. The key was changed from Documents to docs by request in migration 024. It is read via `Mstr.Utls_GetFolderPaths`, with no configuration-file fallback or cached roots.

The physical location is **root + FolderPath + DocumentPath**. Separator padding in logical paths is removed when resolving physical segments. Example:

```text
Mstr.Utls: docs = D:\PortalFiles\Documents
FolderPath: الموارد البشرية \ الاستمارات
DocumentPath: طلب إجازة.docx
File: D:\PortalFiles\Documents\الموارد البشرية\الاستمارات\طلب إجازة.docx
```

Multiple fully qualified local or UNC roots are supported. The API process identity needs file read access and, on UNC storage, share read access. Employees must not have write access to trusted file roots. Keep protected documents outside public static website directories. A drive-relative path such as `\folder\Documents` is not a valid root.

- PDF: inline display in a new tab, PDF signature validation, range support and no editor provided by the portal. Browsers may still save or print PDFs; inline display cannot guarantee download prevention.
- Every other file: attachment download using the original filename, with a UTF-8 filename header for Arabic and application/octet-stream.
- Filenames must be single safe segments. Absolute filenames, traversal, alternate streams, device paths, invalid folder segments and reparse points are rejected.

`GET /api/documents` resolves the current Windows NTName to an active UserId and returns only permitted metadata. Logical folder names and filenames are visible, but physical roots are not. `GET /api/documents/{DocumentID}/file` repeats the current permission lookup before streaming; no browser-supplied path or UserId is accepted. Results are private/no-store. The dialog fetches when opened, clears results on close/hide/failure, and rereads when resumed. It does not persist document content or the authorization catalog in browser storage.

## Development setup

From the repository root, after earlier migrations and the sample SecurityDB:

```powershell
sqlcmd -S localhost -E -b -f 65001 -i CompanyPortal/Backend/Database/Scripts/023_Documents.sql
sqlcmd -S localhost -E -b -f 65001 -i CompanyPortal/Backend/Database/Scripts/024_FolderAndDocsRoot.sql
powershell -NoProfile -File CompanyPortal/Backend/tools/Initialize-DocumentFixture.ps1
```

The initializer creates marked development views over `Mng.Folder` and `Mng.DocumentSampleJobs`, preserving an existing unmarked pair of source views by refusing to replace them. It seeds seven fictional document records: four ordinary files, two files in the restricted 74/75 branch and one file in a hidden folder. All seven PDF/DOCX files use Arabic filenames under `Backend/artifacts/document-fixture`. PDF fixture contents are English; DOCX contents include the Arabic filename. File generation is development tooling only, with no runtime document-generation package added.

The local test employee receives an explicit sample view ID in the procedure. The sample ID currently differs from portal UserId to demonstrate the mapping. The docs folder setting is added only when the key is absent. Existing document records, timestamps, files and folder settings are not overwritten on rerun. Rerunning the initializer reinstalls its sample procedure access list; never use it after configuring real permissions.

## Internal deployment and errors

Apply pending migrations through 024, supply the real views, review the UserID-to-ID mapping and manual list in the integration script, configure docs roots and SQL/file rights, then republish both apps. Do not deploy the development views or their generated access list internally. Fresh Setup SQL includes the table and fail-closed stub only. Existing CurrentData exports and Airgap publish folders were not refreshed for this feature; they need the pending migrations and republish.

401 indicates Windows authentication; 403 indicates an inactive/unregistered employee. File 404 covers missing access, inactive/hidden documents, invalid hierarchy/path, missing file or invalid PDF. A sanitized 503 indicates source/SQL/folder-configuration/read-permission failure; the API logs its detailed cause. Missing file roots do not prevent listing authorized metadata.

## Verification

Both Release builds passed with no warnings. `Backend/tools/Test-Documents.ps1` checks list and file authentication, 74/75 restriction and revocation, hidden/inactive items, cycles/orphans, unsafe paths, PDF signature/ranges, Arabic DOCX attachment filename, missing roots, GUID default and Swagger. Changed fixture paths, flags, access mappings and employee status are restored afterward; the default-value insert is rolled back.

`tools/verify-documents.mjs` executes the real renderer for search, folder/format filters, PDF-vs-download links, plain-text rendering, GUID URL validation, close/hide clearing and empty/error/retry handling. Local browser search/filter/keyboard/layout and permission-filtered rendering checks passed. Decisions regression, offline asset scan and original frontend parity checks also passed. Real internal views, UNC share access and IIS remain destination checks.
