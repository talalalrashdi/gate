# دليل الهاتف — Dalil

الواجهة تستدعي `GET /api/phone-directory?query=...&pageNum=1` في CompanyPortal API، والذي يستدعي Dalil:

`{BaseUrl}/api/contacts/search?query=...&contactType=1&pageNum=1`

القائمة من JSON `contacts` والإجمالي من `total`. النوع ثابت 1، وحجم الصفحة 10. لا توجد جداول أو migrations لهذا الربط، ولا endpoint مفضلة في هذه المرحلة.

## إعداد الاتصال داخل الشبكة

أضف القيم الحقيقية في إعدادات **Backend/CompanyPortal.Api/appsettings.json** تحت `PhoneDirectory`:

```json
"PhoneDirectory": {
  "Enabled": true,
  "BaseUrl": "https://DIRECTORY-SERVER/dalil/",
  "EmailDomain": "email.com",
  "OutlookWebUrl": "https://MAIL-SERVER/owa/",
  "MoreInfoPath": "api/contacts/GetMoreInfo",
  "ThumbnailPath": "api/Assest/GetEmplyeeThumb",
  "ComposeQueryTemplate": "?ae=Item&a=New&t=IPM.Note&to={email}"
}
```

BaseUrl هو عنوان تطبيق Dalil، شاملاً `/dalil/` إذا كان موجودًا؛ لا تضف `api/contacts/search`. الإعداد الافتراضي معطل وعنوانه فارغ لعدم توفر العنوان الحقيقي محليًا. إعداد OutlookWebUrl الفارغ يستخدم Exchange:OutlookWebUrl. لا يتطلب فتح رابط OWA تفعيل اتصال EWS. قالب compose مبدئي وقابل للتغيير من الإعدادات، ويجب التحقق من فتح رسالة جديدة وحقل To في نسخة OWA الداخلية قبل اعتمادها. لا يرسل أي رسالة تلقائيًا.

يتكون البريد من ntUser + @ + EmailDomain، ويظهر زر البريد فقط عند توفر اسم حساب صالح وعنوان OWA صالح. لا نستخرج رقم هاتف من `t`؛ نعرض officePhoneNumber كما هو. تفاصيل الجهة تشمل الوظيفة والقسم والحضور ومكان العمل والوحدات والملاحظات والموظف المكلف إن وجدت. لا تُعرض المعرفات الشخصية الداخلية ولا تُحفظ النتائج في المتصفح. الشريط الجانبي الموجود «أرقام تهمك» ما زال بيانات توضيحية منفصلة، وليس مستخرجًا من Dalil.

## Windows authentication

## المزيد، المكلف والصور

- بطاقة الاتصال تعرض رقم المكتب بشكل مميز وحالة الحضور دون عناوين «رقم المكتب» و«الحضور».
- لا تعرض البطاقة نوع الموظف (موظف، متدرب، متعاقد، متقاعد). يبقى employeeTypeID مستخدمًا لطلب «المزيد».
- يظهر رابط المكلف فقط إذا توفر personalIDAssignedTo (أو personalIdAssignedTo) وassignedToFullName. يمسح النتائج ويبحث بالاسم الكامل في نفس الورقة، ويطابق personalID للنتيجة مع معرف المكلف لمنع عرض شخص آخر له اسم مشابه. إذا كان المعرف في صفحة لاحقة تبقى أزرار الصفحات متاحة. الكتابة في حقل البحث تعود للبحث العادي.
- «المزيد» يحمل البيانات عند أول فتح فقط لكل بطاقة معروضة، ويتيح إعادة المحاولة عند الفشل. إغلاقه وإعادة فتحه لا يكرران طلبًا ناجحًا. يستخدم `GET /api/phone-directory/more?id=...&employeeTypeId=...` ثم Dalil MoreInfoPath بمعاملات `Id`, `employeeTypeId`, `contactType=1`.
- الافتراض الحالي: `persID` هو Id للمزيد، وemployeeTypeID من نفس صف البحث. مسار المزيد الافتراضي `api/contacts/GetMoreInfo` يحتاج تأكيدًا داخليًا لأن المسار الكامل لم يُوفر بعد. الصورة تستخدم **personalID** وليس persID: `{BaseUrl}/{ThumbnailPath}?PersonalID=...&Res=128`. نحتفظ بتهجئة Dalil `Assest/GetEmplyeeThumb` كما وُفرت.
- الصور تمر عبر API بهوية الموظف؛ لا ترسل credentials أو مسارات Dalil للمتصفح. يقبل proxy ملفات PNG/JPEG/WebP بحد2MB، دون HTML أو SVG، مع initials كبديل للفشل. لا يتم تجاوز شهادات HTTPS.
- نقرأ فقط phoneNumbers (number, phoneTypeName, phoneStateName, phonePlace, note, priority) وcontactAddress (currentAddress, permanentAddress). يمكن لـ Dalil إرجاع حقول أخرى؛ تُتجاهل ولا يلزم إضافتها للعقد الآن.

تم اختبار IDs ومعاملات المزيد وحقول الأرقام والعناوين وتجاهل الحقول الإضافية وحماية endpoints وصورة PNG بخدمة محلية، ثم التنقل إلى المكلف وحالتي موجود/غير موجود والمزيد في المتصفح. الاتصال بالخادم الداخلي ما زال يحتاج اختبارًا.

## هوية الاتصال

كل endpoint يتطلب مصادقة Windows وتسجيل الموظف في CompanyPortal. الاتصال بـ Dalil يستخدم هوية الموظف، وليس ApplicationImpersonation الخاص بـ Exchange. على جهاز التطوير إذا طابقت هوية العملية الموظف تُستخدم مباشرة. في IIS تُستخدم RunImpersonatedAsync مع token الموظف وUseDefaultCredentials، مع handler مستقل لكل طلب لمنع مشاركة اتصال موثق بين المستخدمين. لا يوجد انتقال تلقائي لهوية application pool عند فشل هوية الموظف.

نجاح localhost لا يثبت نجاح IIS: عند وجود Dalil على خادم آخر، يجب تأكيد Windows authentication وSPNs وKerberos constrained delegation إلى خدمة HTTP الخاصة بـ Dalil مع فريق البنية التحتية. لم يُختبر هذا الاتصال الحقيقي بعد. لا تعطل التحقق من الشهادات؛ ثبّت شهادة الجهة الداخلية الموثوقة.

## السلوك والتشخيص

- البحث بعد توقف الكتابة 350ms؛ إلغاء الطلب السابق عند تغيير النص أو إغلاق الورقة، وتجاهل النتائج المتأخرة. لا polling ولا طلب لكل جهة اتصال.
- البحث الفارغ لا يجلب بيانات حتى الضغط على «دليل الهاتف». السابق/التالي يرسلان الصفحة المطلوبة فقط.
- انتهاء المهلة: رسالة لإعادة المحاولة. Dalil 401/403: رسالة خاصة بمصادقة Windows/التفويض. JSON غير صالح أو اتصال غير مهيأ: رسالة خدمة واضحة، والتفاصيل التقنية في سجل API.
- لا يمكن للمتصفح تغيير مصدر Dalil أو إرسال عنوان خارجي بديل؛ العنوان من إعداد الخادم فقط. لا يتم تتبع redirects أو مشاركة cookies.

تم اختبار عقد JSON والصفحات 10/10/3 لعدد23، رابط To وترميز البريد وغياب الزر عند ntUser فارغ، upstream401/JSON غير صالح، رفض الطلب المجهول والصفحة غير الصحيحة، والواجهة مع خدمة JSON مؤقتة محلية. ذلك لا يثبت مصادقة Dalil الفعلية أو دعم قالب compose في OWA. انشر الواجهة وAPI معًا ثم اختبرهما داخل الشبكة.
