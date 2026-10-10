import * as THREE from 'three';
import type { OrbitControls } from 'three/examples/jsm/controls/OrbitControls.js';
import { send } from './bridge';
import type { SceneView } from './scene';

const DRAG_PX = 6;
const DRAG_MS = 150;
const TAP_MS = 300;
const DOUBLE_PX = 20;

/**
 * Touch handling in editor mode. A drag never moves the camera and a camera
 * gesture never moves an item: a pointer that lands on an item disables the
 * orbit controls until it lifts, and a second finger cancels the drag.
 */
export class Interaction {
  editable = true;
  private raycaster = new THREE.Raycaster();
  private floor = new THREE.Plane(new THREE.Vector3(0, 1, 0), 0);
  private pointers = new Map<number, { x: number; y: number }>();
  private down: { x: number; y: number; t: number; id: string | null } | null = null;
  private dragging: string | null = null;
  private grab = new THREE.Vector3();
  private start = new THREE.Vector3();
  private pending: { x: number; z: number } | null = null;
  private lastTap = { x: -999, y: -999, t: 0 };
  private holdTimer = 0;

  constructor(
    private el: HTMLElement,
    private camera: THREE.PerspectiveCamera,
    public controls: OrbitControls,
    public view: SceneView,
    private onChange: () => void,
    private onDoubleTap: () => void,
  ) {
    // Registered before the orbit controls so we can disable them first.
    el.addEventListener('pointerdown', this.onDown, { capture: true });
    el.addEventListener('pointermove', this.onMove);
    el.addEventListener('pointerup', this.onUp);
    el.addEventListener('pointercancel', this.onUp);
  }

  private ndc(x: number, y: number): THREE.Vector2 {
    const r = this.el.getBoundingClientRect();
    return new THREE.Vector2(((x - r.left) / r.width) * 2 - 1, -((y - r.top) / r.height) * 2 + 1);
  }

  /** The item (or door or window) under a screen point. */
  pick(x: number, y: number): string | null {
    this.raycaster.setFromCamera(this.ndc(x, y), this.camera);
    const hits = this.raycaster.intersectObjects([...this.view.items.objects(), this.view.room.group], true);
    for (const h of hits) {
      const id = this.view.items.owner(h.object);
      if (id) return id;
      const opening = h.object.userData.opening as string | undefined;
      if (opening) return opening;
      if (h.object.userData.floor) return null;
    }
    return null;
  }

  private floorPoint(x: number, y: number): THREE.Vector3 | null {
    this.raycaster.setFromCamera(this.ndc(x, y), this.camera);
    return this.raycaster.ray.intersectPlane(this.floor, new THREE.Vector3());
  }

  private onDown = (e: PointerEvent): void => {
    this.pointers.set(e.pointerId, { x: e.clientX, y: e.clientY });
    if (this.pointers.size > 1) {
      // A second finger: cancel any drag and hand over to the camera.
      if (this.dragging) {
        const id = this.dragging;
        this.dragging = null;
        this.view.dragging = null;
        this.view.restore(id);
        send('drag.cancel', { id });
      }
      this.down = null;
      window.clearTimeout(this.holdTimer);
      this.controls.enabled = true;
      this.onChange();
      return;
    }
    if (!this.editable) {
      this.down = { x: e.clientX, y: e.clientY, t: performance.now(), id: null };
      return;
    }
    const id = this.pick(e.clientX, e.clientY);
    const isItem = id !== null && this.view.items.get(id) !== undefined;
    this.down = { x: e.clientX, y: e.clientY, t: performance.now(), id };
    if (isItem) {
      this.controls.enabled = false;
      this.holdTimer = window.setTimeout(() => this.beginDrag(e.clientX, e.clientY), DRAG_MS);
    }
  };

  private beginDrag(x: number, y: number): void {
    const d = this.down;
    if (!d || !d.id || this.dragging || this.pointers.size !== 1) return;
    const obj = this.view.items.get(d.id);
    const hit = this.floorPoint(x, y);
    if (!obj || !hit) return;
    this.dragging = d.id;
    this.view.dragging = d.id;
    this.start.copy(obj.position);
    this.grab.copy(hit).sub(obj.position);
    send('drag.start', { id: d.id });
  }

  private onMove = (e: PointerEvent): void => {
    if (!this.pointers.has(e.pointerId)) return;
    this.pointers.set(e.pointerId, { x: e.clientX, y: e.clientY });
    const d = this.down;
    if (!d || this.pointers.size !== 1) return;
    if (!this.dragging && d.id && this.view.items.get(d.id) && Math.hypot(e.clientX - d.x, e.clientY - d.y) > DRAG_PX) {
      window.clearTimeout(this.holdTimer);
      this.beginDrag(d.x, d.y);
    }
    if (!this.dragging) return;
    const hit = this.floorPoint(e.clientX, e.clientY);
    const obj = this.view.items.get(this.dragging);
    if (!hit || !obj) return;
    const centre = hit.sub(this.grab);
    // Optimistic: follow the finger now; Flutter's snapped preview corrects it.
    obj.position.set(centre.x, 0, centre.z);
    this.onChange();
    if (!this.pending) requestAnimationFrame(this.flush);
    this.pending = { x: centre.x, z: centre.z };
  };

  /** At most one drag.move per frame. */
  private flush = (): void => {
    const p = this.pending;
    this.pending = null;
    if (p && this.dragging) send('drag.move', { id: this.dragging, x: round(p.x), z: round(p.z) });
  };

  private onUp = (e: PointerEvent): void => {
    this.pointers.delete(e.pointerId);
    window.clearTimeout(this.holdTimer);
    if (this.pointers.size > 0) return;
    const d = this.down;
    this.down = null;
    if (this.dragging) {
      this.flush();
      send('drag.end', { id: this.dragging });
      this.dragging = null;
      this.view.dragging = null;
      this.controls.enabled = true;
      return;
    }
    this.controls.enabled = true;
    if (!d || e.type === 'pointercancel') return;
    const quick = performance.now() - d.t <= TAP_MS && Math.hypot(e.clientX - d.x, e.clientY - d.y) <= DRAG_PX;
    if (!quick) return;
    if (d.id === null) {
      const now = performance.now();
      const again = now - this.lastTap.t <= TAP_MS && Math.hypot(e.clientX - this.lastTap.x, e.clientY - this.lastTap.y) <= DOUBLE_PX;
      this.lastTap = again ? { x: -999, y: -999, t: 0 } : { x: e.clientX, y: e.clientY, t: now };
      if (again) {
        this.onDoubleTap();
        return;
      }
    }
    if (this.editable) send('tap', { id: d.id });
  };
}

const round = (v: number) => Math.round(v * 1000) / 1000;
