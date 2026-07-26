// Pure helpers for the sea world: island data + docking distance. No three.js
// here so this stays trivial to reason about.

export const DOCK_RADIUS = 9

// Returns the nearest island within DOCK_RADIUS of (x, z), or null.
export function nearestDockable(x, z, islands) {
  let best = null
  let bestD = DOCK_RADIUS * DOCK_RADIUS
  for (const isl of islands) {
    const dx = isl.x - x
    const dz = isl.z - z
    const d = dx * dx + dz * dz
    if (d < bestD) {
      bestD = d
      best = isl
    }
  }
  return best
}

// Island whose center is nearest (x, z) regardless of distance — used to label
// the island you're approaching.
export function nearestIsland(x, z, islands) {
  let best = null
  let bestD = Infinity
  for (const isl of islands) {
    const dx = isl.x - x
    const dz = isl.z - z
    const d = dx * dx + dz * dz
    if (d < bestD) {
      bestD = d
      best = isl
    }
  }
  return best ? {island: best, distance: Math.sqrt(bestD)} : null
}
