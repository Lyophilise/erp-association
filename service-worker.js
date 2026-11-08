// Service worker minimal : juste assez pour rendre l'app installable
// (Chrome exige un SW actif pour proposer "Ajouter à l'écran d'accueil").
// Pas de cache offline pour l'instant - les données viennent de Supabase
// et n'ont pas de sens hors-ligne dans cette V1.

self.addEventListener("install", () => {
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(self.clients.claim());
});

self.addEventListener("fetch", () => {
  // passthrough volontaire : pas d'interception pour l'instant
});
