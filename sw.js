/* ============================================================
   CHARCOT SENTINEL — Service Worker PWA
   Cache-first strategy for offline operation
   ============================================================ */

// Bumped by SAVE_VERSION.ps1 on every release (see its $CompanionFiles handling) so this file's
// bytes actually change each release — that byte diff is what makes the browser notice there's a
// new service worker at all and go fetch it; a same-content sw.js is otherwise invisible to it,
// and the app would stay on old cached code until the site's storage is cleared by hand.
const CACHE_NAME = 'charcot-sentinel-v2.0.35';

// Core assets to cache on install
const PRECACHE_URLS = [
  './LCC sentinel 3.html',
  './manifest.json',
  './assets/img/general/icon-192.png',
  './assets/img/general/icon-512.png',
  './assets/img/general/icon-96.png',
  './assets/img/general/floconlcc.png',
  './assets/img/general/LOGO_CC_RGBv2.ico',
  './assets/img/general/logoponant.png',
  './assets/img/general/namelcc.png',
];

// ── Install: pre-cache core assets ──────────────────────────
self.addEventListener('install', event => {
  self.skipWaiting();
  event.waitUntil(
    caches.open(CACHE_NAME).then(cache => {
      // Cache individually so a single missing file doesn't break install
      return Promise.allSettled(
        PRECACHE_URLS.map(url =>
          cache.add(url).catch(() => {/* ignore missing optional assets */})
        )
      );
    })
  );
});

// ── Activate: clean old caches ──────────────────────────────
self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys().then(keys =>
      Promise.all(
        keys.filter(k => k !== CACHE_NAME).map(k => caches.delete(k))
      )
    ).then(() => self.clients.claim())
  );
});

// ── Fetch: cache-first, network fallback ───────────────────
self.addEventListener('fetch', event => {
  // Only handle GET requests with http(s) scheme
  if (event.request.method !== 'GET') return;
  const url = new URL(event.request.url);
  if (url.protocol !== 'http:' && url.protocol !== 'https:') return;

  event.respondWith(
    caches.match(event.request).then(cached => {
      if (cached) return cached;

      return fetch(event.request).then(response => {
        // Only cache successful same-origin or local responses
        if (!response || response.status !== 200) return response;
        const cloned = response.clone();
        caches.open(CACHE_NAME).then(cache => cache.put(event.request, cloned));
        return response;
      }).catch(() => {
        // For navigation requests, return main HTML as fallback
        if (event.request.mode === 'navigate') {
          return caches.match('./LCC sentinel 3.html');
        }
      });
    })
  );
});
