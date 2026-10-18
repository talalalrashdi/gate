# CompanyPortal database deployment

Follow the [database general rules](../../docs/DATABASE_GENERAL_RULES.md) when designing tables, including string lengths, identity, Active/date columns and NTName → UserId lookup.

The first feature now adds `Portal.UserSettings` and procedures in `Security`/`Portal`. Follow the [theme feature deployment order](../../docs/THEME_SETTINGS.md) for scripts 002–004 and the external security lookup mapping. The `Development/` sample SecurityDB script is excluded from the internal deployment.

Use SQL Server with a new database named `CompanyPortal`. Development uses the default instance `localhost`, selected by the user. The inspected local instance reports SQL Server 2019 Developer Edition (15.0.2000.5). SQL Server instance selection, credentials, certificates and access permissions are environment configuration; application code and SQL schema scripts stay the same between development and the air-gapped network.

## Create the database

From `Backend/`, run with a Windows account authorized to create databases:

```powershell
sqlcmd -S localhost -E -b -i Database/Scripts/001_CreateDatabase.sql
```

Or open the script in SQL Server Management Studio against the selected instance and execute it. `-b` makes sqlcmd stop with a failing exit code on SQL errors. The script uses server-default data/log file locations, creates only an empty database, and leaves an existing database unchanged. No user data is dropped or overwritten. Repeat execution is safe.

Inside the air-gapped network, run the same script against the approved destination SQL Server:

```powershell
sqlcmd -S INTERNAL-SQL-SERVER -E -b -i Database/Scripts/001_CreateDatabase.sql
```

Use the organization's approved TLS/certificate configuration for the SQL client. Future schema scripts will be numbered `002_...sql`, `003_...sql`, etc. Apply them in order, track which have been applied, and add new scripts for changes rather than editing scripts already deployed. Review/backup requirements apply when altering populated databases. The API will not create or upgrade databases at startup.

## Connection configuration

The API's Development-only database connection check uses the configuration key `ConnectionStrings:CompanyPortal`. It runs a read-only database-name query without business tables. The local default is in `CompanyPortal.Api/appsettings.Development.json`:

```text
Server=localhost;Database=CompanyPortal;Integrated Security=True;Encrypt=True;TrustServerCertificate=True;
```

`TrustServerCertificate=True` is a development-only allowance for a locally self-signed SQL certificate. For internal deployment, change the server name and use the approved certificate/trust settings, normally `TrustServerCertificate=False` with a trusted server certificate. An example environment-variable setting for IIS is:

```text
ConnectionStrings__CompanyPortal=Server=INTERNAL-SQL-SERVER;Database=CompanyPortal;Integrated Security=True;Encrypt=True;TrustServerCertificate=False;
```

Integrated security connects as the API's service/process identity by default, not automatically as the employee calling the API. Provision the approved IIS service identity with database rights appropriate to the implemented features; use a separate deployment account for schema creation. Do not grant the runtime account sysadmin/db_owner merely to simplify deployment. AD employee identity and database connection identity are separate concerns.

The intended application handoff is the same code plus ordered SQL scripts and an environment-specific connection string. The destination must also have the agreed SQL Server features/version, network access, service-account permissions and certificate trust. Those infrastructure settings cannot be replaced by a connection string alone. No mailbox/task/calendar records are created in this database.
