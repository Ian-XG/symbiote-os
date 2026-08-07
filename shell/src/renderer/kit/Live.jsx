/* Bridges the shell's real telemetry into the HUD.
 *
 * Returns null when window.symbiote is absent — that is the browser preview,
 * where the kit keeps its own sample values. The same Dashboard source then
 * renders in both places: real numbers on the OS, plausible ones in the design
 * preview. */

function useLive() {
  const bridge = typeof window !== 'undefined' && window.symbiote;
  const [system, setSystem] = React.useState(null);
  const [radios, setRadios] = React.useState(null);
  const [security, setSecurity] = React.useState(null);
  const [processes, setProcesses] = React.useState(null);

  React.useEffect(() => {
    if (!bridge) return undefined;

    const offSystem = bridge.system.onTelemetry(setSystem);
    const offRadios = bridge.onRadios(setRadios);
    const offSecurity = bridge.security.onChange(setSecurity);
    const offProcesses = bridge.processes.onChange(setProcesses);

    // Telemetry is pushed on an interval; ask once so the first frame is not
    // an empty panel.
    Promise.all([
      bridge.system.snapshot(),
      bridge.power.status(),
      bridge.wifi.status(),
      bridge.bluetooth.status(),
      bridge.security.status(),
      bridge.processes.top(8)
    ]).then(([sys, pw, wifi, bt, sec, procs]) => {
      if (sec.ok) setSecurity(sec.data);
      if (procs.ok) setProcesses(procs.data);
      if (sys.ok) setSystem({ ...sys.data, power: pw.ok ? pw.data : null });
      setRadios({
        wifi: wifi.ok ? wifi.data : { available: false, error: wifi.error },
        bluetooth: bt.ok ? bt.data : { available: false, error: bt.error }
      });
    });

    return () => {
      offSystem();
      offRadios();
      offSecurity();
      offProcesses();
    };
  }, [bridge]);

  if (!bridge) return null;
  return { system, radios, security, processes, bridge, connected: !!system };
}

/* Formatting helpers shared by the panels. Kept here so the Dashboard stays
   about layout. */
const Live = {
  bars(pct, n = 8) {
    if (pct === null || pct === undefined) return 0;
    return Math.max(1, Math.min(n, Math.round((pct / 100) * n)));
  },

  primaryInterface(network) {
    if (!network) return null;
    // Busiest interface wins; ties go to the first, which is stable enough.
    let best = null;
    for (const [name, t] of Object.entries(network)) {
      const total = t.downMbs + t.upMbs;
      if (!best || total > best.total) best = { name, total, ...t };
    }
    return best;
  },

  uptime(seconds) {
    if (!seconds) return '—';
    const h = Math.floor(seconds / 3600);
    const m = Math.floor((seconds % 3600) / 60);
    return `${h}h ${m}m`;
  }
};

window.useLive = useLive;
window.Live = Live;
