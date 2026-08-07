/* Oscilloscope trace. Scrolls left on a timer so the panel reads live;
   the sample buffer is seeded and deterministic, no Math.random. */

function Waveform({
  seed = 1,
  height = 46,
  samples = 64,
  critical = false,
  live = true,
  grid = true,
  label
}) {
  const color = critical ? 'var(--state-critical)' : 'var(--accent)';
  const [phase, setPhase] = React.useState(0);

  React.useEffect(() => {
    if (!live) return;
    const id = setInterval(() => setPhase((p) => p + 1), 90);
    return () => clearInterval(id);
  }, [live]);

  const pts = React.useMemo(() => {
    return Array.from({ length: samples }).map((_, i) => {
      const k = i + phase;
      return (
        Math.sin(k / 3.1 + seed) * 0.42 +
        Math.sin(k / 1.3 + seed * 2.7) * 0.22 +
        Math.sin(k / 7.9 + seed * 0.6) * 0.3 +
        Math.sin(k / 0.7 + seed * 4.1) * 0.08
      );
    });
  }, [phase, seed, samples]);

  const w = 200;
  const step = w / (samples - 1);
  const mid = height / 2;
  const line = pts
    .map((p, i) => `${i === 0 ? 'M' : 'L'} ${(i * step).toFixed(1)} ${(mid - p * (height * 0.42)).toFixed(1)}`)
    .join(' ');
  const fill = `${line} L ${w} ${mid} L 0 ${mid} Z`;

  return (
    <div style={{ position: 'relative' }}>
      <svg width="100%" height={height} viewBox={`0 0 ${w} ${height}`} preserveAspectRatio="none">
        {grid && (
          <g opacity="0.5">
            {[0.25, 0.5, 0.75].map((f) => (
              <line
                key={f}
                x1="0"
                y1={height * f}
                x2={w}
                y2={height * f}
                stroke="var(--grey-line)"
                strokeWidth="0.5"
                strokeDasharray="2 4"
              />
            ))}
            {[0.2, 0.4, 0.6, 0.8].map((f) => (
              <line
                key={'v' + f}
                x1={w * f}
                y1="0"
                x2={w * f}
                y2={height}
                stroke="var(--grey-line)"
                strokeWidth="0.5"
                strokeDasharray="2 4"
              />
            ))}
          </g>
        )}
        <path d={fill} fill={color} opacity="0.08" />
        <path
          d={line}
          fill="none"
          stroke={color}
          strokeWidth="1"
          vectorEffect="non-scaling-stroke"
          style={{ filter: `drop-shadow(0 0 3px ${color})` }}
        />
      </svg>
      {label && (
        <span
          style={{
            position: 'absolute',
            top: 0,
            right: 0,
            fontFamily: 'var(--font-mono)',
            fontSize: 'var(--text-2xs)',
            color: 'var(--text-muted)'
          }}
        >
          {label}
        </span>
      )}
    </div>
  );
}
window.Waveform = Waveform;
