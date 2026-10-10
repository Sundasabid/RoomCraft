import type { FurnitureFn } from './builder';

export const tvUnit: FurnitureFn = (b) => {
  const { w, d, h } = b;
  const leg = 0.06;
  b.legs(0.035, leg, 0.05, b.bank.darkWood);
  b.box(w, h - leg, d, 0, leg, 0, 'M');
  b.box(0.01, h - leg - 0.08, 0.006, 0, leg + 0.04, d / 2 + 0.003, b.bank.seam);
};
