import type { FurnitureFn } from './builder';

export const bookshelf: FurnitureFn = (b) => {
  const { w, d, h } = b;
  const t = 0.03;
  for (const s of [-1, 1]) b.box(t, h, d, s * (w / 2 - t / 2), 0, 0, 'M');
  b.box(w, t, d, 0, h - t, 0, 'M');
  b.box(w, t, d, 0, 0, 0, 'M');
  b.box(w - 2 * t, h - 2 * t, 0.01, 0, t, -d / 2 + 0.005, 'M');
  const gap = (h - 2 * t) / 5;
  for (let i = 1; i <= 4; i++) b.box(w - 2 * t, 0.02, d, 0, t + gap * i - 0.01, 0, 'M');
  // A deterministic row of books on every level.
  let k = 0;
  for (let level = 0; level < 5; level++) {
    let x = -w / 2 + t + 0.01;
    const base = t + gap * level + (level === 0 ? 0 : 0.01);
    while (x < w / 2 - t - 0.05) {
      const bw = 0.022 + ((k * 7) % 5) * 0.006;
      const bh = Math.min(gap - 0.04, 0.17 + ((k * 3) % 4) * 0.025);
      b.box(bw, bh, d * 0.75, x + bw / 2, base, 0.01, b.bank.books[k % b.bank.books.length]);
      x += bw + 0.004;
      k++;
      if (k % 9 === 0) x += 0.06;
    }
  }
};
