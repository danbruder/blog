import {Socket} from "phoenix"

// Owns the SeaChannel connection. Exposes the current roster (all visitors) and
// a map of live sailor positions (interpolated toward the latest broadcast).
export class SeaNet {
  constructor(sailorId) {
    this.sailorId = sailorId
    this.roster = [] // [{id, path, flag}]
    this.remote = new Map() // id -> {x, z, h, tx, tz, th}  (t* = target)
    this.onRoster = null
    this._lastSent = 0

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
      const cur = this.remote.get(id) || {x, z, h, tx: x, tz: z, th: h}
      cur.tx = x
      cur.tz = z
      cur.th = h
      this.remote.set(id, cur)
    })
    this.channel.on("gone", ({id}) => this.remote.delete(id))
    this.channel.join()
  }

  // Throttle outgoing positions to ~12 Hz.
  sendPos(x, z, h) {
    const now = performance.now()
    if (now - this._lastSent < 80) return
    this._lastSent = now
    this.channel.push("pos", {x, z, h})
  }

  // Ease live boats toward their latest target; call each frame.
  interpolate() {
    for (const p of this.remote.values()) {
      p.x += (p.tx - p.x) * 0.2
      p.z += (p.tz - p.z) * 0.2
      p.h += angleDelta(p.h, p.th) * 0.2
    }
  }

  destroy() {
    try { this.channel.leave() } catch (_) {}
    try { this.socket.disconnect() } catch (_) {}
  }
}

function angleDelta(a, b) {
  let d = b - a
  while (d > Math.PI) d -= 2 * Math.PI
  while (d < -Math.PI) d += 2 * Math.PI
  return d
}
