(() => {
  'use strict';
  // Retire only SmartStock's worker; retain device drafts and outboxes.
  window.SmartStockOffline = {
    async prepare() {
      throw new Error('Ứng dụng yêu cầu kết nối mạng; không hỗ trợ offline.');
    }
  };
  if ('serviceWorker' in navigator && window.isSecureContext) {
    navigator.serviceWorker.getRegistrations().then(async registrations => {
      for (const registration of registrations) {
        const workers = [registration.active, registration.waiting, registration.installing].filter(Boolean);
        if (workers.some(worker => {
          const url = new URL(worker.scriptURL);
          return url.origin === location.origin && /\/(?:smartstock-sw|flutter_service_worker)\.js$/.test(url.pathname);
        })) await registration.unregister();
      }
    }).catch(() => {});
  }
})();
