import * as THREE from 'three';
import type { FurnitureFn } from './builder';

const LEAF = new THREE.IcosahedronGeometry(1, 1);

export const plant: FurnitureFn = (b) => {
  const r = b.w / 2;
  b.cyl(r * 0.72, 0.36, 0, 0, 0, 'M', r * 0.9);
  b.cyl(r * 0.8, 0.02, 0, 0.34, 0, b.bank.darkWood);
  const clusters: [number, number, number, number, THREE.Material][] = [
    [0, 0.62, 0, 0.2, b.bank.leafA],
    [-0.07, 0.8, 0.04, 0.15, b.bank.leafB],
    [0.06, 0.89, -0.03, 0.11, b.bank.leafC],
  ];
  for (const [x, y, z, s, m] of clusters) {
    const leaf = new THREE.Mesh(LEAF, m);
    leaf.position.set(x, y, z);
    leaf.scale.set(s, s * 1.15, s);
    leaf.castShadow = leaf.receiveShadow = true;
    b.group.add(leaf);
  }
};
