(() => {
  // Header avatar: the employee's Dalil photo (Res=256) via the API; keeps the generic placeholder when
  // no PersonalID is mapped, the photo is missing/invalid, or the service is unavailable.
  const image = document.querySelector('.portal-profile-trigger img');
  const base = document.querySelector('meta[name="companyportal-api-base"]')?.content;
  if (!image || !base) return;
  const url = new URL('api/phone-directory/photo/me', new URL(base.replace(/\/?$/, '/'), location.href));
  const probe = new Image();
  probe.addEventListener('load', () => { if (probe.naturalWidth > 1) image.src = probe.src; }, { once: true });
  probe.src = url.href;
})();
