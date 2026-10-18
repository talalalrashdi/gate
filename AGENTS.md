# قواعد العمل في كليريو

## Authorized CompanyPortal migration

- The user authorized migrating to ASP.NET Core MVC on .NET 10. Follow `docs/COMPANYPORTAL_MVC_MIGRATION_PLAN.md` and the current progress in `CompanyPortal/docs/MIGRATION_STATUS.md`.
- The new frontend solution is under `CompanyPortal/Frontend/`; a separate backend solution under `CompanyPortal/Backend/` is deferred. No API, database, authentication, or redesign belongs to this milestone.
- Preserve `dist/` as the original comparison baseline until migration and browser verification pass. Cleanup of files/code is the final step. Shared layout/partial extraction is pending after initial page verification.
- The legacy technical descriptions below apply to the retained original frontend; they do not prohibit the explicitly authorized MVC migration. Preserve Arabic/RTL, local fonts, existing behavior/storage, and unrelated edits. The user subsequently requested visible themes 1/2/3: majestic (legacy option 4) is now default 1, official remains 2, and formal remains 3. Keep stable internal panel IDs and preserve the original legacy storage key.

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
