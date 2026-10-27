(() => {const retry=document.querySelector('[data-error-retry]');if(!retry)return;retry.hidden=false;retry.addEventListener('click',()=>location.reload());})();
