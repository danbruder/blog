// Tiny event bus shared between the sea scene (loaded lazily, drags in
// three.js) and lightweight sidebar hooks like the minimap (always loaded
// with the main bundle). Keeping this file dependency-free means the minimap
// never has to wait on — or trigger — the heavy three.js import.
export const seaBus = new EventTarget()
