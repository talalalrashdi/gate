-- LOCAL DEVELOPMENT ONLY. Illustrative media, not real institutional events.
USE CompanyPortal;
GO
IF NOT EXISTS(SELECT 1 FROM sys.extended_properties WHERE class=0 AND name=N'CompanyPortalMediaFixture')
BEGIN
 IF EXISTS(SELECT 1 FROM Portal.Media) OR EXISTS(SELECT 1 FROM Portal.MediaGroups)
  THROW 50041,'Refusing to seed existing non-fixture media catalogs.',1;
 SET XACT_ABORT ON;BEGIN TRANSACTION;
 SET IDENTITY_INSERT Portal.MediaGroups ON;
 INSERT Portal.MediaGroups(MediaGroupID,GroupName,DisplayOrder,Active) VALUES(1001,N'فعاليات المؤسسة',10,1),(1002,N'ألبوم مخفي',90,0);
 SET IDENTITY_INSERT Portal.MediaGroups OFF;
 SET IDENTITY_INSERT Portal.Media ON;
 INSERT Portal.Media(MediaID,MediaName,MediaPath,MediaType,MediaGroupID,DisplayOrder,Active) VALUES
 (1001,N'حكايات من المكان',N'fort.png',N'image',1001,10,1),
 (1002,N'تفاصيل العمارة',N'mosque.png',N'image',1001,20,1),
 (1003,N'رمال عُمان',N'desert.png',N'image',1001,30,1),
 (1004,N'من طبيعة عُمان',N'desert.png',N'image',NULL,20,1),
 (1005,N'لقاء الفريق',N'team.mp4',N'video',NULL,10,1),
 (1006,N'مبادرة جديدة',N'initiative.mp4',N'video',NULL,20,1),
 (1007,N'صورة مخفية',N'fort.png',N'image',1001,40,0),
 (1008,N'صورة داخل ألبوم مخفي',N'mosque.png',N'image',1002,10,1),
 (1009,N'فيديو مخفي',N'team.mp4',N'video',NULL,90,0),
 (1010,N'العمارة العُمانية',N'mosque.png',N'image',NULL,30,1),
 (1011,N'من الفكرة إلى الإنجاز',N'team.mp4',N'video',NULL,30,1);
 SET IDENTITY_INSERT Portal.Media OFF;
 UPDATE Portal.MediaGroups SET CoverMediaID=1001 WHERE MediaGroupID=1001;
 UPDATE Portal.MediaGroups SET CoverMediaID=1008 WHERE MediaGroupID=1002;
 EXEC sys.sp_addextendedproperty @name=N'CompanyPortalMediaFixture',@value=1;
 COMMIT;
END;
GO
