'use strict';
/* Top processes, read from procfs.
 *
 * This replaces the "recent activity" feed, which was a scripted list of
 * plausible-sounding events with no connection to the machine. A panel that
 * invents its own contents teaches you to distrust every other panel. */

const fs = require('fs/promises');

/* CPU time in procfs is cumulative, so a percentage only exists as a delta
   between two samples. Keyed by pid. */
let prev = new Map();
let prevAt = 0;

const CLK_TCK = 100; // Linux default; getconf CLK_TCK is 100 on every Debian target

async function readProcess(pid) {
  const stat = await fs.readFile(`/proc/${pid}/stat`, 'utf8');

  // comm can contain spaces and parentheses, so split around the LAST ')'.
  const close = stat.lastIndexOf(')');
  const open = stat.indexOf('(');
  const comm = stat.slice(open + 1, close);
  const rest = stat.slice(close + 2).split(' ');

  // rest[0] is state (field 3); utime is field 14, stime field 15.
  const utime = Number(rest[11]);
  const stime = Number(rest[12]);
  const rssPages = Number(rest[21]);

  return { pid, comm, cpuTicks: utime + stime, rssMb: Math.round((rssPages * 4096) / 1048576) };
}

async function top(limit = 8) {
  let entries;
  try {
    entries = await fs.readdir('/proc');
  } catch {
    return [];
  }

  const pids = entries.filter((e) => /^\d+$/.test(e));
  const now = Date.now();
  const elapsedSec = prevAt ? (now - prevAt) / 1000 : 0;
  const current = new Map();
  const rows = [];

  for (const pid of pids) {
    let p;
    try {
      p = await readProcess(pid);
    } catch {
      continue; // process exited between readdir and read
    }
    current.set(pid, p.cpuTicks);

    let cpu = 0;
    const before = prev.get(pid);
    if (before !== undefined && elapsedSec > 0) {
      cpu = ((p.cpuTicks - before) / CLK_TCK / elapsedSec) * 100;
    }
    rows.push({ pid: Number(pid), name: p.comm, cpu: Math.max(0, cpu), rssMb: p.rssMb });
  }

  prev = current;
  prevAt = now;

  // First call has no delta, so rank by memory instead of showing all zeros.
  const haveCpu = rows.some((r) => r.cpu > 0);
  rows.sort((a, b) => (haveCpu ? b.cpu - a.cpu : b.rssMb - a.rssMb));

  return rows.slice(0, limit).map((r) => ({
    pid: r.pid,
    name: r.name,
    cpu: Math.round(r.cpu * 10) / 10,
    rssMb: r.rssMb
  }));
}

module.exports = { top };
