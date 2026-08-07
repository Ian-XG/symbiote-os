/* App launcher panel: search field + categorised app grid, opens above the
   taskbar. Search filters on title and id. */

function AppLauncher({ apps, onLaunch, onClose, openIds = [] }) {
  const { Input } = window.SymbioteOSDesignSystem_5d2af6;
  const [q, setQ] = React.useState('');

  const needle = q.trim().toLowerCase();
  const matches = apps.filter(
    (a) => !needle || a.title.toLowerCase().includes(needle) || a.id.includes(needle)
  );

  const CATS = [
    ['system', 'SYSTEM'],
    ['recon', 'RECON'],
    ['offense', 'OFFENSE'],
    ['defense', 'DEFENSE']
  ];

  return (
    <>
      {/* click-away */}
      <div
        onClick={onClose}
        style={{ position: 'absolute', inset: 0, zIndex: 55, background: 'rgba(0,0,0,.35)' }}
      />
      <div
        style={{
          position: 'absolute',
          bottom: '80px',
          left: '18px',
          width: '560px',
          padding: '18px',
          boxSizing: 'border-box',
          background: 'var(--surface-panel-strong)',
          backdropFilter: 'var(--blur-glass)',
          WebkitBackdropFilter: 'var(--blur-glass)',
          border: '1px solid var(--border-panel)',
          boxShadow: 'var(--glow-sm)',
          zIndex: 58,
          fontFamily: 'var(--font-mono)'
        }}
      >
        {/* corner brackets */}
        {[
          { top: -1, left: -1, bt: 1, bl: 1 },
          { top: -1, right: -1, bt: 1, br: 1 },
          { bottom: -1, left: -1, bb: 1, bl: 1 },
          { bottom: -1, right: -1, bb: 1, br: 1 }
        ].map((c, i) => (
          <span
            key={i}
            style={{
              position: 'absolute',
              width: 'var(--bracket-size)',
              height: 'var(--bracket-size)',
              top: c.top,
              left: c.left,
              right: c.right,
              bottom: c.bottom,
              borderTop: c.bt ? '1.5px solid var(--accent)' : 'none',
              borderBottom: c.bb ? '1.5px solid var(--accent)' : 'none',
              borderLeft: c.bl ? '1.5px solid var(--accent)' : 'none',
              borderRight: c.br ? '1.5px solid var(--accent)' : 'none',
              pointerEvents: 'none'
            }}
          />
        ))}

        <div
          style={{
            display: 'flex',
            justifyContent: 'space-between',
            alignItems: 'baseline',
            marginBottom: '12px'
          }}
        >
          <span
            style={{
              fontFamily: 'var(--font-display)',
              fontSize: 'var(--text-xs)',
              letterSpacing: 'var(--tracking-wider)',
              color: 'var(--accent)'
            }}
          >
            APPLICATIONS
          </span>
          <span style={{ fontSize: 'var(--text-2xs)', color: 'var(--text-muted)' }}>
            {matches.length}/{apps.length} INDEXED
          </span>
        </div>

        <Input prefix="search" value={q} onChange={setQ} placeholder="filter applications" />

        <div style={{ marginTop: '14px', maxHeight: '470px', overflowY: 'auto' }}>
          {CATS.map(([cat, label]) => {
            const list = matches.filter((a) => a.cat === cat);
            if (!list.length) return null;
            return (
              <div key={cat} style={{ marginBottom: '14px' }}>
                <div
                  style={{
                    fontSize: 'var(--text-2xs)',
                    color: 'var(--text-muted)',
                    letterSpacing: 'var(--tracking-wider)',
                    borderBottom: '1px solid var(--grey-line)',
                    paddingBottom: '4px',
                    marginBottom: '8px'
                  }}
                >
                  {label}
                </div>
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4,1fr)', gap: '6px' }}>
                  {list.map((a) => (
                    <LauncherTile
                      key={a.id}
                      app={a}
                      open={openIds.includes(a.id)}
                      onClick={() => onLaunch(a)}
                    />
                  ))}
                </div>
              </div>
            );
          })}
          {!matches.length && (
            <div
              style={{
                fontSize: 'var(--text-2xs)',
                color: 'var(--text-muted)',
                padding: '18px 0',
                textAlign: 'center'
              }}
            >
              NO MATCH — "{q}"
            </div>
          )}
        </div>
      </div>
    </>
  );
}

function LauncherTile({ app, open, onClick }) {
  const { Icon } = window.SymbioteOSDesignSystem_5d2af6;
  const [hover, setHover] = React.useState(false);
  return (
    <button
      onClick={onClick}
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => setHover(false)}
      style={{
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        gap: '7px',
        padding: '12px 6px',
        background: hover ? 'var(--blue-faint)' : 'transparent',
        border: `1px solid ${hover ? 'var(--accent)' : 'var(--grey-line)'}`,
        color: hover || open ? 'var(--accent)' : 'var(--text-body)',
        cursor: 'pointer',
        fontFamily: 'var(--font-mono)',
        fontSize: '7px',
        letterSpacing: '0.06em',
        textAlign: 'center',
        transition: 'all var(--dur-fast) var(--ease-symbiote)',
        boxShadow: hover ? 'var(--glow-xs)' : 'none'
      }}
    >
      <Icon name={app.icon} size={20} strokeWidth={1.5} />
      {app.title}
    </button>
  );
}

window.AppLauncher = AppLauncher;
