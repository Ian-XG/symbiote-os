/* Full-width OS taskbar: launcher button, pinned apps, system tray.
   Named Taskbar (not Dock) so it does not collide with the desktop kit's
   floating window.Dock. */

const SYM_APPS = [
  { id: 'files',     icon: 'folder',        title: 'FILE MANAGER', cat: 'system' },
  { id: 'terminal',  icon: 'terminal',      title: 'TERMINAL',     cat: 'system' },
  { id: 'browser',   icon: 'globe',         title: 'FIREFOX',      cat: 'system' },
  { id: 'nmap',      icon: 'radar',         title: 'NETWORK SCAN', cat: 'recon' },
  { id: 'vuln',      icon: 'bug',           title: 'VULN SCANNER', cat: 'recon' },
  { id: 'proxy',     icon: 'git-branch',    title: 'INTERCEPT PROXY', cat: 'recon' },
  { id: 'exploit',   icon: 'zap',           title: 'EXPLOIT KIT',  cat: 'offense' },
  { id: 'creds',     icon: 'key-round',     title: 'CREDENTIALS',  cat: 'offense' },
  { id: 'loot',      icon: 'database',      title: 'LOOT DB',      cat: 'offense' },
  { id: 'firewall',  icon: 'shield',        title: 'FIREWALL',     cat: 'defense' },
  { id: 'monitor',   icon: 'activity',      title: 'MONITOR',      cat: 'defense' },
  { id: 'vault',     icon: 'lock',          title: 'VAULT',        cat: 'defense' },
  { id: 'settings',  icon: 'settings',      title: 'SETTINGS',     cat: 'system' },
  { id: 'trash',     icon: 'trash-2',       title: 'TRASH',        cat: 'system' }
];

const PINNED = ['files', 'terminal', 'browser', 'nmap', 'vuln', 'exploit', 'firewall'];

function TaskbarIcon({ app, open, onClick, size = 19 }) {
  const { Icon } = window.SymbioteOSDesignSystem_5d2af6;
  const [hover, setHover] = React.useState(false);
  const lit = hover || open;
  return (
    <button
      title={app.title}
      onClick={onClick}
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => setHover(false)}
      style={{
        position: 'relative',
        width: '46px',
        height: '46px',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        gap: '5px',
        background: hover ? 'var(--blue-faint)' : 'transparent',
        border: '1px solid transparent',
        borderColor: hover ? 'var(--border-panel-dim)' : 'transparent',
        color: lit ? 'var(--accent)' : 'var(--text-muted)',
        cursor: 'pointer',
        padding: 0,
        transition: 'all var(--dur-fast) var(--ease-symbiote)',
        filter: lit ? 'drop-shadow(0 0 5px var(--state-ok-glow))' : 'none'
      }}
    >
      <Icon name={app.icon} size={size} strokeWidth={1.5} />
      <span
        style={{
          width: open ? '14px' : '4px',
          height: '2px',
          background: open ? 'var(--accent)' : 'var(--grey-line)',
          boxShadow: open ? '0 0 5px var(--accent)' : 'none',
          transition: 'all var(--dur-fast) var(--ease-symbiote)'
        }}
      />
    </button>
  );
}

function Taskbar({ apps = SYM_APPS, pinned = PINNED, openIds = [], onLaunch, onToggleLauncher, launcherOpen, time, onExit, vpn = true }) {
  const { Icon, Badge, IconButton } = window.SymbioteOSDesignSystem_5d2af6;
  const byId = Object.fromEntries(apps.map((a) => [a.id, a]));
  const trash = byId.trash;

  return (
    <div
      style={{
        position: 'absolute',
        bottom: 0,
        left: 0,
        right: 0,
        height: '72px',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        padding: '0 18px',
        boxSizing: 'border-box',
        borderTop: '1px solid var(--hud-hairline)',
        background: 'rgba(0,12,7,0.72)',
        backdropFilter: 'var(--blur-glass)',
        WebkitBackdropFilter: 'var(--blur-glass)',
        zIndex: 60
      }}
    >
      {/* launcher */}
      <button
        onClick={onToggleLauncher}
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: '10px',
          height: '46px',
          padding: '0 16px',
          background: launcherOpen ? 'var(--blue-faint)' : 'transparent',
          border: `1px solid ${launcherOpen ? 'var(--accent)' : 'var(--border-panel-dim)'}`,
          color: 'var(--accent)',
          cursor: 'pointer',
          fontFamily: 'var(--font-mono)',
          fontSize: 'var(--text-sm)',
          letterSpacing: 'var(--tracking-wider)',
          boxShadow: launcherOpen ? 'var(--glow-sm)' : 'none',
          transition: 'all var(--dur-fast) var(--ease-symbiote)'
        }}
      >
        <span
          style={{
            width: '11px',
            height: '11px',
            background: 'var(--accent)',
            transform: 'rotate(45deg)',
            boxShadow: 'var(--glow-sm)'
          }}
        />
        MENU
      </button>

      {/* pinned apps */}
      <div style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
        {pinned.map((id) => (
          <TaskbarIcon
            key={id}
            app={byId[id]}
            open={openIds.includes(id)}
            onClick={() => onLaunch(byId[id])}
          />
        ))}
        <span style={{ width: '1px', height: '28px', background: 'var(--grey-line)', margin: '0 8px' }} />
        <TaskbarIcon app={trash} open={openIds.includes('trash')} onClick={() => onLaunch(trash)} />
      </div>

      {/* tray */}
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: '14px',
          fontFamily: 'var(--font-mono)',
          fontSize: 'var(--text-2xs)',
          color: 'var(--text-muted)'
        }}
      >
        <Badge severity={vpn ? 'ok' : 'neutral'} pulse={vpn}>VPN</Badge>
        <span style={{ display: 'flex', alignItems: 'center', gap: '5px' }}>
          <Icon name="wifi" size={13} /> eth1
        </span>
        <span style={{ display: 'flex', alignItems: 'center', gap: '5px' }}>
          <Icon name="cpu" size={13} /> 64%
        </span>
        <span style={{ display: 'flex', alignItems: 'center', gap: '5px' }}>
          <Icon name="battery-charging" size={13} /> 82%
        </span>
        <span
          style={{
            color: 'var(--accent)',
            fontSize: 'var(--text-md)',
            fontVariantNumeric: 'tabular-nums',
            letterSpacing: 'var(--tracking-wide)'
          }}
        >
          {time}
        </span>
        {/* the top bar is gone, so the desktop kit's exit affordance lives here */}
        {onExit && (
          <IconButton label="back to desktop" onClick={onExit}>
            <Icon name="log-out" size={14} />
          </IconButton>
        )}
      </div>
    </div>
  );
}

window.SYM_APPS = SYM_APPS;
window.Taskbar = Taskbar;
window.TaskbarIcon = TaskbarIcon;
