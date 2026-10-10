import type { FurnitureFn } from './builder';

export const bed: FurnitureFn = (b) => {
  const { w, d, h } = b;
  b.box(w, 0.3, d, 0, 0, 0, b.bank.darkWood);
  b.box(w - 0.08, 0.22, d - 0.08, 0, 0.3, 0.02, 'M');
  b.box(w, h, 0.08, 0, 0, -d / 2 + 0.04, 'M');
  const pw = (w - 0.3) / 2;
  for (const s of [-1, 1]) b.box(pw, 0.12, 0.34, s * (pw / 2 + 0.05), 0.52, -d / 2 + 0.3, b.bank.white);
};
