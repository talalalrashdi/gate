-- DEVELOPMENT ONLY. Run through tools/Initialize-NewsFixture.ps1 after migration014.
USE CompanyPortal;
GO
IF NOT EXISTS(SELECT 1 FROM sys.extended_properties WHERE class=1
 AND major_id=OBJECT_ID(N'dbo.VNews') AND name=N'CompanyPortalDevelopmentFixture')
 THROW 50012,'Expected the marked local development news view.',1;
IF OBJECT_ID(N'Mstr.Utls',N'U') IS NULL
 THROW 50012,'Apply migration014 before configuring the news fixture folder.',1;
-- Preserve all later configuration choices, including inactive records.
IF NOT EXISTS(SELECT 1 FROM Mstr.Utls WHERE [Key]=N'PubsInfo')
 INSERT Mstr.Utls([Key],strVal) VALUES(N'PubsInfo',N'$(NewsRoot)');
GO
