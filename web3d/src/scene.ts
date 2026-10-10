import * as THREE from 'three';
import { tween } from './anim';
import { buildFurniture } from './furniture';
import { hatchTexture, type MaterialBank } from './materials';
import { MeshIndex } from './mesh_index';
import { RoomView } from './room';
import type { CatalogueEntry, ItemNode, OpeningNode, Palette, RoomNode, SceneData, SceneNode } from './types';

const PLANE = new THREE.PlaneGeometry(1, 1).rotateX(-Math.PI / 2);

/**
 * Draws whatever scene Flutter sends. Holds no truth of its own: every change
 * arrives as a full replace or as a patch of changed ids.
 */
export class SceneView {
  readonly root = new THREE.Group();
  readonly room: RoomView;
  readonly items = new MeshIndex();
  private itemsGroup = new THREE.Group();
  private draftGroup = new THREE.Group();
  private nodes = new Map<string, SceneNode>();
  private selection = new Set<string>();
  private warnings = new Set<string>();
  private selectFill: THREE.MeshBasicMaterial;
  private selectLine: THREE.LineBasicMaterial;
  private hatch: THREE.MeshBasicMaterial;
  /** Item being dragged here; patches leave its position alone. */
  dragging: string | null = null;

  constructor(
    private bank: MaterialBank,
    private catalogue: Map<string, CatalogueEntry>,
    palette: Palette,
    private viewer: boolean,
    private onChange: () => void,
  ) {
    this.room = new RoomView(bank);
    this.selectFill = new THREE.MeshBasicMaterial({ color: palette.primary, transparent: true, opacity: 0.25, depthWrite: false });
    this.selectLine = new THREE.LineBasicMaterial({ color: palette.primary });
    this.hatch = new THREE.MeshBasicMaterial({ map: hatchTexture(palette.warning), transparent: true, opacity: 0.85, depthWrite: false });
    this.root.add(this.room.group, this.itemsGroup, this.draftGroup);
  }

  /** Every furniture node, for lights that follow items such as lamps. */
  itemNodes(): ItemNode[] {
    return [...this.nodes.values()].filter((n): n is ItemNode => n.type === 'item');
  }

  get roomNode(): RoomNode | undefined {
    for (const n of this.nodes.values()) if (n.type === 'room') return n;
    return undefined;
  }

  private openingNodes(): OpeningNode[] {
    return [...this.nodes.values()].filter((n): n is OpeningNode => n.type === 'opening');
  }

  /** Door centres on the plan, for choosing a clear eye-level spot. */
  doorCentres(): THREE.Vector2[] {
    const room = this.roomNode;
    if (!room) return [];
    const c = room.corners;
    return this.openingNodes()
      .filter((o) => o.kind === 'door')
      .map((o) => {
        const a = new THREE.Vector2(...c[o.wallIndex]);
        const b = new THREE.Vector2(...c[(o.wallIndex + 1) % c.length]);
        return b.sub(a).normalize().multiplyScalar(o.offset).add(a);
      });
  }

  replace(data: SceneData): void {
    for (const id of this.items.ids()) this.removeItem(id);
    this.nodes = new Map(Object.entries(data.nodes));
    this.rebuildRoom();
    for (const n of this.nodes.values()) if (n.type === 'item') this.addItem(n, false);
    this.applyStates();
  }

  /** Rebuilds only the changed ids. */
  patch(upserts: SceneNode[], removes: string[]): void {
    let roomChanged = false;
    for (const id of removes) {
      const n = this.nodes.get(id);
      this.nodes.delete(id);
      if (n?.type === 'item') this.removeItem(id, true);
      if (n?.type === 'opening') roomChanged = true;
    }
    for (const n of upserts) {
      const before = this.nodes.get(n.id);
      this.nodes.set(n.id, n);
      if (n.type !== 'item') {
        roomChanged = true;
        continue;
      }
      const prev = before?.type === 'item' ? before : undefined;
      const obj = this.items.get(n.id);
      if (!obj || !prev || prev.catalogueId !== n.catalogueId || prev.finish !== n.finish || prev.locked !== n.locked) {
        const pos = obj?.position.clone();
        if (obj) this.removeItem(n.id);
        const created = this.addItem(n, !prev);
        // A finish change keeps the item where it was on screen.
        if (pos && prev && prev.finish !== n.finish) created.position.copy(pos);
      }
      this.place(n, this.viewer);
    }
    if (roomChanged) this.rebuildRoom();
    this.applyStates();
  }

  private rebuildRoom(): void {
    const room = this.roomNode;
    if (room) this.room.build(room, this.openingNodes());
  }

  private addItem(n: ItemNode, pop: boolean): THREE.Object3D {
    const entry = this.catalogue.get(n.catalogueId);
    const root = new THREE.Group();
    if (entry) {
      const model = buildFurniture(entry, n.finish, this.bank);
      model.traverse((o) => {
        const m = o as THREE.Mesh;
        if (m.isMesh) m.userData.baseMat = m.material;
      });
      root.add(model);
      root.userData.model = model;
    }
    root.position.set(n.x, 0, n.z);
    root.rotation.y = (-n.rotation * Math.PI) / 180;
    root.visible = n.visible !== false;
    this.items.set(n.id, root);
    this.itemsGroup.add(root);
    if (pop) {
      tween(`pop${n.id}`, 150, (k) => {
        const s = k < 0.66 ? 0.8 + (1.05 - 0.8) * (k / 0.66) : 1.05 - 0.05 * ((k - 0.66) / 0.34);
        root.scale.setScalar(s);
        this.onChange();
      });
    }
    return root;
  }

  private removeItem(id: string, fade = false): void {
    const obj = this.items.get(id);
    if (!obj) return;
    this.items.delete(id);
    if (!fade) {
      this.itemsGroup.remove(obj);
      return;
    }
    tween(`del${id}`, 150, (k) => obj.scale.setScalar(1 - 0.1 * k), undefined, () => this.itemsGroup.remove(obj));
  }

  /** Moves an item to its node position; glides in viewer mode. */
  private place(n: ItemNode, glide: boolean): void {
    const obj = this.items.get(n.id);
    if (!obj || n.id === this.dragging) return;
    const rot = (-n.rotation * Math.PI) / 180;
    const target = new THREE.Vector3(n.x, 0, n.z);
    if (!glide) {
      obj.position.copy(target);
      obj.rotation.y = rot;
      return;
    }
    const p0 = obj.position.clone();
    const r0 = obj.rotation.y;
    tween(`glide${n.id}`, 200, (k) => {
      obj.position.lerpVectors(p0, target, k);
      obj.rotation.y = r0 + (rot - r0) * k;
      this.onChange();
    });
  }

  /** Snapped transient position from Flutter while an item is dragged. */
  preview(id: string, x: number, z: number): void {
    const obj = this.items.get(id);
    if (!obj) return;
    if (this.viewer) {
      const p0 = obj.position.clone();
      tween(`glide${id}`, 100, (k) => {
        obj.position.lerpVectors(p0, new THREE.Vector3(x, 0, z), k);
        this.onChange();
      });
      return;
    }
    const p0 = obj.position.clone();
    tween(`snap${id}`, 60, (k) => {
      obj.position.lerpVectors(p0, new THREE.Vector3(x, 0, z), k);
      this.onChange();
    });
  }

  /** Puts a dragged item back where the scene says it is. */
  restore(id: string): void {
    const n = this.nodes.get(id);
    if (n?.type === 'item') this.place(n, false);
  }

  setSelection(ids: string[]): void {
    this.selection = new Set(ids);
    this.applyStates();
  }

  setWarnings(ids: string[]): void {
    const fresh = ids.filter((id) => !this.warnings.has(id));
    this.warnings = new Set(ids);
    this.applyStates();
    this.pulse(fresh);
  }

  /** One soft pulse: scale 1.00, 1.02, 1.00 over 300 ms. */
  pulse(ids: string[]): void {
    for (const id of ids) {
      const obj = this.items.get(id);
      if (!obj) continue;
      tween(`pulse${id}`, 300, (k) => {
        obj.scale.setScalar(1 + 0.02 * Math.sin(k * Math.PI));
        this.onChange();
      });
    }
  }

  /** Re-applies selection footprints, warning tint and draft ghosting. */
  private applyStates(): void {
    for (const id of this.items.ids()) {
      const obj = this.items.get(id)!;
      const n = this.nodes.get(id);
      const finish = n?.type === 'item' ? n.finish : '';
      const warn = this.warnings.has(id);
      const model = obj.userData.model as THREE.Object3D | undefined;
      model?.traverse((o) => {
        const m = o as THREE.Mesh;
        if (!m.isMesh) return;
        let mat = m.userData.baseMat as THREE.Material;
        if (warn && m.userData.finish) mat = this.bank.warning(finish);
        m.material = mat;
      });
      this.decorate(obj, n?.type === 'item' ? n : undefined, warn, this.selection.has(id));
    }
    this.onChange();
  }

  /** Flat sage footprint for selection, hatched terracotta for warnings. */
  private decorate(obj: THREE.Object3D, n: ItemNode | undefined, warn: boolean, selected: boolean): void {
    for (const child of [...obj.children]) if (child.userData.decal) obj.remove(child);
    const entry = n && this.catalogue.get(n.catalogueId);
    if (!entry) return;
    const [w, d] = [entry.width, entry.depth];
    if (selected) {
      const fill = new THREE.Mesh(PLANE, this.selectFill);
      fill.scale.set(w + 0.06, 1, d + 0.06);
      fill.position.y = 0.026;
      fill.userData.decal = true;
      const pts = [[-1, -1], [1, -1], [1, 1], [-1, 1]].map(([sx, sz]) => new THREE.Vector3((sx * (w + 0.06)) / 2, 0.028, (sz * (d + 0.06)) / 2));
      const line = new THREE.LineLoop(new THREE.BufferGeometry().setFromPoints(pts), this.selectLine);
      line.userData.decal = true;
      obj.add(fill, line);
    }
    if (warn) {
      const h = new THREE.Mesh(PLANE, this.hatch);
      h.scale.set(w, 1, d);
      h.position.y = 0.03;
      h.userData.decal = true;
      obj.add(h);
    }
  }

  /**
   * While an AI draft is open, the main scene is the draft (so it can be
   * picked and dragged) and these items, the real layout, are drawn faint
   * underneath at 25 percent with depth writing off.
   */
  showDraft(realItems: ItemNode[]): void {
    this.hideDraft();
    for (const n of realItems) {
      const entry = this.catalogue.get(n.catalogueId);
      if (!entry || n.visible === false) continue;
      const model = buildFurniture(entry, n.finish, this.bank);
      model.traverse((o) => {
        const m = o as THREE.Mesh;
        if (!m.isMesh) return;
        m.material = this.bank.ghost(m.material as THREE.Material);
        m.castShadow = false;
      });
      model.position.set(n.x, 0, n.z);
      model.rotation.y = (-n.rotation * Math.PI) / 180;
      this.draftGroup.add(model);
    }
    this.onChange();
  }

  hideDraft(): void {
    this.draftGroup.clear();
    this.onChange();
  }

  /** Screen point (CSS px) of the top centre of an item. */
  screenTop(id: string, camera: THREE.Camera, width: number, height: number): { x: number; y: number; visible: boolean } | null {
    const obj = this.items.get(id);
    if (!obj) return null;
    const box = new THREE.Box3().setFromObject(obj);
    const top = new THREE.Vector3((box.min.x + box.max.x) / 2, box.max.y, (box.min.z + box.max.z) / 2).project(camera);
    const x = ((top.x + 1) / 2) * width;
    const y = ((1 - top.y) / 2) * height;
    const visible = top.z < 1 && x >= 0 && x <= width && y >= 0 && y <= height;
    return { x, y, visible };
  }

  /** Hides furniture the camera is standing in, so eye level never shows the inside of a lamp. */
  hideNear(eye: THREE.Vector3): boolean {
    let changed = false;
    const box = new THREE.Box3();
    for (const id of this.items.ids()) {
      const obj = this.items.get(id)!;
      const n = this.nodes.get(id);
      if (n?.type !== 'item' || n.visible === false) continue;
      box.setFromObject(obj);
      const near = box.distanceToPoint(eye) < 0.35;
      if (obj.visible === near) {
        obj.visible = !near;
        changed = true;
      }
    }
    return changed;
  }

  setViewer(v: boolean): void {
    this.viewer = v;
  }
}
