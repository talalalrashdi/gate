(() => {
  const form = document.getElementById('b-electronic-service-form');
  if (!form) return;
  const type = form.elements.type;
  const category = form.elements.category;
  const message = form.elements.message;
  const status = document.getElementById('b-electronic-service-status');
  const storageKey = 'clerio-electronic-service-requests-v1';
  const categories = {
    report: ['الدعم التقني', 'المرافق والصيانة', 'السلامة'],
    initiative: ['تحسين الخدمات', 'بيئة العمل', 'المسؤولية المجتمعية'],
    assignment: ['الدعم التقني', 'الدعم الإداري', 'الدعم التشغيلي'],
  };
  const updateCategories = () => {
    const options = categories[type.value] || [];
    category.replaceChildren(new Option(options.length ? 'اختر التصنيف' : 'اختر نوع الخدمة أولًا', ''));
    options.forEach(label => category.add(new Option(label, label)));
    category.disabled = !options.length;
    status.textContent = '';
  };
  type.addEventListener('change', updateCategories);
  message.addEventListener('input', () => message.setCustomValidity(''));
  form.addEventListener('submit', event => {
    event.preventDefault();
    status.textContent = '';
    message.setCustomValidity(message.value.trim() ? '' : 'اكتب تفاصيل الطلب قبل الإرسال.');
    if (!form.reportValidity()) return;
    if (!categories[type.value]?.includes(category.value)) return;
    try {
      const saved = localStorage.getItem(storageKey);
      const requests = saved ? JSON.parse(saved) : [];
      if (!Array.isArray(requests)) throw new Error('Invalid requests storage');
      requests.push({
        id: crypto.randomUUID(),
        type: type.value,
        category: category.value,
        message: message.value.trim(),
        createdAt: new Date().toISOString(),
      });
      localStorage.setItem(storageKey, JSON.stringify(requests));
      form.reset();
      updateCategories();
      status.textContent = 'تم تسجيل طلبك محليًا بنجاح.';
    } catch {
      status.textContent = 'تعذّر حفظ الطلب. احتفظ بالتفاصيل وحاول مجددًا.';
    }
  });
  updateCategories();
})();
