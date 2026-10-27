(() => {
  // «أرقام تهمك» from Mng.ImportantNumbers (managed at /admin/header-content).
  const list = document.getElementById('portal-important-numbers');
  const base = document.querySelector('meta[name="companyportal-api-base"]')?.content;
  if (!list || !base) return;
  const note = document.getElementById('portal-important-numbers-note');
  async function load() {
    try {
      const url = new URL('api/header-content/important-numbers', new URL(base.replace(/\/?$/, '/'), location.href));
      const response = await fetch(url, { credentials: 'include', cache: 'no-store', signal: AbortSignal.timeout(15000) });
      if (!response.ok) throw new Error();
      const numbers = await response.json();
      if (!Array.isArray(numbers)) throw new Error();
      list.replaceChildren(...numbers.map(item => {
        const row = document.createElement('div'), title = document.createElement('dt'), number = document.createElement('dd');
        title.textContent = item.title; number.textContent = item.number; number.dir = 'ltr';
        row.append(title, number); return row;
      }));
      note.textContent = numbers.length ? '' : 'لا توجد أرقام حاليًا.';
    } catch {
      if (!list.children.length) note.textContent = 'تعذر تحميل الأرقام.';
    }
  }
  void load();
})();
