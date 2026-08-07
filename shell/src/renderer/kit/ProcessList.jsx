/* Live process table, ranked by CPU.
 *
 * Replaces the old "recent activity" feed, which was a scripted list of
 * invented events. This shows what is actually running — which is both true
 * and more useful, since it is how you find out what is eating the machine. */

function ProcessList({ rows, live = true }) {
  if (!live) {
    return (
      <div style={{ fontFamily: 'var(--font-mono)', fontSize: 'var(--text-2xs)', color: 'var(--text-muted)', padding: '10px 0' }}>
        Process data comes from /proc — only available on the running system.
      </div>
    );
  }

  if (!rows) {
    return (
      <div style={{ fontFamily: 'var(--font-mono)', fontSize: 'var(--text-2xs)', color: 'var(--text-muted)', padding: '10px 0' }}>
        Reading /proc…
      </div>
    );
  }

  if (!rows.length) {
    return (
      <div style={{ fontFamily: 'var(--font-mono)', fontSize: 'var(--text-2xs)', color: 'var(--text-muted)', padding: '10px 0' }}>
        No process data available.
      </div>
    );
  }

  const peak = Math.max(1, ...rows.map((r) => r.cpu));

  return (
    <div style={{ fontFamily: 'var(--font-mono)', fontSize: 'var(--text-xs)' }}>
      <div
        style={{
          display: 'grid',
          gridTemplateColumns: '1fr 46px 52px',
          gap: '8px',
          color: 'var(--text-muted)',
          fontSize: 'var(--text-2xs)',
          letterSpacing: 'var(--tracking-wide)',
          paddingBottom: '5px',
          borderBottom: '1px solid var(--grey-line)'
        }}
      >
        <span>PROCESS</span>
        <span style={{ textAlign: 'right' }}>CPU</span>
        <span style={{ textAlign: 'right' }}>MEM</span>
      </div>

      {rows.map((r) => {
        const hot = r.cpu > 60;
        return (
          <div key={r.pid} style={{ padding: '5px 0', borderBottom: '1px solid rgba(255,255,255,0.03)' }}>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 46px 52px', gap: '8px', alignItems: 'baseline' }}>
              <span
                style={{
                  color: hot ? 'var(--state-critical)' : 'var(--text-body)',
                  overflow: 'hidden',
                  textOverflow: 'ellipsis',
                  whiteSpace: 'nowrap'
                }}
                title={`pid ${r.pid}`}
              >
                {r.name}
              </span>
              <span style={{ textAlign: 'right', color: hot ? 'var(--state-critical)' : 'var(--accent)' }}>
                {r.cpu.toFixed(1)}%
              </span>
              <span style={{ textAlign: 'right', color: 'var(--text-muted)' }}>
                {r.rssMb >= 1024 ? `${(r.rssMb / 1024).toFixed(1)}G` : `${r.rssMb}M`}
              </span>
            </div>
            {/* Bar is relative to the busiest process, so movement is visible
                even when nothing is near 100%. */}
            <div style={{ height: '2px', marginTop: '3px', background: 'var(--grey-line)' }}>
              <div
                style={{
                  height: '100%',
                  width: `${Math.max(2, (r.cpu / peak) * 100)}%`,
                  background: hot ? 'var(--state-critical)' : 'var(--accent)',
                  boxShadow: '0 0 4px var(--state-ok-glow)'
                }}
              />
            </div>
          </div>
        );
      })}
    </div>
  );
}

window.ProcessList = ProcessList;
