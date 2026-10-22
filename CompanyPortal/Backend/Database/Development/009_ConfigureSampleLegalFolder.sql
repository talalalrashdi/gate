USE CompanyPortal;
GO
IF NOT EXISTS(SELECT 1 FROM Mstr.Utls WHERE [Key]=N'LegalAffairs')
 INSERT Mstr.Utls([Key],strVal) VALUES(N'LegalAffairs',N'$(LegalRoot)');
ELSE PRINT 'Existing LegalAffairs folder settings preserved. Verify they point to the fixture folder for local tests.';
GO
