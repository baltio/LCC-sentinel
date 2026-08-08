/* ============================================================
   LCC OSC — Service Worker PWA
   Cache-first strategy so the app shell (HTML/CSS/JS) loads with
   no network at all — separate from LCC Sentinel 3's own sw.js
   and LCC Sentinel Mustering's sw-mustering.js.
   Live team/fire-sit/medical/plans data is synced over WebSocket
   by the app itself (NetOSC), not cached here.
   ============================================================ */

// Bump on every release so the browser detects the update (byte-diff triggers install).
const CACHE_NAME = 'lcc-osc-v1.0.0';

const APP_SHELL_URL = './LCC OSC.html';

const PRECACHE_URLS = [
  APP_SHELL_URL,
  './manifest-osc.json',
  './assets/js/oe_crew_data.js',
  './assets/js/oe_spaces_data.js',
  './assets/img/general/icon-192.png',
  './assets/img/general/icon-512.png',
  './assets/img/general/icon-96.png',
  './assets/img/general/LOGO_CC_RGBv2.ico',
  './assets/img/general/floconlcc.png',
  './assets/img/plans/GaLCC_page_01.png',
];

// Retries the app shell specifically (the one file offline access cannot work
// without) instead of letting a flaky first-install connection silently and
// permanently leave the tablet unable to open this app offline.
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

self.addEventListener('install', event => {
  self.skipWaiting();
  event.waitUntil(
    caches.open(CACHE_NAME).then(async cache => {
      await cacheAppShellWithRetry(cache);
      await Promise.allSettled(
        PRECACHE_URLS.filter(u => u !== APP_SHELL_URL).map(url => cache.add(url).catch(() => {/* ignore missing optional assets */}))
      );
    })
  );
});

self.addEventListener('activate', event => {
  event.waitUntil(
    (async () => {
      const keys = await caches.keys();
      await Promise.all(keys.filter(k => k !== CACHE_NAME).map(k => caches.delete(k)));
      const cache = await caches.open(CACHE_NAME);
      if (!(await cache.match(APP_SHELL_URL))) {
        await cacheAppShellWithRetry(cache, 2);
      }
      await self.clients.claim();
    })()
  );
});

self.addEventListener('fetch', event => {
  if (event.request.method !== 'GET') return;
  const url = new URL(event.request.url);
  if (url.protocol !== 'http:' && url.protocol !== 'https:') return;
  // Never cache the live WebSocket/API traffic — only static app-shell assets.
  if (url.pathname.startsWith('/api/')) return;

  const isNavigation = event.request.mode === 'navigate' || event.request.destination === 'document';

  event.respondWith(
    caches.match(event.request).then(cached => {
      if (cached) return cached;
      return fetch(event.request).then(response => {
        if (!response || response.status !== 200) return response;
        const cloned = response.clone();
        caches.open(CACHE_NAME).then(cache => cache.put(event.request, cloned));
        return response;
      }).catch(() => {
        if (isNavigation) {
          return caches.match(APP_SHELL_URL);
        }
      });
    })
  );
});
