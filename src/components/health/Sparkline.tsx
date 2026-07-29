import { useId, useMemo } from 'react';
import { View } from 'react-native';
import Svg, { Circle, Defs, LinearGradient, Path, Stop } from 'react-native-svg';

interface SparklineProps {
  values: Array<number | null>;
  width?: number;
  height?: number;
  color: string;
  /** Draws a soft gradient under the line. */
  filled?: boolean;
  strokeWidth?: number;
  showLastPoint?: boolean;
}

interface Point {
  x: number;
  y: number;
}

/**
 * Missing days are real information — a gap means "no data", not "zero". The
 * path is therefore built as disjoint segments so a week off the watch renders
 * as a break in the line rather than a plunge to the axis.
 */
export function Sparkline({
  values,
  width = 120,
  height = 40,
  color,
  filled = false,
  strokeWidth = 2,
  showLastPoint = true,
}: SparklineProps) {
  // Declared before the early return below so the hook order stays stable.
  const instanceId = useId();

  const { segments, lastPoint, areaPath } = useMemo(() => {
    const present = values.filter((v): v is number => v != null && Number.isFinite(v));

    if (present.length < 2 || values.length < 2) {
      return { segments: [] as string[], lastPoint: null as Point | null, areaPath: null };
    }

    const min = Math.min(...present);
    const max = Math.max(...present);
    // A flat series would divide by zero; give it a nominal band so it renders
    // as a centred horizontal line.
    const span = max - min || Math.abs(max) * 0.1 || 1;

    const pad = strokeWidth;
    const usableHeight = height - pad * 2;
    const stepX = width / (values.length - 1);

    const points: Array<Point | null> = values.map((value, index) => {
      if (value == null || !Number.isFinite(value)) return null;
      return {
        x: index * stepX,
        y: pad + usableHeight - ((value - min) / span) * usableHeight,
      };
    });

    const paths: string[] = [];
    let current: Point[] = [];

    const flush = () => {
      if (current.length >= 2) {
        paths.push(
          current
            .map((p, i) => `${i === 0 ? 'M' : 'L'}${p.x.toFixed(2)},${p.y.toFixed(2)}`)
            .join(' '),
        );
      }
      current = [];
    };

    for (const point of points) {
      if (point === null) flush();
      else current.push(point);
    }
    flush();

    const drawn = points.filter((p): p is Point => p !== null);
    const last = drawn.length > 0 ? drawn[drawn.length - 1]! : null;

    // The fill only spans the longest contiguous run, so a gap does not get a
    // misleading shaded floor beneath it.
    const longest = paths.reduce((best, path) => (path.length > best.length ? path : best), '');
    const first = drawn[0];
    const area =
      filled && longest && first && last
        ? `${longest} L${last.x.toFixed(2)},${height} L${first.x.toFixed(2)},${height} Z`
        : null;

    return { segments: paths, lastPoint: last, areaPath: area };
  }, [values, width, height, strokeWidth, filled]);

  if (segments.length === 0) {
    return <View style={{ width, height }} />;
  }

  // Keyed on the instance, not the colour: two tiles trending the same way
  // share a colour, and `react-native-svg` resolves `url(#id)` against a
  // process-wide registry — so a colour-derived id makes the second sparkline
  // pick up the first one's gradient.
  const gradientId = `spark${instanceId.replace(/:/g, '')}`;

  return (
    <Svg width={width} height={height}>
      {areaPath && (
        <>
          <Defs>
            <LinearGradient id={gradientId} x1="0" y1="0" x2="0" y2="1">
              <Stop offset="0" stopColor={color} stopOpacity={0.28} />
              <Stop offset="1" stopColor={color} stopOpacity={0} />
            </LinearGradient>
          </Defs>
          <Path d={areaPath} fill={`url(#${gradientId})`} />
        </>
      )}

      {segments.map((d, index) => (
        <Path
          key={index}
          d={d}
          stroke={color}
          strokeWidth={strokeWidth}
          strokeLinecap="round"
          strokeLinejoin="round"
          fill="none"
        />
      ))}

      {showLastPoint && lastPoint && (
        <Circle cx={lastPoint.x} cy={lastPoint.y} r={strokeWidth + 1} fill={color} />
      )}
    </Svg>
  );
}
