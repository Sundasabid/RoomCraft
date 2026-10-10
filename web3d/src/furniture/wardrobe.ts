import type { FurnitureFn } from './builder';

export const wardrobe: FurnitureFn = (b) => {
  const { w, d, h } = b;
  b.box(w, h, d, 0, 0, 0, 'M');
  b.box(0.012, h - 0.12, 0.006, 0, 0.06, d / 2 + 0.003, b.bank.seam);
  for (const s of [-1, 1]) b.box(0.02, 0.16, 0.025, s * 0.06, h * 0.48, d / 2 + 0.012, b.bank.darkWood);
};
