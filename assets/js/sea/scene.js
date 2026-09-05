import * as THREE from "three"
import {GLTFLoader} from "three/examples/jsm/loaders/GLTFLoader.js"

// The ship/shark models were all authored nose/bow-forward along +X, beam
// along Z. FORWARD_YAW rotates a clone so that instead faces local +Z, to
// match the local-+Z-is-forward convention every heading in this file
// assumes (see chase()'s `dir`).
const FORWARD_YAW = -Math.PI / 2

const SHIP_URL = "/models/pirateship.glb"
const SHARK_URL = "/models/shark.glb"
const CHEST_URL = "/models/treasurechest.glb"
const LIGHTHOUSE_URL = "/models/lighthouse.glb"
const GULL_URL = "/models/seagull.glb"

// Five hand-built island types (a CC0 asset kit), swapped in for the old
// procedural hex-band islands. `radius`/`height` are each model's own
// native half-footprint (half its longer X/Z extent) and vertical extent at
// scale 1 -- used for collision/docking (world.js's islandRadius) and for
// floating an island's label above its actual peak. Every model already sits
// with its waterline at local y=0 and comes with its own palms/rocks baked
// in, so islands no longer need procedural tree scattering.
const ISLAND_TYPES = [
  {url: "/models/island-palm-cay.glb", radius: 3.53, height: 3.52},
  {url: "/models/island-crescent-lagoon.glb", radius: 5.51, height: 4.13},
  {url: "/models/island-twin-peaks.glb", radius: 8.0, height: 6.45},
  {url: "/models/island-rock-arch.glb", radius: 7.75, height: 6.43},
  {url: "/models/island-volcano.glb", radius: 11.69, height: 7.5}
]
// Trending islands scale up bodily (footprint and height together, since
// each is one rigid model rather than stacked bands) instead of only
// growing taller.
const TRENDING_SCALE_BOOST = 1.3

// SHIP_SCALE brings the pirate ship down to roughly the old procedural
// hull's footprint, just a bit grander.
const SHIP_SCALE = 0.9
// SHARK_SCALE keeps the shark close to its authored size (already
// shark-sized relative to a boat); SHARK_SUBMERGE sinks it so only the
// dorsal fin breaks the surface at rest, same intent as the old procedural
// body's -0.55 sink offset.
const SHARK_SCALE = 1.1
const SHARK_SUBMERGE = -1.6
const CHEST_SCALE = 1
// LIGHTHOUSE_SCALE makes it a proper landmark towering over a trending
// island's peak, without dwarfing the island itself.
const LIGHTHOUSE_SCALE = 2
// GULL_SCALE is big enough to read as a bird gliding at GULL_ALTITUDE (see
// updateGull) rather than a speck.
const GULL_SCALE = 3
const GULL_ALTITUDE = 18 // cruise height above the water
const GULL_BOB_HEIGHT = 1.5
const GULL_BANK_ANGLE = 0.3

// Loaded once per page per model and cloned per instance (see
// makeBoat/addShark) so every sailor's ship/every shark shares one
// GPU-side geometry/texture upload of its kind.
const modelCache = new Map()
function loadModel(url) {
  if (!modelCache.has(url)) {
    modelCache.set(
      url,
      new Promise((resolve, reject) => {
        new GLTFLoader().load(url, (gltf) => resolve(gltf.scene), undefined, reject)
      })
    )
  }
  return modelCache.get(url)
}

// system-v2 palette, approximated in sRGB hex (the CSS uses oklch).
const COL = {
  paper: 0xeef0ec,
  ink: 0x1a1c20,
  lime: 0xc4e600,
  limeDark: 0xa9c700,
  sea: 0x3d4fd4,
  seaDark: 0x2f3ba8
}

// Day/night endpoints the scene lerps between — see applyTimeOfDay(). Kept
// as plain hex numbers (not THREE.Color) since they're only ever fed
// straight into `new THREE.Color(...)`.
const NIGHT = {
  sky: 0x161a33,
  fogNear: 90,
  fogFar: 240,
  sunColor: 0x8fa0ff,
  sunIntensity: 0.45,
  hemiIntensity: 0.3,
  sea: 0x1c2470
}
const DAY = {
  sky: COL.paper,
  fogNear: 120,
  fogFar: 320,
  sunColor: 0xffffff,
  sunIntensity: 2.2,
  hemiIntensity: 1.1,
  sea: COL.sea
}

// A small family of hull fills at the same brightness/saturation as the
// brand's lime and signal-blue accents, so every boat still reads as "one
// system" whichever fill it gets — the shared thick ink outline is what
// ties it together visually.
// Exported so a sailor's boat-customization picker (see index.js) offers
// exactly this palette — a custom hull color still "belongs" to the same
// system as everyone else's hash-derived one, just chosen instead of
// assigned.
export const PALETTE = [
  0xc4e600, // lime (brand)
  0x4fd6c4, // teal
  0xff8a3d, // coral
  0xff5c8a, // pink
  0x8a6cff, // violet
  0x4fa8ff, // sky blue (near signal)
  0xffd23d, // gold
  0x4fd67a // mint
]

// Deterministically maps a sailor id to one of the palette colors, so the
// same sailor's boat is always the same hull color on every screen, not
// just tinted for "you" vs "everyone else".
function themedColor(key) {
  return PALETTE[hashStr(key || "") % PALETTE.length]
}

// A 3-step toon gradient so MeshToonMaterial reads as flat cel bands.
function toonGradient() {
  const data = new Uint8Array([90, 160, 255])
  const tex = new THREE.DataTexture(data, data.length, 1, THREE.RedFormat)
  tex.needsUpdate = true
  return tex
}

function hashStr(s) {
  let h = 0
  for (let i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) >>> 0
  return h
}

// Ink outline via vertex-normal extrusion, for meshes that aren't centered
// on their own local origin — every part of an imported GLTF model (ship,
// shark, island) is authored in one shared whole-model coordinate frame, so
// scaling a copy up about its local origin (as a centered primitive's
// outline could) would puff each part away from the model's center rather
// than away from its own surface. Clones the geometry (never mutates the
// shared template) and pushes every vertex out along its normal by a small
// constant distance.
function normalOutline(geometry, dist = 0.045) {
  const geo = geometry.clone()
  const pos = geo.attributes.position
  const norm = geo.attributes.normal
  for (let i = 0; i < pos.count; i++) {
    pos.setX(i, pos.getX(i) + norm.getX(i) * dist)
    pos.setY(i, pos.getY(i) + norm.getY(i) * dist)
    pos.setZ(i, pos.getZ(i) + norm.getZ(i) * dist)
  }
  pos.needsUpdate = true
  const mat = new THREE.MeshBasicMaterial({color: COL.ink, side: THREE.BackSide})
  return new THREE.Mesh(geo, mat)
}

export class SeaScene {
  constructor(container) {
    this.container = container
    this.gradient = toonGradient()

    this.renderer = new THREE.WebGLRenderer({antialias: true})
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2))
    this.renderer.setSize(container.clientWidth, container.clientHeight)
    container.appendChild(this.renderer.domElement)

    this.scene = new THREE.Scene()
    this.scene.background = new THREE.Color(COL.paper)
    this.scene.fog = new THREE.Fog(COL.paper, 120, 320)

    this.camera = new THREE.PerspectiveCamera(
      55,
      container.clientWidth / container.clientHeight,
      0.1,
      1000
    )
    this.camera.position.set(0, 24, 34)

    this.sun = new THREE.DirectionalLight(0xffffff, 2.2)
    this.sun.position.set(30, 60, 20)
    this.scene.add(this.sun)
    this.hemi = new THREE.HemisphereLight(COL.paper, COL.seaDark, 1.1)
    this.scene.add(this.hemi)

    this._water()

    this.boats = new Map() // id -> {group}
    this._onResize = () => this.resize()
    window.addEventListener("resize", this._onResize)
  }

  // Blends sky/fog/lighting/sea between NIGHT and DAY. `t` is 0 (deepest
  // night) .. 1 (brightest day) — see world.js's dayFactor(), which derives
  // it from the real time of day in US Eastern regardless of the visitor's
  // own timezone, so everyone sailing together sees the same sky at once.
  applyTimeOfDay(t) {
    const sky = new THREE.Color(NIGHT.sky).lerp(new THREE.Color(DAY.sky), t)
    this.scene.background = sky
    this.scene.fog.color = sky
    this.scene.fog.near = THREE.MathUtils.lerp(NIGHT.fogNear, DAY.fogNear, t)
    this.scene.fog.far = THREE.MathUtils.lerp(NIGHT.fogFar, DAY.fogFar, t)

    this.sun.color = new THREE.Color(NIGHT.sunColor).lerp(new THREE.Color(DAY.sunColor), t)
    this.sun.intensity = THREE.MathUtils.lerp(NIGHT.sunIntensity, DAY.sunIntensity, t)
    this.hemi.intensity = THREE.MathUtils.lerp(NIGHT.hemiIntensity, DAY.hemiIntensity, t)

    this.water.material.color = new THREE.Color(NIGHT.sea).lerp(new THREE.Color(DAY.sea), t)
  }

  _water() {
    const geo = new THREE.PlaneGeometry(1200, 1200, 60, 60)
    geo.rotateX(-Math.PI / 2)
    this.waterGeo = geo
    this.waterBase = Float32Array.from(geo.attributes.position.array)
    const mat = new THREE.MeshToonMaterial({color: COL.sea, gradientMap: this.gradient})
    this.water = new THREE.Mesh(geo, mat)
    this.scene.add(this.water)
  }

  // A treasure chest hidden on roughly a quarter of islands, toward the
  // outer beach — a reward for exploring, not a fixture of every island.
  // Position/presence are both derived from the island's hash, same
  // reasoning as _palms.
  _treasureChest(group, h, radius, baseY) {
    if ((h >> 20) % 4 !== 0) return
    const a = ((h >> 22) % 360) * (Math.PI / 180)
    const r = radius * (0.55 + ((h >> 27) % 30) / 100)
    const yaw = ((h >> 17) % 360) * (Math.PI / 180)

    loadModel(CHEST_URL).then((template) => {
      const chest = template.clone(true)
      chest.scale.setScalar(CHEST_SCALE)
      chest.rotation.y = yaw
      chest.position.set(Math.cos(a) * r, baseY, Math.sin(a) * r)
      this._toonify(chest)
      group.add(chest)
    })
  }

  // A lighthouse standing on a trending island's peak, replacing the old
  // glowing beacon cone with an actual landmark — its lamp still reads as
  // lit at any time of day (see _toonify's "..._glow" handling).
  _lighthouse(group, peakY) {
    loadModel(LIGHTHOUSE_URL).then((template) => {
      const lighthouse = template.clone(true)
      lighthouse.scale.setScalar(LIGHTHOUSE_SCALE)
      lighthouse.position.y = peakY
      this._toonify(lighthouse)
      group.add(lighthouse)
    })
  }

  // One of the five whimsical island models (see ISLAND_TYPES), chosen and
  // sized/rotated deterministically from the island's path so every sailor
  // sees the same island in the same spot. `island.radius`/`island.height`
  // are set synchronously (world.js/index.js need them for collision and
  // label placement right away) even though the model itself loads async.
  // Collision stays a single circle of that radius, same simplification as
  // the old procedural islands -- for the crescent lagoon and rock arch this
  // means their lagoon/passage read as open water but still block like solid
  // land; giving them a true opening would need compound/mesh collision,
  // which world.js's collision helpers don't support.
  addIsland(island) {
    const group = new THREE.Group()
    const h = hashStr(island.path)
    const type = ISLAND_TYPES[h % ISLAND_TYPES.length]
    // 0.9..1.19, further boosted for a trending island -- see
    // TRENDING_SCALE_BOOST.
    const scale = (0.9 + ((h >> 8) % 30) / 100) * (island.trending ? TRENDING_SCALE_BOOST : 1)
    const yaw = ((h >> 16) % 360) * (Math.PI / 180)

    island.radius = type.radius * scale
    island.height = type.height * scale

    loadModel(type.url).then((template) => {
      const model = template.clone(true)
      model.scale.setScalar(scale)
      model.rotation.y = yaw
      this._toonify(model, (child, srcMat) => {
        // The volcano's lava reads as an unlit glow rather than lit terrain
        // -- same treatment _toonify gives a lighthouse lamp/chest's
        // "..._glow" materials, just keyed off this kit's own material name.
        if (srcMat.name === "lava") {
          child.material = new THREE.MeshBasicMaterial({color: srcMat.color})
          return false
        }
      })
      group.add(model)
    })

    this._treasureChest(group, h, island.radius, 0.15)
    if (island.trending) this._lighthouse(group, island.height)

    group.position.set(island.x, 0, island.z)
    group.userData.island = island
    this.scene.add(group)
    return group
  }

  // Projects a 3D world point to 2D screen pixels (for floating HTML labels).
  // `visible` is false once the point is behind the camera.
  project(x, y, z) {
    const v = new THREE.Vector3(x, y, z).project(this.camera)
    return {
      x: (v.x * 0.5 + 0.5) * this.container.clientWidth,
      y: (-v.y * 0.5 + 0.5) * this.container.clientHeight,
      visible: v.z < 1
    }
  }

  // Re-materializes every mesh of a cloned imported model (ship/shark/
  // island/treasure chest/lighthouse/seagull) as toon-shaded with a matching
  // ink outline, so it reads in the same low-poly cel-shaded style as
  // everything hand-built in this file. A mesh whose material is named
  // "..._glow" (a lighthouse's lamp, a chest's treasure) is treated as a
  // light source instead: an unlit, outline-free MeshBasicMaterial, so it
  // reads as glowing rather than lit by the scene regardless of time of day.
  // `onMesh(child, originalMaterial)`, if given, runs per mesh before either
  // swap and can return `false` to skip re-materializing that mesh entirely
  // (the caller already handled it) — used to tag the ship's hull mesh, and
  // to give a volcano island's lava the same glow treatment (see addIsland).
  _toonify(root, onMesh) {
    // Collect meshes before touching any of them: traverse() walks the live
    // children array, so adding an outline mesh mid-traversal would have it
    // visit (and try to outline) that new child too, recursing forever.
    const meshes = []
    root.traverse((child) => {
      if (child.isMesh) meshes.push(child)
    })
    for (const child of meshes) {
      const srcMat = child.material
      if (onMesh?.(child, srcMat) === false) continue
      if (srcMat.name.endsWith("_glow")) {
        child.material = new THREE.MeshBasicMaterial({color: srcMat.color})
        continue
      }
      child.material = new THREE.MeshToonMaterial({
        color: srcMat.color,
        gradientMap: this.gradient,
        side: srcMat.side
      })
      child.add(normalOutline(child.geometry))
    }
  }

  // Clones the shared ship template into `group`, toon-shading it and
  // rigging a small masthead pennant that carries the flag texture. Runs
  // once the GLTF has loaded (see makeBoat) — by then `group` may already
  // carry a customized hull color / flag texture in its userData, so those
  // win over the model's own defaults.
  _riggedShip(group, template) {
    const ship = template.clone(true)
    ship.scale.setScalar(SHIP_SCALE)
    ship.rotation.y = FORWARD_YAW

    // GLTFLoader sanitizes mesh names (spaces -> underscores) but leaves
    // material names as authored, so key the hull off the material, not
    // the mesh, and tag it before _toonify replaces that material.
    this._toonify(ship, (child, srcMat) => {
      if (srcMat.name === "hull") child.userData.isHull = true // lets setHullColor find it later
    })

    // Masthead pennant: a small flat flag near the top of the mast, rather
    // than texturing the model's own sails, so the emoji-flag customization
    // (see setSailTexture) keeps working against a plain rectangle.
    const flagGeo = new THREE.PlaneGeometry(1.4, 0.9)
    const flagMat = new THREE.MeshBasicMaterial({
      map: group.userData.sailTexture,
      side: THREE.DoubleSide,
      transparent: true
    })
    const flag = new THREE.Mesh(flagGeo, flagMat)
    flag.userData.isSail = true // lets setSailTexture find it later
    flag.position.set(0.8, 7.6, 0)
    ship.add(flag)

    group.add(ship)
    this.setHullColor(group, group.userData.hullColor)
  }

  // Boat: the shared pirate-ship model (loaded async and rigged in once
  // ready — see _riggedShip) plus a masthead flag. The hull color is keyed
  // by sailor id, not by whether it's "you" — so a given sailor's boat looks
  // the same to every viewer, on every screen. `isSelf` only adds the ring
  // accent beneath your own boat.
  makeBoat(flagTexture, isSelf, sailorId) {
    const group = new THREE.Group()
    group.userData.sailorId = sailorId
    group.userData.hullColor = null // sailor's default until setHullColor overrides it
    group.userData.sailTexture = flagTexture

    loadModel(SHIP_URL).then((template) => this._riggedShip(group, template))

    if (isSelf) {
      const ring = new THREE.Mesh(
        new THREE.RingGeometry(3.2, 3.8, 24),
        new THREE.MeshBasicMaterial({color: COL.lime, side: THREE.DoubleSide})
      )
      ring.rotateX(-Math.PI / 2)
      ring.position.y = 0.2
      group.add(ring)
    }

    this.scene.add(group)
    return group
  }

  // Re-tints an already-built boat's hull — used to apply a sailor's
  // customized color over the hash-derived default (see index.js's
  // boat-customization picker), or falls back to the hash-derived default
  // when `colorHex` is nullish. No-op (beyond recording the pending value)
  // if the ship model hasn't finished loading into `group` yet.
  setHullColor(group, colorHex) {
    group.userData.hullColor = colorHex
    let hull = null
    group.traverse((o) => {
      if (o.userData.isHull) hull = o
    })
    if (hull) hull.material.color.set(colorHex ?? themedColor(group.userData.sailorId))
  }

  // Swaps an already-built boat's sail texture (e.g. a custom flag emoji
  // instead of the hash/GeoIP default). Disposes the old texture -- unlike
  // most meshes in this file, textures here are swapped at runtime rather
  // than built once, so leaving the old one behind would actually leak.
  // No-op (beyond recording the pending value) if the ship model hasn't
  // finished loading into `group` yet.
  setSailTexture(group, texture) {
    group.userData.sailTexture = texture
    let sail = null
    group.traverse((o) => {
      if (o.userData.isSail) sail = o
    })
    if (!sail) return
    sail.material.map?.dispose()
    sail.material.map = texture
    sail.material.needsUpdate = true
  }

  removeBoat(group) {
    this.scene.remove(group)
  }

  // Generic scene-graph attach/detach for standalone objects that aren't
  // boats or islands (e.g. a bottle sprite) — keeps callers from reaching
  // into the internal THREE.Scene directly.
  add(object) {
    this.scene.add(object)
  }

  remove(object) {
    this.scene.remove(object)
  }

  // Shark: the shared shark model (loaded async and toon-shaded in once
  // ready, sunk so only the dorsal fin breaks the surface at rest). Ambient
  // and purely local — see world.js's shark helpers for the patrol/breach
  // simulation this just renders each frame.
  addShark() {
    const group = new THREE.Group()
    loadModel(SHARK_URL).then((template) => {
      const model = template.clone(true)
      model.scale.setScalar(SHARK_SCALE)
      model.rotation.y = FORWARD_YAW
      model.position.y = SHARK_SUBMERGE
      this._toonify(model)
      group.add(model)
    })
    this.scene.add(group)
    return group
  }

  // Applies one frame of a shark's simulated state (see world.js) to its
  // rendered group: patrol position/heading, plus lifting clear of the
  // water and pitching its nose up while `breach` (0..1) is non-zero.
  updateShark(group, shark, breach) {
    group.position.set(shark.x, breach * 3.2, shark.z)
    group.rotation.y = shark.h
    group.rotation.x = -breach * 0.4
  }

  // A seagull cruising well above the water — pure atmosphere, no
  // interaction with the boat at all. See world.js's gull patrol helpers
  // this renders.
  addGull() {
    const group = new THREE.Group()
    loadModel(GULL_URL).then((template) => {
      const model = template.clone(true)
      model.scale.setScalar(GULL_SCALE)
      model.rotation.y = FORWARD_YAW
      this._toonify(model)
      group.add(model)
    })
    this.scene.add(group)
    return group
  }

  // Applies one frame of a gull's simulated state (see world.js): patrol
  // position/heading at a fixed cruise altitude, plus a gentle rise-and-fall
  // bob and a matching wing-tip bank so the glide doesn't read as perfectly
  // level. `bob`/`bank` are both -1..1.
  updateGull(group, gull, bob, bank) {
    group.position.set(gull.x, GULL_ALTITUDE + bob * GULL_BOB_HEIGHT, gull.z)
    group.rotation.y = gull.h
    group.rotation.z = bank * GULL_BANK_ANGLE
  }

  // Cheap animated swell.
  animateWater(t) {
    const pos = this.waterGeo.attributes.position
    const base = this.waterBase
    for (let i = 0; i < pos.count; i++) {
      const x = base[i * 3]
      const z = base[i * 3 + 2]
      pos.array[i * 3 + 1] = Math.sin(x * 0.05 + t) * 0.6 + Math.cos(z * 0.05 + t * 0.8) * 0.6
    }
    pos.needsUpdate = true
  }

  // Chase cam behind a boat group at heading h (radians). Aims ahead of and
  // above the boat rather than straight at it, which tilts the view up and
  // keeps the boat low in the frame (bottom quarter-ish) so islands and
  // labels ahead have more headroom on screen.
  chase(target, h) {
    const dir = new THREE.Vector3(Math.sin(h), 0, Math.cos(h))
    const desired = new THREE.Vector3(
      target.x - dir.x * 34,
      22,
      target.z - dir.z * 34
    )
    this.camera.position.lerp(desired, 0.08)
    this.camera.lookAt(target.x + dir.x * 14, 8, target.z + dir.z * 14)
  }

  render() {
    this.renderer.render(this.scene, this.camera)
  }

  resize() {
    const w = this.container.clientWidth
    const h = this.container.clientHeight
    this.renderer.setSize(w, h)
    this.camera.aspect = w / h
    this.camera.updateProjectionMatrix()
  }

  dispose() {
    window.removeEventListener("resize", this._onResize)
    this.renderer.dispose()
    if (this.renderer.domElement.parentNode) {
      this.renderer.domElement.parentNode.removeChild(this.renderer.domElement)
    }
  }
}

// A billboarded emoji sprite (always faces the camera, unlike a plane mesh)
// for the wave/emote gesture — a bare transparent glyph, not a flag swatch.
// Callers attach it to a boat group and animate/remove it themselves.
export function emoteSprite(emoji) {
  const c = document.createElement("canvas")
  c.width = c.height = 128
  const ctx = c.getContext("2d")
  ctx.font = "96px system-ui, 'Apple Color Emoji', 'Segoe UI Emoji', sans-serif"
  ctx.textAlign = "center"
  ctx.textBaseline = "middle"
  ctx.fillText(emoji, 64, 70)
  const tex = new THREE.CanvasTexture(c)
  tex.needsUpdate = true
  const mat = new THREE.SpriteMaterial({map: tex, transparent: true, depthTest: false})
  const sprite = new THREE.Sprite(mat)
  sprite.scale.set(3.2, 3.2, 1)
  return sprite
}

// A floating message-in-a-bottle marker: a smaller emoteSprite bobbing near
// the waterline rather than above a boat's mast. Caller positions/animates
// it (see Sea#updateBottles in index.js) and removes it on expiry.
export function bottleSprite() {
  const sprite = emoteSprite("🍾")
  sprite.scale.set(2, 2, 1)
  return sprite
}

// One puff of a boat's wake: a small flat, pale, translucent oblong laid on
// the water surface. Caller positions/rotates it to trail behind a moving
// boat and fades/grows it over time (see Sea#updateWakes in index.js) —
// this just builds the mesh.
export function wakeSegment() {
  const geo = new THREE.PlaneGeometry(1.4, 2.4)
  geo.rotateX(-Math.PI / 2)
  const mat = new THREE.MeshBasicMaterial({
    color: 0xf2f4ef,
    transparent: true,
    opacity: 0.5,
    depthWrite: false
  })
  return new THREE.Mesh(geo, mat)
}

// Builds a CanvasTexture showing an emoji flag on a lime sail.
export function flagTexture(flag) {
  const c = document.createElement("canvas")
  c.width = c.height = 128
  const ctx = c.getContext("2d")
  ctx.fillStyle = "#c4e600"
  ctx.fillRect(0, 0, 128, 128)
  ctx.font = "72px system-ui, 'Apple Color Emoji', 'Segoe UI Emoji', sans-serif"
  ctx.textAlign = "center"
  ctx.textBaseline = "middle"
  ctx.fillText(flag || "🏳️", 64, 70)
  const tex = new THREE.CanvasTexture(c)
  tex.needsUpdate = true
  return tex
}
