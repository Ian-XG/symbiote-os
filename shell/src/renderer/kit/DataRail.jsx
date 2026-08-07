/* Dense alphanumeric rail for the side columns: one 8px row per channel,
   code + value + a 20-tick level bar. Values drift on a timer so the column
   reads as live telemetry rather than a static table. */

function DataRail({ rows, ticks = 20, interval = 900, rowGap = 3 }) {
  const [drift, setDrift] = React.useState(0);

  React.useEffect(() => {
    const id = setInterval(() => setDrift((d) => d + 1), interval);
    return () => clearInterval(id);
  }, [interval]);

  return (
    <div style={{ fontFamily: 'var(--font-mono)', fontSize: 'var(--text-2xs)' }}>
      {rows.map((r, i) => {
        // deterministic per-row jitter, no Math.random so re-renders stay stable
        const wobble = r.static
          ? 0
          : Math.round(Math.sin(drift * 0.7 + i * 1.9) * 4 + Math.sin(drift * 0.31 + i) * 2);
        const level = Math.max(0, Math.min(100, r.level + wobble));
        const filled = Math.round((level / 100) * ticks);
        const color = r.critical ? 'var(--state-critical)' : 'var(--accent)';
        return (
          <div
            key={r.code}
            style={{
              display: 'grid',
              gridTemplateColumns: '1fr auto',
              alignItems: 'center',
              columnGap: '8px',
              padding: `${rowGap}px 0`,
              borderBottom:
                i === rows.length - 1 ? 'none' : '1px solid rgba(255,255,255,0.03)'
            }}
          >
            <span
              style={{
                color: r.critical ? 'var(--state-critical)' : 'var(--text-muted)',
                letterSpacing: '0.06em',
                overflow: 'hidden',
                textOverflow: 'ellipsis',
                whiteSpace: 'nowrap'
              }}
            >
              {r.code}
            </span>
            <span style={{ color, fontVariantNumeric: 'tabular-nums' }}>
              {r.unit === '%' ? level + '%' : r.value}
            </span>
            <div style={{ gridColumn: '1 / -1', display: 'flex', gap: '1px', marginTop: '2px' }}>
              {Array.from({ length: ticks }).map((_, t) => (
                <span
                  key={t}
                  style={{
                    flex: 1,
                    height: '2px',
                    background: t < filled ? color : 'var(--grey-line)',
                    opacity: t < filled ? 1 : 0.65,
                    boxShadow: t === filled - 1 ? `0 0 4px ${color}` : 'none'
                  }}
                />
              ))}
            </div>
          </div>
        );
      })}
    </div>
  );
}

/* Two-column key/value block — pure text density, no bars. */
function CodeGrid({ pairs, columns = 2 }) {
  return (
    <div
      style={{
        display: 'grid',
        gridTemplateColumns: `repeat(${columns}, 1fr)`,
        columnGap: '10px',
        rowGap: '3px',
        fontFamily: 'var(--font-mono)',
        fontSize: 'var(--text-2xs)'
      }}
    >
      {pairs.map(([k, v, crit]) => (
        <div key={k} style={{ display: 'flex', justifyContent: 'space-between', gap: '6px' }}>
          <span style={{ color: 'var(--text-muted)' }}>{k}</span>
          <span style={{ color: crit ? 'var(--state-critical)' : 'var(--accent)' }}>{v}</span>
        </div>
      ))}
    </div>
  );
}

/* Plain-language status list: one label, one state, colour by severity.
   Used for things a non-technical operator still needs to read at a glance. */
function StatusList({ rows }) {
  const color = {
    ok: 'var(--accent)',
    attention: 'var(--accent-bright)',
    critical: 'var(--state-critical)',
    idle: 'var(--text-muted)'
  };
  return (
    <div style={{ fontFamily: 'var(--font-mono)', fontSize: 'var(--text-xs)' }}>
      {rows.map((r, i) => (
        <div
          key={r.label}
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            gap: '10px',
            padding: '6px 0',
            borderBottom:
              i === rows.length - 1 ? 'none' : '1px solid rgba(255,255,255,0.04)'
          }}
        >
          <span style={{ color: 'var(--text-body)', letterSpacing: '0.05em' }}>{r.label}</span>
          <span
            style={{
              display: 'inline-flex',
              alignItems: 'center',
              gap: '6px',
              color: color[r.state] || color.ok,
              whiteSpace: 'nowrap'
            }}
          >
            <span
              style={{
                width: '5px',
                height: '5px',
                borderRadius: '50%',
                background: color[r.state] || color.ok,
                boxShadow: `0 0 5px ${color[r.state] || color.ok}`,
                animation:
                  r.state === 'critical' || r.state === 'attention'
                    ? 'symbiote-pulse var(--dur-pulse) ease-in-out infinite'
                    : 'none'
              }}
            />
            {r.value}
          </span>
        </div>
      ))}
    </div>
  );
}

window.DataRail = DataRail;
window.CodeGrid = CodeGrid;
window.StatusList = StatusList;
