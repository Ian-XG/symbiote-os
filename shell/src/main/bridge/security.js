'use strict';
/* Real security posture.
 *
 * The SECURITY panel used to be driven by toggles in Settings: flipping a
 * switch changed the label and nothing else. That is worse than showing
 * nothing — a panel that says "Firewall: ACTIVE" when no firewall is running
 * is actively misleading about the safety of the machine.
 *
 * Everything here is read from the system. Where a fact cannot be established,
 * it reports "unknown" rather than guessing. */

const { exec } = require('child_process');
const fs = require('fs/promises');

function run(cmd, timeoutMs = 4000) {
  return new Promise((resolve) => {
    exec(cmd, { timeout: timeoutMs, maxBuffer: 1 << 20 }, (err, stdout) => {
      resolve(err ? null : String(stdout));
    });
  });
}

/** Is a packet filter actually loaded? nftables first, then legacy iptables. */
async function firewall() {
  const nft = await run('nft list ruleset 2>/dev/null');
  if (nft !== null && nft.trim()) {
    // An empty ruleset is a loaded-but-permissive firewall; say so.
    const rules = (nft.match(/^\s*(accept|drop|reject|jump|goto)\b/gm) || []).length;
    return rules > 0
      ? { state: 'ok', value: `ACTIVE (${rules} rules)` }
      : { state: 'attention', value: 'LOADED, NO RULES' };
  }

  const ipt = await run('iptables-save 2>/dev/null');
  if (ipt !== null && /^-A/m.test(ipt)) {
    const rules = (ipt.match(/^-A/gm) || []).length;
    return { state: 'ok', value: `ACTIVE (${rules} rules)` };
  }

  return { state: 'critical', value: 'NOT RUNNING' };
}

/** A VPN is up if there is a tunnel interface carrying an address. */
async function vpn() {
  let names;
  try {
    names = await fs.readdir('/sys/class/net');
  } catch {
    return { state: 'unknown', value: 'UNKNOWN' };
  }
  const tunnels = names.filter((n) => /^(tun|tap|wg|ppp)\d*/.test(n));
  if (!tunnels.length) return { state: 'idle', value: 'NOT CONNECTED' };

  for (const t of tunnels) {
    try {
      const state = (await fs.readFile(`/sys/class/net/${t}/operstate`, 'utf8')).trim();
      if (state === 'up' || state === 'unknown') return { state: 'ok', value: `UP (${t})` };
    } catch { /* vanished */ }
  }
  return { state: 'idle', value: 'NOT CONNECTED' };
}

/** LUKS volumes announce themselves through device-mapper UUIDs. */
async function diskEncryption() {
  try {
    const blocks = await fs.readdir('/sys/block');
    for (const b of blocks.filter((n) => n.startsWith('dm-'))) {
      try {
        const uuid = (await fs.readFile(`/sys/block/${b}/dm/uuid`, 'utf8')).trim();
        if (uuid.startsWith('CRYPT-')) return { state: 'ok', value: 'ON (LUKS)' };
      } catch { /* not a mapped device we can read */ }
    }
  } catch { /* no sysfs */ }
  // A live ISO runs from squashfs; there is nothing to encrypt yet.
  return { state: 'idle', value: 'OFF' };
}

/* apt is slow and the answer barely changes, so it is cached. */
let updateCache = { at: 0, data: null };
const UPDATE_TTL_MS = 10 * 60 * 1000;

async function updates() {
  if (updateCache.data && Date.now() - updateCache.at < UPDATE_TTL_MS) return updateCache.data;

  const out = await run('apt-get -s -o Debug::NoLocking=1 upgrade 2>/dev/null', 15000);
  let data;
  if (out === null) {
    data = { state: 'unknown', value: 'UNKNOWN' };
  } else {
    const count = (out.match(/^Inst /gm) || []).length;
    data = count === 0
      ? { state: 'ok', value: 'UP TO DATE' }
      : { state: 'attention', value: `${count} PENDING` };
  }
  updateCache = { at: Date.now(), data };
  return data;
}

/** Is the machine reachable from outside — any listening socket on 0.0.0.0? */
async function listeningPorts() {
  try {
    const tcp = await fs.readFile('/proc/net/tcp', 'utf8');
    // state 0A = LISTEN; local address 00000000 = all interfaces
    const lines = tcp.split('\n').slice(1);
    let open = 0;
    for (const line of lines) {
      const f = line.trim().split(/\s+/);
      if (f.length < 4) continue;
      if (f[3] !== '0A') continue;
      const [addr] = f[1].split(':');
      if (addr === '00000000') open += 1;
    }
    return open === 0
      ? { state: 'ok', value: 'NONE EXPOSED' }
      : { state: 'attention', value: `${open} LISTENING` };
  } catch {
    return { state: 'unknown', value: 'UNKNOWN' };
  }
}

async function status() {
  const [fw, vp, enc, upd, ports] = await Promise.all([
    firewall(), vpn(), diskEncryption(), updates(), listeningPorts()
  ]);
  return { firewall: fw, vpn: vp, encryption: enc, updates: upd, ports };
}

module.exports = { status, firewall, vpn, diskEncryption, updates, listeningPorts };
