import type { FurnitureFn } from './builder';

export const desk: FurnitureFn = (b) => {
  const { w, d, h } = b;
  b.box(w, 0.04, d, 0, h - 0.04, 0, 'M');
  b.legs(0.04, h - 0.04, 0.02, 'M');
  b.box(0.4, 0.2, d - 0.08, w / 2 - 0.26, h - 0.24, 0, 'M');
  b.box(0.12, 0.015, 0.015, w / 2 - 0.26, h - 0.15, d / 2 - 0.035, b.bank.darkWood);
};
