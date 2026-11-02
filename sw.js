const CACHE_NAME = 'exxpress-mobile-20261102-google-verification-v1';
const APP_SHELL = ['./', './index.html', './manifest.webmanifest', './icon.svg'];
self.addEventListener('install', event => {
  self.skipWaiting();
  event.waitUntil(caches.open(CACHE_NAME).then(cache => cache.addAll(APP_SHELL).catch(() => {})));
});
self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(key => key !== CACHE_NAME).map(key => caches.delete(key))))
      .then(() => self.clients.claim())
  );
});
self.addEventListener('fetch', event => {
  const request = event.request;
  if (request.method !== 'GET') return;
  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;
  if (request.mode === 'navigate') {
    event.respondWith(
      fetch(new Request(request, { cache: 'no-store' }))
        .then(response => {
          if (response && response.ok) caches.open(CACHE_NAME).then(cache => cache.put('./index.html', response.clone())).catch(() => {});
          return response;
        })
        .catch(() => caches.match('./index.html').then(cached => cached || Response.error()))
    );
    return;
  }
  event.respondWith(
    fetch(request)
      .then(response => {
        if (response && response.ok) caches.open(CACHE_NAME).then(cache => cache.put(request, response.clone())).catch(() => {});
        return response;
      })
      .catch(() => caches.match(request).then(cached => cached || Response.error()))
  );
});
