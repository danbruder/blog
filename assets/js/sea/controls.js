// Steering input for the local boat. `state.throttle` is 0..1 forward,
// `state.turn` is -1..1 (left/right), `state.dock` and `state.emote` latch
// true when their key/button is pressed. Works with keyboard (arrows/WASD +
// space + E) and an on-screen touch joystick + Dock/Wave buttons injected
// into `overlay`.

export function createControls(overlay) {
  const state = {throttle: 0, turn: 0, dock: false, emote: false}
  const keys = new Set()
  let touchActive = false
  let touchTurn = 0
  let touchThrottle = 0

  const onKey = (down) => (e) => {
    const k = e.key.toLowerCase()
    if (["arrowup", "arrowdown", "arrowleft", "arrowright", "w", "a", "s", "d", " ", "e"].includes(k)) {
      e.preventDefault()
    }
    if (down) keys.add(k)
    else keys.delete(k)
    if (down && (k === " ")) state.dock = true
    if (down && (k === "e")) state.emote = true
  }
  const kd = onKey(true)
  const ku = onKey(false)
  window.addEventListener("keydown", kd)
  window.addEventListener("keyup", ku)

  // Touch controls
  const pad = document.createElement("div")
  pad.className = "sea-touch"
  pad.innerHTML = `
    <div class="sea-stick" data-stick>
      <div class="sea-nub" data-nub></div>
    </div>
    <div class="sea-buttons">
      <button class="sea-wave-btn" data-wave type="button">👋</button>
      <button class="sea-dock" data-dock type="button">Dock</button>
    </div>`
  overlay.appendChild(pad)

  const stick = pad.querySelector("[data-stick]")
  const nub = pad.querySelector("[data-nub]")
  let touchId = null

  const setFromTouch = (t) => {
    const r = stick.getBoundingClientRect()
    const cx = r.left + r.width / 2
    const cy = r.top + r.height / 2
    let dx = (t.clientX - cx) / (r.width / 2)
    let dy = (t.clientY - cy) / (r.height / 2)
    dx = Math.max(-1, Math.min(1, dx))
    dy = Math.max(-1, Math.min(1, dy))
    nub.style.transform = `translate(${dx * 34}px, ${dy * 34}px)`
    touchTurn = dx
    // Pulling the stick down reverses (negative throttle), pushing up goes forward.
    touchThrottle = -dy
  }
  const resetTouch = () => {
    touchId = null
    touchActive = false
    nub.style.transform = "translate(0,0)"
    touchTurn = 0
    touchThrottle = 0
  }
  stick.addEventListener("touchstart", (e) => {
    touchId = e.changedTouches[0].identifier
    touchActive = true
    setFromTouch(e.changedTouches[0])
    e.preventDefault()
  }, {passive: false})
  stick.addEventListener("touchmove", (e) => {
    for (const t of e.changedTouches) if (t.identifier === touchId) setFromTouch(t)
    e.preventDefault()
  }, {passive: false})
  stick.addEventListener("touchend", resetTouch)
  stick.addEventListener("touchcancel", resetTouch)
  pad.querySelector("[data-dock]").addEventListener("click", () => (state.dock = true))
  pad.querySelector("[data-wave]").addEventListener("click", () => (state.emote = true))

  // Recompute turn/throttle from whichever input source is active every call,
  // so releasing a key (or the touch stick) actually zeroes it out instead of
  // sticking at its last value.
  const read = () => {
    if (touchActive) {
      state.turn = touchTurn
      state.throttle = touchThrottle
      return state
    }

    let turn = 0
    let throttle = 0
    if (keys.has("arrowleft") || keys.has("a")) turn -= 1
    if (keys.has("arrowright") || keys.has("d")) turn += 1
    if (keys.has("arrowup") || keys.has("w")) throttle += 1
    if (keys.has("arrowdown") || keys.has("s")) throttle -= 0.6
    state.turn = turn
    state.throttle = throttle
    return state
  }

  const destroy = () => {
    window.removeEventListener("keydown", kd)
    window.removeEventListener("keyup", ku)
    if (pad.parentNode) pad.parentNode.removeChild(pad)
  }

  return {read, state, destroy}
}
