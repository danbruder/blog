// Handles method=PUT/DELETE and CSRF submits for <.link> with a method attr.
import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import hljs from "highlight.js/lib/common"
import {seaBus} from "./sea/bus.js"

// Syntax-highlight code blocks in rendered markdown. Earmark emits
// <pre><code class="elixir">…</code></pre>; highlight.js reads that class.
function highlightIn(el) {
  el.querySelectorAll("pre code").forEach((block) => {
    delete block.dataset.highlighted
    hljs.highlightElement(block)
  })
}

let Hooks = {
  Highlight: {
    mounted() { highlightIn(this.el) },
    updated() { highlightIn(this.el) }
  },
  // Light/dark theme toggle. Theme is a pure client concern: flip
  // dataset.theme on <html> and persist to localStorage. The label always
  // names the theme you'd switch TO. The 3D sea lives at its own route
  // (/sea), not a theme.
  ThemeToggle: {
    mounted() {
      const sync = () => {
        this.el.textContent =
          document.documentElement.dataset.theme === "dark" ? "Light" : "Dark"
      }
      sync()
      this.el.addEventListener("click", () => {
        const next =
          document.documentElement.dataset.theme === "dark" ? "light" : "dark"
        document.documentElement.dataset.theme = next
        localStorage.theme = next
        sync()
      })
    }
  },
  // Boots the 3D sea. Lives on the /sea route's own root element, so it
  // mounts/unmounts on LiveView's normal navigation lifecycle instead of a
  // separate toggle button racing a theme-change event. The heavy three.js
  // bundle is only imported once this page actually mounts.
  SeaMode: {
    mounted() {
      this.running = true
      Promise.all([import("/assets/js/sea/index.js"), fetch("/sea/islands.json")]).then(
        async ([mod, res]) => {
          if (!this.running) return // navigated away before the bundle loaded
          this.sea = mod
          const {islands} = await res.json()
          mod.startSea({el: this.el, sailorId: window.SAILOR_ID, islands})
        }
      )
    },
    destroyed() {
      this.running = false
      if (this.sea) this.sea.stopSea()
      sessionStorage.removeItem("seaActive")
    }
  },
  // Sidebar minimap on the /sea page: draws islands + other sailors from
  // "tick" events published by the sea scene, and lets a click steer the
  // boat there via a "navigate" event. Statically bundled (no three.js), so
  // it renders immediately even while the 3D scene is still loading.
  SeaMinimap: {
    mounted() {
      this.ctx = this.el.getContext("2d")
      this.w = this.el.width
      this.h = this.el.height
      this.state = null

      this.onTick = (e) => {
        this.state = e.detail
        this.draw()
      }
      seaBus.addEventListener("sea:tick", this.onTick)

      this.el.addEventListener("click", (e) => {
        if (!this.state) return
        const rect = this.el.getBoundingClientRect()
        const px = ((e.clientX - rect.left) / rect.width) * this.w
        const py = ((e.clientY - rect.top) / rect.height) * this.h
        const {x, z} = this.toWorld(px, py)
        seaBus.dispatchEvent(new CustomEvent("sea:navigate", {detail: {x, z}}))
      })
    },
    // World bounds padded a bit beyond the islands so boats near the edge
    // aren't drawn right on the frame.
    bounds() {
      const pts = [{x: 0, z: 0}, ...this.state.islands, ...this.state.boats, this.state.self]
      const xs = pts.map((p) => p.x)
      const zs = pts.map((p) => p.z)
      const pad = 20
      return {
        minX: Math.min(...xs) - pad,
        maxX: Math.max(...xs) + pad,
        minZ: Math.min(...zs) - pad,
        maxZ: Math.max(...zs) + pad
      }
    },
    toScreen(x, z, b) {
      return {
        px: ((x - b.minX) / (b.maxX - b.minX)) * this.w,
        py: ((z - b.minZ) / (b.maxZ - b.minZ)) * this.h
      }
    },
    toWorld(px, py) {
      const b = this.bounds()
      return {
        x: b.minX + (px / this.w) * (b.maxX - b.minX),
        z: b.minZ + (py / this.h) * (b.maxZ - b.minZ)
      }
    },
    // Read live theme tokens rather than hardcoding hex — the minimap must
    // stay legible whichever of light/dark is active, and canvas fillStyle
    // accepts the same oklch() values the CSS custom properties use.
    themeColor(name) {
      return getComputedStyle(document.documentElement).getPropertyValue(name).trim()
    },
    draw() {
      const {ctx, w, h, state} = this
      ctx.clearRect(0, 0, w, h)
      const b = this.bounds()

      const inkColor = this.themeColor("--color-ink-3")
      const limeColor = this.themeColor("--color-lime")
      for (const isl of state.islands) {
        const {px, py} = this.toScreen(isl.x, isl.z, b)
        // Trending islands stand out here too — bigger, lime dot instead of
        // the muted default, matching the beacon in the 3D scene.
        ctx.fillStyle = isl.trending ? limeColor : inkColor
        ctx.beginPath()
        ctx.arc(px, py, isl.trending ? 4 : 2.5, 0, Math.PI * 2)
        ctx.fill()
      }

      ctx.fillStyle = this.themeColor("--color-signal")
      for (const boat of state.boats) {
        const {px, py} = this.toScreen(boat.x, boat.z, b)
        ctx.beginPath()
        ctx.arc(px, py, 3.5, 0, Math.PI * 2)
        ctx.fill()
      }

      const self = this.toScreen(state.self.x, state.self.z, b)
      ctx.fillStyle = this.themeColor("--color-lime")
      ctx.strokeStyle = this.themeColor("--color-ink")
      ctx.lineWidth = 1.5
      ctx.beginPath()
      ctx.arc(self.px, self.py, 4.5, 0, Math.PI * 2)
      ctx.fill()
      ctx.stroke()
    },
    destroyed() {
      seaBus.removeEventListener("sea:tick", this.onTick)
    }
  },
  // Top-of-page banner offering a way back into the sea, shown on every page
  // except /sea itself once a sea session has been paused (docked at a
  // post). Dismissing it hides it for the rest of this paused session; it
  // re-appears the next time the sailor docks somewhere new.
  SeaBanner: {
    sync() {
      const show =
        sessionStorage.seaActive === "1" && sessionStorage.seaBannerDismissed !== "1"
      this.el.style.display = show ? "flex" : "none"
    },
    mounted() {
      this.sync()
      this.el.querySelector("[data-dismiss]").addEventListener("click", () => {
        sessionStorage.seaBannerDismissed = "1"
        this.sync()
      })
    }
  },
  // LiveView has no native phx-dblclick; bridge a dblclick into a server event.
  DblClickEdit: {
    mounted() {
      this.el.addEventListener("dblclick", () => this.pushEvent("edit_name", {}))
    }
  },
  // Toggles the mobile nav open/closed on small screens, and closes it again
  // once the visitor taps a link (LiveView keeps the layout DOM across
  // navigation, so the menu would otherwise stay open over the new page).
  MobileNav: {
    mounted() {
      const nav = document.getElementById("mobile-nav")
      this.el.addEventListener("click", () => {
        if (nav) nav.classList.toggle("hidden")
      })
      if (nav) {
        nav.addEventListener("click", (e) => {
          if (e.target.closest("a")) nav.classList.add("hidden")
        })
      }
    }
  },
  // Renders the shared sand grid onto a <canvas> and captures paint strokes.
  // The server pushes the full grid as base64 on the "grid" event; this hook
  // decodes it and repaints. Pointer drags send `paint` events back.
  SandCanvas: {
    mounted() {
      this.w = parseInt(this.el.dataset.w, 10)
      this.h = parseInt(this.el.dataset.h, 10)
      this.el.width = this.w
      this.el.height = this.h
      this.ctx = this.el.getContext("2d")
      this.colors = {
        0: "#18181b", // empty
        1: "#e6c07b", // sand
        2: "#38bdf8", // water
        3: "#71717a", // stone
        4: "#92640f", // wood
        5: "#f97316"  // fire
      }
      this.selected = () => parseInt(this.el.dataset.selected || "1", 10)
      this.painting = false

      this.handleEvent("grid", ({grid}) => this.draw(grid))

      const paintAt = (e) => {
        const rect = this.el.getBoundingClientRect()
        const px = e.clientX - rect.left
        const py = e.clientY - rect.top
        const gx = Math.floor((px / rect.width) * this.w)
        const gy = Math.floor((py / rect.height) * this.h)
        const r = 2
        const cells = []
        for (let dy = -r; dy <= r; dy++) {
          for (let dx = -r; dx <= r; dx++) {
            const x = gx + dx, y = gy + dy
            if (x >= 0 && x < this.w && y >= 0 && y < this.h && dx*dx + dy*dy <= r*r) {
              cells.push(y * this.w + x)
            }
          }
        }
        if (cells.length) this.pushEvent("paint", {cells, element: this.selected()})
      }

      this.el.addEventListener("pointerdown", (e) => { this.painting = true; paintAt(e) })
      this.el.addEventListener("pointermove", (e) => { if (this.painting) paintAt(e) })
      window.addEventListener("pointerup", () => { this.painting = false })
      // Stop touch-drag from scrolling/zooming while painting.
      this.el.style.touchAction = "none"
    },

    draw(b64) {
      const bin = atob(b64)
      const img = this.ctx.createImageData(this.w, this.h)
      for (let i = 0; i < bin.length; i++) {
        const hex = this.colors[bin.charCodeAt(i)] || this.colors[0]
        const r = parseInt(hex.slice(1, 3), 16)
        const g = parseInt(hex.slice(3, 5), 16)
        const bl = parseInt(hex.slice(5, 7), 16)
        const o = i * 4
        img.data[o] = r; img.data[o+1] = g; img.data[o+2] = bl; img.data[o+3] = 255
      }
      this.ctx.putImageData(img, 0, 0)
    }
  },
  // The "hold for 3s to give kudos" button under each post. Hold state and
  // the completion fetch are entirely client-driven (phx-update="ignore" --
  // see BlogWeb.PostLive.Show) so the confetti and fill never wait on a
  // server round trip; the server only needs to know once, when the hold
  // actually completes.
  Kudos: {
    HOLD_MS: 3000,
    // Scale reached at the end of the hold -- big enough that "getting
    // bigger" reads clearly rather than needing a side-by-side to notice.
    HOLD_SCALE: 1.5,

    mounted() {
      this.button = this.el.querySelector("[data-kudos-button]")
      this.fill = this.el.querySelector("[data-kudos-fill]")
      this.countEl = this.el.querySelector("[data-kudos-count]")
      this.labelEl = this.el.querySelector("[data-kudos-label]")
      this.path = this.el.dataset.path
      this.given = this.el.dataset.given === "true"
      this.timer = null

      this.setFill(0, false)

      if (this.given) {
        this.markGiven()
      } else {
        this.button.addEventListener("pointerenter", () => this.startHold())
        this.button.addEventListener("pointerleave", () => this.cancelHold())
        // Prevent a click/tap alone (no hold) from doing anything odd.
        this.button.addEventListener("pointerdown", (e) => e.preventDefault())
      }
    },

    destroyed() {
      if (this.timer) clearTimeout(this.timer)
    },

    // fraction is 0..1 of the square to fill from the bottom up; animate
    // (ms, or false) controls whether the fill/color/icon transition
    // smoothly (holding/resetting) or jump instantly (initial paint,
    // already-given state). Fill and icon color move together so the
    // button has already reached its "given" look the instant it's full.
    setFill(fraction, animate) {
      const transition = animate
        ? `height ${animate}ms linear, color ${animate}ms ${fraction > 0 ? "ease-in" : "ease"}`
        : "none"
      this.fill.style.transition = transition
      this.fill.style.height = `${fraction * 100}%`
      this.button.style.transition = animate ? `${transition}, transform ${animate}ms ease` : "none"
      this.button.style.color = fraction > 0 ? "var(--on-lime)" : ""
    },

    startHold() {
      if (this.given || this.timer) return
      this.el.classList.add("is-holding")
      // Set the transition (via setFill) before the transform it covers,
      // so the button's very first hold picks it up rather than snapping.
      this.setFill(1, this.HOLD_MS)
      this.button.style.transform = `scale(${this.HOLD_SCALE})`
      this.timer = setTimeout(() => this.complete(), this.HOLD_MS)
    },

    cancelHold() {
      if (!this.timer) return
      clearTimeout(this.timer)
      this.timer = null
      this.el.classList.remove("is-holding")
      this.setFill(0, 250)
      this.button.style.transform = "scale(1)"
    },

    complete() {
      this.timer = null
      this.given = true
      this.markGiven()
      this.confetti()

      const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

      fetch("/kudos", {
        method: "POST",
        headers: {"Content-Type": "application/json", "x-csrf-token": csrfToken},
        body: JSON.stringify({path: this.path, session_id: window.SAILOR_ID})
      })
        .then((res) => res.json())
        .then((data) => {
          if (this.countEl && typeof data.kudos === "number") {
            this.countEl.textContent = data.kudos
          }
        })
        .catch(() => {}) // best-effort -- the hold already happened visually
    },

    markGiven() {
      this.el.classList.remove("is-holding")
      this.el.classList.add("is-given")
      this.button.style.transform = "scale(1)"
      this.setFill(1, false)
      if (this.labelEl) this.labelEl.textContent = "thanks!"
      this.button.disabled = true
    },

    confetti() {
      const colors = [
        "var(--color-lime)",
        "var(--color-signal)",
        "var(--color-ink)",
        "#f97316",
        "#e879f9"
      ]
      const field = document.createElement("div")
      field.className = "kudos-confetti-field"
      document.body.appendChild(field)

      for (let i = 0; i < 110; i++) {
        const piece = document.createElement("span")
        piece.className = "kudos-confetti-piece"
        piece.style.left = `${Math.random() * 100}vw`
        piece.style.background = colors[i % colors.length]
        piece.style.setProperty("--drift", `${(Math.random() - 0.5) * 160}px`)
        piece.style.setProperty("--spin", `${(Math.random() - 0.5) * 900}deg`)
        piece.style.animationDuration = `${1.8 + Math.random() * 1.4}s`
        piece.style.animationDelay = `${Math.random() * 0.35}s`
        field.appendChild(piece)
      }

      setTimeout(() => field.remove(), 3600)
    }
  }
}

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  hooks: Hooks,
  params: {_csrf_token: csrfToken, sailor_id: window.SAILOR_ID, referrer: document.referrer}
})

liveSocket.connect()
window.liveSocket = liveSocket

if (typeof CSS !== "undefined" && CSS.paintWorklet) {
  CSS.paintWorklet.addModule("/assets/js/paintWorklet.js")
}
