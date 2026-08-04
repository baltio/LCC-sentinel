/* ============================================================
   CHARCOT SENTINEL — Service Worker PWA
   Cache-first strategy for offline operation
   ============================================================ */

// Bumped by SAVE_VERSION.ps1 on every release (see its $CompanionFiles handling) so this file's
// bytes actually change each release — that byte diff is what makes the browser notice there's a
// new service worker at all and go fetch it; a same-content sw.js is otherwise invisible to it,
// and the app would stay on old cached code until the site's storage is cleared by hand.
const CACHE_NAME = 'charcot-sentinel-v2.0.36';

// The main HTML is the one file offline access cannot work without — everything else
// (icons, manifest) degrades gracefully if missing, this one doesn't.
const APP_SHELL_URL = './LCC sentinel 3.html';

// Core assets to cache on install
const PRECACHE_URLS = [
  APP_SHELL_URL,
  './manifest.json',
  './assets/img/general/icon-192.png',
  './assets/img/general/icon-512.png',
  './assets/img/general/icon-96.png',
  './assets/img/general/floconlcc.png',
  './assets/img/general/LOGO_CC_RGBv2.ico',
  './assets/img/general/logoponant.png',
  './assets/img/general/namelcc.png',
];

/* Tablets install this while docked at a port with WiFi and then go offline for days/weeks at
   sea — if the app shell's own precache fetch happened to fail (flaky connection during that
   one install moment), the old code swallowed it silently via Promise.allSettled + a no-op
   .catch(), with no retry and no way to notice: the tablet would be "installed" but permanently
   unable to open offline until someone thought to reconnect it to WiFi. Retries a few times with
   a backoff, and logs clearly (visible via chrome://inspect) instead of failing silently. */
async function cacheAppShellWithRetry(cache, attempts = 3) {
  for (let i = 0; i < attempts; i++) {
    try {
      await cache.add(APP_SHELL_URL);
      console.log(`[SW] App shell cached (attempt ${i + 1})`);
      return true;
    } catch (e) {
      console.warn(`[SW] App shell cache attempt ${i + 1} failed:`, e);
      if (i < attempts - 1) await new Promise(r => setTimeout(r, 1500 * (i + 1)));
    }
  }
  console.error('[SW] App shell could not be cached after retries — offline launch will fail until next successful online load');
  return false;
}

// ── Install: pre-cache core assets ──────────────────────────
self.addEventListener('install', event => {
  self.skipWaiting();
  event.waitUntil(
    caches.open(CACHE_NAME).then(async cache => {
      await cacheAppShellWithRetry(cache);
      // Everything else: cache individually so one missing/optional file doesn't block install
      await Promise.allSettled(
        PRECACHE_URLS.filter(u => u !== APP_SHELL_URL).map(url =>
          cache.add(url).catch(() => {/* ignore missing optional assets */})
        )
      );
    })
  );
});

// ── Activate: clean old caches, self-heal a missing app shell ──────────────
self.addEventListener('activate', event => {
  event.waitUntil(
    (async () => {
      const keys = await caches.keys();
      await Promise.all(keys.filter(k => k !== CACHE_NAME).map(k => caches.delete(k)));
      const cache = await caches.open(CACHE_NAME);
      // Covers the case where THIS activation is a fresh install whose 'install' handler above
      // already retried and gave up (still offline) — try once more now, and again on every
      // future activate (i.e. every update check) until it finally succeeds.
      if (!(await cache.match(APP_SHELL_URL))) {
        await cacheAppShellWithRetry(cache, 2);
      }
      await self.clients.claim();
    })()
  );
});

// ── Fetch: cache-first, network fallback ───────────────────
self.addEventListener('fetch', event => {
  // Only handle GET requests with http(s) scheme
  if (event.request.method !== 'GET') return;
  const url = new URL(event.request.url);
  if (url.protocol !== 'http:' && url.protocol !== 'https:') return;

  const isNavigation = event.request.mode === 'navigate' || event.request.destination === 'document';

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
        // Offline and not in cache — for a page navigation, serve the app shell so the app at
        // least opens (it runs entirely client-side once loaded) instead of the browser's own
        // "no internet" error page.
        if (isNavigation) {
          return caches.match(APP_SHELL_URL);
        }
      });
    })
  );
});
