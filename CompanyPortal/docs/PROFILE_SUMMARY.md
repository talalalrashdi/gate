# Profile picture: employee details, attendance and leave

Click the profile picture to load the current employee’s details from SQL. No illustrative attendance times or balance values remain in the header. Existing profile-picture artwork and the separate /profile page are unchanged.

## The two SP contracts

Both SPs live in **CompanyPortal**, accept **@UserId int**, and return zero or one row. Windows NTName is resolved server-side through the existing `Security.User_getByUsername`; a browser cannot choose another employee’s UserId. Keep SP parameters, aliases and SQL types when replacing their SELECTs internally.

| SP | Returned columns |
|---|---|
| `Portal.UserAttendance_Get` | DisplayName nvarchar(300) NULL; JobTitle nvarchar(300) NULL; Department nvarchar(300) NULL; AttendanceDate date NULL; ArrivalAt datetime NULL; ExpectedLeaveAt datetime NULL |
| `Portal.UserLeaveBalance_Get` | HolidayDays decimal(10,2) NULL; DaysToBeDeleted decimal(10,2) NULL; AsOfDate date NULL; DeletionDate date NULL |

The first SP supplies basic employee details and today’s actual arrival/expected departure. The second supplies the holiday balance and the number of days scheduled for deletion. Fractional days and zero balances are supported. Null means unavailable; zero means zero. Negative balances/deductions are rejected by the API contract. Actual leave rules, accrual, deletion calculations and expected departure calculation belong in the source SP/system. **The portal never deletes days or calculates a shift length.** DeletionDate is source-provided, not assumed to be year-end.

Date/time fields are local source wall-clock values (no browser timezone conversion). Map the real HR/attendance timezone correctly inside the source integration. Return current-day attendance, not an old attendance record labelled as today. Basic details can still be returned when no attendance exists.

## API and UI

- `GET /api/profile/attendance`
- `GET /api/profile/leave-balance`

Each returns `{ "data": { ... } }`, or `{ "data": null }` if no source row exists. Windows authentication and active employee registration are required on each request; no-store headers and parameterized SP calls are used. Errors are sanitized 503 problems with server log references; authentication/registration failures are 401/403. More than one source row is a contract error. No write endpoint exists.

The two requests run independently when the profile panel opens, with separate Arabic loading/error/retry messages. One source can remain visible while the other fails. Names/department/job and values use plain text. Data is cleared on close/page hide, pending requests are cancelled, and reopening reloads it; there is no polling or browser storage of personal data. Showing the panel makes no database writes.

## Migration and development samples

1. Apply `Backend/Database/Scripts/029_ProfileSummary.sql` once to an existing portal database. It creates empty safe adapters only if missing, preserving any existing mappings on rerun. Fresh Setup.sql includes this migration but no fictional employee/attendance/leave records.
2. **Local development only:** run `Backend/Database/Development/014_CreateSampleProfileSummary.sql` using the registered development Windows account. It creates marked `Development.ProfilePeople`, `Development.ProfileAttendance` and `Development.ProfileLeaveBalances` tables in CompanyPortal and maps the two SPs to them.
3. The sample is أحمد سالم / أخصائي نظم معلومات / دائرة تقنية المعلومات; today’s arrival 08:07, expected departure 15:07; balance 32.5 days, scheduled deletion 2.5 days on December31. These are fictional SQL records, not live HR results. Reruns preserve edits and add attendance for a new current date if missing. They refuse an existing custom SP mapping or unmarked sample tables.
4. Internally, replace both SP SELECTs with authorized source lookups on the same server. Do not deploy/run the development fixture over real source mappings. Grant the API appropriate SP/source read permissions. Neither the frontend nor API needs the real HR table names.

Sample tables follow identity-first, explicit nvarchar lengths, GETDATE timestamp defaults and Active bit/default1. The two adapter SPs return records filtered by the supplied current-user ID and Active status.

Both apps must be rebuilt/republished. Historical CurrentData exports and Airgap publish folders have not been refreshed by this feature.

## Validation

Both Release builds, JS syntax, Swagger generation, anonymous denial, current-user scope (including ignoring a supplied UserId), no-store, decimal balances, independent missing-attendance and missing-balance cases passed locally. API tests restore fixture Active flags. Browser confirmed all SP values, clearing on close and fetching on reopening. Frontend baseline and offline assets checks are included in acceptance.

Run `Backend/tools/Test-ProfileSummary.ps1` against the marked local fixture and a temporary API. No external Exchange connection is involved.

## Header panel update (26 October 2026)

- **Name and title** come from `Portal.UserProfile_Get @UserId` (DisplayName, JobTitle, Department) through `GET /api/profile/person`. Migration `038_UserProfile.sql` creates the default contract (no rows) and never replaces a mapped procedure on rerun; map it to the real employee source internally. Local only: `Development/020_MapSampleUserProfile.sql` maps it to `Development.ProfilePeople`.
- **وقت الحضور / الخروج المتوقع** (from `Portal.UserAttendance_Get`) are shown only when today's record has a value; nothing is shown for an empty value, no record or an error.
- **رصيد الإجازات / الأيام التي ستُحذف** (from `Portal.UserLeaveBalance_Get`) are shown as before, «—» when missing.
- The status lines and retry buttons were removed. Clicking inside the panel no longer closes it.
