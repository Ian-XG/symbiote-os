'use strict';
/* CPU / memory / storage / thermal, read straight from procfs and sysfs.
   No dependencies — these files are the kernel's own interface. */

const fs = require('fs/promises');
const { statfs } = require('fs');
const { promisify } = require('util');
const statfsAsync = promisify(statfs);

/* /proc/stat gives cumulative jiffies, so utilisation is only meaningful as a
   delta between two reads. We keep the previous sample here. */
let prevCpu = null;

async function cpu() {
  const text = await fs.readFile('/proc/stat', 'utf8');
  const line = text.split('\n', 1)[0]; // aggregate "cpu " line
  const v = line.trim().split(/\s+/).slice(1).map(Number);
  // user nice system idle iowait irq softirq steal
  const idle = v[3] + v[4];
  const total = v.reduce((a, b) => a + b, 0);

  let usage = 0;
  if (prevCpu) {
    const dIdle = idle - prevCpu.idle;
    const dTotal = total - prevCpu.total;
    if (dTotal > 0) usage = Math.max(0, Math.min(100, ((dTotal - dIdle) / dTotal) * 100));
  }
  prevCpu = { idle, total };

  let cores = 0;
  let mhz = null;
  try {
    const info = await fs.readFile('/proc/cpuinfo', 'utf8');
    cores = (info.match(/^processor\s*:/gm) || []).length;
    const m = info.match(/^cpu MHz\s*:\s*([\d.]+)/m);
    if (m) mhz = Number(m[1]);
  } catch { /* container without cpuinfo */ }

  return { usage: Math.round(usage), cores, ghz: mhz ? +(mhz / 1000).toFixed(1) : null };
}

async function memory() {
  const text = await fs.readFile('/proc/meminfo', 'utf8');
  const kb = (key) => {
    const m = text.match(new RegExp('^' + key + ':\\s+(\\d+) kB', 'm'));
    return m ? Number(m[1]) : 0;
  };
  const total = kb('MemTotal');
  const available = kb('MemAvailable');
  const used = total - available;
  return {
    usedGb: +(used / 1048576).toFixed(1),
    totalGb: +(total / 1048576).toFixed(1),
    usage: total ? Math.round((used / total) * 100) : 0
  };
}

async function storage(mount = '/') {
  const s = await statfsAsync(mount);
  const total = s.blocks * s.bsize;
  const free = s.bavail * s.bsize;
  const used = total - free;
  const gb = (n) => Math.round(n / 1073741824);
  return {
    usedGb: gb(used),
    freeGb: gb(free),
    totalGb: gb(total),
    usage: total ? Math.round((used / total) * 100) : 0
  };
}

/* Prefer a thermal zone that names itself as a package/CPU sensor; fall back to
   the first readable zone. Machines vary a lot here, so this stays defensive. */
async function thermal() {
  let zones;
  try {
    zones = await fs.readdir('/sys/class/thermal');
  } catch {
    return { celsius: null, fanRpm: null };
  }

  let best = null;
  for (const z of zones.filter((n) => n.startsWith('thermal_zone'))) {
    try {
      const type = (await fs.readFile(`/sys/class/thermal/${z}/type`, 'utf8')).trim();
      const milli = Number(await fs.readFile(`/sys/class/thermal/${z}/temp`, 'utf8'));
      if (!Number.isFinite(milli)) continue;
      const celsius = Math.round(milli / 1000);
      const preferred = /pkg|x86_pkg_temp|cpu|coretemp|soc/i.test(type);
      if (preferred) return { celsius, fanRpm: await fanRpm(), type };
      if (best === null) best = { celsius, type };
    } catch { /* unreadable zone */ }
  }
  return { celsius: best ? best.celsius : null, fanRpm: await fanRpm(), type: best && best.type };
}

async function fanRpm() {
  try {
    const hwmons = await fs.readdir('/sys/class/hwmon');
    for (const h of hwmons) {
      try {
        const rpm = Number(await fs.readFile(`/sys/class/hwmon/${h}/fan1_input`, 'utf8'));
        if (Number.isFinite(rpm) && rpm > 0) return rpm;
      } catch { /* no fan on this chip */ }
    }
  } catch { /* no hwmon */ }
  return null;
}

/* Throughput needs a delta too. Keyed by interface. */
const prevNet = new Map();

async function throughput() {
  const text = await fs.readFile('/proc/net/dev', 'utf8');
  const now = Date.now();
  const result = {};

  for (const line of text.split('\n').slice(2)) {
    const m = line.trim().match(/^([^:]+):\s*(.+)$/);
    if (!m) continue;
    const iface = m[1].trim();
    if (iface === 'lo') continue;
    const f = m[2].trim().split(/\s+/).map(Number);
    const rx = f[0];
    const tx = f[8];

    const prev = prevNet.get(iface);
    prevNet.set(iface, { rx, tx, at: now });
    if (!prev) continue;

    const dt = (now - prev.at) / 1000;
    if (dt <= 0) continue;
    result[iface] = {
      downMbs: +(((rx - prev.rx) / dt) / 1048576).toFixed(1),
      upMbs: +(((tx - prev.tx) / dt) / 1048576).toFixed(1)
    };
  }
  return result;
}

async function osRelease() {
  try {
    const text = await fs.readFile('/etc/os-release', 'utf8');
    const get = (k) => {
      const m = text.match(new RegExp('^' + k + '=(.*)$', 'm'));
      return m ? m[1].replace(/^"|"$/g, '') : null;
    };
    return { name: get('PRETTY_NAME'), version: get('VERSION_ID') };
  } catch {
    return { name: null, version: null };
  }
}

async function snapshot() {
  const [c, m, s, t, n, os] = await Promise.all([
    cpu(), memory(), storage(), thermal(), throughput(), osRelease()
  ]);
  return {
    cpu: c,
    memory: m,
    storage: s,
    thermal: t,
    network: n,
    os,
    uptime: Math.floor(require('os').uptime()),
    hostname: require('os').hostname()
  };
}

module.exports = { cpu, memory, storage, thermal, throughput, osRelease, snapshot };
