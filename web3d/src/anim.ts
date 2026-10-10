// Small tween runner. The render loop asks it whether anything is moving.

export type Ease = (t: number) => number;
export const easeOutCubic: Ease = (t) => 1 - Math.pow(1 - t, 3);
export const easeInOut: Ease = (t) => (t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2);

interface Tween {
  key: string;
  start: number;
  duration: number;
  ease: Ease;
  step: (k: number) => void;
  done?: () => void;
}

const tweens = new Map<string, Tween>();
let reduceMotion = false;

export function setReduceMotion(v: boolean): void {
  reduceMotion = v;
}

/** Runs [step] from 0 to 1 over [ms]. A new tween with the same key replaces the old one. */
export function tween(key: string, ms: number, step: (k: number) => void, ease: Ease = easeOutCubic, done?: () => void): void {
  if (reduceMotion || ms <= 0) {
    step(1);
    done?.();
    tweens.delete(key);
    return;
  }
  tweens.set(key, { key, start: performance.now(), duration: ms, ease, step, done });
}

export function cancel(key: string): void {
  tweens.delete(key);
}

/**
 * Advances every tween. Returns true if any ran this frame, including one
 * that just finished, so the frame where its done() acts (an item removed
 * after its fade, say) is still drawn.
 */
export function tick(now: number): boolean {
  const ran = tweens.size > 0;
  for (const t of [...tweens.values()]) {
    const raw = Math.min(1, (now - t.start) / t.duration);
    t.step(t.ease(raw));
    if (raw >= 1) {
      tweens.delete(t.key);
      t.done?.();
    }
  }
  return ran;
}
