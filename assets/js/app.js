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
  }
}

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  hooks: Hooks,
  params: {_csrf_token: csrfToken}
})

liveSocket.connect()
window.liveSocket = liveSocket

if (typeof CSS !== "undefined" && CSS.paintWorklet) {
  CSS.paintWorklet.addModule("/assets/js/paintWorklet.js")
}
