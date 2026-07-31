import * as THREE from "three"

// system-v2 palette, approximated in sRGB hex (the CSS uses oklch).
const COL = {
  paper: 0xeef0ec,
  ink: 0x1a1c20,
  lime: 0xc4e600,
  limeDark: 0xa9c700,
  sea: 0x3d4fd4,
  seaDark: 0x2f3ba8,
  sand: 0xe8d9a0,
  rock: 0x7d8088,
  palm: 0x2f8f4f,
  shark: 0x5b6470
}

// A small family of fills at the same brightness/saturation as the brand's
// lime and signal-blue accents, so colorful islands and boats still read as
// "one system" — everything keeps the same thick ink outline regardless of
// fill, which is what ties it together visually.
const PALETTE = [
  0xc4e600, // lime (brand)
  0x4fd6c4, // teal
  0xff8a3d, // coral
  0xff5c8a, // pink
  0x8a6cff, // violet
  0x4fa8ff, // sky blue (near signal)
  0xffd23d, // gold
  0x4fd67a // mint
]

// Deterministically maps any key (category/tag/section, or a sailor id) to
// one of the palette colors, so the same thing always looks the same color to
// everyone — e.g. a given sailor's boat is the same hull color on every
// screen, not just tinted for "you" vs "everyone else".
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

// Ink outline: a slightly larger back-side copy of a geometry.
function outline(geometry, scale = 1.06) {
  const mat = new THREE.MeshBasicMaterial({color: COL.ink, side: THREE.BackSide})
  const mesh = new THREE.Mesh(geometry, mat)
  mesh.scale.multiplyScalar(scale)
  return mesh
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

    const sun = new THREE.DirectionalLight(0xffffff, 2.2)
    sun.position.set(30, 60, 20)
    this.scene.add(sun)
    this.scene.add(new THREE.HemisphereLight(COL.paper, COL.seaDark, 1.1))

    this._water()

    this.boats = new Map() // id -> {group}
    this._onResize = () => this.resize()
    window.addEventListener("resize", this._onResize)
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

  // One tapered hexagonal band (beach/slope/peak) with a matching ink
  // outline nested as a child, so the outline inherits the band's transform.
  _band(topR, botR, h, color) {
    const geo = new THREE.CylinderGeometry(topR, botR, h, 6)
    const mat = new THREE.MeshToonMaterial({color, gradientMap: this.gradient})
    const mesh = new THREE.Mesh(geo, mat)
    mesh.add(outline(geo, 1.05))
    return mesh
  }

  // A cheap procedural palm: an ink trunk plus a squashed low-poly canopy.
  // Positions are derived from the island's hash so every sailor sees the
  // same trees in the same spots.
  _palms(group, h, radius, baseY) {
    if (!this._palmTrunkGeo) {
      this._palmTrunkGeo = new THREE.CylinderGeometry(0.12, 0.18, 2.4)
      this._palmLeafGeo = new THREE.IcosahedronGeometry(0.9, 0)
    }
    const leafMat = new THREE.MeshToonMaterial({color: COL.palm, gradientMap: this.gradient})
    const count = 2 + (h % 3) // 2..4
    for (let i = 0; i < count; i++) {
      const a = ((h >> (i * 5 + 1)) % 360) * (Math.PI / 180)
      const r = radius * (0.15 + ((h >> (i * 3 + 2)) % 40) / 100) // scattered near the shoreline

      const trunk = new THREE.Mesh(this._palmTrunkGeo, new THREE.MeshBasicMaterial({color: COL.ink}))
      trunk.position.set(Math.cos(a) * r, baseY + 1.2, Math.sin(a) * r)
      trunk.rotation.z = Math.sin(a + i) * 0.2
      group.add(trunk)

      const leaf = new THREE.Mesh(this._palmLeafGeo, leafMat)
      leaf.scale.set(1, 0.55, 1)
      leaf.position.set(Math.cos(a) * r, baseY + 2.5, Math.sin(a) * r)
      group.add(leaf)
    }
  }

  // Islands are stacked hexagonal bands — a sand beach, a landmass slope,
  // and a peak (rocky if the island is tall) — plus a few palms, rather than
  // a single cone, so the silhouette reads as terrain rather than a triangle.
  // Radius/height/tree placement are all deterministic from the island's
  // path, so every sailor sees the same shape.
  addIsland(island) {
    const group = new THREE.Group()
    const h = hashStr(island.path)
    const radius = 5 + ((h % 100) / 100) * 5 // 5..10
    const height = 7 + (((h >> 8) % 100) / 100) * 9 // 7..16
    island.radius = radius

    const fill = themedColor(island.color || island.section)
    const sandH = height * 0.16
    const slopeH = height * 0.5
    const peakH = height - sandH - slopeH
    const peakFill = height > 12 ? COL.rock : fill

    let y = 0
    const beach = this._band(radius * 0.72, radius * 1.1, sandH, COL.sand)
    beach.position.y = y + sandH / 2
    group.add(beach)
    y += sandH

    const slope = this._band(radius * 0.3, radius * 0.72, slopeH, fill)
    slope.position.y = y + slopeH / 2
    group.add(slope)
    y += slopeH

    const peak = this._band(radius * 0.12, radius * 0.3, peakH, peakFill)
    peak.position.y = y + peakH / 2
    group.add(peak)
    y += peakH

    island.height = y // actual peak height, used to float the label above it

    this._palms(group, h, radius, sandH)

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

  // A pointed-bow hull cut from a canoe-shaped outline and tapered inward
  // toward the deck, instead of a box — the local +Z axis is the bow, to
  // match how callers set `group.rotation.y` as heading. Built once and
  // shared (read-only) across every boat instance.
  _hullGeometry() {
    if (this._hullGeo) return this._hullGeo
    const w = 2.4
    const l = 4.2
    const hgt = 1.3

    const shape = new THREE.Shape()
    shape.moveTo(0, -l / 2 - 0.3) // bow tip, raked out ahead of the hull body
    shape.lineTo(w / 2, -0.5) // starboard shoulder
    shape.lineTo(w / 2 - 0.3, l / 2) // starboard stern corner
    shape.lineTo(-(w / 2 - 0.3), l / 2) // port stern corner
    shape.lineTo(-w / 2, -0.5) // port shoulder
    shape.closePath()

    const geo = new THREE.ExtrudeGeometry(shape, {depth: hgt, bevelEnabled: false})
    geo.rotateX(-Math.PI / 2) // shape was drawn top-down; stand the extrusion up
    geo.translate(0, -hgt / 2, 0) // center vertically, like a BoxGeometry

    // Taper the sides inward toward the deck for a hull-like cross section.
    const pos = geo.attributes.position
    for (let i = 0; i < pos.count; i++) {
      const t = (pos.getY(i) + hgt / 2) / hgt // 0 at keel, 1 at deck
      pos.setX(i, pos.getX(i) * (1 - 0.35 * t))
    }
    pos.needsUpdate = true
    geo.computeVertexNormals()

    this._hullGeo = geo
    return geo
  }

  // Boat: ink-outlined pointed hull + a curved sail carrying a flag canvas
  // texture. The hull color is keyed by sailor id, not by whether it's
  // "you" — so a given sailor's boat looks the same to every viewer, on
  // every screen. `isSelf` only adds the ring accent beneath your own boat.
  makeBoat(flagTexture, isSelf, sailorId) {
    const group = new THREE.Group()

    const hullGeo = this._hullGeometry()
    const hull = new THREE.Mesh(
      hullGeo,
      new THREE.MeshToonMaterial({color: themedColor(sailorId), gradientMap: this.gradient})
    )
    hull.position.y = 1
    group.add(outline(hullGeo, 1.1).translateY(1))
    group.add(hull)

    const keelGeo = new THREE.BoxGeometry(0.15, 0.8, 1.8)
    const keel = new THREE.Mesh(keelGeo, new THREE.MeshBasicMaterial({color: COL.ink}))
    keel.position.set(0, 0.2, -0.3)
    group.add(keel)

    const mastGeo = new THREE.CylinderGeometry(0.12, 0.12, 4)
    const mast = new THREE.Mesh(mastGeo, new THREE.MeshBasicMaterial({color: COL.ink}))
    mast.position.set(0, 3.2, 0.2)
    group.add(mast)

    // A few extra width segments so the sail can belly out, as if filled
    // with wind, instead of sitting perfectly flat.
    const sailGeo = new THREE.PlaneGeometry(2.6, 2.6, 6, 1)
    const sailPos = sailGeo.attributes.position
    for (let i = 0; i < sailPos.count; i++) {
      const t = sailPos.getX(i) / 1.3 // -1..1 across the sail's width
      sailPos.setZ(i, (1 - t * t) * 0.35)
    }
    sailPos.needsUpdate = true
    sailGeo.computeVertexNormals()
    const sailMat = new THREE.MeshBasicMaterial({
      map: flagTexture,
      side: THREE.DoubleSide
    })
    const sail = new THREE.Mesh(sailGeo, sailMat)
    sail.position.set(0, 3.1, 0.2)
    group.add(sail)

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

  removeBoat(group) {
    this.scene.remove(group)
  }

  // A single raked fin blade: a thin triangle (root-to-root along the base,
  // swept tip above) extruded for thickness. Local origin is the *front*
  // root, extending backward (-z) and up (+y) from there, so callers place
  // it by setting `position` to where the front of the fin meets the body.
  _finBlade(len, height, thickness, color = COL.ink) {
    const shape = new THREE.Shape()
    shape.moveTo(0, 0)
    shape.lineTo(len, 0)
    shape.lineTo(len * 0.45, height)
    shape.closePath()

    const geo = new THREE.ExtrudeGeometry(shape, {depth: thickness, bevelEnabled: false})
    geo.rotateY(Math.PI / 2) // shape drawn as a side profile; swing it to face forward
    geo.translate(-thickness / 2, 0, 0) // center the blade's thickness
    return new THREE.Mesh(geo, new THREE.MeshBasicMaterial({color}))
  }

  // Shark: a stretched low-poly body (mostly submerged) plus a dorsal and
  // tail fin. Ambient and purely local — see world.js's shark helpers for
  // the patrol/breach simulation this just renders each frame.
  addShark() {
    const group = new THREE.Group()

    const bodyGeo = new THREE.IcosahedronGeometry(1, 1)
    const body = new THREE.Mesh(
      bodyGeo,
      new THREE.MeshToonMaterial({color: COL.shark, gradientMap: this.gradient})
    )
    body.scale.set(0.85, 0.6, 2.4)
    body.position.y = -0.55 // mostly underwater; only the topmost sliver breaks the surface
    body.add(outline(bodyGeo, 1.08))
    group.add(body)

    const dorsal = this._finBlade(1.3, 1.3, 0.14)
    dorsal.position.set(0, 0, 0.4)
    group.add(dorsal)

    const tail = this._finBlade(0.8, 1.0, 0.12)
    tail.position.set(0, 0, -2.1)
    group.add(tail)

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
