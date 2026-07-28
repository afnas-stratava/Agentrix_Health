/**
 * Collision-resistant, sortable-enough IDs without pulling in a uuid polyfill
 * (crypto.getRandomValues is available in Hermes but uuid v9 still drags in
 * a Node shim under the New Architecture bundler config).
 */
export function createId(prefix: string): string {
  const time = Date.now().toString(36);
  const rand = Math.random().toString(36).slice(2, 10);
  return `${prefix}_${time}${rand}`;
}
