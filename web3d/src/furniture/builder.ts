import * as THREE from 'three';
import type { MaterialBank } from '../materials';

const UNIT_BOX = new THREE.BoxGeometry(1, 1, 1);
const cylinders = new Map<string, THREE.CylinderGeometry>();

function cylinder(topRatio: number, segments: number): THREE.CylinderGeometry {
  const key = `${topRatio.toFixed(3)}:${segments}`;
  let g = cylinders.get(key);
  if (!g) {
    g = new THREE.CylinderGeometry(topRatio, 1, 1, segments);
    cylinders.set(key, g);
  }
  return g;
}

/** 'M' is the item's finish; parts in it are re-tinted for warnings. */
export type Mat = 'M' | THREE.Material;

/**
 * Builds a model from boxes and cylinders. The origin is the footprint centre
 * on the floor; width runs along x, depth along z, and the front faces +z.
 */
export class Builder {
  readonly group = new THREE.Group();

  constructor(
    readonly bank: MaterialBank,
    readonly finish: string,
    readonly w: number,
    readonly d: number,
    readonly h: number,
  ) {}

  private add(geometry: THREE.BufferGeometry, mat: Mat): THREE.Mesh {
    const m = new THREE.Mesh(geometry, mat === 'M' ? this.bank.finish(this.finish) : mat);
    m.castShadow = true;
    m.receiveShadow = true;
    if (mat === 'M') m.userData.finish = true;
    this.group.add(m);
    return m;
  }

  /** A box with its bottom at [y]. */
  box(sx: number, sy: number, sz: number, x: number, y: number, z: number, mat: Mat): THREE.Mesh {
    const m = this.add(UNIT_BOX, mat);
    m.scale.set(sx, sy, sz);
    m.position.set(x, y + sy / 2, z);
    return m;
  }

  /** A cylinder (optionally tapered) with its bottom at [y]. */
  cyl(rBottom: number, height: number, x: number, y: number, z: number, mat: Mat, rTop = rBottom, segments = 20): THREE.Mesh {
    const m = this.add(cylinder(rTop / rBottom, segments), mat);
    m.scale.set(rBottom, height, rBottom);
    m.position.set(x, y + height / 2, z);
    return m;
  }

  /** Four square legs inset from the footprint corners. */
  legs(size: number, height: number, inset: number, mat: Mat, y = 0): void {
    const x = this.w / 2 - inset - size / 2;
    const z = this.d / 2 - inset - size / 2;
    for (const [sx, sz] of [[-1, -1], [1, -1], [-1, 1], [1, 1]]) {
      this.box(size, height, size, sx * x, y, sz * z, mat);
    }
  }
}

export type FurnitureFn = (b: Builder) => void;
