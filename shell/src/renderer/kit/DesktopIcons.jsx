/* Desktop icons: folders and installed apps sitting directly on the wallpaper,
   not inside a panel. Single click opens.

   The glyphs are drawn here rather than taken from the icon set: generic line
   icons read as "some app", and next to the hologram and the bracketed panels
   they looked borrowed. These are built from the same vocabulary as the rest of
   the HUD — thin strokes, angular geometry, concentric rings, corner brackets. */

/* Deliberately short. Everything else lives in the taskbar and the launcher,
   so the desktop stays a place for the few things you reach for constantly. */
const DESKTOP_ITEMS = [
  { id: 'files',    glyph: 'files',    label: 'FILES',    code: 'FS_00', app: 'files' },
  { id: 'browser',  glyph: 'browser',  label: 'FIREFOX',  code: 'NET_01', app: 'browser' },
  { id: 'settings', glyph: 'settings', label: 'SETTINGS', code: 'SYS_02', app: 'settings' },
  { id: 'trash',    glyph: 'trash',    label: 'TRASH',    code: 'BIN_03', app: 'trash' }
];

/* Each glyph is a 32x32 viewBox. Strokes inherit currentColor so the icon
   follows the hover / open / starting state without duplicating the palette. */
function DesktopGlyph({ name, size = 30 }) {
  const s = { fill: 'none', stroke: 'currentColor', strokeWidth: 1.25, strokeLinecap: 'square' };
  const faint = { ...s, opacity: 0.45 };

  const glyphs = {
    // Angular folder with a data manifest inside, not a rounded document icon.
    files: (
      <g>
        <path d="M3.5 25.5 L3.5 7.5 L12 7.5 L14.5 11 L28.5 11 L28.5 25.5 Z" style={s} />
        <path d="M3.5 15 L28.5 15" style={faint} />
        <path d="M7 19 L14 19" style={faint} />
        <path d="M7 22 L11 22" style={faint} />
        <rect x="24" y="18" width="3" height="3" style={{ ...s, opacity: 0.8 }} />
      </g>
    ),

    // Wireframe globe echoing the symbiont hologram: meridian plus latitudes.
    browser: (
      <g>
        <circle cx="16" cy="16" r="12" style={s} />
        <ellipse cx="16" cy="16" rx="5" ry="12" style={faint} />
        <path d="M4.6 12.5 L27.4 12.5" style={faint} />
        <path d="M4.6 19.5 L27.4 19.5" style={faint} />
        <path d="M16 4 L16 28" style={{ ...s, opacity: 0.25 }} />
        <circle cx="24.5" cy="10" r="1.4" style={{ ...s, fill: 'currentColor' }} />
      </g>
    ),

    // Arc-reactor dial rather than a cog: same language as the gauges.
    settings: (
      <g>
        <circle cx="16" cy="16" r="11" style={s} />
        <circle cx="16" cy="16" r="4.5" style={s} />
        {Array.from({ length: 8 }).map((_, i) => {
          const a = (i / 8) * Math.PI * 2;
          return (
            <line
              key={i}
              x1={16 + Math.cos(a) * 11}
              y1={16 + Math.sin(a) * 11}
              x2={16 + Math.cos(a) * 14}
              y2={16 + Math.sin(a) * 14}
              style={i % 2 === 0 ? s : faint}
            />
          );
        })}
        <circle cx="16" cy="16" r="7.75" style={{ ...faint, strokeDasharray: '2 3' }} />
      </g>
    ),

    // Tapered bin with slats; the lid is a single hairline like a panel edge.
    trash: (
      <g>
        <path d="M7.5 10 L9.5 27 L22.5 27 L24.5 10" style={s} />
        <path d="M4 10 L28 10" style={s} />
        <path d="M12.5 10 L12.5 6.5 L19.5 6.5 L19.5 10" style={s} />
        <path d="M13 14.5 L13 23" style={faint} />
        <path d="M16 14.5 L16 23" style={faint} />
        <path d="M19 14.5 L19 23" style={faint} />
      </g>
    )
  };

  return (
    <svg width={size} height={size} viewBox="0 0 32 32" style={{ display: 'block', overflow: 'visible' }}>
      {glyphs[name] || null}
    </svg>
  );
}

function DesktopIcons({ items = DESKTOP_ITEMS, openIds = [], starting = [], onOpen, columns = 1 }) {
  const [selected, setSelected] = React.useState(null);

  return (
    <div
      onClick={() => setSelected(null)}
      style={{
        display: 'grid',
        gridTemplateColumns: `repeat(${columns}, 1fr)`,
        gridAutoRows: 'min-content',
        gap: '10px',
        alignContent: 'start'
      }}
    >
      {items.map((it) => (
        <DesktopIcon
          key={it.id}
          item={it}
          selected={selected === it.id}
          open={openIds.includes(it.app)}
          starting={starting.includes(it.app)}
          onSelect={(e) => {
            e.stopPropagation();
            setSelected(it.id);
          }}
          onOpen={() => onOpen && onOpen(it)}
        />
      ))}
    </div>
  );
}

/* Corner brackets, matching the panels. Drawn as four spans rather than a
   border so the frame stays open at the edges. */
function Brackets({ color, size = 9 }) {
  const base = { position: 'absolute', width: size, height: size, pointerEvents: 'none' };
  const t = `1px solid ${color}`;
  return (
    <React.Fragment>
      <span style={{ ...base, top: 0, left: 0, borderTop: t, borderLeft: t }} />
      <span style={{ ...base, top: 0, right: 0, borderTop: t, borderRight: t }} />
      <span style={{ ...base, bottom: 0, left: 0, borderBottom: t, borderLeft: t }} />
      <span style={{ ...base, bottom: 0, right: 0, borderBottom: t, borderRight: t }} />
    </React.Fragment>
  );
}

function DesktopIcon({ item, selected, open, starting, onSelect, onOpen }) {
  const [hover, setHover] = React.useState(false);
  const lit = selected || hover || open || starting;

  /* Single click opens. Double click is the desktop convention, but here the
     only thing single click did was select, and selection drives nothing —
     so a click looked like the icon was broken. */
  return (
    <button
      onClick={(e) => {
        onSelect(e);
        onOpen();
      }}
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => setHover(false)}
      title={starting ? `${item.label} — starting...` : item.label}
      style={{
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        gap: '7px',
        padding: '4px 2px 6px',
        background: 'transparent',
        border: 'none',
        color: lit ? 'var(--accent)' : 'var(--text-body)',
        cursor: 'pointer',
        fontFamily: 'var(--font-mono)',
        transition: 'color var(--dur-fast) var(--ease-symbiote)'
      }}
    >
      {/* the framed cell */}
      <span
        style={{
          position: 'relative',
          width: '62px',
          height: '62px',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          background: lit ? 'var(--blue-faint)' : 'rgba(0,255,136,0.02)',
          transition: 'background var(--dur-fast) var(--ease-symbiote)',
          filter: lit ? 'drop-shadow(0 0 6px var(--state-ok-glow))' : 'none'
        }}
      >
        <Brackets color={lit ? 'var(--accent)' : 'var(--grey-line)'} />
        <DesktopGlyph name={item.glyph} size={30} />

        {(open || starting) && (
          <span
            style={{
              position: 'absolute',
              top: '5px',
              right: '5px',
              width: '4px',
              height: '4px',
              background: 'var(--accent)',
              boxShadow: '0 0 5px var(--accent)',
              // Firefox under software rendering can take half a minute to show
              // its first window. Without this the click looks like it did nothing.
              animation: starting ? 'symbiote-pulse 900ms ease-in-out infinite' : 'none'
            }}
          />
        )}

        {/* the module's code, bottom-left inside the frame */}
        <span
          style={{
            position: 'absolute',
            bottom: '3px',
            left: '5px',
            fontSize: '6px',
            letterSpacing: '0.08em',
            color: 'var(--text-muted)',
            opacity: lit ? 0.9 : 0.45
          }}
        >
          {item.code}
        </span>
      </span>

      <span
        style={{
          fontSize: 'var(--text-2xs)',
          letterSpacing: '0.1em',
          lineHeight: 1.3,
          whiteSpace: 'nowrap'
        }}
      >
        {starting ? 'STARTING…' : item.label}
      </span>
    </button>
  );
}

window.DESKTOP_ITEMS = DESKTOP_ITEMS;
window.DesktopIcons = DesktopIcons;
