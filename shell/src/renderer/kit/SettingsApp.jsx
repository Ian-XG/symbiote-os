/* Settings window content. Every control here is wired to real state in
   Dashboard — nothing is a decorative toggle. */

function SettingRow({ label, hint, children }) {
  return (
    <div
      style={{
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        gap: '24px',
        padding: '13px 0',
        borderBottom: '1px solid rgba(255,255,255,0.05)'
      }}
    >
      <div style={{ minWidth: 0 }}>
        <div style={{ fontSize: 'var(--text-sm)', color: 'var(--text-body)', letterSpacing: '0.04em' }}>
          {label}
        </div>
        {hint && (
          <div style={{ fontSize: 'var(--text-2xs)', color: 'var(--text-muted)', marginTop: '3px' }}>
            {hint}
          </div>
        )}
      </div>
      <div style={{ flexShrink: 0 }}>{children}</div>
    </div>
  );
}

function Segmented({ options, value, onChange }) {
  return (
    <div style={{ display: 'flex', gap: '6px' }}>
      {options.map((o) => {
        const on = o.value === value;
        return (
          <button
            key={o.value}
            onClick={() => onChange(o.value)}
            style={{
              padding: '6px 12px',
              background: on ? 'var(--blue-faint)' : 'transparent',
              border: `1px solid ${on ? 'var(--accent)' : 'var(--grey-line)'}`,
              color: on ? 'var(--accent)' : 'var(--text-muted)',
              fontFamily: 'var(--font-mono)',
              fontSize: 'var(--text-2xs)',
              letterSpacing: 'var(--tracking-wide)',
              cursor: 'pointer',
              boxShadow: on ? 'var(--glow-xs)' : 'none',
              transition: 'all var(--dur-fast) var(--ease-symbiote)'
            }}
          >
            {o.label}
          </button>
        );
      })}
    </div>
  );
}

function SettingsApp({ settings, onChange, uptime, live }) {
  const { Tabs, Switch, Input, Badge } = window.SymbioteOSDesignSystem_5d2af6;
  const [section, setSection] = React.useState('APPEARANCE');
  const set = (k) => (v) => onChange({ ...settings, [k]: v });

  const hh = String(Math.floor(uptime / 3600)).padStart(2, '0');
  const mm = String(Math.floor((uptime % 3600) / 60)).padStart(2, '0');

  return (
    <div style={{ fontFamily: 'var(--font-mono)' }}>
      <div style={{ borderBottom: '1px solid var(--grey-line)', paddingBottom: '12px', marginBottom: '6px' }}>
        <Tabs
          items={['APPEARANCE', 'NETWORK', 'SYSTEM', 'SECURITY', 'ABOUT']}
          active={section}
          onChange={setSection}
        />
      </div>

      {section === 'APPEARANCE' && (
        <div>
          <SettingRow label="Accent colour" hint="Recolours the whole interface">
            <Segmented
              value={settings.accent}
              onChange={set('accent')}
              options={[
                { value: 'toxin', label: 'TOXIN GREEN' },
                { value: 'signal', label: 'SIGNAL BLUE' }
              ]}
            />
          </SettingRow>
          <SettingRow
            label="Interface scale"
            hint="Auto doubles it on high-density panels. Change this if the text is too small or too large."
          >
            <Segmented
              value={settings.scale}
              onChange={(v) => {
                set('scale')(v);
                if (window.symbiote) window.symbiote.ui.setScale(v === 'auto' ? 'auto' : Number(v));
              }}
              options={[
                { value: 'auto', label: 'AUTO' },
                { value: '1', label: '1×' },
                { value: '1.5', label: '1.5×' },
                { value: '2', label: '2×' }
              ]}
            />
          </SettingRow>
          <SettingRow label="Scan line" hint="Sweeping highlight across the screen">
            <Switch checked={settings.scanline} onChange={set('scanline')} label={settings.scanline ? 'on' : 'off'} />
          </SettingRow>
          <SettingRow label="Background grid" hint="Technical grid behind the desktop">
            <Switch checked={settings.grid} onChange={set('grid')} label={settings.grid ? 'on' : 'off'} />
          </SettingRow>
          <SettingRow label="Screen vignette" hint="Darkens the edges of the display">
            <Switch checked={settings.vignette} onChange={set('vignette')} label={settings.vignette ? 'on' : 'off'} />
          </SettingRow>
          <SettingRow label="Hologram rotation" hint="Also pauses itself when a window covers it or the machine is on battery — it costs a CPU core to animate.">
            <Switch checked={settings.spin} onChange={set('spin')} label={settings.spin ? 'on' : 'off'} />
          </SettingRow>
        </div>
      )}

      {section === 'NETWORK' && <window.NetworkPanel />}

      {section === 'SYSTEM' && (
        <div>
          <SettingRow label="Device name" hint="Shown on the network and in About">
            <div style={{ width: '220px' }}>
              <Input prefix="host" value={settings.hostname} onChange={set('hostname')} />
            </div>
          </SettingRow>
          <SettingRow label="24-hour clock" hint="Affects the taskbar clock">
            <Switch checked={settings.clock24} onChange={set('clock24')} label={settings.clock24 ? '24h' : '12h'} />
          </SettingRow>
          <SettingRow label="Show seconds" hint="Taskbar clock precision">
            <Switch checked={settings.seconds} onChange={set('seconds')} label={settings.seconds ? 'on' : 'off'} />
          </SettingRow>
          <SettingRow label="Automatic updates" hint="3 packages waiting to install">
            <Switch checked={settings.autoUpdate} onChange={set('autoUpdate')} label={settings.autoUpdate ? 'on' : 'off'} />
          </SettingRow>
        </div>
      )}

      {section === 'SECURITY' && (
        <div>
          {/* These were switches. They looked like controls but changed only a
              label — the firewall was never touched. Reporting the real state
              and saying plainly where it is changed is more use than a toggle
              that lies. */}
          <div
            style={{
              fontSize: 'var(--text-2xs)',
              color: 'var(--text-muted)',
              padding: '10px 0 14px',
              lineHeight: 1.6
            }}
          >
            Read from the running system. This is a live image, so changes made here
            do not survive a reboot until the installer lands.
          </div>
          {live && live.security ? (
            <window.StatusList
              rows={[
                { label: 'Firewall', value: live.security.firewall.value, state: live.security.firewall.state },
                { label: 'VPN', value: live.security.vpn.value, state: live.security.vpn.state },
                { label: 'Disk encryption', value: live.security.encryption.value, state: live.security.encryption.state },
                { label: 'Updates', value: live.security.updates.value, state: live.security.updates.state },
                { label: 'Ports open to the network', value: live.security.ports.value, state: live.security.ports.state }
              ]}
            />
          ) : (
            <div style={{ fontSize: 'var(--text-xs)', color: 'var(--text-muted)' }}>
              {live ? 'Reading system state…' : 'Only available on the running system.'}
            </div>
          )}
        </div>
      )}

      {section === 'ABOUT' && (
        <div style={{ fontSize: 'var(--text-sm)' }}>
          {/* These were hardcoded (8 cores, 16 GB, 512 GB) regardless of the
              machine. Now they come from the same snapshot the rail uses. */}
          {(() => {
            const sys = live && live.system;
            const rows = [
              ['Device name', (sys && sys.hostname) || settings.hostname],
              ['Edition', (sys && sys.os && sys.os.name) || 'Symbiote OS 4.2.1 "Toxin"'],
              ['Processor', sys ? `${sys.cpu.cores} cores${sys.cpu.ghz ? ' · ' + sys.cpu.ghz + ' GHz' : ''}` : '—'],
              ['Memory', sys ? `${sys.memory.totalGb} GB` : '—'],
              ['Storage', sys ? `${sys.storage.totalGb} GB` : '—'],
              ['Uptime', sys ? window.Live.uptime(sys.uptime) : `${hh}h ${mm}m`],
              ['Shell', 'Symbiote Shell 1.4'],
              ['Licence', 'GPL-3.0']
            ];
            return rows.map(([k, v]) => (
              <div
                key={k}
                style={{
                  display: 'flex',
                  justifyContent: 'space-between',
                  gap: '20px',
                  padding: '9px 0',
                  borderBottom: '1px solid rgba(255,255,255,0.05)'
                }}
              >
                <span style={{ color: 'var(--text-muted)' }}>{k}</span>
                <span style={{ color: 'var(--text-body)' }}>{v}</span>
              </div>
            ));
          })()}
        </div>
      )}
    </div>
  );
}

window.SettingsApp = SettingsApp;
