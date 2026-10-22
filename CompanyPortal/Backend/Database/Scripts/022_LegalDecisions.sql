USE CompanyPortal;
GO
IF SCHEMA_ID(N'Legal') IS NULL EXEC(N'CREATE SCHEMA Legal');
GO
-- Integration adapter: replace with the real permission-filtered lookup.
-- Rerunning a migration must never overwrite an installed adapter.
IF OBJECT_ID(N'Legal.Decisions_getForUser',N'P') IS NULL
 EXEC(N'CREATE PROCEDURE Legal.Decisions_getForUser @UserId int,@DecisionId bigint=NULL AS
 BEGIN SET NOCOUNT ON; THROW 50030,''Legal decisions source is not configured.'',1; END');
GO
