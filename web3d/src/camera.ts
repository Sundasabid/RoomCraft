import * as THREE from 'three';
import type { OrbitControls } from 'three/examples/jsm/controls/OrbitControls.js';
import { easeInOut, tween } from './anim';

export type Preset = 'corner' | 'top' | 'eye';

/** Camera presets fitted to the room's bounding box and centroid. */
export class CameraRig {
  preset: Preset = 'corner';
  private box = new THREE.Box3(new THREE.Vector3(0, 0, 0), new THREE.Vector3(4, 2.6, 4));
  private centroid = new THREE.Vector2(2, 2);
  /** Scores an eye position: higher is a clearer place to stand. */
  private eyeScore: (p: THREE.Vector2) => number = () => 0;

  constructor(
    private camera: THREE.PerspectiveCamera,
    private controls: OrbitControls,
  ) {}

  fit(box: THREE.Box3, centroid: THREE.Vector2, eyeScore?: (p: THREE.Vector2) => number): void {
    this.box = box.clone();
    this.centroid = centroid.clone();
    if (eyeScore) this.eyeScore = eyeScore;
    const size = box.getSize(new THREE.Vector3());
    const diagonal = Math.hypot(size.x, size.z);
    this.controls.minDistance = 1.5;
    this.controls.maxDistance = Math.max(4, 2.2 * diagonal);
  }

  private pose(name: Preset): { pos: THREE.Vector3; target: THREE.Vector3 } {
    const size = this.box.getSize(new THREE.Vector3());
    const w = size.x;
    const l = size.z;
    const cx = this.centroid.x;
    const cz = this.centroid.y;
    const d = 1.2 * Math.max(w, l);
    switch (name) {
      case 'top':
        return {
          pos: new THREE.Vector3(cx, 1.6 * Math.hypot(w, l), cz + 0.001),
          target: new THREE.Vector3(cx, 0, cz),
        };
      case 'eye': {
        // Stand in the clearest of the four quarter points (away from doors
        // and furniture) and look across the room.
        const options = [
          [-1, 1],
          [1, 1],
          [-1, -1],
          [1, -1],
        ].map(([sx, sz]) => new THREE.Vector2(cx + sx * 0.4 * w, cz + sz * 0.4 * l));
        let best = options[0];
        let bestScore = -Infinity;
        for (const p of options) {
          const score = this.eyeScore(p);
          if (score > bestScore + 1e-6) {
            best = p;
            bestScore = score;
          }
        }
        const look = new THREE.Vector2(cx, cz).sub(best).multiplyScalar(0.25).add(new THREE.Vector2(cx, cz));
        return {
          pos: new THREE.Vector3(best.x, 1.5, best.y),
          target: new THREE.Vector3(look.x, 1.1, look.y),
        };
      }
      default:
        return {
          pos: new THREE.Vector3(cx + 0.8 * d, 0.9 * d, cz + 0.9 * d),
          target: new THREE.Vector3(cx, 0.4, cz),
        };
    }
  }

  /** Moves to a preset over 400 ms (instant when [animate] is false). */
  go(name: Preset, animate = true): void {
    this.preset = name;
    const { pos, target } = this.pose(name);
    this.moveTo(pos, target, animate ? 400 : 0);
  }

  /** Frames a set of objects from the current viewing direction. */
  focus(objects: THREE.Object3D[]): void {
    if (!objects.length) return;
    const box = new THREE.Box3();
    for (const o of objects) box.expandByObject(o);
    const centre = box.getCenter(new THREE.Vector3());
    const radius = Math.max(0.8, box.getSize(new THREE.Vector3()).length() / 2);
    const dir = this.camera.position.clone().sub(this.controls.target).normalize();
    const dist = Math.min(this.controls.maxDistance, Math.max(this.controls.minDistance, radius * 2.6));
    this.moveTo(centre.clone().add(dir.multiplyScalar(dist)), centre, 400);
  }

  private moveTo(pos: THREE.Vector3, target: THREE.Vector3, ms: number): void {
    const p0 = this.camera.position.clone();
    const t0 = this.controls.target.clone();
    tween(
      'camera',
      ms,
      (k) => {
        this.camera.position.lerpVectors(p0, pos, k);
        this.controls.target.lerpVectors(t0, target, k);
        this.controls.update();
      },
      easeInOut,
    );
  }
}
