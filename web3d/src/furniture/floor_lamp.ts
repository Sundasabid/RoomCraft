import type { FurnitureFn } from './builder';

export const floorLamp: FurnitureFn = (b) => {
  const r = b.w / 2;
  b.cyl(r * 0.9, 0.03, 0, 0, 0, 'M');
  b.cyl(0.014, 1.3, 0, 0.03, 0, b.bank.darkWood, 0.014, 10);
  b.cyl(r, 0.3, 0, b.h - 0.3, 0, b.bank.glow(b.finish), r * 0.55).userData.finish = true;
};
