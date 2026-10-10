import type { FurnitureFn } from './builder';

export const diningTable: FurnitureFn = (b) => {
  const { w, d, h } = b;
  b.box(w, 0.05, d, 0, h - 0.05, 0, 'M');
  b.legs(0.06, h - 0.05, 0.06, 'M');
};
