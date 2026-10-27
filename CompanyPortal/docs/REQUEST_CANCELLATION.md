# إلغاء طلبات المتصفح

صفحات مكتبة الوثائق والسلامة والبحث تلغي fetch عند إخفاء التبويب أو إغلاق النافذة أو بدء طلب بديل. ينتقل RequestAborted إلى SQL لمنع استمرار تحميل بيانات لم يعد المتصفح يحتاجها. قد يظهر TaskCanceledException أو OperationCanceledException عند OpenAsync أو أثناء قراءة SQL؛ ظهور الاستثناء وحده لا يثبت وجود عطل في قاعدة البيانات.

RequestCancellationMiddleware داخل معالج الاستثناءات يلتقط OperationCanceledException **فقط إذا** HttpContext.RequestAborted ملغى. يعيد الحالة499 إذا لم تبدأ الاستجابة، دون كتابة صفحة خطأ إلى اتصال مغلق؛ لا يعدل استجابة بدأت بالفعل. يسجل التشخيص بمستوىDebug دون اعتباره خطأ تطبيق. الإلغاء غير المؤكد والأخطاء الأخرى تستمر إلى المعالجة المعتادة.

SqlClient قد يعيد SqlException رقم0 برسالة Operation cancelled by user بدل OperationCanceledException. DocumentLibraryController وDocumentsController يحولان هذه الحالة المحددة إلى إلغاء فقط عندما يكون كل من token الطلب وRequestAborted ملغى. أخطاء SQL الأخرى، بما فيها timeouts وفشل الاتصال مع وجود عميل نشط، لا تُخفى وتحتفظ برسالة503 وسجل الخطأ.

قد تتوقف Visual Studio عند مكان رمي الاستثناء حتى لو سيلتقطه التطبيق لاحقًا، إذا كان Break on thrown فعالًا. اضغط Continue أولًا. لتقليل الوقفات المتوقعة فقط: Debug → Windows → Exception Settings، ابحث عن System.Threading.Tasks.TaskCanceledException وألغِ خيار Thrown لهذه الفئة المحددة (وكذلك System.OperationCanceledException إذا كانت مضبوطة عليه). لا تعطل جميع CLR exceptions. هذا إعداد للمصحح، وليس إصلاح اتصال SQL أو دليلًا على نجاحه.

إذا فشلت المكتبة دون إغلاق أو تبديل الصفحة، افحص استجابة endpoint وسجلAPI. لا تُفسَّر503 أو timeout على أنها إلغاء متصفح إلا إذا كان token الطلب ملغى بالفعل.

التحقق: buildAPI دون تحذيرات؛ فحص middleware للإلغاء499/دونbody، انتقال الإلغاء غير المؤكد والأخطاء الحقيقية، والحفاظ على استجابات بدأت وطلبات ناجحة. اختبارات HTTP محلية ألغت طلبات عمدًا ثم أكدت استجابة200 لمكتبات الوثائق والسلامة وقائمة المستندات. لا تغييرات علىSP أو قواعد البيانات أو سياسات الصلاحية.
