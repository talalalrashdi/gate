USE CompanyPortal;
GO
-- Read-only history readers. Super-admin authorization is enforced by the API.
CREATE OR ALTER PROCEDURE Portal.AdminChanges_GetPage
 @Section varchar(40)=NULL,@ChangedBy nvarchar(512)=NULL,@FromAt datetime=NULL,@ToAt datetime=NULL,
 @Page int=1,@PageSize int=25
AS
BEGIN
 SET NOCOUNT ON;
 SET @Page=CASE WHEN @Page BETWEEN 1 AND 1000000 THEN @Page ELSE 1 END;
 SET @PageSize=CASE WHEN @PageSize BETWEEN 1 AND 100 THEN @PageSize ELSE 25 END;
 DECLARE @Rows TABLE(AdminChangeId bigint PRIMARY KEY);
 INSERT @Rows SELECT AdminChangeId FROM Portal.AdminChanges
 WHERE (@Section IS NULL OR Section=@Section)
 AND (NULLIF(@ChangedBy,N'') IS NULL OR ChangedBy LIKE N'%'+REPLACE(REPLACE(REPLACE(@ChangedBy,N'[',N'[[]'),N'%',N'[%]'),N'_',N'[_]')+N'%')
 AND (@FromAt IS NULL OR ChangedAt>=@FromAt) AND (@ToAt IS NULL OR ChangedAt<@ToAt);
 SELECT COUNT(*) Total FROM @Rows;
 SELECT CONVERT(nvarchar(20),c.AdminChangeId) ChangeId,c.ChangedAt,c.ChangedBy,c.Section,c.Action,c.ItemType,c.ItemId,c.ItemTitle
 FROM @Rows r JOIN Portal.AdminChanges c ON c.AdminChangeId=r.AdminChangeId
 ORDER BY c.AdminChangeId DESC OFFSET (@Page-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END;
GO
CREATE OR ALTER PROCEDURE Portal.AdminChanges_GetById @AdminChangeId bigint AS
BEGIN
 SET NOCOUNT ON;
 SELECT CONVERT(nvarchar(20),AdminChangeId) ChangeId,ChangedAt,ChangedBy,Section,Action,ItemType,ItemId,ItemTitle,OldJson,NewJson
 FROM Portal.AdminChanges WHERE AdminChangeId=@AdminChangeId;
END;
GO
