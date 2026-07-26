// Steering input for the local boat. `state.throttle` is 0..1 forward,
// `state.turn` is -1..1 (left/right), `state.dock` latches true when the dock
// key/button is pressed. Works with keyboard (arrows/WASD + space) and an
// on-screen touch joystick + Dock button injected into `overlay`.

export function createControls(overlay) {
  const state = {throttle: 0, turn: 0, dock: false}
  const keys = new Set()

  const onKey = (down) => (e) => {
    const k = e.key.toLowerCase()
    if (["arrowup", "arrowdown", "arrowleft", "arrowright", "w", "a", "s", "d", " "].includes(k)) {
      e.preventDefault()
    }
    if (down) keys.add(k)
    else keys.delete(k)
    if (down && (k === " ")) state.dock = true
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
    <button class="sea-dock" data-dock type="button">Dock</button>`
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
    state.turn = dx
    state.throttle = Math.max(0, -dy)
  }
  const resetTouch = () => {
    touchId = null
    nub.style.transform = "translate(0,0)"
    state.turn = 0
    state.throttle = 0
  }
  stick.addEventListener("touchstart", (e) => {
    touchId = e.changedTouches[0].identifier
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

  // Fold keyboard into the state each time it's read.
  const read = () => {
    let turn = 0
    let throttle = 0
    if (keys.has("arrowleft") || keys.has("a")) turn -= 1
    if (keys.has("arrowright") || keys.has("d")) turn += 1
    if (keys.has("arrowup") || keys.has("w")) throttle += 1
    if (keys.has("arrowdown") || keys.has("s")) throttle -= 0.4
    // Keyboard overrides only when actually pressed; else keep touch values.
    if (turn !== 0) state.turn = turn
    if (throttle !== 0) state.throttle = Math.max(0, throttle)
    return state
  }

  const destroy = () => {
    window.removeEventListener("keydown", kd)
    window.removeEventListener("keyup", ku)
    if (pad.parentNode) pad.parentNode.removeChild(pad)
  }

  return {read, state, destroy}
}
