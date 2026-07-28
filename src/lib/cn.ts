import { twMerge } from 'tailwind-merge';

type ClassValue = string | undefined | null | false | Record<string, boolean | undefined>;

/**
 * Conditional class joiner with Tailwind conflict resolution, so a caller's
 * `className` prop always wins over a component's defaults.
 */
export function cn(...inputs: ClassValue[]): string {
  const parts: string[] = [];

  for (const input of inputs) {
    if (!input) continue;
    if (typeof input === 'string') {
      parts.push(input);
      continue;
    }
    for (const [key, active] of Object.entries(input)) {
      if (active) parts.push(key);
    }
  }

  return twMerge(parts.join(' '));
}
