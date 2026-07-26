// Handles method=PUT/DELETE and CSRF submits for <.link> with a method attr.
import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import hljs from "highlight.js/lib/common"

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
  // names the theme you'd switch TO.
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
  }
}

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  hooks: Hooks,
  params: {_csrf_token: csrfToken, sailor_id: window.SAILOR_ID}
})

liveSocket.connect()
window.liveSocket = liveSocket

if (typeof CSS !== "undefined" && CSS.paintWorklet) {
  CSS.paintWorklet.addModule("/assets/js/paintWorklet.js")
}
