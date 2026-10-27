USE CompanyPortal;
GO
-- Read-only presentation adapters. Identity and profile mappings stay in their existing SPs.
CREATE OR ALTER PROCEDURE Portal.AdminAuthors_Get @NamesJson nvarchar(max) AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @Name nvarchar(512),@UserId int;
 DECLARE @Users TABLE(UserId int);
 DECLARE @Person TABLE(DisplayName nvarchar(1000),JobTitle nvarchar(1000),Department nvarchar(1000));
 DECLARE @Result TABLE(ChangedBy nvarchar(512),DisplayName nvarchar(1000));
 DECLARE authors CURSOR LOCAL FAST_FORWARD FOR
 SELECT DISTINCT CONVERT(nvarchar(512),value) FROM OPENJSON(@NamesJson) WHERE type=1 AND LEN(value)<=512;
 OPEN authors; FETCH NEXT FROM authors INTO @Name;
 WHILE @@FETCH_STATUS=0
 BEGIN
  DELETE @Users; DELETE @Person; SET @UserId=NULL;
  INSERT @Users EXEC Security.User_getByUsername @Username=@Name;
  SELECT TOP(1) @UserId=UserId FROM @Users;
  IF @UserId IS NOT NULL INSERT @Person EXEC Portal.UserProfile_Get @UserId=@UserId;
  INSERT @Result SELECT @Name,COALESCE((SELECT TOP(1) NULLIF(DisplayName,N'') FROM @Person),@Name);
  FETCH NEXT FROM authors INTO @Name;
 END;
 CLOSE authors; DEALLOCATE authors;
 SELECT ChangedBy,DisplayName FROM @Result;
END;
GO
