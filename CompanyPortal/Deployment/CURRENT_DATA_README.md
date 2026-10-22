# Import the current databases with their existing data

Use **CompanyPortal-CurrentData.sql**, instead of CompanyPortal-Setup.sql. Do not run both.

This is the actual local database state exported on 20 October 2026: all 20 tables / 132 rows across **CompanyPortal**, **SecurityDB** and **Pubs_Info_V4**, including inactive/soft-deleted test rows. It includes schemas, tables, table types, keys, indexes, constraints, views, stored procedures, extended properties, current identity counters, and all table data. The 9 SQL image records include their full binary content; themes, groups, assignments, user preferences, cards, app grants and role grants retain their existing IDs and values.

## Import

1. Use a fresh SQL Server 2017 or later test installation where **none of these three database names exists**. The script refuses existing databases and never drops them. If the offline SQL instance already has a real SecurityDB/Pubs_Info_V4, use a separate test instance for this exact three-database snapshot.
2. Open `CompanyPortal-CurrentData.sql` in SSMS and execute the whole file. No SQLCMD mode is required. Or run:

   ```powershell
   sqlcmd -S YOURSQL -E -b -I -f 65001 -i .\CompanyPortal-CurrentData.sql
   ```

3. Stop if any SQL error occurs; do not continue/replay over a partial installation. The script uses the destination SQL Server's default database file locations. It contains no source server MDF/LDF paths.
4. Configure the API connection string and its destination domain service identity/SQL rights as described in the IIS guide. **Server logins, passwords and machine-specific SQL users/permissions are not copied.** Create/map the API service login in all three databases. It needs EXECUTE on the CompanyPortal application procedures, EXECUTE/REFERENCES on its table types, and SELECT on the sample SecurityDB/Pubs_Info_V4 source tables. The import account needs database creation rights; the API account does not need db_owner/sysadmin.
5. Existing sample users keep the original machine's NTName. Before testing Windows sign-in, map the intended internal test employee to the existing sample UserId in `SecurityDB.dbo.Users` (retain that UserId to keep its settings/cards/grants), or explicitly register another test user with their own grants. Align `Exchange:MailboxAddresses` keys with the actual authenticated NTNames and configure EWS/Outlook URLs. Exchange permissions remain an infrastructure prerequisite, not database data.

## News PDFs and pictures

SQL images from صور الواجهة are embedded in the SQL export. News PDFs/pictures are external files and are supplied in **NewsFiles/**. The intentional outside-root test PDF is supplied as **outside.pdf**, beside that folder; missing/invalid/denied fixture cases are retained exactly as before.

The exported news paths and `Mstr.Utls` root are preserved unchanged:

```text
E:\GatePortal\gate\CompanyPortal\Backend\artifacts\news-fixture
```

Either copy the contents of NewsFiles to that exact destination directory (and outside.pdf to its parent), or copy to another directory and update paths after import. Example for `C:\CompanyPortal\NewsFiles`:

```sql
DECLARE @Old nvarchar(4000)=N'E:\GatePortal\gate\CompanyPortal\Backend\artifacts\news-fixture';
DECLARE @New nvarchar(4000)=N'C:\CompanyPortal\NewsFiles';
UPDATE CompanyPortal.Mstr.Utls SET strVal=@New WHERE [Key]=N'PubsInfo' AND strVal=@Old;
UPDATE Pubs_Info_V4.dbo.Public_info_News
SET PIN_PicturePath=@New+SUBSTRING(PIN_PicturePath,LEN(@Old)+1,4000)
WHERE LEFT(PIN_PicturePath,LEN(@Old)+1)=@Old+N'\';
UPDATE Pubs_Info_V4.dbo.Attachment
SET ATT_File_Path=@New+SUBSTRING(ATT_File_Path,LEN(@Old)+1,4000)
WHERE LEFT(ATT_File_Path,LEN(@Old)+1)=@Old+N'\';
```

Give the API service identity read permission on the destination news files. Existing attachment errors in negative sample cases are expected; the valid sample news PDF/image should open.

## Verified

The export was imported into three disposable local databases. Every table's row count and ordered SHA256 data hash matched the exported source, including all image bytes. Identity counters and schema object counts matched, and constraint validation passed. Temporary verification databases were removed after testing; the source databases were not changed.

`CompanyPortal-CurrentData.sql.manifest.json` contains the per-table counts/hashes. The source tools `Export-CurrentDatabases.ps1` and `Test-CurrentDataExport.ps1` regenerate/verify future exports; they use installed SQL scripting components and are not required on the destination for importing the SQL file. For the published app/IIS configuration, follow START_HERE.md and AIRGAP_IIS_GUIDE.md.
