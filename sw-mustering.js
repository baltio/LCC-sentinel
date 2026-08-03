/* ============================================================
   LCC SENTINEL MUSTERING — Service Worker PWA
   Cache-first strategy so the app shell (HTML/CSS/JS) loads with
   no network at all — separate from LCC Sentinel 3's own sw.js.
   Live crew/PAX roster data is a separate concern, cached in
   localStorage by the app itself (STATE.cachedRoster).
   ============================================================ */

// Bumped by SAVE_VERSION.ps1 on every release, in step with Sentinel 3's own sw.js — see its
// comment for why this byte-diff is what makes an update visible to the browser at all.
const CACHE_NAME = 'lcc-mustering-v2.0.35';

const PRECACHE_URLS = [
  './LCC Sentinel Mustering.html',
  './manifest-mustering.json',
  './assets/img/general/icon-192.png',
  './assets/img/general/icon-512.png',
  './assets/img/general/icon-96.png',
  './assets/img/general/LOGO_CC_RGBv2.ico',
];

self.addEventListener('install', event => {
  self.skipWaiting();
  event.waitUntil(
    caches.open(CACHE_NAME).then(cache =>
      Promise.allSettled(
        PRECACHE_URLS.map(url => cache.add(url).catch(() => {/* ignore missing optional assets */}))
      )
    )
  );
});

self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(k => k !== CACHE_NAME).map(k => caches.delete(k)))
    ).then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', event => {
  if (event.request.method !== 'GET') return;
  const url = new URL(event.request.url);
  if (url.protocol !== 'http:' && url.protocol !== 'https:') return;

  event.respondWith(
    caches.match(event.request).then(cached => {
      if (cached) return cached;
      return fetch(event.request).then(response => {
        if (!response || response.status !== 200) return response;
        const cloned = response.clone();
        caches.open(CACHE_NAME).then(cache => cache.put(event.request, cloned));
        return response;
      }).catch(() => {
        if (event.request.mode === 'navigate') {
          return caches.match('./LCC Sentinel Mustering.html');
        }
      });
    })
  );
});
