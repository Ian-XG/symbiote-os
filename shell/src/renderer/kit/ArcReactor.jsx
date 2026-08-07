/* Arc-reactor dial: wraps the design system's RadialGauge in the concentric
   tick rings and segment arcs the brief calls for, plus a delta readout. */

function ArcReactor({ value, label, code, delta, critical = false, size = 168 }) {
  const { RadialGauge } = window.SymbioteOSDesignSystem_5d2af6;
  const color = critical ? 'var(--state-critical)' : 'var(--accent)';
  const outer = size + 96;
  const ticks = 60;

  // segmented outer arc: fills clockwise with `value`
  const segs = 36;
  const litSegs = Math.round((value / 100) * segs);

  return (
    <div
      style={{
        position: 'relative',
        width: outer,
        height: outer,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        flexShrink: 0
      }}
    >
      <svg
        viewBox="0 0 100 100"
        style={{
          position: 'absolute',
          inset: 0,
          animation: critical
            ? 'symbiote-pulse 2.2s ease-in-out infinite'
            : 'none'
        }}
      >
        {/* fine tick ring */}
        {Array.from({ length: ticks }).map((_, i) => {
          const a = (i / ticks) * Math.PI * 2 - Math.PI / 2;
          const major = i % 5 === 0;
          return (
            <line
              key={i}
              x1={50 + Math.cos(a) * (major ? 43 : 45)}
              y1={50 + Math.sin(a) * (major ? 43 : 45)}
              x2={50 + Math.cos(a) * 47}
              y2={50 + Math.sin(a) * 47}
              stroke={color}
              strokeWidth={major ? 0.7 : 0.35}
              opacity={major ? 0.6 : 0.25}
            />
          );
        })}
        {/* segmented fill arc */}
        {Array.from({ length: segs }).map((_, i) => {
          const a0 = (i / segs) * Math.PI * 2 - Math.PI / 2;
          const lit = i < litSegs;
          return (
            <line
              key={'s' + i}
              x1={50 + Math.cos(a0) * 38.5}
              y1={50 + Math.sin(a0) * 38.5}
              x2={50 + Math.cos(a0) * 41.5}
              y2={50 + Math.sin(a0) * 41.5}
              stroke={lit ? color : 'var(--grey-line)'}
              strokeWidth="1.6"
              opacity={lit ? 0.95 : 0.8}
              style={lit ? { filter: `drop-shadow(0 0 2px ${color})` } : undefined}
            />
          );
        })}
        <circle
          cx="50"
          cy="50"
          r="48.5"
          fill="none"
          stroke={color}
          strokeWidth="0.3"
          opacity="0.3"
          strokeDasharray="6 4"
        />
      </svg>

      <RadialGauge value={value} label={label} size={size} critical={critical} />

      {code && (
        <div
          style={{
            position: 'absolute',
            top: 2,
            left: '50%',
            transform: 'translateX(-50%)',
            fontFamily: 'var(--font-mono)',
            fontSize: 'var(--text-2xs)',
            color: 'var(--text-muted)',
            letterSpacing: '0.08em',
            whiteSpace: 'nowrap'
          }}
        >
          {code}
        </div>
      )}
      {delta && (
        <div
          style={{
            position: 'absolute',
            bottom: 2,
            left: '50%',
            transform: 'translateX(-50%)',
            fontFamily: 'var(--font-mono)',
            fontSize: 'var(--text-2xs)',
            color,
            whiteSpace: 'nowrap'
          }}
        >
          {delta}
        </div>
      )}
    </div>
  );
}
window.ArcReactor = ArcReactor;
