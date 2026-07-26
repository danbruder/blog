import {SeaScene, flagTexture} from "./scene.js"
import {createControls} from "./controls.js"
import {SeaNet} from "./net.js"
import {nearestDockable, nearestIsland} from "./world.js"

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

    // Local boat starts at the harbor.
    const harbor = this.islandsByPath.get("/") || {x: 0, z: 0}
    this.pos = {x: harbor.x, z: harbor.z + 20, h: Math.PI}
    this.selfBoat = this.scene.makeBoat(flagTexture("🏴"), true)

    this.controls = createControls(el)
    this.net = new SeaNet(sailorId)
    this.readerBoats = new Map() // id -> {group}
    this.remoteBoats = new Map() // id -> {group}

    this.banner = document.createElement("div")
    this.banner.className = "sea-banner"
    el.appendChild(this.banner)

    this.hint = document.createElement("div")
    this.hint.className = "sea-hint"
    this.hint.textContent = "Arrows / WASD to sail · Space to dock · toggle theme to leave"
    el.appendChild(this.hint)

    this.leaveBtn = document.createElement("button")
    this.leaveBtn.className = "sea-leave"
    this.leaveBtn.textContent = "Leave the sea"
    this.leaveBtn.addEventListener("click", () => {
      const prev = localStorage.themePrev || "light"
      localStorage.theme = prev
      document.documentElement.dataset.theme = prev
      document.dispatchEvent(new CustomEvent("theme:changed", {detail: {theme: prev}}))
    })
    el.appendChild(this.leaveBtn)

    this.t = 0
    this.running = true
    this.loop = this.loop.bind(this)
    requestAnimationFrame(this.loop)
  }

  loop() {
    if (!this.running) return
    this.t += 0.016

    const input = this.controls.read()
    // Integrate simple boat motion.
    this.pos.h -= input.turn * 0.03
    const speed = input.throttle * 0.6
    this.pos.x += Math.sin(this.pos.h) * speed
    this.pos.z += Math.cos(this.pos.h) * speed

    this.selfBoat.position.set(this.pos.x, 0, this.pos.z)
    this.selfBoat.rotation.y = this.pos.h

    this.net.sendPos(
      round(this.pos.x),
      round(this.pos.z),
      round(this.pos.h)
    )
    this.net.interpolate()

    this.syncOtherBoats()
    this.updateBanner()

    if (input.dock) {
      input.dock = false
      const isl = nearestDockable(this.pos.x, this.pos.z, this.islands)
      if (isl) this.dockTo(isl)
    }

    this.scene.animateWater(this.t)
    this.scene.chase(this.pos, this.pos.h)
    this.scene.render()
    requestAnimationFrame(this.loop)
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
        b = this.scene.makeBoat(flagTexture(this.flagFor(id)), false)
        this.remoteBoats.set(id, b)
      }
      b.position.set(p.x, 0, p.z)
      b.rotation.y = p.h
    }
    for (const [id, b] of this.remoteBoats) {
      if (!liveIds.has(id)) {
        this.scene.removeBoat(b)
        this.remoteBoats.delete(id)
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
        b = this.scene.makeBoat(flagTexture(s.flag), false)
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

  flagFor(id) {
    const s = this.net.roster.find((r) => r.id === id)
    return s ? s.flag : "🏳️"
  }

  updateBanner() {
    const near = nearestIsland(this.pos.x, this.pos.z, this.islands)
    if (near && near.distance < 40) {
      this.banner.textContent =
        near.distance < 9 ? `${near.island.title} — press Space to dock` : near.island.title
      this.banner.style.opacity = "1"
    } else {
      this.banner.style.opacity = "0"
    }
  }

  dockTo(island) {
    // Leaving Sea mode: restore the previous light/dark theme, then navigate.
    const prev = localStorage.themePrev || "light"
    localStorage.theme = prev
    document.documentElement.dataset.theme = prev
    document.dispatchEvent(new CustomEvent("theme:changed", {detail: {theme: prev}}))
    window.location.href = island.path
  }

  destroy() {
    this.running = false
    this.controls.destroy()
    this.net.destroy()
    this.scene.dispose()
    if (this.banner.parentNode) this.banner.remove()
    if (this.hint.parentNode) this.hint.remove()
    if (this.leaveBtn.parentNode) this.leaveBtn.remove()
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
