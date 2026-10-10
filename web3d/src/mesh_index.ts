import type * as THREE from 'three';

/** Node id to its 3D object, used for updates and picking. */
export class MeshIndex {
  private map = new Map<string, THREE.Object3D>();

  set(id: string, obj: THREE.Object3D): void {
    obj.userData.id = id;
    this.map.set(id, obj);
  }

  get(id: string): THREE.Object3D | undefined {
    return this.map.get(id);
  }

  delete(id: string): void {
    this.map.delete(id);
  }

  ids(): string[] {
    return [...this.map.keys()];
  }

  objects(): THREE.Object3D[] {
    return [...this.map.values()];
  }

  /** The indexed object an arbitrary mesh belongs to. */
  owner(obj: THREE.Object3D | null): string | null {
    for (let o = obj; o; o = o.parent) {
      const id = o.userData.id as string | undefined;
      if (id && this.map.get(id) === o) return id;
    }
    return null;
  }
}
