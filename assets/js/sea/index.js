import {SeaScene, flagTexture, emoteSprite, bottleSprite, wakeSegment, PALETTE, BOAT_TYPES} from "./scene.js"
import {createControls} from "./controls.js"
import {SeaNet} from "./net.js"
import {SeaAudio} from "./audio.js"
import {
  nearestDockable,
  nearestIsland,
  nearestBottle,
  isCloseEnoughToDock,
  resolveCollision,
  COLLISION_MARGIN,
  makeSharks,
  stepShark,
  sharkBreach,
  nearestBitingShark,
  easternHour,
  dayFactor,
  makeGulls,
  stepGull,
  gullBob,
  gullBank,
  boatRiseOffset,
  boatSinkOffset,
  BOAT_RISE_DURATION
} from "./world.js"
import {seaBus} from "./bus.js"

const MAX_SPEED = 0.85
const ACCEL = 0.07
const DECAY = 0.94 // per-frame friction applied when no throttle is held
const TURN_RATE = 0.03
const MIN_SPEED_TO_TURN = 0.05 // above this, turning is at full rate
const STATIONARY_TURN_FACTOR = 0.35 // turning while dead in the water is slower, not blocked
const CRASH_BOUNCE = -0.25 // reverses and dampens speed on collision
const BOAT_RADIUS = 2.2 // other boats are obstacles too, not just islands
const BOAT_COLLISION_MARGIN = 1
const SHARK_COUNT = 5
const SHARK_BOUNDS = 140 // sharks patrol within this radius of the harbor
const BITE_BOUNCE = -0.6 // harder knockback than a plain crash
const BITE_COOLDOWN = 2 // seconds of invulnerability after a bite
const DOCK_CHIME_DELAY = 150 // ms to let the chime start before navigating away
const EMOTE_COOLDOWN = 0.8 // seconds between waves, so holding/mashing the key doesn't spam
const EMOTE_DURATION = 1.3 // seconds the wave sprite rises and fades over
const BOTTLE_MAX_LENGTH = 80
const TIME_OF_DAY_REFRESH_MS = 60_000 // sky doesn't need per-frame updates -- just re-check each minute
const WAKE_SPAWN_DISTANCE = 2.5 // a boat drops one wake puff per this many units traveled
const WAKE_DURATION = 1.6 // seconds a puff takes to fully fade
const MAX_WAKES = 120 // hard cap so a crowded sea can't run away with the segment count
const GULL_COUNT = 6
const GULL_BOUNDS = 130 // seagulls patrol within this radius of the harbor
const CUSTOM_COLOR_KEY = "seaCustomColor"
const CUSTOM_FLAG_KEY = "seaCustomFlag"
const CUSTOM_BOAT_KEY = "seaCustomBoat"
// Curated rather than free text, same reasoning as the hull PALETTE: a
// fixed set keeps every sailor's picker rendering something every browser
// actually has a glyph for.
const FLAG_EMOJI = ["🏴", "🏳️", "🏁", "🚩", "⚓", "⛵", "🦈", "🐙", "🐬", "🌊", "⭐", "💀", "🔥", "🍀", "🌈", "⚡"]

// The seaplane's flight mechanic (see updateFlight()): needs a runway-speed
// minimum before it can lift off, then altitude is held directly by
// holding the ascend/descend keys/buttons -- no separate "toggle flight"
// control, so up/down (climb/descend) IS takeoff/landing.
const TAKEOFF_SPEED_FRACTION = 0.55 // fraction of the seaplane's own max speed needed to leave the water
const CRUISE_ALTITUDE = 16 // a bit under GULL_ALTITUDE, so a flying boat reads as lower than the gulls
const CLIMB_RATE = 9 // units/sec while holding ascend
const DESCEND_RATE = 11 // units/sec while holding descend -- a touch faster, like coming in to land
const TAKEOFF_HINT_COOLDOWN = 3 // seconds between "get up to speed" toasts, so holding the key doesn't spam

let active = null

export function startSea({el, sailorId, islands}) {
  if (active) return
  active = new Sea(el, sailorId, islands)
}

export function stopSea() {
  if (active) {
    active.destroy()
    active = null
  }
}

class Sea {
  constructor(el, sailorId, islands) {
    this.el = el
    this.sailorId = sailorId
    this.islands = islands
    this.islandsByPath = new Map(islands.map((i) => [i.path, i]))

    this.scene = new SeaScene(el)
    for (const isl of islands) this.scene.addIsland(isl)

    // Always follows US Eastern time, not the visitor's own timezone, so
    // every sailor sees the same sky at once. Refreshed periodically rather
    // than per-frame -- the sky doesn't need to update faster than once a
    // minute, and this also catches a tab left open across the dawn/dusk
    // curve or a DST transition.
    this.scene.applyTimeOfDay(dayFactor(easternHour()))
    this.timeOfDayTimer = setInterval(() => {
      this.scene.applyTimeOfDay(dayFactor(easternHour()))
    }, TIME_OF_DAY_REFRESH_MS)

    // Resume at the last saved spot (e.g. returning from a docked post);
    // otherwise start at the harbor.
    const harbor = this.islandsByPath.get("/") || {x: 0, z: 0}
    this.pos = loadPos() || {x: harbor.x, z: harbor.z + 20, h: Math.PI}
    this.speed = 0
    this.wasColliding = false
    this.emoteCooldown = 0
    this.emotes = [] // active {sprite, boatGroup, t} wave sprites, see updateEmotes()
    this.bottleMeshes = new Map() // id -> {sprite, bottle}
    this.wakes = [] // active {mesh, t} wake puffs, see updateWakes()
    this.lastWakePos = new Map() // sailorId -> {x, z}, throttles wake spawning by distance traveled
    // A customized hull color/flag/boat (see the 🎨 picker below) is applied
    // right after creation, overriding the hash-derived hull color and the
    // placeholder "🏴" flag for *this sailor's own view only* — other
    // sailors still see this boat's hash-derived color, GeoIP flag, and the
    // default pirate ship, the same as before. Syncing a custom look to
    // other viewers would need extending the presence/channel roster; left
    // for later.
    this.customColor = localStorage.getItem(CUSTOM_COLOR_KEY)
    this.customFlag = localStorage.getItem(CUSTOM_FLAG_KEY)
    this.boatType = BOAT_TYPES.find((b) => b.id === localStorage.getItem(CUSTOM_BOAT_KEY)) || BOAT_TYPES[0]
    // Altitude above the water -- only a canFly boat (the seaplane) ever
    // moves this off 0; see updateFlight().
    this.altitude = 0
    this.selfBoat = this.scene.makeBoat(flagTexture(this.customFlag || "🏴"), true, sailorId, this.boatType)
    if (this.customColor) this.scene.setHullColor(this.selfBoat, this.customColor)
    // Every boat (self, live sailors, anchored readers) rises from below the
    // water when it first appears rather than popping in -- see
    // spawnRise/applyRise. A departing sailor's boat sinks instead of
    // vanishing -- see sinkBoat/updateSinkingBoats.
    this.spawnRise = new Map() // id -> elapsed seconds since appearing, while still rising
    this.sinkingBoats = [] // [{group, t}] boats currently playing their exit animation
    this.spawnRise.set(sailorId, 0)

    this.customizeBtn = document.createElement("button")
    this.customizeBtn.className = "sea-customize-btn"
    this.customizeBtn.type = "button"
    this.customizeBtn.textContent = "🎨"
    this.customizeBtn.setAttribute("aria-label", "Customize your boat")
    this.customizePanel = this.buildCustomizePanel()
    this.customizeBtn.addEventListener("click", () => {
      this.customizePanel.style.display = this.customizePanel.style.display === "none" ? "flex" : "none"
    })
    el.appendChild(this.customizeBtn)
    el.appendChild(this.customizePanel)

    this.controls = createControls(el)
    this.controls.setFlightControlsVisible(this.boatType.canFly)
    this.net = new SeaNet(sailorId)
    this.readerBoats = new Map() // id -> {group}
    this.remoteBoats = new Map() // id -> {group}

    // Sharks are ambient and purely local (see world.js) — not networked, so
    // every visitor patrols their own and a bite only affects their own boat.
    this.sharks = makeSharks(SHARK_COUNT, SHARK_BOUNDS)
    this.sharkMeshes = this.sharks.map(() => this.scene.addShark())
    this.biteCooldown = 0

    // Seagulls circle overhead — same ambient, unsynced, purely local story.
    this.gulls = makeGulls(GULL_COUNT, GULL_BOUNDS)
    this.gullMeshes = this.gulls.map(() => this.scene.addGull())

    this.banner = document.createElement("div")
    this.banner.className = "sea-banner"
    el.appendChild(this.banner)

    this.hint = document.createElement("div")
    this.hint.className = "sea-hint"
    el.appendChild(this.hint)
    this.updateHint()

    this.bottleBanner = document.createElement("div")
    this.bottleBanner.className = "sea-bottle-banner"
    el.appendChild(this.bottleBanner)

    this.biteMsg = document.createElement("div")
    this.biteMsg.className = "sea-bite"
    this.biteMsg.textContent = "🦈 Bitten! Watch the fins."
    el.appendChild(this.biteMsg)

    this.toast = document.createElement("div")
    this.toast.className = "sea-toast"
    el.appendChild(this.toast)
    this.toastQueue = []
    this.toastTimer = null
    this.net.onArrive = (flag) => this.queueToast(`${flag} a sailor has joined the sea`)
    this.net.onDepart = (flag) => this.queueToast(`${flag} a sailor has left the sea`)
    this.net.onEmote = (id) => {
      // Best-effort visual: only attaches if that sailor's boat is currently
      // rendered (live sailor or anchored reader). The sound plays either
      // way, so a wave still reads as "someone out there waved" even if
      // their boat isn't drawn (e.g. past MAX_BOATS).
      const boat = this.remoteBoats.get(id) || this.readerBoats.get(id)
      if (boat) this.spawnEmote(boat)
      this.audio.wave()
    }
    this.net.onBottleDropped = (bottle) => this.spawnBottle(bottle)
    this.net.onBottleExpired = (id) => this.despawnBottle(id)

    // Ambient waves + a few event sounds (splash, shark bite, dock chime).
    // Always muted on first visit — the mute button click is the only thing
    // that can turn it on. See audio.js for the autoplay-safe details.
    this.audio = new SeaAudio()
    this.muteBtn = document.createElement("button")
    this.muteBtn.className = "sea-mute"
    this.muteBtn.type = "button"
    this.refreshMuteBtn()
    this.muteBtn.addEventListener("click", () => {
      this.audio.toggle()
      this.refreshMuteBtn()
    })
    el.appendChild(this.muteBtn)
    this.audio.armFromStoredPreference(el, () => this.refreshMuteBtn())

    this.onNavigate = (e) => {
      this.pos.x = e.detail.x
      this.pos.z = e.detail.z
      this.speed = 0
    }
    seaBus.addEventListener("sea:navigate", this.onNavigate)

    this.t = 0
    this.tickEvery = 6 // throttle minimap updates to ~10Hz at 60fps
    this.running = true
    this.loop = this.loop.bind(this)
    requestAnimationFrame(this.loop)
  }

  loop() {
    if (!this.running) return
    this.t += 0.016

    const input = this.controls.read()

    // Airborne (only possible for a canFly boat -- see updateFlight): sails
    // clean over islands and other boats, and cruises at its own flying
    // speed rather than its on-water one.
    const flying = this.boatType.canFly && this.altitude > 0.5
    const speedFactor = flying && this.boatType.flySpeedFactor ? this.boatType.flySpeedFactor : this.boatType.speedFactor

    // Ease speed toward the throttle target, decaying with friction when the
    // throttle is released — so letting go coasts to a stop instead of
    // snapping, and tapping briefly doesn't leave the boat drifting forever.
    const target = input.throttle * MAX_SPEED * speedFactor
    if (target !== 0) {
      this.speed += (target - this.speed) * ACCEL * speedFactor
    } else {
      this.speed *= DECAY
      if (Math.abs(this.speed) < 0.002) this.speed = 0
    }

    // Turning works even standing still, but is slower than while under way.
    const turnRate =
      Math.abs(this.speed) > MIN_SPEED_TO_TURN ? TURN_RATE : TURN_RATE * STATIONARY_TURN_FACTOR
    this.pos.h -= input.turn * turnRate

    const nextX = this.pos.x + Math.sin(this.pos.h) * this.speed
    const nextZ = this.pos.z + Math.cos(this.pos.h) * this.speed
    if (flying) {
      this.pos.x = nextX
      this.pos.z = nextZ
      this.wasColliding = false
    } else {
      // Collision clearance scales with the boat's own footprint (see
      // BOAT_TYPES' sizeFactor) -- a container ship needs more room than a
      // speedboat to keep its bow from visually poking through land.
      const land = resolveCollision(nextX, nextZ, this.islands, COLLISION_MARGIN * this.boatType.sizeFactor)
      const boats = resolveCollision(
        land.x,
        land.z,
        this.boatObstacles(),
        BOAT_COLLISION_MARGIN * this.boatType.sizeFactor
      )
      const colliding = land.hit || boats.hit
      if (colliding) this.speed *= CRASH_BOUNCE
      // Edge-triggered so holding the throttle into an island plays one splash
      // on impact, not one every frame for as long as contact continues.
      if (colliding && !this.wasColliding) this.audio.splash()
      this.wasColliding = colliding
      this.pos.x = boats.x
      this.pos.z = boats.z
    }

    this.updateFlight(input)

    this.selfBoat.position.set(this.pos.x, this.altitude, this.pos.z)
    this.selfBoat.rotation.y = this.pos.h
    this.applyRise(this.sailorId, this.selfBoat)
    // A boat wake is a water-surface effect -- skip it while airborne.
    if (!flying) this.maybeSpawnWake(this.sailorId, this.pos.x, this.pos.z, this.pos.h)

    this.stepSharks(flying)
    this.stepGulls()

    this.net.sendPos(
      round(this.pos.x),
      round(this.pos.z),
      round(this.pos.h)
    )
    this.net.interpolate()

    this.syncOtherBoats()
    this.updateBanner()
    if (Math.round(this.t * 60) % this.tickEvery === 0) this.publishTick()

    if (input.dock) {
      input.dock = false
      const isl = nearestDockable(this.pos.x, this.pos.z, this.islands)
      if (isl) this.dockTo(isl)
    }

    if (this.emoteCooldown > 0) this.emoteCooldown -= 0.016
    if (input.emote) {
      input.emote = false
      this.tryEmote()
    }
    this.updateEmotes()

    if (input.drop) {
      input.drop = false
      this.tryDropBottle()
    }
    this.updateBottles()
    this.updateBottleBanner()

    this.updateWakes()
    this.updateSinkingBoats()

    this.scene.animateWater(this.t)
    this.scene.chase(this.pos, this.pos.h)
    this.scene.render()
    requestAnimationFrame(this.loop)
  }

  // Advances every shark's patrol/breach state and its rendered mesh, then
  // — once any post-bite invulnerability has worn off — knocks the boat back
  // and flashes a warning if it strayed within range of one. `flying` skips
  // just the bite check: a seaplane in the air is out of reach.
  stepSharks(flying) {
    for (let i = 0; i < this.sharks.length; i++) {
      const shark = this.sharks[i]
      stepShark(shark, 0.016, SHARK_BOUNDS)
      this.scene.updateShark(this.sharkMeshes[i], shark, sharkBreach(shark))
    }
    if (flying) return

    if (this.biteCooldown > 0) {
      this.biteCooldown -= 0.016
      return
    }
    const shark = nearestBitingShark(this.pos.x, this.pos.z, this.sharks)
    if (!shark) return

    this.biteCooldown = BITE_COOLDOWN
    this.speed *= BITE_BOUNCE
    this.audio.biteAlarm()
    const dx = this.pos.x - shark.x
    const dz = this.pos.z - shark.z
    const d = Math.hypot(dx, dz) || 0.001
    this.pos.x += (dx / d) * 4
    this.pos.z += (dz / d) * 4

    this.biteMsg.style.opacity = "1"
    clearTimeout(this._biteMsgTimer)
    this._biteMsgTimer = setTimeout(() => {
      this.biteMsg.style.opacity = "0"
    }, 1200)
  }

  // Advances every seagull's patrol/bob state — pure atmosphere, cruising
  // well above anything else in the scene.
  stepGulls() {
    for (let i = 0; i < this.gulls.length; i++) {
      const g = this.gulls[i]
      stepGull(g, 0.016, GULL_BOUNDS)
      this.scene.updateGull(this.gullMeshes[i], g, gullBob(g), gullBank(g))
    }
  }

  // The seaplane's altitude, held directly by holding ascend/descend --
  // there's no separate "toggle flight" control, so climbing off the water
  // (once past TAKEOFF_SPEED_FRACTION) IS taking off, and descending back
  // to 0 IS landing. No-ops (beyond a safety-net landing) for every other
  // boat, so this is always safe to call regardless of selection.
  updateFlight(input) {
    if (!this.boatType.canFly) {
      if (this.altitude > 0) this.altitude = 0 // switched away from the seaplane mid-flight
      this.selfBoat.rotation.x = 0
      return
    }

    const wasAirborne = this.altitude > 0
    const effectiveMax = MAX_SPEED * this.boatType.speedFactor

    if (input.ascend) {
      const canLift = wasAirborne || Math.abs(this.speed) >= effectiveMax * TAKEOFF_SPEED_FRACTION
      if (canLift) this.altitude = Math.min(CRUISE_ALTITUDE, this.altitude + CLIMB_RATE * 0.016)
      else this.showTakeoffHint()
    } else if (input.descend && this.altitude > 0) {
      this.altitude = Math.max(0, this.altitude - DESCEND_RATE * 0.016)
    }

    const nowAirborne = this.altitude > 0
    if (!wasAirborne && nowAirborne) this.audio.liftoff()
    if (wasAirborne && !nowAirborne) this.audio.splash() // splashdown

    // Nose pitches with climb/descent for visual feedback, easing back
    // level (0) once neither key is held or altitude is pinned at an end.
    if (input.ascend && nowAirborne) this.selfBoat.rotation.x = -0.25
    else if (input.descend && wasAirborne) this.selfBoat.rotation.x = 0.2
    else this.selfBoat.rotation.x *= 0.8
  }

  // Throttled so holding ascend without enough speed doesn't spam the toast
  // queue every single frame.
  showTakeoffHint() {
    if (this._lastTakeoffHint !== undefined && this.t - this._lastTakeoffHint < TAKEOFF_HINT_COOLDOWN) return
    this._lastTakeoffHint = this.t
    this.queueToast("🛫 Get up to speed first, then keep holding to take off")
  }

  // Live sailors (from net.remote). A sailor id that is also in the roster is
  // still drawn from its live position; the roster only anchors *readers*.
  syncOtherBoats() {
    const MAX_BOATS = 60
    let drawn = 0
    const liveIds = new Set()
    for (const [id, p] of this.net.remote) {
      if (id === this.sailorId) continue
      if (drawn++ > MAX_BOATS) break
      liveIds.add(id)
      let b = this.remoteBoats.get(id)
      if (!b) {
        b = this.scene.makeBoat(flagTexture(this.flagFor(id)), false, id)
        this.remoteBoats.set(id, b)
        this.spawnRise.set(id, 0)
      }
      b.position.set(p.x, 0, p.z)
      b.rotation.y = p.h
      this.applyRise(id, b)
      this.maybeSpawnWake(id, p.x, p.z, p.h)
    }
    for (const [id, b] of this.remoteBoats) {
      if (!liveIds.has(id)) {
        this.sinkBoat(id, b)
        this.remoteBoats.delete(id)
        this.lastWakePos.delete(id) // stop tracking distance-traveled for a sailor who's gone
      }
    }

    // Anchored reader boats: everyone in the roster who is NOT sailing live and
    // is not us. Bob them gently at their island.
    const anchored = new Set()
    for (const s of this.net.roster) {
      if (s.id === this.sailorId || liveIds.has(s.id)) continue
      if (drawn++ > MAX_BOATS) break
      const isl = this.islandsByPath.get(s.path)
      if (!isl) continue
      anchored.add(s.id)
      let b = this.readerBoats.get(s.id)
      if (!b) {
        b = this.scene.makeBoat(flagTexture(s.flag), false, s.id)
        this.readerBoats.set(s.id, b)
        this.spawnRise.set(s.id, 0)
      }
      const bob = Math.sin(this.t * 1.5 + hash(s.id)) * 0.4
      b.position.set(isl.x + 10, bob, isl.z + 10)
      b.rotation.y = hash(s.id)
      this.applyRise(s.id, b)
    }
    for (const [id, b] of this.readerBoats) {
      if (!anchored.has(id)) {
        this.sinkBoat(id, b)
        this.readerBoats.delete(id)
      }
    }
  }

  // Adds this frame's rise offset (see world.js's boatRiseOffset) on top of
  // `group`'s just-set normal position, for however many boats (self, live
  // sailors, anchored readers) are still mid-entrance. No-op once a boat
  // isn't tracked in spawnRise (the common case: already fully surfaced).
  applyRise(id, group) {
    const t = this.spawnRise.get(id)
    if (t === undefined) return
    const next = t + 0.016
    if (next >= BOAT_RISE_DURATION) {
      this.spawnRise.delete(id)
      return
    }
    this.spawnRise.set(id, next)
    group.position.y += boatRiseOffset(next)
  }

  // Starts a departing boat's sink-and-remove animation (see world.js's
  // boatSinkOffset) rather than deleting it from the scene outright. Cancels
  // any in-flight rise so a boat that leaves mid-entrance doesn't fight itself.
  sinkBoat(id, group) {
    this.spawnRise.delete(id)
    this.sinkingBoats.push({group, t: 0})
  }

  // Advances every sinking boat's descent/list, removing it for good once
  // its animation completes.
  updateSinkingBoats() {
    for (let i = this.sinkingBoats.length - 1; i >= 0; i--) {
      const s = this.sinkingBoats[i]
      s.t += 0.016
      const {y, tilt, done} = boatSinkOffset(s.t)
      s.group.position.y = y
      s.group.rotation.z = tilt
      if (done) {
        this.scene.removeBoat(s.group)
        this.sinkingBoats.splice(i, 1)
      }
    }
  }

  // Drops one wake puff behind `id`'s boat once it's traveled
  // WAKE_SPAWN_DISTANCE since its last one — called for the self boat and
  // every live remote sailor (not anchored readers, which don't move), so
  // distance-since-last-spawn is what throttles density, not a fixed timer;
  // a stationary boat naturally stops generating wake.
  maybeSpawnWake(id, x, z, h) {
    const last = this.lastWakePos.get(id)
    if (last && Math.hypot(x - last.x, z - last.z) < WAKE_SPAWN_DISTANCE) return
    this.lastWakePos.set(id, {x, z})

    if (this.wakes.length >= MAX_WAKES) {
      const oldest = this.wakes.shift()
      this.scene.remove(oldest.mesh)
    }

    const mesh = wakeSegment()
    // Drop it a little behind the stern rather than right under the boat.
    mesh.position.set(x - Math.sin(h) * 2, 0.12, z - Math.cos(h) * 2)
    mesh.rotation.y = h
    this.scene.add(mesh)
    this.wakes.push({mesh, t: 0})
  }

  // Fades and slightly spreads each active wake puff, removing it once its
  // duration is up.
  updateWakes() {
    for (let i = this.wakes.length - 1; i >= 0; i--) {
      const w = this.wakes[i]
      w.t += 0.016
      if (w.t >= WAKE_DURATION) {
        this.scene.remove(w.mesh)
        this.wakes.splice(i, 1)
        continue
      }
      const p = w.t / WAKE_DURATION
      w.mesh.material.opacity = 0.5 * (1 - p)
      w.mesh.scale.setScalar(1 + p * 0.6)
    }
  }

  // Other boats treated as obstacles for the local boat's own collision
  // check — mirrors the live-vs-anchored split in syncOtherBoats so both
  // moving sailors and boats bobbing at their island block the way.
  boatObstacles() {
    const list = []
    const liveIds = new Set()
    for (const [id, p] of this.net.remote) {
      if (id === this.sailorId) continue
      liveIds.add(id)
      list.push({x: p.x, z: p.z, radius: BOAT_RADIUS})
    }
    for (const s of this.net.roster) {
      if (s.id === this.sailorId || liveIds.has(s.id)) continue
      const isl = this.islandsByPath.get(s.path)
      if (isl) list.push({x: isl.x + 10, z: isl.z + 10, radius: BOAT_RADIUS})
    }
    return list
  }

  // Snapshot of everyone's position for the sidebar minimap: live sailors
  // from net.remote plus anchored readers bobbing at their island — the same
  // two groups syncOtherBoats() draws in the 3D scene.
  publishTick() {
    const boats = []
    const liveIds = new Set()
    for (const [id, p] of this.net.remote) {
      if (id === this.sailorId) continue
      liveIds.add(id)
      boats.push({id, x: p.x, z: p.z})
    }
    for (const s of this.net.roster) {
      if (s.id === this.sailorId || liveIds.has(s.id)) continue
      const isl = this.islandsByPath.get(s.path)
      if (isl) boats.push({id: s.id, x: isl.x + 10, z: isl.z + 10})
    }
    seaBus.dispatchEvent(
      new CustomEvent("sea:tick", {
        detail: {self: {x: this.pos.x, z: this.pos.z, h: this.pos.h}, boats, islands: this.islands}
      })
    )
  }

  flagFor(id) {
    const s = this.net.roster.find((r) => r.id === id)
    return s ? s.flag : "🏳️"
  }

  // The wave/emote gesture: local feedback (sprite + sound) plus a network
  // broadcast so other sailors see/hear it too. Cooldown-gated so holding
  // or mashing the key doesn't spam either.
  tryEmote() {
    if (this.emoteCooldown > 0) return
    this.emoteCooldown = EMOTE_COOLDOWN
    this.spawnEmote(this.selfBoat)
    this.audio.wave()
    this.net.sendEmote()
  }

  spawnEmote(boatGroup) {
    const sprite = emoteSprite("👋")
    sprite.position.set(0, 6, 0)
    boatGroup.add(sprite)
    this.emotes.push({sprite, boatGroup, t: 0})
  }

  // Rises and fades each active wave sprite, removing it once its duration
  // is up — run every frame regardless of whether *this* sailor just waved,
  // since remote waves land in the same queue via `net.onEmote`.
  updateEmotes() {
    for (let i = this.emotes.length - 1; i >= 0; i--) {
      const e = this.emotes[i]
      e.t += 0.016
      if (e.t >= EMOTE_DURATION) {
        e.boatGroup.remove(e.sprite)
        this.emotes.splice(i, 1)
        continue
      }
      const p = e.t / EMOTE_DURATION
      e.sprite.position.y = 6 + p * 2.5
      e.sprite.material.opacity = 1 - p
    }
  }

  // Prompts for up to BOTTLE_MAX_LENGTH characters and, if given anything
  // non-blank, drops it at the current position. A blocking native prompt
  // is a deliberate simplification over a custom text-input overlay — it's
  // a rare, deliberate action (unlike steering), and handles cancel/empty
  // for free.
  tryDropBottle() {
    const text = window.prompt(`Drop a message in a bottle (max ${BOTTLE_MAX_LENGTH} chars):`, "")
    if (text == null) return
    const trimmed = text.trim().slice(0, BOTTLE_MAX_LENGTH)
    if (!trimmed) return
    this.net.dropBottle(round(this.pos.x), round(this.pos.z), trimmed)
  }

  spawnBottle(bottle) {
    if (this.bottleMeshes.has(bottle.id)) return // already have it (e.g. duplicate join snapshot)
    const sprite = bottleSprite()
    sprite.position.set(bottle.x, 1.5, bottle.z)
    this.scene.add(sprite)
    this.bottleMeshes.set(bottle.id, {sprite, bottle})
  }

  despawnBottle(id) {
    const entry = this.bottleMeshes.get(id)
    if (!entry) return
    this.scene.remove(entry.sprite)
    this.bottleMeshes.delete(id)
  }

  // Gentle per-bottle bob, phase-offset by id so a cluster of bottles
  // doesn't move in lockstep.
  updateBottles() {
    for (const {sprite, bottle} of this.bottleMeshes.values()) {
      sprite.position.y = 1.5 + Math.sin(this.t * 1.2 + hash(String(bottle.id))) * 0.3
    }
  }

  // Auto-reveals the nearest bottle's text once you're close enough to read
  // it — no key needed, same "just approach it" treatment updateBanner()
  // gives an island's title.
  updateBottleBanner() {
    const bottles = Array.from(this.bottleMeshes.values()).map((e) => e.bottle)
    const near = nearestBottle(this.pos.x, this.pos.z, bottles)
    if (!near) {
      this.bottleBanner.style.opacity = "0"
      return
    }

    const p = this.scene.project(near.bottle.x, 3, near.bottle.z)
    if (!p.visible) {
      this.bottleBanner.style.opacity = "0"
      return
    }

    this.bottleBanner.textContent = `${near.bottle.flag} "${near.bottle.text}"`
    this.bottleBanner.style.left = `${p.x}px`
    this.bottleBanner.style.top = `${p.y}px`
    this.bottleBanner.style.opacity = "1"
  }

  // Floats the label above the actual island in the scene (not fixed to the
  // top of the screen) by projecting its 3D position to screen pixels each
  // frame, so it tracks the island as the chase cam moves.
  updateBanner() {
    const near = nearestIsland(this.pos.x, this.pos.z, this.islands)
    if (!near || near.distance > 50) {
      this.banner.style.opacity = "0"
      return
    }

    const island = near.island
    const topY = (island.height ?? 9) + 5
    const p = this.scene.project(island.x, topY, island.z)
    if (!p.visible) {
      this.banner.style.opacity = "0"
      return
    }

    const title = island.trending ? `🔥 ${island.title}` : island.title
    this.banner.textContent = isCloseEnoughToDock(island, near.distance)
      ? `${title} — press Space to dock`
      : title
    this.banner.style.left = `${p.x}px`
    this.banner.style.top = `${p.y}px`
    this.banner.style.opacity = "1"
  }

  // One arrival/departure line at a time, queued so a burst of joins/leaves
  // doesn't overwrite itself mid-fade.
  queueToast(text) {
    this.toastQueue.push(text)
    if (!this.toastTimer) this.showNextToast()
  }

  showNextToast() {
    const text = this.toastQueue.shift()
    if (!text) {
      this.toastTimer = null
      return
    }
    this.toast.textContent = text
    this.toast.style.opacity = "1"
    this.toastTimer = setTimeout(() => {
      this.toast.style.opacity = "0"
      this.toastTimer = setTimeout(() => this.showNextToast(), 300)
    }, 2500)
  }

  // Floats/hides the mute button's icon to match the audio module's actual
  // state (which can change out from under a click — e.g. the stored-
  // preference auto-resume on first keypress).
  refreshMuteBtn() {
    this.muteBtn.textContent = this.audio.muted ? "🔇" : "🔊"
    this.muteBtn.setAttribute("aria-label", this.audio.muted ? "Unmute sea sounds" : "Mute sea sounds")
  }

  // Applies a new boat choice: persists it, swaps the rigged hull (see
  // scene.js's setBoatType, which keeps the current hull color/flag), shows
  // or hides the ascend/descend touch buttons, and refreshes the hint text
  // and the switcher's own selection highlight. Selecting the seaplane also
  // teaches its takeoff/landing controls; switching *away* from it while
  // airborne lands it immediately (updateFlight's own safety net would
  // catch this too, but doing it here avoids one frame of a non-seaplane
  // hull hanging in mid-air).
  selectBoatType(type) {
    this.boatType = type
    localStorage.setItem(CUSTOM_BOAT_KEY, type.id)
    this.scene.setBoatType(this.selfBoat, type)
    this.controls.setFlightControlsVisible(type.canFly)
    this.updateHint()
    if (type.canFly) {
      this.queueToast("✈️ Get up to speed, then hold 🛫 to take off — 🛬 to land")
    } else if (this.altitude > 0) {
      this.altitude = 0
    }
    for (const [id, btn] of this.boatSwatchButtons) {
      btn.classList.toggle("is-selected", id === type.id)
    }
  }

  // Base steering hint, plus the flight controls only while a canFly boat
  // (the seaplane) is selected.
  updateHint() {
    const base = "Arrows / WASD to sail · Space to dock · E to wave · B for a bottle"
    this.hint.textContent = this.boatType.canFly ? `${base} · F/C to fly` : base
  }

  // Small hidden-by-default popover: a swatch per PALETTE color, a swatch
  // per FLAG_EMOJI option, and a text pill per BOAT_TYPES entry, all applied
  // immediately and persisted to localStorage. See the
  // customColor/customFlag/boatType comment above for why this only affects
  // this sailor's own view.
  buildCustomizePanel() {
    const panel = document.createElement("div")
    panel.className = "sea-customize-panel"
    panel.style.display = "none"

    const swatches = document.createElement("div")
    swatches.className = "sea-swatches"
    for (const hex of PALETTE) {
      const css = `#${hex.toString(16).padStart(6, "0")}`
      const swatch = document.createElement("button")
      swatch.type = "button"
      swatch.className = "sea-swatch"
      swatch.style.background = css
      swatch.setAttribute("aria-label", `Set hull color ${css}`)
      swatch.addEventListener("click", () => {
        this.customColor = css
        localStorage.setItem(CUSTOM_COLOR_KEY, css)
        this.scene.setHullColor(this.selfBoat, css)
      })
      swatches.appendChild(swatch)
    }
    panel.appendChild(swatches)

    const flags = document.createElement("div")
    flags.className = "sea-swatches"
    for (const emoji of FLAG_EMOJI) {
      const btn = document.createElement("button")
      btn.type = "button"
      btn.className = "sea-flag-swatch"
      btn.textContent = emoji
      btn.setAttribute("aria-label", `Set sail flag ${emoji}`)
      btn.addEventListener("click", () => {
        this.customFlag = emoji
        localStorage.setItem(CUSTOM_FLAG_KEY, emoji)
        this.scene.setSailTexture(this.selfBoat, flagTexture(emoji))
      })
      flags.appendChild(btn)
    }
    panel.appendChild(flags)

    const boats = document.createElement("div")
    boats.className = "sea-boat-swatches"
    this.boatSwatchButtons = new Map() // type.id -> button, so selectBoatType can update the highlight
    for (const type of BOAT_TYPES) {
      const btn = document.createElement("button")
      btn.type = "button"
      btn.className = "sea-boat-swatch"
      if (type.id === this.boatType.id) btn.classList.add("is-selected")
      btn.textContent = type.label
      btn.setAttribute("aria-label", `Switch to the ${type.label}`)
      btn.addEventListener("click", () => this.selectBoatType(type))
      this.boatSwatchButtons.set(type.id, btn)
      boats.appendChild(btn)
    }
    panel.appendChild(boats)

    return panel
  }

  dockTo(island) {
    // Leaving the sea to read a post. Mark that a sea session is paused (and
    // save where the boat was) so the destination page can offer a banner
    // back to the boat, at the same spot.
    sessionStorage.seaActive = "1"
    sessionStorage.removeItem("seaBannerDismissed")
    savePos(this.pos)
    this.audio.dockChime()
    // A brief delay so the chime actually gets to start before the page
    // unload cuts audio off — imperceptible as navigation latency.
    setTimeout(() => {
      window.location.href = island.path
    }, DOCK_CHIME_DELAY)
  }

  destroy() {
    this.running = false
    savePos(this.pos)
    this.controls.destroy()
    this.net.destroy()
    this.audio.destroy()
    this.scene.dispose()
    seaBus.removeEventListener("sea:navigate", this.onNavigate)
    clearTimeout(this._biteMsgTimer)
    clearTimeout(this.toastTimer)
    clearInterval(this.timeOfDayTimer)
    if (this.banner.parentNode) this.banner.remove()
    if (this.hint.parentNode) this.hint.remove()
    if (this.biteMsg.parentNode) this.biteMsg.remove()
    if (this.toast.parentNode) this.toast.remove()
    if (this.muteBtn.parentNode) this.muteBtn.remove()
    if (this.bottleBanner.parentNode) this.bottleBanner.remove()
    if (this.customizeBtn.parentNode) this.customizeBtn.remove()
    if (this.customizePanel.parentNode) this.customizePanel.remove()
  }
}

function round(n) {
  return Math.round(n * 100) / 100
}

function hash(s) {
  let h = 0
  for (let i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) % 6283
  return h / 1000
}

function savePos(pos) {
  sessionStorage.seaPos = JSON.stringify(pos)
}

function loadPos() {
  try {
    const raw = sessionStorage.seaPos
    if (!raw) return null
    const p = JSON.parse(raw)
    if (typeof p.x === "number" && typeof p.z === "number" && typeof p.h === "number") return p
  } catch (_) {
    // ignore malformed/stale data
  }
  return null
}
