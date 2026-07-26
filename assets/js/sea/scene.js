import * as THREE from "three"

// system-v2 palette, approximated in sRGB hex (the CSS uses oklch).
const COL = {
  paper: 0xeef0ec,
  ink: 0x1a1c20,
  lime: 0xc4e600,
  limeDark: 0xa9c700,
  sea: 0x3d4fd4,
  seaDark: 0x2f3ba8
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

  // Radius/height vary per island, deterministically from its path, so every
  // sailor sees the same shape and the archipelago doesn't look uniform.
  addIsland(island) {
    const group = new THREE.Group()
    const h = hashStr(island.path)
    const radius = 5 + ((h % 100) / 100) * 5 // 5..10
    const height = 7 + (((h >> 8) % 100) / 100) * 9 // 7..16
    island.radius = radius
    island.height = height

    const geo = new THREE.ConeGeometry(radius, height, 5)
    const mat = new THREE.MeshToonMaterial({color: COL.lime, gradientMap: this.gradient})
    const cone = new THREE.Mesh(geo, mat)
    cone.position.y = height / 2
    group.add(outline(geo).translateY(height / 2))
    group.add(cone)

    // A little ink post so the island reads as a marker.
    const postGeo = new THREE.CylinderGeometry(0.25, 0.25, 6)
    const post = new THREE.Mesh(postGeo, new THREE.MeshBasicMaterial({color: COL.ink}))
    post.position.y = height + 3
    group.add(post)

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

  // Boat: ink-outlined hull + a lime sail carrying a flag canvas texture.
  makeBoat(flagTexture, isSelf) {
    const group = new THREE.Group()

    const hullGeo = new THREE.BoxGeometry(2.4, 1.1, 4.2)
    const hull = new THREE.Mesh(
      hullGeo,
      new THREE.MeshToonMaterial({color: isSelf ? COL.lime : COL.paper, gradientMap: this.gradient})
    )
    hull.position.y = 1
    group.add(outline(hullGeo, 1.12).translateY(1))
    group.add(hull)

    const mastGeo = new THREE.CylinderGeometry(0.12, 0.12, 4)
    const mast = new THREE.Mesh(mastGeo, new THREE.MeshBasicMaterial({color: COL.ink}))
    mast.position.set(0, 3.2, 0.2)
    group.add(mast)

    const sailGeo = new THREE.PlaneGeometry(2.6, 2.6)
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

  // Chase cam behind a boat group at heading h (radians).
  chase(target, h) {
    const back = new THREE.Vector3(Math.sin(h), 0, Math.cos(h))
    const desired = new THREE.Vector3(
      target.x - back.x * 34,
      22,
      target.z - back.z * 34
    )
    this.camera.position.lerp(desired, 0.08)
    this.camera.lookAt(target.x, 2, target.z)
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
