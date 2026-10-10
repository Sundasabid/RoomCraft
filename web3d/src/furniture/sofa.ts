import type { FurnitureFn } from './builder';

export const sofa: FurnitureFn = (b) => {
  const { w, d, h } = b;
  const leg = 0.08;
  for (const [sx, sz] of [[-1, -1], [1, -1], [-1, 1], [1, 1]]) {
    b.cyl(0.025, leg, sx * (w / 2 - 0.08), 0, sz * (d / 2 - 0.08), b.bank.darkWood);
  }
  b.box(w, 0.3, d, 0, leg, 0, 'M');
  b.box(w, h - leg, 0.22, 0, leg, -d / 2 + 0.11, 'M');
  const arm = 0.18;
  for (const s of [-1, 1]) b.box(arm, 0.62 - leg, d, s * (w / 2 - arm / 2), leg, 0, 'M');
  const cw = (w - 2 * arm) / 2 - 0.02;
  for (const s of [-1, 1]) {
    b.box(cw, 0.14, d - 0.26, s * (cw / 2 + 0.01), leg + 0.3, 0.1, b.bank.lighter(b.finish)).userData.finish = true;
  }
};
