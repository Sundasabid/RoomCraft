import type { FurnitureFn } from './builder';

export const chair: FurnitureFn = (b) => {
  const { w, d, h } = b;
  b.legs(0.04, 0.42, 0.02, 'M');
  b.box(w, 0.05, d, 0, 0.42, 0, 'M');
  b.box(w, h - 0.47, 0.05, 0, 0.47, -d / 2 + 0.025, 'M');
};
