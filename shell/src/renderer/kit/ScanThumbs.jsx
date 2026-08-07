/* Grid of "scan" thumbnails — each tile is a synthetic capture with its own
   raster angle, a sweeping scan bar, node id and status corner. */

const SCAN_TILES = [
  { id: 'NODE_14A', st: 'ok', ang: 18 },
  { id: 'NODE_09C', st: 'ok', ang: 62 },
  { id: 'NODE_22F', st: 'warn', ang: 104 },
  { id: 'NODE_31B', st: 'ok', ang: 141 },
  { id: 'NODE_07E', st: 'crit', ang: 7 },
  { id: 'NODE_18D', st: 'ok', ang: 85 }
];

function ScanThumbs({ tiles = SCAN_TILES }) {
  const stColor = {
    ok: 'var(--accent)',
    warn: 'var(--accent-bright)',
    crit: 'var(--state-critical)'
  };
  return (
    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3,1fr)', gap: '6px' }}>
      {tiles.map((t, i) => {
        const c = stColor[t.st];
        return (
          <div
            key={t.id}
            style={{
              position: 'relative',
              aspectRatio: '1',
              background: 'var(--hud-wash)',
              border: `1px solid ${t.st === 'ok' ? 'var(--grey-line)' : c}`,
              overflow: 'hidden'
            }}
          >
            {/* raster */}
            <div
              style={{
                position: 'absolute',
                inset: 0,
                backgroundImage: `repeating-linear-gradient(${t.ang}deg, ${
                  t.st === 'crit' ? 'rgba(255,23,68,.16)' : 'rgba(0,255,136,.14)'
                } 0px, ${
                  t.st === 'crit' ? 'rgba(255,23,68,.16)' : 'rgba(0,255,136,.14)'
                } 1px, transparent 1px, transparent 5px)`
              }}
            />
            {/* subject blob */}
            <svg viewBox="0 0 40 40" style={{ position: 'absolute', inset: 0 }}>
              <circle
                cx={14 + ((i * 5) % 13)}
                cy={13 + ((i * 7) % 15)}
                r={5 + (i % 3) * 2}
                fill="none"
                stroke={c}
                strokeWidth="0.6"
                opacity="0.75"
              />
              <circle
                cx={14 + ((i * 5) % 13)}
                cy={13 + ((i * 7) % 15)}
                r={2 + (i % 2)}
                fill={c}
                opacity="0.35"
              />
            </svg>
            {/* sweep */}
            <div
              style={{
                position: 'absolute',
                left: 0,
                right: 0,
                height: '26%',
                background: `linear-gradient(to bottom, transparent, ${
                  t.st === 'crit' ? 'rgba(255,23,68,.22)' : 'rgba(0,255,136,.2)'
                }, transparent)`,
                animation: `hud-sweep ${2.6 + i * 0.35}s linear infinite`
              }}
            />
            {/* corner ticks */}
            <span style={{ position: 'absolute', top: 2, left: 2, width: 5, height: 5, borderTop: `1px solid ${c}`, borderLeft: `1px solid ${c}` }} />
            <span style={{ position: 'absolute', bottom: 2, right: 2, width: 5, height: 5, borderBottom: `1px solid ${c}`, borderRight: `1px solid ${c}` }} />
            <div
              style={{
                position: 'absolute',
                bottom: 2,
                left: 3,
                fontFamily: 'var(--font-mono)',
                fontSize: '6px',
                letterSpacing: '0.04em',
                color: c
              }}
            >
              {t.id}
            </div>
          </div>
        );
      })}
    </div>
  );
}
window.ScanThumbs = ScanThumbs;
