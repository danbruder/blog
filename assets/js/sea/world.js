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

// Sharks are ambient and purely local — every visitor simulates their own,
// unsynced, so there's no server/channel cost to them. They wander with a
// gentle random turn bias and periodically breach.
const SHARK_SPEED = 0.16
const SHARK_JUMP_MIN = 4 // seconds of patrol before the next jump, at least
const SHARK_JUMP_MAX = 10
const SHARK_JUMP_DURATION = 1.2 // seconds a breach takes, up and back down
const SHARK_BITE_RADIUS = 3.2

export function makeSharks(count, bounds, rand = Math.random) {
  const sharks = []
  for (let i = 0; i < count; i++) {
    sharks.push({
      x: (rand() - 0.5) * bounds * 2,
      z: (rand() - 0.5) * bounds * 2,
      h: rand() * Math.PI * 2,
      turnBias: (rand() - 0.5) * 0.012,
      jumpIn: SHARK_JUMP_MIN + rand() * (SHARK_JUMP_MAX - SHARK_JUMP_MIN),
      jumpT: 0 // > 0 while mid-breach; counts down from SHARK_JUMP_DURATION
    })
  }
  return sharks
}

// Advances one shark's patrol/breach state by dt seconds, wandering within
// `bounds` of the harbor (turns back inward once it strays past the edge).
export function stepShark(shark, dt, bounds, rand = Math.random) {
  shark.h += shark.turnBias + (rand() - 0.5) * 0.01
  shark.x += Math.sin(shark.h) * SHARK_SPEED
  shark.z += Math.cos(shark.h) * SHARK_SPEED
  if (Math.hypot(shark.x, shark.z) > bounds) shark.h += Math.PI

  if (shark.jumpT > 0) {
    shark.jumpT -= dt
    if (shark.jumpT <= 0) {
      shark.jumpT = 0
      shark.jumpIn = SHARK_JUMP_MIN + rand() * (SHARK_JUMP_MAX - SHARK_JUMP_MIN)
    }
  } else {
    shark.jumpIn -= dt
    if (shark.jumpIn <= 0) shark.jumpT = SHARK_JUMP_DURATION
  }
}

// 0 (submerged, fin only) .. 1 (fully breached) for the shark's current
// instant — a simple arc up and back down over the breach's duration, 0 the
// rest of the time.
export function sharkBreach(shark) {
  if (shark.jumpT <= 0) return 0
  const p = 1 - shark.jumpT / SHARK_JUMP_DURATION
  return Math.sin(p * Math.PI)
}

// The first shark within bite range of (x, z), or null. Bounds a shark's
// hitbox to its own radius regardless of how deep the caller wants to go
// with a cooldown on top (that's the caller's concern, not this check's).
export function nearestBitingShark(x, z, sharks, radius = SHARK_BITE_RADIUS) {
  for (const shark of sharks) {
    if (Math.hypot(shark.x - x, shark.z - z) < radius) return shark
  }
  return null
}
