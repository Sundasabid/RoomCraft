import type { FurnitureFn } from './builder';

export const coffeeTable: FurnitureFn = (b) => {
  const { w, d, h } = b;
  b.box(w, 0.04, d, 0, h - 0.04, 0, 'M');
  b.legs(0.04, h - 0.04, 0.03, 'M');
  b.box(w - 0.14, 0.03, d - 0.14, 0, 0.12, 0, 'M');
};
