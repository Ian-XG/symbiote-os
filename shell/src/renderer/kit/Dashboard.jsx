const DEFAULT_SETTINGS = {
  accent: 'toxin',
  scale: 'auto',
  scanline: true,
  grid: true,
  vignette: true,
  spin: true,
  hostname: 'symbiote-01',
  clock24: true,
  seconds: true,
  autoUpdate: false
};

/* Tracks the viewport so the shell can lay out at the display's real size.
   The design preview keeps the fixed 1920x1080 artboard; the OS does not. */
function useViewport(enabled) {
  const [size, setSize] = React.useState(() => ({
    w: typeof window !== 'undefined' ? window.innerWidth : 1920,
    h: typeof window !== 'undefined' ? window.innerHeight : 1080
  }));
  React.useEffect(() => {
    if (!enabled) return undefined;
    const onResize = () => setSize({ w: window.innerWidth, h: window.innerHeight });
    window.addEventListener('resize', onResize);
    return () => window.removeEventListener('resize', onResize);
  }, [enabled]);
  return size;
}

function Dashboard(props) {
  const { onExit, fill = false } = props || {};
  const { Panel } = window.SymbioteOSDesignSystem_5d2af6;
  const {
    Hologram, MicroReadout, Waveform, ProcessList, StatusList,
    DesktopIcons, Taskbar, AppLauncher, SettingsApp, WindowFrame, SYM_APPS
  } = window;

  const [clock, setClock] = React.useState(new Date());
  const [tick, setTick] = React.useState(0);
  const [uptime, setUptime] = React.useState(50557);
  const [openIds, setOpenIds] = React.useState(['terminal']);
  const [minimized, setMinimized] = React.useState([]);
  const [launcherOpen, setLauncherOpen] = React.useState(false);
  const [settings, setSettings] = React.useState(DEFAULT_SETTINGS);

  React.useEffect(() => {
    const id = setInterval(() => {
      setClock(new Date());
      setTick((t) => t + 1);
      setUptime((u) => u + 1);
    }, 1000);
    return () => clearInterval(id);
  }, []);

  const [launchError, setLaunchError] = React.useState(null);
  const [starting, setStarting] = React.useState([]);

  /* On the OS this spawns a real process; the compositor puts its window above
     the shell. In the browser preview there is no bridge, so it stays a state
     toggle and the indicator is all you get. Settings is a window inside the
     shell either way, so it never goes to the launcher. */
  const toggle = (id) => {
    const bridge = typeof window !== 'undefined' && window.symbiote;

    if (id === 'settings' || !bridge) {
      if (!openIds.includes(id)) {
        setOpenIds((ids) => [...ids, id]);
        setMinimized((m) => m.filter((i) => i !== id));
      } else {
        setMinimized((m) => (m.includes(id) ? m.filter((i) => i !== id) : [...m, id]));
      }
      return;
    }

    if (openIds.includes(id)) {
      bridge.apps.close(id);
      return;
    }

    /* Firefox under software rendering can take 30s to show a window. Without
       immediate feedback the click reads as "nothing happened" and people
       click again, launching it twice. */
    setStarting((s) => (s.includes(id) ? s : [...s, id]));
    bridge.apps.launch(id).then((r) => {
      if (!r.ok) {
        setStarting((s) => s.filter((i) => i !== id));
        setLaunchError(`${id}: ${r.error}`);
        setTimeout(() => setLaunchError(null), 6000);
      }
    });
  };

  /* Processes can exit on their own, so the open list follows the main process
     rather than our own clicks. Settings is tracked locally alongside it. */
  React.useEffect(() => {
    const bridge = typeof window !== 'undefined' && window.symbiote;
    if (!bridge) return undefined;
    const apply = (ids) => {
      setOpenIds((prev) => (prev.includes('settings') ? [...ids, 'settings'] : ids));
      // A process that is now running is no longer starting.
      setStarting((s) => s.filter((i) => !ids.includes(i)));
    };
    bridge.apps.open().then((r) => r.ok && apply(r.data));
    return bridge.apps.onChange(apply);
  }, []);

  const close = (id) => {
    setOpenIds((ids) => ids.filter((i) => i !== id));
    setMinimized((m) => m.filter((i) => i !== id));
  };

  const launch = (app) => {
    setLauncherOpen(false);
    toggle(app.id);
  };

  const time = clock.toLocaleTimeString('en-US', {
    hour12: !settings.clock24,
    hour: '2-digit',
    minute: '2-digit',
    ...(settings.seconds ? { second: '2-digit' } : {})
  });

  /* On the OS these come from /proc, /sys and D-Bus. In the browser preview
     window.symbiote does not exist, so we fall back to the deterministic
     sample values the design was built with — no Math.random, so a reload
     always starts from the same place. */
  const live = window.useLive ? window.useLive() : null;
  const sys = live && live.system;
  const bars = window.Live ? window.Live.bars : (p, n = 8) => Math.max(1, Math.round((p / 100) * n));

  const wob = (base, amp, phase) =>
    Math.round(base + Math.sin(tick / 7 + phase) * amp + Math.sin(tick / 2.3 + phase) * (amp / 3));

  const iface = sys && window.Live.primaryInterface(sys.network);

  const vitals = sys
    ? {
        cpu: sys.cpu.usage,
        cpuDetail: `${sys.cpu.cores} CORES${sys.cpu.ghz ? ' · ' + sys.cpu.ghz + ' GHz' : ''}`,
        mem: sys.memory.usage,
        memDetail: `${sys.memory.usedGb} / ${sys.memory.totalGb} GB`,
        storage: sys.storage.usage,
        storageDetail: `${sys.storage.freeGb} / ${sys.storage.totalGb} GB FREE`,
        temp: sys.thermal.celsius === null ? 'NO SENSOR' : `${sys.thermal.celsius}°C`,
        tempPct: sys.thermal.celsius === null ? 0 : Math.min(100, sys.thermal.celsius),
        tempDetail: sys.thermal.fanRpm ? `FAN ${sys.thermal.fanRpm.toLocaleString()} RPM` : 'NO FAN DATA',
        battery: sys.power && sys.power.present ? `${sys.power.percent}%` : 'AC POWER',
        batteryPct: sys.power && sys.power.present ? sys.power.percent : 100,
        batteryDetail:
          sys.power && sys.power.present
            ? (sys.power.remaining ? `${sys.power.remaining} REMAINING` : sys.power.state.toUpperCase())
            : 'NO BATTERY',
        down: iface ? iface.downMbs.toFixed(1) : '0.0',
        up: iface ? iface.upMbs.toFixed(1) : '0.0',
        ifaceName: iface ? iface.name.toUpperCase() : 'NO LINK'
      }
    : {
        cpu: wob(34, 9, 0),
        cpuDetail: '8 CORES · 3.4 GHz',
        mem: wob(39, 4, 2),
        memDetail: '6.2 / 16.0 GB',
        storage: 43,
        storageDetail: '218 / 512 GB FREE',
        temp: '62°C',
        tempPct: 55,
        tempDetail: 'FAN 1,420 RPM',
        battery: '82%',
        batteryPct: 82,
        batteryDetail: '2h 41m REMAINING',
        down: (4.2 + Math.sin(tick / 4) * 1.6).toFixed(1),
        up: (1.1 + Math.sin(tick / 5 + 1) * 0.5).toFixed(1),
        ifaceName: 'ETH1'
      };

  const radios = live && live.radios;
  const procs = live && live.processes;

  /* The hologram is the one fixed-size element, so it has to be sized from the
     space actually left between the icon column and the status rail. */
  /* The hologram is the single most expensive thing on screen — the process
     panel measured the shell pinning a full core to animate it. So it stops
     when nobody is looking at it: covered by a window, or running on battery.
     `settings.spin` is permission to animate, not a command to. */
  const appWindowOpen = openIds.some((id) => id !== 'settings');
  const onBattery = !!(sys && sys.power && sys.power.present && !sys.power.onAc);
  const holoPaused = !settings.spin || appWindowOpen || onBattery;

  const view = useViewport(fill);
  const holoSize = fill
    ? Math.max(280, Math.min(view.h - 200, view.w - 124 - 340 - 140))
    : 740;

  /* Everything here is read from the machine. It used to be driven by the
     Settings toggles, which meant the panel reported whatever you had last
     clicked — a screen that claims "Firewall: ACTIVE" with no firewall running
     is worse than no screen at all. Facts that cannot be established say
     UNKNOWN rather than guessing. */
  const sec = live && live.security;
  const securityRows = sec
    ? [
        { label: 'Firewall', value: sec.firewall.value, state: sec.firewall.state },
        { label: 'VPN', value: sec.vpn.value, state: sec.vpn.state },
        { label: 'Disk encryption', value: sec.encryption.value, state: sec.encryption.state },
        { label: 'Updates', value: sec.updates.value, state: sec.updates.state },
        { label: 'Open ports', value: sec.ports.value, state: sec.ports.state }
      ]
    : live
      ? [{ label: 'Reading system state', value: '…', state: 'idle' }]
      : [
          { label: 'Firewall', value: 'ACTIVE', state: 'ok' },
          { label: 'VPN', value: 'NOT CONNECTED', state: 'idle' },
          { label: 'Disk encryption', value: 'ON (LUKS)', state: 'ok' },
          { label: 'Updates', value: 'UP TO DATE', state: 'ok' },
          { label: 'Open ports', value: 'NONE EXPOSED', state: 'ok' }
        ];

  const okCount = securityRows.filter((r) => r.state === 'ok').length;

  const settingsOpen = openIds.includes('settings') && !minimized.includes('settings');

  return (
    <div
      className={'symbiote-hud' + (settings.accent === 'signal' ? ' theme-signal' : '')}
      style={{
        width: fill ? '100vw' : '1920px',
        height: fill ? '100vh' : '1080px',
        background: 'var(--bg-void)',
        position: 'relative',
        overflow: 'hidden',
        fontFamily: 'var(--font-mono)',
        color: 'var(--text-body)'
      }}
    >
      {settings.grid && (
        <div
          style={{
            position: 'absolute',
            inset: 0,
            backgroundImage:
              'linear-gradient(var(--grid-line) 1px, transparent 1px), linear-gradient(90deg, var(--grid-line) 1px, transparent 1px)',
            backgroundSize: '32px 32px',
            pointerEvents: 'none'
          }}
        />
      )}
      {settings.vignette && (
        <div
          style={{
            position: 'absolute',
            inset: 0,
            background:
              'radial-gradient(ellipse at center, transparent 42%, rgba(0,0,0,.6) 100%)',
            pointerEvents: 'none'
          }}
        />
      )}
      {settings.scanline && (
        <div
          style={{
            position: 'absolute',
            left: 0,
            right: 0,
            height: '180px',
            background:
              'linear-gradient(to bottom, transparent, var(--hud-wash), transparent)',
            animation: 'hud-scanline 8s linear infinite',
            pointerEvents: 'none',
            zIndex: 40
          }}
        />
      )}

      {/* ── DESKTOP ─────────────────────────────────────────── */}
      <div
        style={{
          position: 'relative',
          display: 'grid',
          gridTemplateColumns: '124px 1fr 340px',
          gap: '24px',
          padding: '20px',
          height: fill ? 'calc(100vh - 72px)' : '1008px',
          boxSizing: 'border-box',
          zIndex: 10
        }}
      >
        {/* folders + installed apps, straight on the wallpaper */}
        <DesktopIcons openIds={openIds} starting={starting} onOpen={(it) => toggle(it.app)} />

        {/* the symbiont mass */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', minHeight: 0 }}>
          <Hologram size={holoSize} paused={holoPaused} />
        </div>

        {/* ── STATUS RAIL ── */}
        <div
          style={{
            display: 'flex',
            flexDirection: 'column',
            gap: '16px',
            minHeight: 0,
            overflowY: 'auto',
            paddingRight: '4px'
          }}
        >
          <Panel style={{ flexShrink: 0 }} title="SYSTEM" code={live ? (live.connected ? 'LIVE' : 'CONNECTING') : 'LIVE'} active>
            <MicroReadout code={vitals.cpuDetail} compact label="PROCESSOR" value={vitals.cpu + '%'} active={bars(vitals.cpu)} />
            <MicroReadout code={vitals.memDetail} compact label="MEMORY" value={vitals.mem + '%'} active={bars(vitals.mem)} />
            <MicroReadout code={vitals.storageDetail} compact label="STORAGE" value={vitals.storage + '%'} active={bars(vitals.storage)} />
            <MicroReadout
              code={vitals.tempDetail}
              compact
              label="TEMPERATURE"
              value={vitals.temp}
              active={bars(vitals.tempPct)}
              critical={vitals.tempPct > 85}
            />
            <MicroReadout
              code={vitals.batteryDetail}
              compact
              label="BATTERY"
              value={vitals.battery}
              active={bars(vitals.batteryPct)}
              critical={vitals.batteryPct < 15}
            />
          </Panel>

          <Panel style={{ flexShrink: 0 }} title="NETWORK" code={vitals.ifaceName}>
            <Waveform seed={3} height={40} />
            <div
              style={{
                display: 'flex',
                justifyContent: 'space-between',
                marginTop: '8px',
                fontSize: 'var(--text-xs)'
              }}
            >
              <span style={{ color: 'var(--text-muted)' }}>
                DOWN <span style={{ color: 'var(--accent)' }}>{vitals.down} MB/s</span>
              </span>
              <span style={{ color: 'var(--text-muted)' }}>
                UP <span style={{ color: 'var(--accent)' }}>{vitals.up} MB/s</span>
              </span>
            </div>
          </Panel>

          <Panel style={{ flexShrink: 0 }} title="SECURITY" code={`${okCount} CHECKS OK`}>
            <StatusList rows={securityRows} />
          </Panel>

          <Panel
            title="PROCESSES"
            code={procs ? `${procs.length} SHOWN` : '…'}
            active
            style={{ flex: 1, minHeight: '150px', overflow: 'hidden' }}
          >
            <ProcessList rows={procs} live={!!live} />
          </Panel>
        </div>
      </div>

      {/* ── SETTINGS WINDOW ─────────────────────────────────── */}
      {settingsOpen && (
        <WindowFrame
          title="Settings"
          icon="settings"
          x={520}
          y={190}
          w={780}
          h={560}
          z={50}
          focused
          onFocus={() => {}}
          onClose={() => close('settings')}
          onMinimize={() => setMinimized((m) => [...m, 'settings'])}
        >
          <SettingsApp settings={settings} onChange={setSettings} uptime={uptime} live={live} />
        </WindowFrame>
      )}

      {/* A launch that failed says so. Silently doing nothing is what made the
          icons feel broken in the first place. */}
      {launchError && (
        <div
          style={{
            position: 'absolute',
            bottom: '86px',
            left: '50%',
            transform: 'translateX(-50%)',
            padding: '10px 18px',
            background: 'rgba(20,0,6,.92)',
            border: '1px solid var(--state-critical)',
            color: 'var(--state-critical)',
            fontFamily: 'var(--font-mono)',
            fontSize: 'var(--text-xs)',
            letterSpacing: 'var(--tracking-wide)',
            boxShadow: 'var(--glow-critical)',
            zIndex: 70
          }}
        >
          {launchError}
        </div>
      )}

      {/* ── LAUNCHER + TASKBAR ──────────────────────────────── */}
      {launcherOpen && (
        <AppLauncher
          apps={SYM_APPS}
          openIds={openIds}
          onLaunch={launch}
          onClose={() => setLauncherOpen(false)}
        />
      )}
      <Taskbar
        openIds={openIds}
        onLaunch={launch}
        launcherOpen={launcherOpen}
        onToggleLauncher={() => setLauncherOpen((o) => !o)}
        time={time}
        onExit={onExit}
        vpn={!!(sec && sec.vpn && sec.vpn.state === 'ok')}
      />
    </div>
  );
}

window.Dashboard = Dashboard;
