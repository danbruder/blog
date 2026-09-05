// Steering input for the local boat. `state.throttle` is 0..1 forward,
// `state.turn` is -1..1 (left/right), `state.dock`/`state.emote`/`state.drop`
// latch true when their key/button is pressed. `state.ascend`/`state.descend`
// are held states (true only while the key/button is down), used only by a
// boat that can fly (see index.js's flight mechanic) -- harmless to read
// otherwise. Works with keyboard (arrows/WASD + space + E + B + F + C) and
// an on-screen touch joystick + Dock/Wave/Bottle/Ascend/Descend buttons
// injected into `overlay`.

export function createControls(overlay) {
  const state = {throttle: 0, turn: 0, dock: false, emote: false, drop: false, ascend: false, descend: false}
  const keys = new Set()
  let touchActive = false
  let touchTurn = 0
  let touchThrottle = 0
  let touchAscend = false
  let touchDescend = false

  const onKey = (down) => (e) => {
    const k = e.key.toLowerCase()
    if (
      ["arrowup", "arrowdown", "arrowleft", "arrowright", "w", "a", "s", "d", " ", "e", "b", "f", "c"].includes(k)
    ) {
      e.preventDefault()
    }
    if (down) keys.add(k)
    else keys.delete(k)
    if (down && (k === " ")) state.dock = true
    if (down && (k === "e")) state.emote = true
    if (down && (k === "b")) state.drop = true
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
      <button class="sea-wave-btn" data-bottle type="button">🍾</button>
      <button class="sea-dock" data-dock type="button">Dock</button>
    </div>
    <div class="sea-buttons sea-flight-buttons">
      <button class="sea-wave-btn" data-ascend type="button" aria-label="Ascend / take off">🛫</button>
      <button class="sea-wave-btn" data-descend type="button" aria-label="Descend / land">🛬</button>
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
  pad.querySelector("[data-bottle]").addEventListener("click", () => (state.drop = true))

  // Ascend/descend are held states, not one-shot clicks -- pointerdown/up
  // covers mouse and touch alike, unlike the stick's separate touch-only
  // handling above. Harmless to hold on a boat that can't fly (index.js's
  // flight logic no-ops); pointercancel/leave release it the same as up, so
  // dragging off the button doesn't leave it stuck ascending.
  const ascendBtn = pad.querySelector("[data-ascend]")
  const descendBtn = pad.querySelector("[data-descend]")
  ascendBtn.addEventListener("pointerdown", () => (touchAscend = true))
  descendBtn.addEventListener("pointerdown", () => (touchDescend = true))
  for (const ev of ["pointerup", "pointercancel", "pointerleave"]) {
    ascendBtn.addEventListener(ev, () => (touchAscend = false))
    descendBtn.addEventListener(ev, () => (touchDescend = false))
  }

  // Recompute turn/throttle from whichever input source is active every call,
  // so releasing a key (or the touch stick) actually zeroes it out instead of
  // sticking at its last value. Ascend/descend are independent of the stick's
  // own touchActive state, since the flight buttons are separate elements.
  const read = () => {
    state.ascend = touchAscend || keys.has("f")
    state.descend = touchDescend || keys.has("c")

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

  const flightButtons = pad.querySelector(".sea-flight-buttons")
  // Hidden by default (most boats can't fly) -- index.js shows these only
  // while a flight-capable boat (the seaplane) is selected.
  flightButtons.hidden = true
  const setFlightControlsVisible = (visible) => {
    flightButtons.hidden = !visible
    if (!visible) touchAscend = touchDescend = false // don't leave a held button latched on a boat that can't use it
  }

  const destroy = () => {
    window.removeEventListener("keydown", kd)
    window.removeEventListener("keyup", ku)
    if (pad.parentNode) pad.parentNode.removeChild(pad)
  }

  return {read, state, destroy, setFlightControlsVisible}
}
