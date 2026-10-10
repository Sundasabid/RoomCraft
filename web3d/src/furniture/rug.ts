import type { FurnitureFn } from './builder';

export const rug: FurnitureFn = (b) => {
  const slab = b.box(b.w, b.h, b.d, 0, 0, 0, 'M');
  slab.castShadow = false;
};
