import {SeaScene, flagTexture, emoteSprite, bottleSprite, wakeSegment} from "./scene.js"
import {createControls} from "./controls.js"
import {SeaNet} from "./net.js"
import {SeaAudio} from "./audio.js"
import {
  nearestDockable,
  nearestIsland,
  nearestBottle,
  isCloseEnoughToDock,
  resolveCollision,
  makeSharks,
  stepShark,
  sharkBreach,
  nearestBitingShark,
  regattaBuoys,
  isAtBuoy,
  easternHour,
  dayFactor
} from "./world.js"
import {seaBus} from "./bus.js"

const MAX_SPEED = 0.6
const ACCEL = 0.05
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
const REGATTA_BEST_KEY = "seaRegattaBest"
const TIME_OF_DAY_REFRESH_MS = 60_000 // sky doesn't need per-frame updates -- just re-check each minute
const WAKE_SPAWN_DISTANCE = 2.5 // a boat drops one wake puff per this many units traveled
const WAKE_DURATION = 1.6 // seconds a puff takes to fully fade
const MAX_WAKES = 120 // hard cap so a crowded sea can't run away with the segment count
const BUOY_RESTING_SCALE = 3.2
const BUOY_TARGET_SCALE = 4.6 // bigger than resting, marks the current target

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
    this.selfBoat = this.scene.makeBoat(flagTexture("🏴"), true, sailorId)

    // Regatta: a fixed ring of buoys around the harbor, sailed in order.
    // Buoy 0 starts the clock; the last one stops it and reports a time.
    this.buoys = regattaBuoys(harbor)
    this.buoyMeshes = this.buoys.map((b) => {
      const sprite = emoteSprite("🚩")
      sprite.scale.set(BUOY_RESTING_SCALE, BUOY_RESTING_SCALE, 1)
      sprite.position.set(b.x, 3, b.z)
      this.scene.add(sprite)
      return sprite
    })
    this.regattaNext = 0 // index of the next buoy that must be hit
    this.regattaStart = null // this.t at buoy 0, or null when no run is active
    this.regattaBest = parseFloat(localStorage.getItem(REGATTA_BEST_KEY)) || null

    this.regattaHud = document.createElement("div")
    this.regattaHud.className = "sea-regatta"
    el.appendChild(this.regattaHud)

    this.controls = createControls(el)
    this.net = new SeaNet(sailorId)
    this.readerBoats = new Map() // id -> {group}
    this.remoteBoats = new Map() // id -> {group}

    // Sharks are ambient and purely local (see world.js) — not networked, so
    // every visitor patrols their own and a bite only affects their own boat.
    this.sharks = makeSharks(SHARK_COUNT, SHARK_BOUNDS)
    this.sharkMeshes = this.sharks.map(() => this.scene.addShark())
    this.biteCooldown = 0

    this.banner = document.createElement("div")
    this.banner.className = "sea-banner"
    el.appendChild(this.banner)

    this.hint = document.createElement("div")
    this.hint.className = "sea-hint"
    this.hint.textContent = "Arrows / WASD to sail · Space to dock · E to wave · B for a bottle"
    el.appendChild(this.hint)

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
    this.net.onRegattaFinish = (seconds) =>
      this.queueToast(`🏁 a sailor finished the regatta in ${seconds.toFixed(1)}s`)

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

    // Ease speed toward the throttle target, decaying with friction when the
    // throttle is released — so letting go coasts to a stop instead of
    // snapping, and tapping briefly doesn't leave the boat drifting forever.
    const target = input.throttle * MAX_SPEED
    if (target !== 0) {
      this.speed += (target - this.speed) * ACCEL
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
    const land = resolveCollision(nextX, nextZ, this.islands)
    const boats = resolveCollision(land.x, land.z, this.boatObstacles(), BOAT_COLLISION_MARGIN)
    const colliding = land.hit || boats.hit
    if (colliding) this.speed *= CRASH_BOUNCE
    // Edge-triggered so holding the throttle into an island plays one splash
    // on impact, not one every frame for as long as contact continues.
    if (colliding && !this.wasColliding) this.audio.splash()
    this.wasColliding = colliding
    this.pos.x = boats.x
    this.pos.z = boats.z

    this.selfBoat.position.set(this.pos.x, 0, this.pos.z)
    this.selfBoat.rotation.y = this.pos.h
    this.maybeSpawnWake(this.sailorId, this.pos.x, this.pos.z, this.pos.h)

    this.stepSharks()

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

    this.updateRegatta()
    this.updateWakes()

    this.scene.animateWater(this.t)
    this.scene.chase(this.pos, this.pos.h)
    this.scene.render()
    requestAnimationFrame(this.loop)
  }

  // Advances every shark's patrol/breach state and its rendered mesh, then
  // — once any post-bite invulnerability has worn off — knocks the boat back
  // and flashes a warning if it strayed within range of one.
  stepSharks() {
    for (let i = 0; i < this.sharks.length; i++) {
      const shark = this.sharks[i]
      stepShark(shark, 0.016, SHARK_BOUNDS)
      this.scene.updateShark(this.sharkMeshes[i], shark, sharkBreach(shark))
    }

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
      }
      b.position.set(p.x, 0, p.z)
      b.rotation.y = p.h
      this.maybeSpawnWake(id, p.x, p.z, p.h)
    }
    for (const [id, b] of this.remoteBoats) {
      if (!liveIds.has(id)) {
        this.scene.removeBoat(b)
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
      }
      const bob = Math.sin(this.t * 1.5 + hash(s.id)) * 0.4
      b.position.set(isl.x + 10, bob, isl.z + 10)
      b.rotation.y = hash(s.id)
    }
    for (const [id, b] of this.readerBoats) {
      if (!anchored.has(id)) {
        this.scene.removeBoat(b)
        this.readerBoats.delete(id)
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

  // Bobs every buoy, keeps the current target visually bigger than the
  // rest, and advances the regatta on a hit: buoy 0 starts the clock, the
  // last buoy stops it, reports the time (local + broadcast), and resets
  // for another lap.
  updateRegatta() {
    for (let i = 0; i < this.buoyMeshes.length; i++) {
      const sprite = this.buoyMeshes[i]
      const isTarget = i === this.regattaNext
      const scale = isTarget ? BUOY_TARGET_SCALE : BUOY_RESTING_SCALE
      sprite.scale.set(scale, scale, 1)
      sprite.position.y = 3 + Math.sin(this.t * 1.3 + i) * 0.4
    }

    const target = this.buoys[this.regattaNext]
    if (isAtBuoy(this.pos.x, this.pos.z, target)) {
      if (this.regattaNext === 0) this.regattaStart = this.t
      this.regattaNext += 1

      if (this.regattaNext >= this.buoys.length) {
        const elapsed = this.t - this.regattaStart
        this.regattaNext = 0
        this.regattaStart = null

        const improved = this.regattaBest === null || elapsed < this.regattaBest
        if (improved) {
          this.regattaBest = elapsed
          localStorage.setItem(REGATTA_BEST_KEY, String(elapsed))
        }

        this.audio.finishFanfare()
        this.queueToast(
          improved
            ? `🏁 Regatta finished in ${elapsed.toFixed(1)}s — new best!`
            : `🏁 Regatta finished in ${elapsed.toFixed(1)}s`
        )
        this.net.sendRegattaFinish(elapsed)
      }
    }

    this.updateRegattaHud()
  }

  updateRegattaHud() {
    if (this.regattaStart !== null) {
      const elapsed = this.t - this.regattaStart
      const best = this.regattaBest !== null ? ` · best ${this.regattaBest.toFixed(1)}s` : ""
      this.regattaHud.textContent =
        `Buoy ${this.regattaNext + 1}/${this.buoys.length} · ${elapsed.toFixed(1)}s${best}`
      this.regattaHud.style.opacity = "1"
    } else if (this.regattaBest !== null) {
      this.regattaHud.textContent = `Regatta best: ${this.regattaBest.toFixed(1)}s`
      this.regattaHud.style.opacity = "1"
    } else {
      this.regattaHud.style.opacity = "0"
    }
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
    if (this.regattaHud.parentNode) this.regattaHud.remove()
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
