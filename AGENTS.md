# قواعد العمل في كليريو

## Authorized CompanyPortal migration

- The user authorized the frontend → API → SQL connection check, explicitly deferring portal preferences. See `CompanyPortal/docs/CONNECTION_CHECK.md`. Dapper/SqlClient and a Development-only read-only diagnostic now connect MVC HttpClient (process identity) to the Windows-authenticated API and local CompanyPortal database. This is not employee impersonation/delegation or an Exchange connection. No business tables/preferences or portal design changes belong to this connectivity step.

- The user has now authorized the API foundation milestone. `CompanyPortal/Backend/` contains its own solution and one .NET 10 controller-based API project; see `CompanyPortal/docs/API_FOUNDATION.md` and `Backend/README.md`. Use Swagger/Swashbuckle and Windows/AD authentication. SQL Server with Dapper/SqlClient and numbered SQL scripts is agreed; no EF Core. The user selected the default local SQL instance (`localhost`); script 001 created an empty `CompanyPortal` database and was verified safe to rerun. Schema/data access, Exchange access and frontend connection remain later steps. Exchange SE build 15.2.2562.17 was reported, with EWS planned for the same Outlook records and Exchange-enforced calendar delegation. The frontend-only restrictions below describe the earlier milestone.

- The user authorized migrating to ASP.NET Core MVC on .NET 10. Follow `docs/COMPANYPORTAL_MVC_MIGRATION_PLAN.md` and the current progress in `CompanyPortal/docs/MIGRATION_STATUS.md`.
- The new frontend solution is under `CompanyPortal/Frontend/`; a separate backend solution under `CompanyPortal/Backend/` is deferred. No API, database, authentication, or redesign belongs to this milestone.
- Preserve `dist/` as the original comparison baseline until browser verification passes. The user authorized finishing the frontend: shared MVC layout/partials, local offline assets and cleanup of 12 proven unused files in the new project are now implemented. The legacy files outside `CompanyPortal` remain retained; see the current acceptance checklist before retiring them.
- The legacy technical descriptions below apply to the retained original frontend; they do not prohibit the explicitly authorized MVC migration. Preserve Arabic/RTL, local fonts, existing behavior/storage, and unrelated edits. Visible themes are 1/2/3: majestic is default 1, official is 2, and formal is 3.
- The user authorized replacing design-era filenames/selectors with descriptive names in the MVC application. See `CompanyPortal/docs/NAMING_CONVENTIONS.md`. Theme keys and panels now use semantic names; translate older numeric saved selections. Keep existing storage keys (including `clerio-design-b-pinned-systems-v1`) and the untouched `dist/` baseline. `/design-b.html` remains only as a compatibility redirect.

- المشروع HTML/CSS/JavaScript مع Vite؛ مجلد `dist` يحتوي المصدر القابل للتعديل. الصفحة الحالية `dist/design-b.html`. حافظ على العربية وRTL والخط المحلي GT America Arabic.
- لا تغيّر التقنية، ولا تضف مكتبات دون ضرورة مرتبطة بالمطلوب.
- استبعد البنفسجي واللافندر من الاقتراحات والتعديلات الجديدة. لا تُعد العناصر المحذوفة دون طلب.
- حافظ على `localStorage` والوظائف الحالية وتعديلات المستخدم؛ لا تمسح البيانات أو تستبدل تغييرات غير مرتبطة بالمهمة.
- نفّذ المطلوب فقط؛ لا تبدأ إعادة تصميم أو مراجعة شاملة.
- ابحث بحثًا موجّهًا واقرأ الأجزاء والملفات المرتبطة بالمهمة فقط. وسّع القراءة عند وجود اعتماد فعلي.
- راجع ترتيب تحميل CSS وأولوية القواعد، وعدّل القاعدة المناسبة بدل تكديس overrides.
- التصميم ب هو التصميم الوحيد المعتمد؛ حُذف التصميم ج وملفاته الحصرية بطلب المستخدم. حافظ على ملفات ب المشتركة مع صفحة المستخدم ولا تُعد التصميم المحذوف.
- لا تستخدم وكلاء متوازيين أو بحث الإنترنت إلا إذا تطلبت المهمة ذلك، ومع مراعاة تعليمات الجلسة الأعلى أولوية.
- لا تُعد تثبيت الحزم إذا كانت جاهزة، ولا تكرر فحصًا ناجحًا دون تغييرات أو سبب جديد.
- افحص السلوك المتأثر بقدر يتناسب مع التعديل. لتعديلات التخطيط، افحص عرضًا كبيرًا وعرض جوال إن أمكن؛ اذكر تعذر المعاينة إذا كان قيدًا فعليًا.
- بعد تحقيق المطلوب ونجاح الفحص المناسب، توقف.
- اجعل الرد النهائي مختصرًا: ما تغير، الملفات، ما فُحص، وأي قيد فعلي. لا تطبع الملفات كاملة.
- المرجع التفصيلي في `PROJECT_REFERENCE.md`: اقرأ الأقسام المرتبطة فقط عند الحاجة، ولا تختصر المتطلبات الملزمة أو تحذفها. اعتبر طلب المستخدم الأحدث مقدمًا على الوصف التاريخي.
