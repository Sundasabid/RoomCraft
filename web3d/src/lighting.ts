import * as THREE from 'three';
import { easeInOut, tween } from './anim';
import type { ItemNode } from './types';

/**
 * One mood for the room. The sun is described by where it sits relative to
 * the room (elevation 0 is the horizon, 1 straight overhead), so the same
 * preset works for any room size. Values are in three.js physical units.
 */
interface Mood {
  skyColor: string;
  groundColor: string;
  skyIntensity: number;
  sunColor: string;
  sunIntensity: number;
  sunElevation: number;
  sunAround: number;
  fillColor: string;
  fillIntensity: number;
  shadowSoftness: number;
  /** Warm light from each floor lamp; 0 leaves lamps off. */
  lampIntensity: number;
  lampGlow: number;
}

const moods: Record<string, Mood> = {
  day: {
    skyColor: '#fff6e8', groundColor: '#d9c8aa', skyIntensity: 1.25,
    sunColor: '#ffefd6', sunIntensity: 1.9, sunElevation: 0.62, sunAround: 0.35,
    fillColor: '#dfe8ff', fillIntensity: 0, shadowSoftness: 3,
    lampIntensity: 0, lampGlow: 0.28,
  },
  golden: {
    skyColor: '#ffe6c8', groundColor: '#7a6450', skyIntensity: 1.0,
    sunColor: '#ffb877', sunIntensity: 2.3, sunElevation: 0.22, sunAround: 0.15,
    fillColor: '#9fb4ff', fillIntensity: 0.3, shadowSoftness: 4,
    lampIntensity: 0, lampGlow: 0.4,
  },
  evening: {
    skyColor: '#8794bd', groundColor: '#3a332a', skyIntensity: 0.6,
    sunColor: '#b9c6ff', sunIntensity: 0.25, sunElevation: 0.7, sunAround: 0.6,
    fillColor: '#ffcf9a', fillIntensity: 0.35, shadowSoftness: 6,
    lampIntensity: 7, lampGlow: 1.8,
  },
  soft: {
    skyColor: '#fbfbf7', groundColor: '#d6d3cb', skyIntensity: 1.95,
    sunColor: '#f6f6f2', sunIntensity: 0.7, sunElevation: 0.85, sunAround: 0.3,
    fillColor: '#ffffff', fillIntensity: 0.2, shadowSoftness: 9,
    lampIntensity: 0, lampGlow: 0.28,
  },
};

const LAMP_COLOR = '#ffb874';
const LAMP_RANGE = 6;

/** Owns every light in the room and blends between moods. */
export class RoomLighting {
  readonly hemi = new THREE.HemisphereLight();
  readonly sun = new THREE.DirectionalLight();
  readonly fill = new THREE.DirectionalLight();
  private readonly lamps = new Map<string, THREE.PointLight>();
  private current: Mood = { ...moods.day };
  private id = 'day';
  private centre = new THREE.Vector2();
  private span = 4;
  private wallHeight = 2.6;

  constructor(
    private readonly scene: THREE.Scene,
    private readonly setLampGlow: (k: number) => void,
    private readonly requestRender: () => void,
  ) {
    this.sun.castShadow = true;
    this.sun.shadow.mapSize.set(1024, 1024);
    this.sun.shadow.bias = -0.0005;
    this.sun.shadow.normalBias = 0.02;
    scene.add(this.hemi, this.sun, this.sun.target, this.fill, this.fill.target);
    this.write(this.current);
  }

  /** Keeps the sun and its shadow box sized to the room. */
  fit(centre: THREE.Vector2, span: number, wallHeight: number): void {
    this.centre.copy(centre);
    this.span = span;
    this.wallHeight = wallHeight;
    const cam = this.sun.shadow.camera;
    const r = span * 0.9;
    cam.left = -r;
    cam.right = r;
    cam.top = r;
    cam.bottom = -r;
    cam.near = 0.1;
    cam.far = wallHeight + span * 4;
    cam.updateProjectionMatrix();
    this.place(this.current);
  }

  /** Blends to another mood over 400 ms (instantly with reduced motion). */
  set(id: string, animate = true): void {
    const target = moods[id] ?? moods.day;
    if (id === this.id) return;
    this.id = id in moods ? id : 'day';
    const from = { ...this.current };
    tween('lighting', animate ? 400 : 0, (k) => {
      this.current = blend(from, target, k);
      this.write(this.current);
      this.requestRender();
    }, easeInOut);
  }

  /** Writes the current mood again, after materials were rebuilt. */
  refresh(): void {
    this.write(this.current);
  }

  /** One warm point light per visible floor lamp, at shade height. */
  syncLamps(items: ItemNode[], lampHeight: number): void {
    const seen = new Set<string>();
    for (const n of items) {
      if (n.catalogueId !== 'floor_lamp' || n.visible === false) continue;
      seen.add(n.id);
      let light = this.lamps.get(n.id);
      if (!light) {
        light = new THREE.PointLight(LAMP_COLOR, 0, LAMP_RANGE, 2);
        this.lamps.set(n.id, light);
        this.scene.add(light);
      }
      light.position.set(n.x, lampHeight, n.z);
      light.intensity = this.current.lampIntensity;
    }
    for (const [id, light] of this.lamps) {
      if (seen.has(id)) continue;
      this.scene.remove(light);
      light.dispose();
      this.lamps.delete(id);
    }
    this.requestRender();
  }

  private place(m: Mood): void {
    const a = m.sunAround * Math.PI * 2;
    const dist = this.span * 1.6;
    const up = Math.max(0.08, m.sunElevation);
    const flat = dist * Math.cos(up * Math.PI / 2);
    const height = this.wallHeight + dist * Math.sin(up * Math.PI / 2);
    this.sun.position.set(this.centre.x + Math.cos(a) * flat, height, this.centre.y + Math.sin(a) * flat);
    this.sun.target.position.set(this.centre.x, 0, this.centre.y);
    this.fill.position.set(this.centre.x - Math.cos(a) * flat, this.wallHeight + this.span, this.centre.y - Math.sin(a) * flat);
    this.fill.target.position.set(this.centre.x, 0, this.centre.y);
  }

  private write(m: Mood): void {
    this.hemi.color.set(m.skyColor);
    this.hemi.groundColor.set(m.groundColor);
    this.hemi.intensity = m.skyIntensity;
    this.sun.color.set(m.sunColor);
    this.sun.intensity = m.sunIntensity;
    this.sun.shadow.radius = m.shadowSoftness;
    this.fill.color.set(m.fillColor);
    this.fill.intensity = m.fillIntensity;
    for (const light of this.lamps.values()) light.intensity = m.lampIntensity;
    this.setLampGlow(m.lampGlow);
    this.place(m);
  }
}

function blend(a: Mood, b: Mood, k: number): Mood {
  const c = (x: string, y: string) => '#' + new THREE.Color(x).lerp(new THREE.Color(y), k).getHexString();
  const n = (x: number, y: number) => x + (y - x) * k;
  return {
    skyColor: c(a.skyColor, b.skyColor),
    groundColor: c(a.groundColor, b.groundColor),
    skyIntensity: n(a.skyIntensity, b.skyIntensity),
    sunColor: c(a.sunColor, b.sunColor),
    sunIntensity: n(a.sunIntensity, b.sunIntensity),
    sunElevation: n(a.sunElevation, b.sunElevation),
    sunAround: n(a.sunAround, b.sunAround),
    fillColor: c(a.fillColor, b.fillColor),
    fillIntensity: n(a.fillIntensity, b.fillIntensity),
    shadowSoftness: n(a.shadowSoftness, b.shadowSoftness),
    lampIntensity: n(a.lampIntensity, b.lampIntensity),
    lampGlow: n(a.lampGlow, b.lampGlow),
  };
}
