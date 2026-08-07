/* Wi-Fi: the part that was missing.
 *
 * The bridge could scan, list and connect from the start, but nothing in the
 * interface ever called it — the status rail showed a read-only summary and
 * there was no way to actually join a network. On a laptop that means no
 * internet, which makes everything else academic. This is the missing UI. */

function SignalBars({ strength, critical }) {
  // Four bars, filled by signal percentage. Reads faster than a number.
  const lit = Math.max(1, Math.ceil((strength / 100) * 4));
  return (
    <span style={{ display: 'inline-flex', alignItems: 'flex-end', gap: '2px', height: '12px' }}>
      {[0, 1, 2, 3].map((i) => (
        <span
          key={i}
          style={{
            width: '3px',
            height: `${4 + i * 3}px`,
            background: i < lit ? (critical ? 'var(--state-critical)' : 'var(--accent)') : 'var(--grey-line)',
            boxShadow: i < lit ? '0 0 4px var(--state-ok-glow)' : 'none'
          }}
        />
      ))}
    </span>
  );
}

function NetworkPanel() {
  const { Icon, Input, Badge } = window.SymbioteOSDesignSystem_5d2af6;
  const bridge = typeof window !== 'undefined' && window.symbiote;

  const [status, setStatus] = React.useState(null);
  const [busy, setBusy] = React.useState(null);      // 'scan' | ssid | null
  const [selected, setSelected] = React.useState(null);
  const [passphrase, setPassphrase] = React.useState('');
  const [error, setError] = React.useState(null);

  const refresh = React.useCallback(() => {
    if (!bridge) return;
    bridge.wifi.status().then((r) => {
      if (r.ok) setStatus(r.data);
      else setError(r.error);
    });
  }, [bridge]);

  React.useEffect(() => {
    refresh();
    if (!bridge) return undefined;
    // The rail already polls; this keeps the list fresh while the panel is open.
    const id = setInterval(refresh, 6000);
    return () => clearInterval(id);
  }, [bridge, refresh]);

  if (!bridge) {
    return (
      <div style={{ padding: '20px 0', fontSize: 'var(--text-xs)', color: 'var(--text-muted)' }}>
        Network control is only available on the running system, not in the design preview.
      </div>
    );
  }

  const scan = () => {
    setBusy('scan');
    setError(null);
    bridge.wifi.scan().then((r) => {
      setBusy(null);
      if (r.ok) setStatus(r.data);
      else setError(r.error);
    });
  };

  const connect = (net) => {
    setBusy(net.ssid);
    setError(null);
    bridge.wifi.connect(net.ssid, net.secure ? passphrase : undefined).then((r) => {
      setBusy(null);
      if (r.ok) {
        setStatus(r.data);
        setSelected(null);
        setPassphrase('');
      } else {
        // Wrong passphrase is the common case and NM's message is cryptic.
        setError(/secret|key|auth/i.test(r.error) ? 'Wrong password, or the network refused the connection.' : r.error);
      }
    });
  };

  const disconnect = () => {
    setBusy('disconnect');
    bridge.wifi.disconnect().then((r) => {
      setBusy(null);
      if (r.ok) setStatus(r.data);
      else setError(r.error);
    });
  };

  const toggleRadio = (on) => {
    setBusy('radio');
    bridge.wifi.setEnabled(on).then((r) => {
      setBusy(null);
      if (r.ok) setStatus(r.data);
      else setError(r.error);
    });
  };

  if (!status) {
    return <div style={{ padding: '20px 0', fontSize: 'var(--text-xs)', color: 'var(--text-muted)' }}>Querying NetworkManager…</div>;
  }

  if (!status.available) {
    return (
      <div style={{ padding: '20px 0' }}>
        <Badge severity="neutral">NO WI-FI ADAPTER</Badge>
        <div style={{ fontSize: 'var(--text-2xs)', color: 'var(--text-muted)', marginTop: '10px' }}>
          {status.error
            ? status.error
            : 'This machine has no wireless device, or its driver did not load. A wired connection still works.'}
        </div>
      </div>
    );
  }

  const connected = (status.networks || []).find((n) => n.connected);

  return (
    <div>
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          padding: '12px 0',
          borderBottom: '1px solid rgba(255,255,255,0.05)'
        }}
      >
        <div>
          <div style={{ fontSize: 'var(--text-sm)', color: 'var(--text-body)' }}>Wi-Fi</div>
          <div style={{ fontSize: 'var(--text-2xs)', color: 'var(--text-muted)', marginTop: '3px' }}>
            {status.device}
            {connected ? ` · connected to ${connected.ssid}` : status.enabled ? ' · not connected' : ' · radio off'}
          </div>
        </div>
        <div style={{ display: 'flex', gap: '8px' }}>
          <HudButton onClick={() => toggleRadio(!status.enabled)} busy={busy === 'radio'}>
            {status.enabled ? 'TURN OFF' : 'TURN ON'}
          </HudButton>
          {status.enabled && (
            <HudButton onClick={scan} busy={busy === 'scan'}>
              {busy === 'scan' ? 'SCANNING…' : 'SCAN'}
            </HudButton>
          )}
          {connected && (
            <HudButton onClick={disconnect} busy={busy === 'disconnect'} danger>
              DISCONNECT
            </HudButton>
          )}
        </div>
      </div>

      {error && (
        <div
          style={{
            margin: '12px 0',
            padding: '9px 12px',
            border: '1px solid var(--state-critical)',
            color: 'var(--state-critical)',
            fontSize: 'var(--text-2xs)',
            background: 'rgba(255,23,68,.08)'
          }}
        >
          {error}
        </div>
      )}

      {!status.enabled && (
        <div style={{ padding: '18px 0', fontSize: 'var(--text-xs)', color: 'var(--text-muted)' }}>
          The radio is off. Turn it on to see nearby networks.
        </div>
      )}

      {status.enabled && !(status.networks || []).length && (
        <div style={{ padding: '18px 0', fontSize: 'var(--text-xs)', color: 'var(--text-muted)' }}>
          No networks found yet. Press SCAN — the first sweep after boot can take a few seconds.
        </div>
      )}

      <div style={{ maxHeight: '260px', overflowY: 'auto', marginTop: '4px' }}>
        {(status.networks || []).map((net) => {
          const open = selected === net.ssid;
          return (
            <div key={net.ssid} style={{ borderBottom: '1px solid rgba(255,255,255,0.04)' }}>
              <button
                onClick={() => {
                  setError(null);
                  setPassphrase('');
                  setSelected(open ? null : net.ssid);
                }}
                style={{
                  width: '100%',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  gap: '12px',
                  padding: '10px 4px',
                  background: open ? 'var(--blue-faint)' : 'transparent',
                  border: 'none',
                  color: net.connected ? 'var(--accent)' : 'var(--text-body)',
                  fontFamily: 'var(--font-mono)',
                  fontSize: 'var(--text-xs)',
                  cursor: 'pointer',
                  textAlign: 'left'
                }}
              >
                <span style={{ display: 'flex', alignItems: 'center', gap: '9px', minWidth: 0 }}>
                  <SignalBars strength={net.strength} />
                  <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                    {net.connected ? '● ' : ''}{net.ssid}
                  </span>
                </span>
                <span style={{ display: 'flex', alignItems: 'center', gap: '10px', color: 'var(--text-muted)', flexShrink: 0 }}>
                  <span>{net.band}</span>
                  <span>{net.secure ? 'WPA' : 'OPEN'}</span>
                  <span>{net.strength}%</span>
                </span>
              </button>

              {open && !net.connected && (
                <div style={{ padding: '4px 4px 14px', display: 'flex', gap: '8px', alignItems: 'center' }}>
                  {net.secure && (
                    <div style={{ flex: 1 }}>
                      <Input
                        prefix="key"
                        value={passphrase}
                        onChange={setPassphrase}
                        placeholder="network password"
                        onKeyDown={(e) => {
                          if (e.key === 'Enter' && passphrase) connect(net);
                        }}
                      />
                    </div>
                  )}
                  <HudButton
                    onClick={() => connect(net)}
                    busy={busy === net.ssid}
                    disabled={net.secure && !passphrase}
                  >
                    {busy === net.ssid ? 'CONNECTING…' : 'CONNECT'}
                  </HudButton>
                </div>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}

function HudButton({ children, onClick, busy, disabled, danger }) {
  const [hover, setHover] = React.useState(false);
  const off = disabled || busy;
  const color = danger ? 'var(--state-critical)' : 'var(--accent)';
  return (
    <button
      onClick={off ? undefined : onClick}
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => setHover(false)}
      disabled={off}
      style={{
        padding: '6px 12px',
        background: hover && !off ? 'var(--blue-faint)' : 'transparent',
        border: `1px solid ${off ? 'var(--grey-line)' : color}`,
        color: off ? 'var(--text-muted)' : color,
        fontFamily: 'var(--font-mono)',
        fontSize: 'var(--text-2xs)',
        letterSpacing: 'var(--tracking-wide)',
        cursor: off ? 'default' : 'pointer',
        whiteSpace: 'nowrap',
        transition: 'all var(--dur-fast) var(--ease-symbiote)'
      }}
    >
      {children}
    </button>
  );
}

window.NetworkPanel = NetworkPanel;
