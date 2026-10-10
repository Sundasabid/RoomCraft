import * as THREE from 'three';
import type { FinishDef } from './types';

const TERRACOTTA = new THREE.Color('#c8553d');

/** Canvas-drawn planks, greyscale so the floor finish can tint them. */
function plankTexture(): THREE.CanvasTexture {
  const size = 512;
  const canvas = document.createElement('canvas');
  canvas.width = canvas.height = size;
  const g = canvas.getContext('2d')!;
  g.fillStyle = '#ffffff';
  g.fillRect(0, 0, size, size);
  const rows = 6;
  const h = size / rows;
  let seed = 7;
  const rand = () => ((seed = (seed * 16807) % 2147483647) / 2147483647);
  for (let r = 0; r < rows; r++) {
    let x = -rand() * size * 0.6;
    while (x < size) {
      const len = size * (0.45 + rand() * 0.5);
      const shade = 225 + Math.floor(rand() * 30);
      g.fillStyle = `rgb(${shade},${shade},${shade})`;
      g.fillRect(x, r * h, len, h);
      // Grain
      g.strokeStyle = 'rgba(0,0,0,0.035)';
      for (let k = 0; k < 5; k++) {
        const y = r * h + rand() * h;
        g.beginPath();
        g.moveTo(x, y);
        g.bezierCurveTo(x + len * 0.3, y + 3, x + len * 0.6, y - 3, x + len, y);
        g.stroke();
      }
      g.fillStyle = 'rgba(0,0,0,0.18)';
      g.fillRect(x, r * h, 1.5, h);
      x += len;
    }
    g.fillStyle = 'rgba(0,0,0,0.2)';
    g.fillRect(0, r * h, size, 1.5);
  }
  const tex = new THREE.CanvasTexture(canvas);
  tex.wrapS = tex.wrapT = THREE.RepeatWrapping;
  tex.colorSpace = THREE.SRGBColorSpace;
  tex.anisotropy = 4;
  return tex;
}

/** Terracotta 45 degree stripes for warning footprints. */
export function hatchTexture(color: string): THREE.CanvasTexture {
  const canvas = document.createElement('canvas');
  canvas.width = canvas.height = 64;
  const g = canvas.getContext('2d')!;
  g.strokeStyle = color;
  g.lineWidth = 6;
  for (let i = -64; i < 128; i += 16) {
    g.beginPath();
    g.moveTo(i, 64);
    g.lineTo(i + 64, 0);
    g.stroke();
  }
  const tex = new THREE.CanvasTexture(canvas);
  tex.wrapS = tex.wrapT = THREE.RepeatWrapping;
  return tex;
}

/**
 * One shared material per finish, plus cached warning and ghost copies.
 * Nothing here decides anything; it only paints.
 */
export class MaterialBank {
  private finishes = new Map<string, FinishDef>();
  private base = new Map<string, THREE.MeshStandardMaterial>();
  private warned = new Map<string, THREE.MeshStandardMaterial>();
  private ghosts = new Map<string, THREE.Material>();
  readonly plank = plankTexture();

  readonly darkWood = new THREE.MeshStandardMaterial({ color: '#5a4632', roughness: 0.6 });
  readonly white = new THREE.MeshStandardMaterial({ color: '#ffffff', roughness: 0.85 });
  readonly leafA = new THREE.MeshStandardMaterial({ color: '#5f8a5a', roughness: 0.8 });
  readonly leafB = new THREE.MeshStandardMaterial({ color: '#4c7a4f', roughness: 0.8 });
  readonly leafC = new THREE.MeshStandardMaterial({ color: '#79a06e', roughness: 0.8 });
  readonly frame = new THREE.MeshStandardMaterial({ color: '#7a5230', roughness: 0.55 });
  readonly glass = new THREE.MeshStandardMaterial({
    color: '#cfe3e6',
    roughness: 0.05,
    metalness: 0.1,
    transparent: true,
    opacity: 0.35,
    depthWrite: false,
  });
  readonly seam = new THREE.MeshStandardMaterial({ color: '#2f2a24', roughness: 0.9 });
  readonly books = ['#6b8f71', '#d9c8aa', '#7a5230', '#a9bfa9', '#b98b5e'].map(
    (c) => new THREE.MeshStandardMaterial({ color: c, roughness: 0.9 }),
  );

  constructor(defs: FinishDef[]) {
    for (const f of defs) this.finishes.set(f.id, f);
  }

  finish(id: string): THREE.MeshStandardMaterial {
    let m = this.base.get(id);
    if (!m) {
      const def = this.finishes.get(id) ?? { id, hex: '#b98b5e', roughness: 0.6 };
      m = new THREE.MeshStandardMaterial({ color: def.hex, roughness: def.roughness });
      this.base.set(id, m);
    }
    return m;
  }

  /** The finish mixed 50 percent toward terracotta. */
  warning(id: string): THREE.MeshStandardMaterial {
    let m = this.warned.get(id);
    if (!m) {
      m = this.finish(id).clone();
      m.color.lerp(TERRACOTTA, 0.5);
      this.warned.set(id, m);
    }
    return m;
  }

  private lighters = new Map<string, THREE.MeshStandardMaterial>();
  private glows = new Map<string, THREE.MeshStandardMaterial>();
  private glowLevel = 0.28;

  /** The finish a touch lighter, for sofa cushions. */
  lighter(id: string): THREE.MeshStandardMaterial {
    let m = this.lighters.get(id);
    if (!m) {
      m = this.finish(id).clone();
      m.color.lerp(new THREE.Color('#ffffff'), 0.12);
      this.lighters.set(id, m);
    }
    return m;
  }

  /** The finish with a faint warm glow, for the lamp shade. */
  glow(id: string): THREE.MeshStandardMaterial {
    let m = this.glows.get(id);
    if (!m) {
      m = this.finish(id).clone();
      m.emissive = new THREE.Color('#ffd9a8');
      m.emissiveIntensity = this.glowLevel;
      this.glows.set(id, m);
    }
    return m;
  }

  /** How strongly lamp shades glow; the evening mood turns them up. */
  setGlow(k: number): void {
    this.glowLevel = k;
    for (const m of this.glows.values()) m.emissiveIntensity = k;
  }

  /** A 25 percent see-through copy for the real layout under a draft. */
  ghost(source: THREE.Material): THREE.Material {
    let m = this.ghosts.get(source.uuid);
    if (!m) {
      m = source.clone();
      m.transparent = true;
      m.opacity = 0.25;
      m.depthWrite = false;
      this.ghosts.set(source.uuid, m);
    }
    return m;
  }

  floor(id: string): THREE.MeshStandardMaterial {
    const def = this.finishes.get(id);
    const m = new THREE.MeshStandardMaterial({ color: def?.hex ?? '#b98b5e', roughness: def?.roughness ?? 0.6, map: this.plank });
    return m;
  }

  /** A finish's colour as a CSS hex value. */
  hexOf(id: string, fallback: string): string {
    return this.finishes.get(id)?.hex ?? fallback;
  }

  wallColor(id: string): string {
    return this.finishes.get(id)?.hex ?? '#f7f3ec';
  }
}
