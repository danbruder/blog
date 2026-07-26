// Pure helpers for the sea world: island data + docking distance. No three.js
// here so this stays trivial to reason about.

// Islands vary in visual radius (set by scene.js once rendered); fall back to
// this for any island a caller hasn't rendered yet.
const DEFAULT_RADIUS = 8
const DOCK_MARGIN = 3 // how far beyond an island's edge you can still dock
const COLLISION_MARGIN = 1.5 // boat half-length buffer beyond an island's edge

export function islandRadius(island) {
  return island.radius ?? DEFAULT_RADIUS
}

// Returns whichever island (x, z) is within dock range of, or null. Range
// scales with each island's own size.
export function nearestDockable(x, z, islands, margin = DOCK_MARGIN) {
  let best = null
  let bestSlack = -Infinity
  for (const isl of islands) {
    const dx = isl.x - x
    const dz = isl.z - z
    const d = Math.sqrt(dx * dx + dz * dz)
    const r = islandRadius(isl) + margin
    const slack = r - d
    if (slack > 0 && slack > bestSlack) {
      bestSlack = slack
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

// True once a boat at `distance` from `island`'s center is close enough that
// pressing dock would work — kept in sync with nearestDockable's threshold.
export function isCloseEnoughToDock(island, distance, margin = DOCK_MARGIN) {
  return distance < islandRadius(island) + margin
}

// Pushes (x, z) back outside any island's collision radius, so a boat can't
// sail through land. Returns the corrected position and whether a collision
// happened this frame (used to trigger a "crash" bump). Each island's
// collision size follows its own visual radius.
export function resolveCollision(x, z, islands, margin = COLLISION_MARGIN) {
  let hit = false
  for (const isl of islands) {
    const dx = x - isl.x
    const dz = z - isl.z
    const d = Math.sqrt(dx * dx + dz * dz)
    const r = islandRadius(isl) + margin
    if (d < r) {
      const safeD = d || 0.001
      const push = r / safeD
      x = isl.x + (dx || safeD) * push
      z = isl.z + dz * push
      hit = true
    }
  }
  return {x, z, hit}
}
