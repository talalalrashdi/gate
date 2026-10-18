(() => {
  const section = document.getElementById('safety'), sheet = document.getElementById('safety-book-sheet');
  if (!section || !sheet) return;
  const booklets = [
  {
    "title": "السلامة في بيئة العمل",
    "subtitle": "مكان عمل مرتب وآمن",
    "points": [
      "حافظ على الممرات والأبواب خالية من العوائق.",
      "أبلغ عن الأرضيات المبللة أو التالفة لتأمين المكان.",
      "رتّب الأسلاك والأدوات بعيدًا عن مسارات الحركة."
    ]
  },
  {
    "title": "سلامة الأجهزة والكهرباء",
    "subtitle": "استخدم المعدات بعناية",
    "points": [
      "استخدم الأجهزة المخصصة للعمل وفق تعليمات تشغيلها.",
      "توقف عن استخدام أي جهاز أو سلك تظهر عليه علامات تلف.",
      "أبلغ فريق الصيانة عن الأعطال، واترك الإصلاح للمختصين."
    ]
  },
  {
    "title": "الاستعداد للطوارئ",
    "subtitle": "اعرف طريقك مسبقًا",
    "points": [
      "تعرّف على مخارج الطوارئ ونقطة التجمع المعتمدة في موقعك.",
      "اطّلع على خطة الإخلاء وأرقام التواصل الداخلية للطوارئ.",
      "شارك في تمارين السلامة واتبع تعليمات فريق الموقع."
    ]
  },
  {
    "title": "الإخلاء الآمن",
    "subtitle": "تحرّك بهدوء واتبع الخطة",
    "points": [
      "اتبع التنبيهات وتعليمات المسؤولين ومسارات الإخلاء المحددة.",
      "اتجه إلى نقطة التجمع دون العودة لجمع الأغراض الشخصية.",
      "ابقَ في نقطة التجمع ولا تعد إلى المبنى قبل التصريح."
    ]
  },
  {
    "title": "الإبلاغ عن المخاطر",
    "subtitle": "بلّغ بوضوح وسرعة",
    "points": [
      "أبلغ مسؤول السلامة عند ملاحظة خطر أو وقوع حادث.",
      "وضّح الموقع وطبيعة الموقف دون تعريض نفسك للخطر.",
      "اطلب المساعدة من المختصين، واترك الممرات متاحة لهم."
    ]
  },
  {
    "title": "الراحة أثناء العمل",
    "subtitle": "اعتنِ بعاداتك اليومية",
    "points": [
      "اضبط الكرسي والشاشة بما يناسب وضعية جلوس مريحة.",
      "غيّر وضعيتك وخذ فواصل قصيرة أثناء العمل المتواصل.",
      "اطلب أدوات مناسبة أو مساعدة عند نقل أغراض ثقيلة."
    ]
  }
];
  let trigger;
  section.querySelectorAll('[data-safety-book]').forEach(button => button.addEventListener('click', () => {
    const booklet = booklets[Number(button.dataset.safetyBook)];
    if (!booklet) return;
    trigger = button;
    sheet.querySelector('#safety-book-title').textContent = booklet.title;
    sheet.querySelector('#safety-book-subtitle').textContent = booklet.subtitle;
    const points = sheet.querySelector('#safety-book-points');
    points.replaceChildren(...booklet.points.map(text => { const li = document.createElement('li'); li.textContent = text; return li; }));
    if (!sheet.open) sheet.showModal();
  }));
  sheet.querySelector('[data-safety-close]').addEventListener('click', () => sheet.close());
  sheet.addEventListener('click', event => {
    const r = sheet.getBoundingClientRect();
    if (event.target === sheet && (event.clientX < r.left || event.clientX > r.right || event.clientY < r.top || event.clientY > r.bottom)) sheet.close();
  });
  sheet.addEventListener('close', () => trigger?.focus({ preventScroll: true }));
})();
