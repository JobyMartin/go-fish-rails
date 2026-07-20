
const addResourcesToCache = async (resources) => {
  const cache = await caches.open("v1")
  await cache.addAll(resources)
}


self.addEventListener("install", (event) => {
  event.waitUntil(
    addResourcesToCache([
      "/offlines",
    ]),
  );
  console.log('installing...')
});

self.addEventListener("fetch", (event) => {
  if (event.request.mode === "navigate") {
    event.respondWith(
      fetch(event.request).catch(() => {
        return caches.match('/offlines');
      })
    );
  }
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) =>
        Promise.all(
          keys.filter((key) => key !== 'v1').map((key) => caches.delete(key))
        )
      )
      .then(() => self.clients.claim())
  )
})

