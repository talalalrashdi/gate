USE CompanyPortal;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET ARITHABORT ON;
SET NUMERIC_ROUNDABORT OFF;
GO
-- Rename only the original system label; preserve a custom admin-supplied name.
UPDATE Master.Cards SET CardName=N'الخدمات الفنية',LastChangeAt=GETDATE()
WHERE CardKey=N'electronic-services' AND CardName IN(N'الخدمات الالكترونية',N'الخدمات الإلكترونية');
GO
-- Integration contracts: install once, preserve configured real-system adapters.
IF OBJECT_ID(N'Portal.Isnad_Recipients_Get',N'P') IS NULL
 EXEC(N'CREATE PROCEDURE Portal.Isnad_Recipients_Get @UserId int AS BEGIN SET NOCOUNT ON; THROW 50030,''Technical services source is not configured.'',1; END');
GO
IF OBJECT_ID(N'Portal.Reports_Categories_Get',N'P') IS NULL
 EXEC(N'CREATE PROCEDURE Portal.Reports_Categories_Get @UserId int AS BEGIN SET NOCOUNT ON; THROW 50030,''Technical services source is not configured.'',1; END');
GO
IF OBJECT_ID(N'Portal.Reports_Recipients_Get',N'P') IS NULL
 EXEC(N'CREATE PROCEDURE Portal.Reports_Recipients_Get @UserId int AS BEGIN SET NOCOUNT ON; THROW 50030,''Technical services source is not configured.'',1; END');
GO
IF OBJECT_ID(N'Portal.Reports_Types_Get',N'P') IS NULL
 EXEC(N'CREATE PROCEDURE Portal.Reports_Types_Get @UserId int AS BEGIN SET NOCOUNT ON; THROW 50030,''Technical services source is not configured.'',1; END');
GO
IF OBJECT_ID(N'Portal.Initiatives_Types_Get',N'P') IS NULL
 EXEC(N'CREATE PROCEDURE Portal.Initiatives_Types_Get @UserId int AS BEGIN SET NOCOUNT ON; THROW 50030,''Technical services source is not configured.'',1; END');
GO
IF OBJECT_ID(N'Portal.Isnad_Create',N'P') IS NULL
 EXEC(N'CREATE PROCEDURE Portal.Isnad_Create @UserId int,@RecipientId int,@Details nvarchar(4000),@OfficeNumber nvarchar(100)=NULL,@DocumentNumber nvarchar(200)=NULL,@RequestKey uniqueidentifier=NULL AS BEGIN SET NOCOUNT ON; THROW 50030,''Technical services source is not configured.'',1; END');
GO
IF OBJECT_ID(N'Portal.Reports_Create',N'P') IS NULL
 EXEC(N'CREATE PROCEDURE Portal.Reports_Create @UserId int,@CategoryId int,@RecipientId int=NULL,@TypeId int=NULL,@Title nvarchar(500)=NULL,@Details nvarchar(4000)=NULL,@RequestKey uniqueidentifier=NULL AS BEGIN SET NOCOUNT ON; THROW 50030,''Technical services source is not configured.'',1; END');
GO
IF OBJECT_ID(N'Portal.Initiatives_Create',N'P') IS NULL
 EXEC(N'CREATE PROCEDURE Portal.Initiatives_Create @UserId int,@TypeId int,@Title nvarchar(500),@Details nvarchar(4000),@RequestKey uniqueidentifier=NULL AS BEGIN SET NOCOUNT ON; THROW 50030,''Technical services source is not configured.'',1; END');
GO
