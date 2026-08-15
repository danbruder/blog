// Lightweight WebAudio sound design for Sea mode. Everything is synthesized
// (filtered noise + oscillators) rather than loaded from audio files, so
// there's nothing to fetch and nothing added to the asset bundle.
//
// Muted by default, always — no autoplay, ever. Sound only starts from an
// explicit `toggle()` call, which callers must wire to a real user gesture
// (the mute button's click handler). If a visitor previously turned sound
// on, that preference is remembered (localStorage), but actually resuming
// audio on a later visit still waits for `armFromStoredPreference`'s
// one-time listener to see a genuine user gesture (a keypress or tap),
// which browser autoplay policies require regardless of prior consent.
const MUTE_KEY = "seaMuted"

export class SeaAudio {
  constructor() {
    this.ctx = null
    this.master = null
    this.ambientStarted = false
    this.muted = localStorage.getItem(MUTE_KEY) !== "0"
  }

  // If the visitor previously left sound on, unmute as soon as they make any
  // real gesture in the scene (first key press or touch) — satisfies
  // autoplay policy without asking them to click a button they already
  // opted into last time. `onChange` fires so the caller can refresh a mute
  // button's icon.
  armFromStoredPreference(el, onChange) {
    if (this.muted) return
    const resume = () => {
      this.setMuted(false)
      if (onChange) onChange()
    }
    el.addEventListener("keydown", resume, {once: true})
    el.addEventListener("touchstart", resume, {once: true})
    this._disarm = () => {
      el.removeEventListener("keydown", resume)
      el.removeEventListener("touchstart", resume)
    }
  }

  toggle() {
    this.setMuted(!this.muted)
    return this.muted
  }

  setMuted(muted) {
    this.muted = muted
    localStorage.setItem(MUTE_KEY, muted ? "1" : "0")
    if (muted) {
      if (this.master) this.master.gain.setTargetAtTime(0, this._now(), 0.15)
      return
    }
    if (!this.ctx) this._init()
    if (this.ctx.state === "suspended") this.ctx.resume()
    this.master.gain.setTargetAtTime(0.5, this._now(), 0.3)
  }

  _now() {
    return this.ctx.currentTime
  }

  _init() {
    const Ctx = window.AudioContext || window.webkitAudioContext
    if (!Ctx) return
    this.ctx = new Ctx()
    this.master = this.ctx.createGain()
    this.master.gain.value = 0 // ramped up by setMuted(false)
    this.master.connect(this.ctx.destination)
    this._startAmbientWaves()
  }

  // A loop of filtered noise with two slow LFOs wobbling its cutoff and
  // level, so it reads as surf/wind swelling rather than a flat hiss.
  _startAmbientWaves() {
    if (this.ambientStarted) return
    this.ambientStarted = true
    const ctx = this.ctx

    const src = ctx.createBufferSource()
    src.buffer = this._noiseBuffer(4)
    src.loop = true

    const filter = ctx.createBiquadFilter()
    filter.type = "lowpass"
    filter.frequency.value = 500

    const gain = ctx.createGain()
    gain.gain.value = 0.35

    src.connect(filter)
    filter.connect(gain)
    gain.connect(this.master)
    src.start()

    const cutoffLfo = ctx.createOscillator()
    cutoffLfo.frequency.value = 0.08
    const cutoffLfoGain = ctx.createGain()
    cutoffLfoGain.gain.value = 250
    cutoffLfo.connect(cutoffLfoGain)
    cutoffLfoGain.connect(filter.frequency)
    cutoffLfo.start()

    const levelLfo = ctx.createOscillator()
    levelLfo.frequency.value = 0.05
    const levelLfoGain = ctx.createGain()
    levelLfoGain.gain.value = 0.15
    levelLfo.connect(levelLfoGain)
    levelLfoGain.connect(gain.gain)
    levelLfo.start()
  }

  _noiseBuffer(seconds) {
    const len = Math.floor(seconds * this.ctx.sampleRate)
    const buf = this.ctx.createBuffer(1, len, this.ctx.sampleRate)
    const data = buf.getChannelData(0)
    for (let i = 0; i < len; i++) data[i] = Math.random() * 2 - 1
    return buf
  }

  // A short burst of filtered noise for hitting land or another boat.
  splash() {
    this._oneShot((ctx, out) => {
      const src = ctx.createBufferSource()
      src.buffer = this._noiseBuffer(0.3)
      const filter = ctx.createBiquadFilter()
      filter.type = "bandpass"
      filter.frequency.value = 900
      const gain = ctx.createGain()
      gain.gain.setValueAtTime(0.6, ctx.currentTime)
      gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.3)
      src.connect(filter)
      filter.connect(gain)
      gain.connect(out)
      src.start()
      src.stop(ctx.currentTime + 0.3)
    })
  }

  // A falling sawtooth growl for a shark bite.
  biteAlarm() {
    this._oneShot((ctx, out) => {
      const osc = ctx.createOscillator()
      osc.type = "sawtooth"
      osc.frequency.setValueAtTime(220, ctx.currentTime)
      osc.frequency.exponentialRampToValueAtTime(90, ctx.currentTime + 0.35)
      const gain = ctx.createGain()
      gain.gain.setValueAtTime(0.5, ctx.currentTime)
      gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.35)
      osc.connect(gain)
      gain.connect(out)
      osc.start()
      osc.stop(ctx.currentTime + 0.35)
    })
  }

  // A little three-note major arpeggio for docking.
  dockChime() {
    this._oneShot((ctx, out) => {
      ;[523.25, 659.25, 784].forEach((freq, i) => {
        const osc = ctx.createOscillator()
        osc.type = "sine"
        osc.frequency.value = freq
        const gain = ctx.createGain()
        const start = ctx.currentTime + i * 0.08
        gain.gain.setValueAtTime(0, start)
        gain.gain.linearRampToValueAtTime(0.35, start + 0.02)
        gain.gain.exponentialRampToValueAtTime(0.001, start + 0.5)
        osc.connect(gain)
        gain.connect(out)
        osc.start(start)
        osc.stop(start + 0.5)
      })
    })
  }

  // Builds and discards its own nodes per call so overlapping triggers
  // (e.g. two crashes in a row) don't fight over shared state. No-ops
  // while muted so callers don't need to guard every call site.
  _oneShot(build) {
    if (this.muted || !this.ctx) return
    build(this.ctx, this.master)
  }

  destroy() {
    if (this._disarm) this._disarm()
    if (this.ctx) this.ctx.close().catch(() => {})
  }
}
