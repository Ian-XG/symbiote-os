'use strict';
/* Real application launching.
 *
 * Until now the taskbar only toggled a flag in the renderer — it lit an
 * indicator and started nothing. This spawns actual processes and tracks them,
 * so "open" in the UI means a live PID and closing the app clears it.
 *
 * Requires a compositor that can show more than one window. cage cannot; the
 * image uses labwc, with a rule pinning the shell below everything else. */

const { spawn } = require('child_process');
const { access, constants } = require('fs/promises');

/* Every launchable app, keyed by the ids the taskbar and desktop icons use.
   `args` is an array so nothing is passed through a shell — no quoting bugs,
   no injection surface. */
const CATALOG = {
  files:     { cmd: 'nautilus', args: ['--new-window'] },
  terminal:  { cmd: 'foot',     args: [] },
  browser:   { cmd: 'firefox',  args: [] },
  settings:  { internal: true },

  // Security tools are CLI, so they open inside a terminal that stays around
  // after the command exits rather than flashing a window and vanishing.
  nmap:      { cmd: 'foot', args: ['-T', 'Network Scan', 'sh', '-c', 'nmap --help; exec ${SHELL:-sh}'] },
  vuln:      { cmd: 'foot', args: ['-T', 'Vuln Scanner', 'sh', '-c', 'nikto -Help; exec ${SHELL:-sh}'] },
  proxy:     { cmd: 'foot', args: ['-T', 'Intercept Proxy', 'sh', '-c', 'echo "mitmproxy not installed"; exec ${SHELL:-sh}'] },
  exploit:   { cmd: 'foot', args: ['-T', 'Exploit Kit', 'sh', '-c', 'echo "metasploit is not in Debian - see README-tools"; exec ${SHELL:-sh}'] },
  creds:     { cmd: 'foot', args: ['-T', 'Credentials', 'sh', '-c', 'john --help 2>&1 | head -20; exec ${SHELL:-sh}'] },
  loot:      { cmd: 'foot', args: ['-T', 'Loot DB', 'sh', '-c', 'exec ${SHELL:-sh}'] },
  firewall:  { cmd: 'foot', args: ['-T', 'Firewall', 'sh', '-c', 'nft list ruleset 2>&1 | head -40; exec ${SHELL:-sh}'] },
  monitor:   { cmd: 'foot', args: ['-T', 'Monitor', 'sh', '-c', 'exec top'] },
  vault:     { cmd: 'foot', args: ['-T', 'Vault', 'sh', '-c', 'exec ${SHELL:-sh}'] },
  trash:     { cmd: 'nautilus', args: ['trash:///'] }
};

/** id -> ChildProcess, for everything currently alive. */
const running = new Map();

/** id -> why it died, for apps that failed to start. Read by the UI. */
const lastFailure = new Map();

async function onPath(cmd) {
  for (const dir of (process.env.PATH || '/usr/bin:/bin').split(':')) {
    try {
      await access(`${dir}/${cmd}`, constants.X_OK);
      return true;
    } catch { /* keep looking */ }
  }
  return false;
}

/**
 * Start an app. Returns what actually happened rather than a bare boolean, so
 * the UI can say "not installed" instead of silently doing nothing.
 */
async function launch(id) {
  const entry = CATALOG[id];
  if (!entry) throw new Error(`unknown app: ${id}`);

  // Settings is a window inside the shell, not a separate process.
  if (entry.internal) return { id, internal: true, running: true };

  if (running.has(id)) return { id, running: true, pid: running.get(id).pid, alreadyOpen: true };

  if (!(await onPath(entry.cmd))) {
    throw new Error(`${entry.cmd} is not installed`);
  }

  const child = spawn(entry.cmd, entry.args, {
    detached: true,
    // stderr is piped rather than discarded. It used to be 'ignore', which
    // meant an app that failed to start left no trace anywhere — the icon just
    // never lit and there was nothing to read. Diagnosing that cost a whole
    // debugging cycle.
    stdio: ['ignore', 'ignore', 'pipe'],
    env: { ...process.env, GDK_BACKEND: 'wayland', QT_QPA_PLATFORM: 'wayland' }
  });

  let stderr = '';
  const startedAt = Date.now();
  child.stderr.on('data', (chunk) => {
    // Keep only the head: GTK apps are chatty and we want the first failure,
    // not the last warning.
    if (stderr.length < 2000) stderr += chunk.toString();
  });
  child.stderr.on('error', () => {});

  child.on('error', (err) => {
    lastFailure.set(id, String(err.message || err));
    running.delete(id);
  });
  child.on('exit', (code, signal) => {
    // Exiting within a few seconds means it did not really start. Later exits
    // are the user closing the window, which is not a failure.
    if (Date.now() - startedAt < 5000 && code !== 0) {
      const why = stderr.trim().split('\n').filter(Boolean).slice(-2).join(' / ');
      lastFailure.set(
        id,
        why || `exited immediately (${signal ? 'signal ' + signal : 'code ' + code})`
      );
    }
    running.delete(id);
  });
  // Let it outlive the shell's own process group so a shell restart does not
  // kill the user's open windows.
  child.unref();

  lastFailure.delete(id);
  running.set(id, child);
  return { id, running: true, pid: child.pid };
}

/** Why an app stopped, if it stopped badly. Cleared on the next successful launch. */
function failure(id) {
  return lastFailure.get(id) || null;
}

/** Ask an app to close. SIGTERM so it can save; the caller sees it disappear. */
function close(id) {
  const child = running.get(id);
  if (!child) return { id, running: false };
  try {
    process.kill(-child.pid, 'SIGTERM'); // negative: the whole detached group
  } catch {
    try { child.kill('SIGTERM'); } catch { /* already gone */ }
  }
  running.delete(id);
  return { id, running: false };
}

function openIds() {
  return [...running.keys()];
}

/** Which catalog entries this machine can actually run. */
async function available() {
  const out = {};
  for (const [id, entry] of Object.entries(CATALOG)) {
    out[id] = entry.internal ? true : await onPath(entry.cmd);
  }
  return out;
}

module.exports = { launch, close, openIds, available, failure, CATALOG };
