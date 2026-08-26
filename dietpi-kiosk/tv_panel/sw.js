/* Minimal SW — required for Chrome installability */
self.addEventListener("install", (event) => {
  event.waitUntil(self.skipWaiting());
});

self.addEventListener("activate", (event) => {
  event.waitUntil(self.clients.claim());
});

self.addEventListener("fetch", (event) => {
  // Network-only; auth pages must not be precached anonymously
  event.respondWith(fetch(event.request));
});
