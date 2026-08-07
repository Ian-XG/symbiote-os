/* Rotating wireframe of the symbiont mass — the centrepiece.
   Built as a real 3D wireframe: N meridian planes fanned around Y, each one an
   irregular closed path (harmonic noise, not a circle) so the silhouette reads
   as a living membrane rather than a globe. Latitude rings + filament tendrils
   sit on top. */

const HOLO_MERIDIANS = 12;
const HOLO_LATITUDES = 5;

/* Closed organic outline, 0-100 box. Phase shifts per meridian so no two
   planes trace the same lump. */
function holoBlobPath(phase, radius, wobble) {
  const steps = 40;
  let d = '';
  for (let i = 0; i <= steps; i++) {
    const t = (i / steps) * Math.PI * 2;
    const r =
      radius *
      (1 +
        wobble * 0.9 * Math.sin(3 * t + phase) +
        wobble * 0.55 * Math.sin(5 * t + phase * 1.7) +
        wobble * 0.3 * Math.sin(7 * t + phase * 0.4) +
        wobble * 0.18 * Math.sin(11 * t + phase * 2.3));
    const x = 50 + Math.cos(t) * r;
    const y = 50 + Math.sin(t) * r;
    d += (i === 0 ? 'M' : 'L') + x.toFixed(2) + ' ' + y.toFixed(2) + ' ';
  }
  return d + 'Z';
}

function Hologram({ size = 430, paused = false }) {
  const meridians = React.useMemo(
    () =>
      Array.from({ length: HOLO_MERIDIANS }).map((_, i) => ({
        rot: (180 / HOLO_MERIDIANS) * i,
        d: holoBlobPath(i * 0.85, 36, 0.17),
        dim: i % 3 !== 0
      })),
    []
  );

  const latitudes = React.useMemo(
    () =>
      Array.from({ length: HOLO_LATITUDES }).map((_, i) => {
        const k = (i - (HOLO_LATITUDES - 1) / 2) / ((HOLO_LATITUDES - 1) / 2); // -1..1
        const shrink = Math.sqrt(Math.max(0.08, 1 - k * k));
        return {
          z: k * size * 0.17,
          d: holoBlobPath(2.4 + i * 1.3, 36 * shrink, 0.2),
          dim: i === 0 || i === HOLO_LATITUDES - 1
        };
      }),
    [size]
  );

  /* Tendrils reaching out of the mass into the surrounding readouts. */
  const filaments = React.useMemo(
    () =>
      Array.from({ length: 6 }).map((_, i) => {
        const a = (i / 6) * Math.PI * 2 + 0.4;
        const r0 = 30 + (i % 3) * 3;
        const r1 = 44 + (i % 4) * 5;
        const x0 = 50 + Math.cos(a) * r0;
        const y0 = 50 + Math.sin(a) * r0 * 0.86;
        const x1 = 50 + Math.cos(a) * r1;
        const y1 = 50 + Math.sin(a) * r1 * 0.86;
        const bend = i % 2 ? 9 : -9;
        return {
          d: `M ${x0.toFixed(1)} ${y0.toFixed(1)} Q ${(
            (x0 + x1) / 2 + bend
          ).toFixed(1)} ${((y0 + y1) / 2 - bend).toFixed(1)} ${x1.toFixed(
            1
          )} ${y1.toFixed(1)}`,
          delay: (i * 0.4).toFixed(1),
          tip: [x1, y1]
        };
      }),
    []
  );

  const ticks = React.useMemo(
    () => Array.from({ length: 72 }).map((_, i) => i),
    []
  );

  return (
    <div
      style={{
        position: 'relative',
        width: size,
        height: size,
        perspective: '1100px',
        flexShrink: 0
      }}
    >
      {/* containment glow */}
      <div
        style={{
          position: 'absolute',
          inset: '6%',
          borderRadius: '50%',
          background:
            'radial-gradient(circle, rgba(0,255,136,0.13) 0%, rgba(0,255,136,0.035) 48%, transparent 72%)',
          animation: 'hud-breathe 5.5s ease-in-out infinite',
          animationPlayState: paused ? 'paused' : 'running'
        }}
      />

      {/* fixed reticle: degree ticks + cardinal labels, does not spin */}
      <svg
        viewBox="0 0 100 100"
        style={{ position: 'absolute', inset: 0, overflow: 'visible' }}
      >
        {ticks.map((i) => {
          const a = (i / 72) * Math.PI * 2;
          const major = i % 6 === 0;
          const r0 = major ? 45.5 : 47.2;
          return (
            <line
              key={i}
              x1={50 + Math.cos(a) * r0}
              y1={50 + Math.sin(a) * r0}
              x2={50 + Math.cos(a) * 48.6}
              y2={50 + Math.sin(a) * 48.6}
              stroke="var(--accent)"
              strokeWidth={major ? 0.5 : 0.25}
              opacity={major ? 0.55 : 0.22}
            />
          );
        })}
        <circle
          cx="50"
          cy="50"
          r="44"
          fill="none"
          stroke="var(--hud-hairline)"
          strokeWidth="0.3"
          strokeDasharray="1 3"
        />
      </svg>

      {/* rotating mass */}
      <div
        style={{
          position: 'absolute',
          inset: 0,
          transformStyle: 'preserve-3d',
          animation: 'symbiote-spin 26s linear infinite',
          animationPlayState: paused ? 'paused' : 'running',
          // Promote to a GPU layer: rotating this group re-rasterised every
          // meridian on every frame otherwise, which cost a full CPU core.
          willChange: paused ? 'auto' : 'transform',
          backfaceVisibility: 'hidden'
        }}
      >
        {meridians.map((m, i) => (
          <svg
            key={'m' + i}
            viewBox="0 0 100 100"
            style={{
              position: 'absolute',
              inset: 0,
              transform: `rotateY(${m.rot}deg)`,
              transformStyle: 'preserve-3d'
            }}
          >
            <path
              d={m.d}
              fill="none"
              stroke="var(--accent)"
              strokeWidth={m.dim ? 0.22 : 0.4}
              opacity={m.dim ? 0.3 : 0.72}
            />
          </svg>
        ))}

        {latitudes.map((l, i) => (
          <svg
            key={'l' + i}
            viewBox="0 0 100 100"
            style={{
              position: 'absolute',
              inset: 0,
              transform: `rotateX(90deg) translateZ(${l.z}px)`
            }}
          >
            <path
              d={l.d}
              fill="none"
              stroke="var(--accent-bright)"
              strokeWidth={l.dim ? 0.25 : 0.42}
              opacity={l.dim ? 0.3 : 0.6}
            />
          </svg>
        ))}

        {/* nucleus */}
        <div
          style={{
            position: 'absolute',
            left: '50%',
            top: '50%',
            width: size * 0.13,
            height: size * 0.13,
            marginLeft: -size * 0.065,
            marginTop: -size * 0.065,
            borderRadius: '50%',
            background:
              'radial-gradient(circle, var(--accent-bright) 0%, rgba(0,255,136,.5) 35%, transparent 70%)',
            filter: 'blur(2px)',
            animation: 'symbiote-pulse 2.6s ease-in-out infinite',
            animationPlayState: paused ? 'paused' : 'running'
          }}
        />
      </div>

      {/* filaments + vertex nodes, layered above the mass */}
      <svg
        viewBox="0 0 100 100"
        style={{ position: 'absolute', inset: 0, pointerEvents: 'none' }}
      >
        {filaments.map((f, i) => (
          <g key={'f' + i}>
            <path
              d={f.d}
              fill="none"
              stroke="var(--accent)"
              strokeWidth="0.35"
              opacity="0.55"
              strokeDasharray="2 3"
              style={{
                animation: 'hud-filament 3.2s linear infinite',
                animationDelay: `${f.delay}s`,
                animationPlayState: paused ? 'paused' : 'running'
              }}
            />
            <circle
              cx={f.tip[0]}
              cy={f.tip[1]}
              r="0.7"
              fill="var(--accent-bright)"
              opacity="0.9"
            />
          </g>
        ))}
      </svg>

      {/* callouts */}
      <HoloCallout style={{ left: -18, top: '17%' }} code="SYM_EM_03.4" value="MEMBRANE STABLE" />
      <HoloCallout style={{ right: -14, top: '30%' }} code="X_300:1" value="MAG / LOCKED" align="right" />
      <HoloCallout style={{ right: -10, bottom: '26%' }} code="CROSS_SE" value="Δ 0.0041" align="right" />
      <HoloCallout style={{ left: -14, bottom: '19%' }} code="INTEGRATION_0001" value="97.2% BIND" />

      <div
        style={{
          position: 'absolute',
          bottom: -18,
          left: '50%',
          transform: 'translateX(-50%)',
          fontFamily: 'var(--font-mono)',
          fontSize: 'var(--text-2xs)',
          letterSpacing: 'var(--tracking-wider)',
          color: 'var(--text-muted)',
          textTransform: 'uppercase',
          whiteSpace: 'nowrap'
        }}
      >
        SYMBIONT MASS &nbsp;//&nbsp; {paused ? 'PAUSED' : 'LIVE RENDER'}
      </div>
    </div>
  );
}

function HoloCallout({ style, code, value, align = 'left' }) {
  return (
    <div
      style={{
        position: 'absolute',
        fontFamily: 'var(--font-mono)',
        fontSize: 'var(--text-2xs)',
        lineHeight: 1.5,
        textAlign: align,
        whiteSpace: 'nowrap',
        pointerEvents: 'none',
        ...style
      }}
    >
      <div style={{ color: 'var(--accent)', letterSpacing: '0.08em' }}>{code}</div>
      <div style={{ color: 'var(--text-muted)' }}>{value}</div>
      <div
        style={{
          height: 1,
          marginTop: 3,
          background:
            align === 'right'
              ? 'linear-gradient(to left, var(--accent), transparent)'
              : 'linear-gradient(to right, var(--accent), transparent)',
          opacity: 0.5
        }}
      />
    </div>
  );
}

window.Hologram = Hologram;
