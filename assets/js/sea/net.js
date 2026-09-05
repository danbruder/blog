import {Socket} from "phoenix"

// Base outgoing position rate: ~12 Hz, plenty smooth for a chase-cam boat.
// See batterySendInterval() for when this backs off.
const BASE_SEND_INTERVAL_MS = 80
// On battery and below these thresholds, send less often — halves the
// radio/JS wake-ups for a sailor's position broadcast without anyone else's
// view visibly degrading (see interpolate(), which eases toward wherever a
// remote boat actually is over however long the last update took, rather
// than assuming a fixed cadence).
const LOW_BATTERY_SEND_INTERVAL_MS = 200 // <=20% and unplugged: ~5 Hz
const CRITICAL_BATTERY_SEND_INTERVAL_MS = 400 // <=10% and unplugged: ~2.5 Hz
// Bounds on a remote boat's measured update interval -- guards against a
// stale/huge gap (e.g. its very first update, or a dropped connection) making
// it crawl into position, and against near-zero gaps (network jitter) making
// it snap instead of ease.
const MIN_INTERP_MS = 60
const MAX_INTERP_MS = 1000

// Owns the SeaChannel connection. Exposes the current roster (all visitors) and
// a map of live sailor positions (interpolated toward the latest broadcast).
export class SeaNet {
  constructor(sailorId) {
    this.sailorId = sailorId
    this.roster = [] // [{id, path, flag}]
    // id -> {x, z, h} (current, interpolated), plus the two endpoints
    // interpolate() eases between: {px, pz, ph} where it started, {tx, tz,
    // th} where it's headed, `duration` how long that ease should take (the
    // gap since the previous update, so a slower sender still animates
    // smoothly instead of snapping) and `elapsed` how far into it we are.
    this.remote = new Map()
    this.onRoster = null
    this.onArrive = null // (flag) => void — another sailor joined Sea mode
    this.onDepart = null // (flag) => void — another sailor left Sea mode
    this.onEmote = null // (id) => void — another sailor waved
    this.bottles = new Map() // id -> {id, x, z, text, flag}
    this.onBottleDropped = null // (bottle) => void
    this.onBottleExpired = null // (id) => void
    this._lastSent = 0
    this._lastReceivedAt = new Map() // id -> performance.now() of its last "pos"
    this._sendIntervalMs = BASE_SEND_INTERVAL_MS
    this._battery = null // set once/if the Battery Status API resolves
    this._onBatteryChange = null

    const token = document
      .querySelector("meta[name='csrf-token']")
      .getAttribute("content")
    this.socket = new Socket("/socket", {params: {_csrf_token: token}})
    this.socket.connect()
    this.channel = this.socket.channel("sea:ocean", {sailor_id: sailorId})

    this.channel.on("roster", ({sailors}) => {
      this.roster = sailors
      if (this.onRoster) this.onRoster(sailors)
    })
    this.channel.on("pos", ({id, x, z, h}) => {
      if (id === this.sailorId) return
      const now = performance.now()
      const last = this._lastReceivedAt.get(id)
      this._lastReceivedAt.set(id, now)

      const cur = this.remote.get(id)
      if (!cur) {
        // First sighting: nothing to ease from, appear right where sent.
        this.remote.set(id, {x, z, h, px: x, pz: z, ph: h, tx: x, tz: z, th: h, duration: 0, elapsed: 0})
        return
      }
      cur.px = cur.x
      cur.pz = cur.z
      cur.ph = cur.h
      cur.tx = x
      cur.tz = z
      cur.th = h
      cur.duration = last ? clamp(now - last, MIN_INTERP_MS, MAX_INTERP_MS) : MIN_INTERP_MS
      cur.elapsed = 0
    })
    // The server already excludes the joining sailor from "arrived" via
    // broadcast_from!, but "gone" (sent via broadcast! from terminate/2, when
    // the leaving sailor's own socket is already closed) can't do the same —
    // guard here so a sailor never toasts their own arrival/departure.
    this.channel.on("arrived", ({id, flag}) => {
      if (id !== this.sailorId && this.onArrive) this.onArrive(flag)
    })
    this.channel.on("gone", ({id, flag}) => {
      this.remote.delete(id)
      this._lastReceivedAt.delete(id)
      if (id !== this.sailorId && this.onDepart) this.onDepart(flag)
    })
    this.channel.on("emote", ({id}) => {
      if (id !== this.sailorId && this.onEmote) this.onEmote(id)
    })
    // "bottles" (the initial snapshot on join) and "bottle_dropped" (each
    // subsequent one, including a bottle *this* sailor just dropped -- the
    // server relays it back to every member rather than excluding the
    // sender) both funnel through the same per-bottle callback.
    this.channel.on("bottles", ({bottles}) => {
      for (const b of bottles) this._addBottle(b)
    })
    this.channel.on("bottle_dropped", (bottle) => this._addBottle(bottle))
    this.channel.on("bottle_expired", ({id}) => {
      this.bottles.delete(id)
      if (this.onBottleExpired) this.onBottleExpired(id)
    })
    this.channel.join()

    this._initBatteryAdaptiveRate()
  }

  // Backs the outgoing position rate off while unplugged and low on battery
  // (see the *_SEND_INTERVAL_MS constants) — everyone else's view stays
  // smooth regardless since interpolate() eases over however long an update
  // actually took, not a fixed cadence. Best-effort: the Battery Status API
  // is Chromium-only and can also reject under a stricter permissions
  // policy, so this silently keeps the base rate wherever it isn't there.
  async _initBatteryAdaptiveRate() {
    if (typeof navigator.getBattery !== "function") return
    try {
      const battery = await navigator.getBattery()
      this._battery = battery
      this._onBatteryChange = () => {
        this._sendIntervalMs = batterySendInterval(battery.level, battery.charging)
      }
      this._onBatteryChange()
      battery.addEventListener("levelchange", this._onBatteryChange)
      battery.addEventListener("chargingchange", this._onBatteryChange)
    } catch (_) {
      // Blocked or unsupported in this browser/context -- stay at the base rate.
    }
  }

  // Throttle outgoing positions to _sendIntervalMs (adaptive, see above).
  sendPos(x, z, h) {
    const now = performance.now()
    if (now - this._lastSent < this._sendIntervalMs) return
    this._lastSent = now
    this.channel.push("pos", {x, z, h})
  }

  sendEmote() {
    this.channel.push("emote", {})
  }

  dropBottle(x, z, text) {
    this.channel.push("drop_bottle", {x, z, text})
  }

  _addBottle(bottle) {
    this.bottles.set(bottle.id, bottle)
    if (this.onBottleDropped) this.onBottleDropped(bottle)
  }

  // Eases every live boat from where its last update left it (px/pz/ph)
  // toward its latest target (tx/tz/th) over `duration` -- the gap between
  // its last two updates -- rather than a fixed per-frame damping factor, so
  // a sparser sender (see the battery back-off above) still reads as
  // continuous motion instead of a snap-then-pause. Call each frame with the
  // fixed ~16ms step the rest of this file's simulation uses.
  interpolate(dtMs = 16) {
    for (const p of this.remote.values()) {
      if (p.elapsed >= p.duration) continue
      p.elapsed = Math.min(p.duration, p.elapsed + dtMs)
      const frac = p.duration > 0 ? p.elapsed / p.duration : 1
      p.x = p.px + (p.tx - p.px) * frac
      p.z = p.pz + (p.tz - p.pz) * frac
      p.h = p.ph + angleDelta(p.ph, p.th) * frac
    }
  }

  destroy() {
    try { this.channel.leave() } catch (_) {}
    try { this.socket.disconnect() } catch (_) {}
    if (this._battery && this._onBatteryChange) {
      this._battery.removeEventListener("levelchange", this._onBatteryChange)
      this._battery.removeEventListener("chargingchange", this._onBatteryChange)
    }
  }
}

// <=10% and unplugged backs off the most; <=20% backs off some; charging
// (or a battery that never reports low) keeps the normal rate.
function batterySendInterval(level, charging) {
  if (charging) return BASE_SEND_INTERVAL_MS
  if (level <= 0.1) return CRITICAL_BATTERY_SEND_INTERVAL_MS
  if (level <= 0.2) return LOW_BATTERY_SEND_INTERVAL_MS
  return BASE_SEND_INTERVAL_MS
}

function clamp(n, min, max) {
  return Math.min(max, Math.max(min, n))
}

function angleDelta(a, b) {
  let d = b - a
  while (d > Math.PI) d -= 2 * Math.PI
  while (d < -Math.PI) d += 2 * Math.PI
  return d
}
