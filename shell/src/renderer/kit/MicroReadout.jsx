function MicroReadout({
  code,
  label,
  value,
  bars = 8,
  active = 4,
  critical = false,
  compact = false
}) {
  const color = critical ? 'var(--state-critical)' : 'var(--accent)';
  return (
    <div
      style={{
        marginBottom: compact ? '7px' : '10px',
        fontFamily: 'var(--font-mono)'
      }}
    >
      <div
        style={{
          display: 'flex',
          justifyContent: 'space-between',
          fontSize: 'var(--text-2xs)',
          color: 'var(--text-muted)',
          letterSpacing: '0.05em'
        }}
      >
        <span>{code}</span>
        <span style={{ color }}>{value}</span>
      </div>
      <div
        style={{
          fontSize: 'var(--text-2xs)',
          color: critical ? 'var(--state-critical)' : 'var(--text-body)',
          marginBottom: '3px'
        }}
      >
        {label}
      </div>
      <div style={{ display: 'flex', gap: '2px' }}>
        {Array.from({ length: bars }).map((_, i) => (
          <span
            key={i}
            style={{
              flex: 1,
              height: compact ? '3px' : '4px',
              background: i < active ? color : 'var(--grey-line)',
              boxShadow: i < active ? `0 0 3px ${color}` : 'none'
            }}
          />
        ))}
      </div>
    </div>
  );
}
window.MicroReadout = MicroReadout;
