import * as THREE from 'three';
import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls.js';
import { setReduceMotion, tick } from './anim';
import { on, send } from './bridge';
import { CameraRig, type Preset } from './camera';
import { Interaction } from './interaction';
import { RoomLighting } from './lighting';
import { MaterialBank } from './materials';
import { SceneView } from './scene';
import type { CatalogueEntry, FinishDef, ItemNode, Palette, SceneData, SceneNode } from './types';

// --- Renderer -----------------------------------------------------------

let renderer: THREE.WebGLRenderer;
try {
  renderer = new THREE.WebGLRenderer({ antialias: true, powerPreference: 'high-performance' });
} catch (e) {
  send('error', { message: 'webgl-unavailable', fatal: true });
  throw e;
}
let pixelRatio = Math.min(window.devicePixelRatio, 2);
renderer.setPixelRatio(pixelRatio);
renderer.outputColorSpace = THREE.SRGBColorSpace;
renderer.toneMapping = THREE.NoToneMapping;
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
document.body.appendChild(renderer.domElement);

renderer.domElement.addEventListener('webglcontextlost', (e) => {
  e.preventDefault();
  send('error', { message: 'context-lost' });
});

const scene = new THREE.Scene();
scene.background = new THREE.Color('#f5efe6');

const camera = new THREE.PerspectiveCamera(45, 1, 0.05, 200);
camera.position.set(6, 5, 6);

// Interaction must register its listeners before the orbit controls.
let needsRender = true;
const requestRender = () => {
  needsRender = true;
};

let view: SceneView | null = null;
let bank: MaterialBank | null = null;
let catalogueById = new Map<string, CatalogueEntry>();
// Brighter than the first draft values: three.js uses physical light units.
const lighting = new RoomLighting(scene, (k) => bank?.setGlow(k), requestRender);
let interaction: Interaction | null = null;
let controls: OrbitControls | null = null;
let rig: CameraRig | null = null;
let selected: string | null = null;

// --- Messages from Flutter -----------------------------------------------

on('init', (m) => {
  const palette = m.palette as Palette;
  const catalogue = new Map((m.catalogue as CatalogueEntry[]).map((c) => [c.id, c]));
  catalogueById = catalogue;
  bank = new MaterialBank(m.finishes as FinishDef[]);
  const viewer = m.mode === 'viewer';
  setReduceMotion(Boolean(m.reduceMotion));
  scene.background = new THREE.Color(palette.background);

  if (view) scene.remove(view.root);
  view = new SceneView(bank, catalogue, palette, viewer, requestRender);
  scene.add(view.root);

  if (!controls) {
    interaction = new Interaction(renderer.domElement, camera, null as unknown as OrbitControls, view, requestRender, () => rig?.go('corner'));
    controls = new OrbitControls(camera, renderer.domElement);
    controls.enableDamping = true;
    controls.dampingFactor = 0.08;
    controls.maxPolarAngle = Math.PI / 2 - 0.05;
    controls.screenSpacePanning = true;
    controls.touches = { ONE: THREE.TOUCH.ROTATE, TWO: THREE.TOUCH.DOLLY_PAN };
    controls.addEventListener('change', () => {
      requestRender();
      reportSelection();
    });
    interaction.controls = controls;
    rig = new CameraRig(camera, controls);
  } else {
    interaction!.view = view;
  }
  interaction!.editable = !viewer;

  view.replace(m.scene as SceneData);
  fitToRoom(true);
  syncLighting(false);
  if (m.debug) showFps();
  requestRender();
});

on('scene.replace', (m) => {
  view?.replace(m.scene as SceneData);
  fitToRoom(false);
  syncLighting(true);
});

on('scene.patch', (m) => {
  const roomBefore = JSON.stringify(view?.roomNode?.corners);
  view?.patch((m.upserts as SceneNode[]) ?? [], (m.removes as string[]) ?? []);
  if (JSON.stringify(view?.roomNode?.corners) !== roomBefore) fitToRoom(false);
  syncLighting(true);
  reportSelection();
});

on('item.preview', (m) => view?.preview(m.id as string, m.x as number, m.z as number));

on('selection.set', (m) => {
  const ids = (m.ids as string[]) ?? [];
  selected = ids[0] ?? null;
  view?.setSelection(ids);
  reportSelection(true);
});

on('warnings.set', (m) => view?.setWarnings((m.ids as string[]) ?? []));
on('draft.show', (m) => view?.showDraft((m.items as ItemNode[]) ?? []));
on('draft.hide', () => view?.hideDraft());
on('camera.preset', (m) => rig?.go(m.name as Preset));

on('camera.focus', (m) => {
  const ids = (m.ids as string[]) ?? [];
  const objs = ids.map((id) => view?.items.get(id)).filter((o): o is THREE.Object3D => !!o);
  rig?.focus(objs);
  view?.pulse(ids);
});

on('theme.set', (m) => {
  scene.background = new THREE.Color((m.palette as Palette).background);
  requestRender();
});

/** The room's mood, and a light for each floor lamp. */
function syncLighting(animate: boolean): void {
  if (!view) return;
  lighting.set(view.roomNode?.lighting ?? 'day', animate);
  lighting.refresh();
  const lamp = catalogueById.get('floor_lamp');
  lighting.syncLamps(view.itemNodes(), (lamp?.height ?? 1.6) - 0.15);
}

/** Clearance of a standing point: inside the room, far from doors and furniture. */
function eyeScore(p: THREE.Vector2): number {
  if (!view) return 0;
  const room = view.roomNode!;
  const c = room.corners;
  let inside = false;
  for (let i = 0, j = c.length - 1; i < c.length; j = i++) {
    const [xi, zi] = c[i];
    const [xj, zj] = c[j];
    if (zi > p.y !== zj > p.y && p.x < ((xj - xi) * (p.y - zi)) / (zj - zi) + xi) inside = !inside;
  }
  if (!inside) return -1000;
  let score = 0;
  for (const d of view.doorCentres()) score += Math.min(2, d.distanceTo(p)) * 2;
  const eye = new THREE.Vector3(p.x, 1.5, p.y);
  const box = new THREE.Box3();
  for (const obj of view.items.objects()) {
    box.setFromObject(obj);
    score += Math.min(1, box.distanceToPoint(eye));
  }
  return score;
}

/** Fits the camera limits and the sun's shadow box to the room. */
function fitToRoom(resetCamera: boolean): void {
  if (!view || !rig || !controls) return;
  const box = view.room.bounds;
  if (box.isEmpty()) return;
  const room = view.roomNode!;
  const c = room.corners;
  let area = 0;
  let cx = 0;
  let cz = 0;
  for (let i = 0; i < c.length; i++) {
    const [x0, z0] = c[i];
    const [x1, z1] = c[(i + 1) % c.length];
    const cross = x0 * z1 - x1 * z0;
    area += cross;
    cx += (x0 + x1) * cross;
    cz += (z0 + z1) * cross;
  }
  area /= 2;
  const centroid = new THREE.Vector2(cx / (6 * area), cz / (6 * area));
  rig.fit(box, centroid, (p) => eyeScore(p));

  const size = box.getSize(new THREE.Vector3());
  lighting.fit(centroid, Math.max(size.x, size.z), room.wallHeight);
  if (resetCamera) rig.go(rig.preset, false);
  requestRender();
}

// --- Selection position for the floating action bar ----------------------

let lastReport = 0;
function reportSelection(force = false): void {
  if (!view || !selected || !view.items.get(selected)) return;
  const now = performance.now();
  if (!force && now - lastReport < 33) return;
  lastReport = now;
  const p = view.screenTop(selected, camera, window.innerWidth, window.innerHeight);
  if (p) send('selection.screen', { id: selected, x: Math.round(p.x), y: Math.round(p.y), visible: p.visible });
}

// --- Loop: render only when something changed ----------------------------

function resize(): void {
  const w = window.innerWidth;
  const h = window.innerHeight;
  renderer.setSize(w, h, false);
  camera.aspect = w / Math.max(h, 1);
  camera.updateProjectionMatrix();
  requestRender();
  reportSelection(true);
}
window.addEventListener('resize', resize);
resize();

// Adaptive quality: if frames average above 33 ms for 2 s, step down once
// at a time (pixel ratio 1.5, then 1.0, then no shadows) and never step up.
let slowSince = 0;
let frameTimes: number[] = [];
let quality = 0;
function adapt(dt: number, now: number): void {
  frameTimes.push(dt);
  if (frameTimes.length > 120) frameTimes.shift();
  const avg = frameTimes.reduce((a, b) => a + b, 0) / frameTimes.length;
  if (avg <= 33 || frameTimes.length < 30) {
    slowSince = 0;
    return;
  }
  if (!slowSince) slowSince = now;
  if (now - slowSince < 2000 || quality >= 3) return;
  quality++;
  slowSince = 0;
  frameTimes = [];
  if (quality === 1) pixelRatio = Math.min(pixelRatio, 1.5);
  if (quality === 2) pixelRatio = 1;
  if (quality === 3) renderer.shadowMap.enabled = false;
  renderer.setPixelRatio(pixelRatio);
  resize();
}

let fpsEl: HTMLDivElement | null = null;
let frames = 0;
let fpsAt = performance.now();
function showFps(): void {
  if (fpsEl) return;
  fpsEl = document.createElement('div');
  fpsEl.id = 'fps';
  document.body.appendChild(fpsEl);
}

let last = performance.now();
function loop(now: number): void {
  requestAnimationFrame(loop);
  const animating = tick(now);
  const moving = controls?.update() ?? false;
  if (view && view.room.updateCutaway(camera)) needsRender = true;
  if (!needsRender && !animating && !moving) {
    last = now;
    return;
  }
  view?.hideNear(camera.position);
  needsRender = false;
  renderer.render(scene, camera);
  const dt = now - last;
  last = now;
  if (animating || moving) adapt(dt, now);
  if (moving) reportSelection();
  frames++;
  if (fpsEl && now - fpsAt > 500) {
    fpsEl.textContent = `${Math.round((frames * 1000) / (now - fpsAt))} fps`;
    frames = 0;
    fpsAt = now;
  }
}
requestAnimationFrame(loop);

send('ready');
