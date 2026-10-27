# الخدمات الفنية

البطاقة تحتوي أزرار الإسناد، البلاغات، المبادرات بجانب بعضها. القوائم من قاعدة البيانات والإرسال الحقيقي من API إلى إجراءات CompanyPortal التي تتصل بقاعدتي المصدر. أزيل الحفظ السابق في localStorage؛ لا يرسل المتصفح SQL أو UserId. المسودات تحفظ في ذاكرة الصفحة لكل تبويب فقط.

## واجهة المستخدم

- الإسناد: جهة استلام البلاغ، رقم المكتب، رقم المستند، التفاصيل، إرسال، ثم نظام الإسناد. الجهة والتفاصيل مطلوبان؛ رقم المكتب والمستند اختياريان في النسخة الحالية.
- البلاغات: تصنيف البلاغ يبدأ بـ«اختر تصنيف البلاغ»، وإذا كانت RequiresRecipient=1 يظهر إلى جهة مع قائمة الجهات. النوع يأتي من تصنيف البلاغ نفسه. التصنيف الآخر ذو RequiresRecipient=0 يخفي الجهة ويعرض أنواعه المختلفة. عنوان وتفاصيل مطلوبان في الحالتين؛ إرسال ثم نظام البلاغات.
- المبادرات: النوع، العنوان، التفاصيل، إرسال ثم نظام البلاغات.
- أزرار الإرسال وسطية النص. أخطاء الاتصال لا تمسح المدخلات. أثناء الإرسال تُعطل الحقول والتبويبات لمنع تبديل نوع الطلب. النجاح يظهر بعد تأكيد SQL مع رقم الطلب ويعيد تهيئة النموذج.
- كل القوائم تبدأ بخيار فارغ «اختر…» ويتطلب الإرسال اختيار قيمة حقيقية. تغيير التصنيف يعيد الجهة والنوع إلى الخيار الفارغ. رقم المكتب ورقم المستند في صف واحد؛ إلى جهة والنوع بجانب بعضهما في فرع البلاغ المباشر. تكبير مساحة التفاصيل وضبط المسافات أتاح عرض الحالات الأربع دون تمرير داخلي في حجم سطح المكتب المختبر، مع إبقاء التمرير عند الحاجة لتكبير الخط أو تغيير حجم المنطقة.
- القوائم تحمل مرة واحدة عند فتح الصفحة؛ زر إعادة تحميل القوائم عند الفشل يعيد جلبها، دون polling. التبويبات تدعم الأسهم يمين/يسار وHome/End.

## قواعد التطوير

`Development/025_CreateSampleTechnicalServices.sql` ينشئ **IsnadDB** و**ReportsDB** بعلامة CompanyPortalDevelopmentFixture. يرفض قواعد موجودة غير موسومة. البيانات أمثلة محلية، ولا يفترض أنها هي مخططات الأنظمة الحقيقية.

| قاعدة | الجداول |
|---|---|
| IsnadDB | dbo.Recipients، dbo.Requests |
| ReportsDB | dbo.Categories، dbo.Recipients، dbo.ReportTypes، dbo.InitiativeTypes، dbo.Reports، dbo.Initiatives |

المبادرات في ReportsDB لأنها تستخدم نظام البلاغات. قوائمها منفصلة عن أنواع البلاغات. عينات التصنيف «بلاغ إلى جهة» و«بلاغ عام» توضح الفرعين؛ أسماء القوائم وRequiresRecipient من المصدر وليست نصوصًا تحدد المنطق في JavaScript.

الجداول تستخدم identity أولًا، nvarchar بأحجام صريحة، Timestamp datetime DEFAULT(GETDATE()) لطلبات الإنشاء، Active bit DEFAULT(1) في آخر الأعمدة، ومفتاح فريد(UserId,RequestKey) لمنع تكرار نفس محاولة الإرسال.

## عقود SP في CompanyPortal

| SP | المدخلات | النتيجة |
|---|---|---|
| Portal.Isnad_Recipients_Get | UserId int | Id int, Name nvarchar(500) |
| Portal.Reports_Categories_Get | UserId int | Id int, Name nvarchar(300), RequiresRecipient bit |
| Portal.Reports_Recipients_Get | UserId int | Id int, Name nvarchar(500), CategoryId int |
| Portal.Reports_Types_Get | UserId int | Id int, Name nvarchar(300), CategoryId int |
| Portal.Initiatives_Types_Get | UserId int | Id int, Name nvarchar(300) |
| Portal.Isnad_Create | UserId, RecipientId int, Details nvarchar(4000), OfficeNumber nvarchar(100) NULL, DocumentNumber nvarchar(200) NULL, RequestKey uniqueidentifier | معرف الطلب bigint واحد |
| Portal.Reports_Create | UserId, CategoryId, RecipientId NULL, TypeId int, Title nvarchar(500), Details nvarchar(4000), RequestKey uniqueidentifier | معرف البلاغ bigint واحد |
| Portal.Initiatives_Create | UserId, TypeId int, Title nvarchar(500), Details nvarchar(4000), RequestKey uniqueidentifier | معرف المبادرة bigint واحد |

إجراءات الإنشاء تتحقق من Active وتوافق نوع البلاغ مع التصنيف، ووجوب الجهة أو منعها حسب التصنيف. كود الخطأ50012 يعني مدخلات غير متوافقة، ويُعرض كـ400. تستخدم معاملات معUPDLOCK/HOLDLOCK ومفتاح فريد؛ إعادة نفس RequestKey للموظف تعيد الرقم الموجود دون INSERT جديد أو تغيير Timestamp.

عند ربط النظام الداخلي، عدّل إجراءات CompanyPortal لتقرأ/تنادي إجراءات الأنظمة الحقيقية، مع الاحتفاظ بالعقد والتحقق من صلاحيات الموظف وتوافق القوائم ومنع التكرار. يجب أن تحافظ إجراءات الإنشاء الحقيقية على قواعد العمل والإشعارات الخاصة بالنظام المصدر؛ لا تفترض أن INSERT مباشرًا كافٍ له. البيانات المحلية نموذج اختبار فقط.

## API والأمان

- `GET /api/technical-services`: طلب متصفح واحد يجمع قوائمSP الخمسة والروابط.
- `POST /api/technical-services/assignment|report|initiative`: JSON حسب التبويب، مع RequestKey. الهوية من Windows ثم Security.User_getByUsername، وليس من جسم الطلب أو querystring.
- كل endpoint يتطلب حساب موظف نشط. الإنشاء يتطلب `X-CompanyPortal-Request: technical-services` وOrigin مسموحًا. أحجام الحقول ونوع الخدمة والقوائم تُفحص على الخادم وSQL.
- لا حفظ للمحتوى في localStorage، ولا تضمين النصوص كـHTML. الصلاحيات على قواعد المصدر تعتمد على هوية تشغيل API في SQL. منح الموظف الوصول للبوابة لا يمنحه صلاحية SQL مباشرة.
- الإعادة بعد مهلة تحفظ المفتاح طالما المحتوى نفسه وفي نفس الصفحة؛ تعديل المحتوى ينتج محاولة جديدة. إعادة تحميل الصفحة تفقد المفتاح والمسودة، لذلك راجع النظام المصدر عند عدم معرفة نتيجة إرسال سابق.

## النقل والإعداد

1. طبّق `Scripts/041_TechnicalServices.sql` على CompanyPortal الموجود. ينشئ العقود فقط إن لم تكن موجودة، ولا يستبدل adapters مهيأة. يغير الاسم الأصلي للبطاقة إلى الخدمات الفنية مع الإبقاء على أي اسم خصصه المسؤول.
2. محليًا فقط نفّذ `Development/025_CreateSampleTechnicalServices.sql` لإنشاء المصادر والقوائم وربط الإجراءات بها. يمكن إعادة تنفيذه دون مضاعفة القوائم أو حذف الطلبات.
3. داخل الشبكة لا تنفذ Development على قواعد الأنظمة الحقيقية. ضع SELECTs/EXECs الملائمة فيSP، وأعط هويةAPI صلاحيات EXECUTE والوصول اللازمة، وفق قواعد الخوادم الداخلية.
4. انشر API والواجهة معًا. إعدادات Backend/CompanyPortal.Api/appsettings.json:

```json
"TechnicalServices": {
  "IsnadUrl": "https://ISNAD-SERVER/",
  "ReportsUrl": "https://REPORTS-SERVER/"
}
```

الأزرار تفتح روابط http/https المحددة على الخادم في تبويب جديد. إذا لم يُضبط الرابط، يبقى الزر غير متاح، ولا يُستخدم عنوان وهمي. إرسال الطلبات إلى SQL لا يحتاج ضبط هذه الروابط.

Setup المولّد يشمل041 وعقود التكامل، لكنه لا ينشئ قواعد المصدر الوهمية. ملفات CurrentData التاريخية لم تتغير.

## التحقق

`Backend/tools/Test-TechnicalServices.ps1` يختبر أربعة مسارات حفظ، التطابق مع UserId، duplicate/no-op timestamp، رفض الأنواع غير المطابقة وغياب/زيادة الجهة، الحجم، Header/Origin، الطلب المجهول وSwagger. يتطلب قواعد محلية موسومة وAPI على5091، ويزيل صفوفه المؤقتة بالمعرف والمحتوى الفريد فقط. فحوص المتصفح حفظت الإسناد والفرعين والمبادرة بنجاح؛ تأكدت الصفوف في قواعدها ثم أزيلت طلبات التحقق بالمعرف والتفاصيل، وبقيت القوائم. البناءان دون تحذيرات. القواعد والإجراءات الحقيقية والروابط والصلاحيات الداخلية تحتاج اختبارًا عند توفرها.
