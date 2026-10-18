# Database general rules

Recorded: 18 October 2026. Applies to future CompanyPortal SQL Server tables where appropriate. This document records conventions; it does not create tables or finalize a feature schema.

## String columns

- Use `nvarchar(n)` with an explicit length for string columns.
- Choose a generous length with reasonable room for future values, rather than sizing only for today's examples.
- Review lengths for each field when designing its table. Do not use the same length for every string or silently substitute `nvarchar(max)`.
- Match API validation limits to the agreed database lengths.

## Identity column

- The first column is the table's identity primary key, where appropriate.
- Choose a meaningful name, such as `UserId`, and select the integer size when reviewing the table.
- A typical declaration is `UserId int IDENTITY(1,1) NOT NULL PRIMARY KEY`; this is an example, not an approved Users table definition.

## Active column

- Include an `Active` column where the table needs an active/inactive state.
- Use `Active bit NOT NULL DEFAULT (1)`.
- Define how inactive records affect reads, writes and access when implementing the relevant feature. The column alone does not implement those rules.

## Date/time column

- Some tables need a timestamp recording when a row was created or recorded.
- Where required, use a `datetime` column with `DEFAULT (GETDATE())`.
- Agree on the column name for each table, such as `CreatedAt` or `TimeStamp`.
- SQL Server's `timestamp` data type is a row-version value, not a date/time value. A column named `TimeStamp` must still be declared as `datetime` for this convention.
- `GETDATE()` uses the SQL Server's current date/time. Its default applies on insertion when the value is omitted; it does not automatically update the value when a row is edited. Add update-tracking columns only when needed.

## Employee identity: NTName and UserId

The agreed approach is to identify the employee by **NTName**, then retrieve their **UserId** from the database. Both can be used, with separate purposes:

| Value | Purpose |
| --- | --- |
| `NTName` | Windows/AD account name used to find the employee's database user record |
| `UserId` | Internal database identity used for user relationships and ownership |

Intended flow:

1. Obtain the employee's NTName from their trusted authenticated Windows identity.
2. Look up the corresponding user record in the database using a parameterized query.
3. Use its UserId for database relationships and employee-owned records; retain NTName where account lookup, diagnostics or a specific feature requires it.

Do not accept a browser-supplied NTName or UserId as proof of identity, and do not confuse an IIS service/process account with the employee. The existing connectivity diagnostic uses process credentials and does not yet implement this employee lookup.

Before implementing the user table, confirm NTName's stored format (for example, `DOMAIN\username`), uniqueness/domain handling, lookup comparison rules, column length, and behavior for missing, inactive or renamed accounts. These details are not finalized by this document. Storing both identifiers does not mean duplicating NTName in every related table.

## Schema changes and deployment

- Security user records belong to the external security database (local sample: `SecurityDB`), not a duplicate CompanyPortal users table.
- CompanyPortal's `Security` schema contains identity-related procedures such as `Security.User_getByUsername`; portal preferences belong to the `Portal` schema (`Portal.UserSettings`).
- The first agreed feature resolves authenticated NTName through that lookup to an external UserId. See [theme settings](THEME_SETTINGS.md) for the reviewed columns and development-only sample scripts. The real internal mapping must preserve the lookup contract and stable user identity.

- Review each proposed table and its lengths before writing business schema scripts.
- Keep changes in numbered SQL scripts, applied in order; do not change schema automatically on API startup.
- Use the same scripts in development and the air-gapped network, with environment-specific connection configuration and appropriate SQL permissions/certificate trust.
- See [database deployment](../Backend/Database/README.md) for the existing empty-database creation script.
