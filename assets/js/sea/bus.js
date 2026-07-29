// Event bus shared between the sea scene and lightweight sidebar hooks like
// the minimap. app.js and sea/index.js are two independent esbuild bundles
// (the sea scene is lazy-loaded to keep three.js out of the main bundle), so
// each gets its own copy of any module-level object — a plain EventTarget
// here would give the scene and the minimap two different instances that
// never see each other's events. `document` is the one thing both bundles
// actually share, so it doubles as the bus (same trick as the site's
// existing "theme:changed" event).
export const seaBus = document
