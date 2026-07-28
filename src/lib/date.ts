import type { IsoDay } from '@/schemas/health';

/**
 * All day-bucketing happens in the device's local timezone, matching how
 * HealthKit and the Health app present daily totals. Using UTC here would
 * shift every metric by the user's offset and silently corrupt correlations.
 */
export function toIsoDay(date: Date): IsoDay {
  const y = date.getFullYear();
  const m = `${date.getMonth() + 1}`.padStart(2, '0');
  const d = `${date.getDate()}`.padStart(2, '0');
  return `${y}-${m}-${d}`;
}

export function fromIsoDay(day: IsoDay): Date {
  const [y, m, d] = day.split('-').map(Number) as [number, number, number];
  return new Date(y, m - 1, d, 0, 0, 0, 0);
}

export function startOfLocalDay(date: Date): Date {
  const copy = new Date(date);
  copy.setHours(0, 0, 0, 0);
  return copy;
}

export function endOfLocalDay(date: Date): Date {
  const copy = new Date(date);
  copy.setHours(23, 59, 59, 999);
  return copy;
}

export function addDays(date: Date, days: number): Date {
  const copy = new Date(date);
  copy.setDate(copy.getDate() + days);
  return copy;
}

export function daysBetween(a: Date, b: Date): number {
  const ms = startOfLocalDay(b).getTime() - startOfLocalDay(a).getTime();
  return Math.round(ms / 86_400_000);
}

/** Inclusive list of ISO days spanning `from`…`to`. */
export function enumerateDays(from: Date, to: Date): IsoDay[] {
  const out: IsoDay[] = [];
  const cursor = startOfLocalDay(from);
  const last = startOfLocalDay(to);
  while (cursor.getTime() <= last.getTime()) {
    out.push(toIsoDay(cursor));
    cursor.setDate(cursor.getDate() + 1);
  }
  return out;
}

export function formatDay(day: IsoDay, style: 'short' | 'long' = 'short'): string {
  const date = fromIsoDay(day);
  return date.toLocaleDateString(undefined, {
    month: style === 'long' ? 'long' : 'short',
    day: 'numeric',
    ...(style === 'long' ? { year: 'numeric' } : {}),
  });
}

export function formatRelativeDay(day: IsoDay): string {
  const diff = daysBetween(fromIsoDay(day), new Date());
  if (diff === 0) return 'Today';
  if (diff === 1) return 'Yesterday';
  if (diff < 7) return `${diff} days ago`;
  return formatDay(day);
}

export function formatDuration(hours: number): string {
  const h = Math.floor(hours);
  const m = Math.round((hours - h) * 60);
  return m === 0 ? `${h}h` : `${h}h ${m}m`;
}

export function nowIso(): string {
  return new Date().toISOString();
}
