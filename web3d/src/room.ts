import * as THREE from 'three';
import { tween } from './anim';
import type { MaterialBank } from './materials';
import type { OpeningNode, RoomNode } from './types';

const T = 0.1; // wall thickness
const UNIT = new THREE.BoxGeometry(1, 1, 1);
const CUTAWAY = 0.12;

interface Wall {
  group: THREE.Group;
  outward: THREE.Vector3;
  centre: THREE.Vector3;
  materials: THREE.MeshStandardMaterial[];
  faded: boolean;
}

/** Floor, walls split around openings, door and window frames, cutaway. */
export class RoomView {
  readonly group = new THREE.Group();
  private walls: Wall[] = [];
  bounds = new THREE.Box3();

  constructor(private bank: MaterialBank) {
    this.bank.plank.repeat.set(1 / 1.2, 1 / 1.2);
  }

  build(room: RoomNode, openings: OpeningNode[]): void {
    this.dispose();
    const c = room.corners;
    const shape = new THREE.Shape(c.map(([x, z]) => new THREE.Vector2(x, -z)));
    const floor = new THREE.Mesh(new THREE.ShapeGeometry(shape), this.bank.floor(room.floorFinish));
    floor.rotation.x = -Math.PI / 2;
    floor.receiveShadow = true;
    floor.userData.floor = true;
    this.group.add(floor);

    const wallColor = this.bank.wallColor(room.wallFinish);
    for (let i = 0; i < c.length; i++) {
      const a = new THREE.Vector2(...c[i]);
      const b = new THREE.Vector2(...c[(i + 1) % c.length]);
      const len = a.distanceTo(b);
      const d = b.clone().sub(a).divideScalar(len);
      const n = new THREE.Vector2(-d.y, d.x);
      const angle = Math.atan2(-d.y, d.x);
      const wallMat = new THREE.MeshStandardMaterial({ color: wallColor, roughness: 0.9, transparent: true });
      const frameMat = (this.bank.frame.clone() as THREE.MeshStandardMaterial);
      frameMat.transparent = true;
      const glassMat = (this.bank.glass.clone() as THREE.MeshStandardMaterial);
      glassMat.userData.baseOpacity = glassMat.opacity;
      const g = new THREE.Group();

      const piece = (s: number, e: number, y0: number, y1: number, mat: THREE.Material, depth = T) => {
        if (e - s <= 1e-4 || y1 - y0 <= 1e-4) return;
        const ext0 = s <= 1e-6 ? T / 2 : 0;
        const ext1 = e >= len - 1e-6 ? T / 2 : 0;
        const m = new THREE.Mesh(UNIT, mat);
        m.scale.set(e - s + ext0 + ext1, y1 - y0, depth);
        const mid = (s - ext0 + e + ext1) / 2;
        m.position.set(a.x + d.x * mid, (y0 + y1) / 2, a.y + d.y * mid);
        m.rotation.y = angle;
        m.castShadow = m.receiveShadow = true;
        g.add(m);
        return m;
      };

      const here = openings.filter((o) => o.wallIndex === i).sort((x, y) => x.offset - y.offset);
      let from = 0;
      for (const o of here) {
        const s = Math.max(0, o.offset - o.width / 2);
        const e = Math.min(len, o.offset + o.width / 2);
        piece(from, s, 0, room.wallHeight, wallMat);
        piece(s, e, Math.min(room.wallHeight, o.sillHeight + o.height), room.wallHeight, wallMat);
        if (o.kind === 'window') piece(s, e, 0, o.sillHeight, wallMat);
        this.frame(g, o, a, d, n, angle, frameMat, glassMat);
        from = Math.max(from, e);
      }
      piece(from, len, 0, room.wallHeight, wallMat);

      const centre = new THREE.Vector3((a.x + b.x) / 2, room.wallHeight / 2, (a.y + b.y) / 2);
      this.walls.push({ group: g, outward: new THREE.Vector3(-n.x, 0, -n.y), centre, materials: [wallMat, frameMat, glassMat], faded: false });
      this.group.add(g);
    }
    this.bounds = new THREE.Box3().setFromObject(this.group);
  }

  private frame(
    g: THREE.Group,
    o: OpeningNode,
    a: THREE.Vector2,
    d: THREE.Vector2,
    n: THREE.Vector2,
    angle: number,
    frameMat: THREE.Material,
    glassMat: THREE.Material,
  ): void {
    const at = (along: number, y: number, inward = 0) =>
      new THREE.Vector3(a.x + d.x * along + n.x * inward, y, a.y + d.y * along + n.y * inward);
    const bar = (len: number, h: number, depth: number, pos: THREE.Vector3, mat: THREE.Material, rot = angle) => {
      const m = new THREE.Mesh(UNIT, mat);
      m.scale.set(len, h, depth);
      m.position.copy(pos);
      m.rotation.y = rot;
      m.castShadow = true;
      m.userData.opening = o.id;
      g.add(m);
      return m;
    };
    const s = o.offset - o.width / 2;
    const e = o.offset + o.width / 2;
    const top = o.sillHeight + o.height;
    const f = 0.05;
    bar(f, o.height, T + 0.04, at(s + f / 2, o.sillHeight + o.height / 2), frameMat);
    bar(f, o.height, T + 0.04, at(e - f / 2, o.sillHeight + o.height / 2), frameMat);
    bar(o.width, f, T + 0.04, at(o.offset, top - f / 2), frameMat);
    if (o.kind === 'window') {
      bar(o.width, f, T + 0.04, at(o.offset, o.sillHeight + f / 2), frameMat);
      bar(o.width - 2 * f, o.height - 2 * f, 0.012, at(o.offset, o.sillHeight + o.height / 2), glassMat);
      bar(0.025, o.height - 2 * f, 0.03, at(o.offset, o.sillHeight + o.height / 2), frameMat);
      return;
    }
    // Door leaf standing ajar at 60 degrees into the room, hinged at the start.
    const swing = (60 * Math.PI) / 180;
    const dir = new THREE.Vector2(d.x * Math.cos(swing) + n.x * Math.sin(swing), d.y * Math.cos(swing) + n.y * Math.sin(swing));
    const leafLen = o.width - 2 * f;
    const hinge = at(s + f, 0, T / 2);
    const leaf = bar(leafLen, o.height - f - 0.01, 0.04, new THREE.Vector3(hinge.x + (dir.x * leafLen) / 2, (o.height - f) / 2, hinge.z + (dir.y * leafLen) / 2), frameMat, Math.atan2(-dir.y, dir.x));
    leaf.receiveShadow = true;
  }

  /** Fades walls whose outer side faces the camera. Returns true if any changed. */
  updateCutaway(camera: THREE.Camera): boolean {
    let changed = false;
    this.walls.forEach((w, i) => {
      const toCam = camera.position.clone().sub(w.centre);
      toCam.y = 0;
      const fade = w.outward.dot(toCam) > 0.05;
      if (fade === w.faded) return;
      w.faded = fade;
      changed = true;
      const from = w.materials.map((m) => m.opacity);
      tween(`wall${i}`, 150, (k) => {
        w.materials.forEach((m, j) => {
          const full = (m.userData.baseOpacity as number | undefined) ?? 1;
          const target = fade ? CUTAWAY * full : full;
          m.opacity = from[j] + (target - from[j]) * k;
          m.depthWrite = m.opacity > 0.99;
        });
      });
    });
    return changed;
  }

  dispose(): void {
    this.group.traverse((o) => {
      const m = o as THREE.Mesh;
      if (m.isMesh && m.geometry !== UNIT) m.geometry.dispose();
    });
    this.group.clear();
    this.walls = [];
  }
}
