'use strict';
/* IPC surface. Every channel the renderer can call is registered here and
   nowhere else — the preload allowlist mirrors this list exactly. */

const { ipcMain } = require('electron');
const system = require('./system');
const network = require('./network');
const bluetooth = require('./bluetooth');
const power = require('./power');
const apps = require('./apps');
const security = require('./security');
const processes = require('./processes');

/* Polling intervals. System stats need a short window for the CPU delta to be
   meaningful; radios are slower-moving and D-Bus round trips are not free. */
const SYSTEM_MS = 1000;
const RADIO_MS = 5000;

/* A D-Bus call to a service that is absent or not permitted can hang rather
   than reject, which leaves the UI stuck on "querying..." forever with no clue
   why. Every call is therefore raced against a deadline so a stall becomes a
   visible error instead of silence. */
const CALL_TIMEOUT_MS = 6000;

function withTimeout(promise, label, ms = CALL_TIMEOUT_MS) {
  let timer;
  const deadline = new Promise((_, reject) => {
    timer = setTimeout(() => reject(new Error(`${label} timed out after ${ms}ms`)), ms);
    if (timer.unref) timer.unref();
  });
  return Promise.race([promise, deadline]).finally(() => clearTimeout(timer));
}

/** Wrap a handler so a D-Bus failure surfaces as data, never an unhandled reject. */
function safe(fn, label) {
  return async (_event, ...args) => {
    try {
      return { ok: true, data: await withTimeout(fn(...args), label) };
    } catch (err) {
      return { ok: false, error: String((err && err.message) || err) };
    }
  };
}

function registerHandlers() {
  const handlers = {
    'system:snapshot': () => system.snapshot(),

    'wifi:status': () => network.status(),
    'wifi:scan': async () => {
      const devices = await network.wifiDevices();
      if (!devices.length) throw new Error('no wifi device');
      await network.scan(devices[0].path);
      // NM populates results asynchronously; give it a beat before reading back.
      await new Promise((r) => setTimeout(r, 2000));
      return network.status();
    },
    'wifi:connect': async (ssid, passphrase) => {
      const devices = await network.wifiDevices();
      if (!devices.length) throw new Error('no wifi device');
      await network.connect(devices[0].path, ssid, passphrase);
      return network.status();
    },
    'wifi:disconnect': async () => {
      const devices = await network.wifiDevices();
      if (devices.length) await network.disconnect(devices[0].path);
      return network.status();
    },
    'wifi:enable': async (on) => {
      await network.setWirelessEnabled(on);
      return network.status();
    },

    'bt:status': () => bluetooth.status(),
    'bt:power': async (on) => {
      await bluetooth.setPowered(on);
      return bluetooth.status();
    },
    'bt:discover': async (on) => {
      if (on) await bluetooth.startDiscovery();
      else await bluetooth.stopDiscovery();
      return bluetooth.status();
    },
    'bt:pair': async (path) => {
      await bluetooth.pair(path);
      return bluetooth.status();
    },
    'bt:connect': async (path) => {
      await bluetooth.connect(path);
      return bluetooth.status();
    },
    'bt:disconnect': async (path) => {
      await bluetooth.disconnect(path);
      return bluetooth.status();
    },
    'bt:forget': async (path) => {
      await bluetooth.remove(path);
      return bluetooth.status();
    },

    'power:status': () => power.status(),

    'app:launch': (id) => apps.launch(id),
    'app:close': (id) => apps.close(id),
    'app:open': () => apps.openIds(),
    'app:available': () => apps.available(),

    'security:status': () => security.status(),
    'processes:top': (limit) => processes.top(limit)
  };

  for (const [channel, fn] of Object.entries(handlers)) {
    ipcMain.handle(channel, safe(fn, channel));
  }

  return Object.keys(handlers);
}

/** Push telemetry to the window so the renderer never has to poll over IPC. */
function startTelemetry(win) {
  const send = (channel, payload) => {
    if (!win.isDestroyed()) win.webContents.send(channel, payload);
  };

  const systemTimer = setInterval(async () => {
    try {
      send('telemetry:system', { ...(await system.snapshot()), power: await power.status() });
    } catch (err) {
      send('telemetry:error', String(err.message || err));
    }
  }, SYSTEM_MS);

  const radioTimer = setInterval(async () => {
    const [wifi, bt] = await Promise.allSettled([
      withTimeout(network.status(), 'wifi:status'),
      withTimeout(bluetooth.status(), 'bt:status')
    ]);
    // Report *why* a radio is unavailable. "available: false" alone is
    // indistinguishable from a machine that genuinely has no adapter.
    send('telemetry:radios', {
      wifi: wifi.status === 'fulfilled'
        ? wifi.value
        : { available: false, error: String(wifi.reason && wifi.reason.message) },
      bluetooth: bt.status === 'fulfilled'
        ? bt.value
        : { available: false, error: String(bt.reason && bt.reason.message) }
    });

    const [sec, procs] = await Promise.allSettled([
      withTimeout(security.status(), 'security:status', 20000),
      withTimeout(processes.top(8), 'processes:top')
    ]);
    send('telemetry:security', sec.status === 'fulfilled' ? sec.value : null);
    send('telemetry:processes', procs.status === 'fulfilled' ? procs.value : []);
  }, RADIO_MS);

  // Apps can also exit on their own (user closes the window), so the taskbar's
  // "open" state has to follow the processes rather than only our own clicks.
  let lastOpen = '';
  const appTimer = setInterval(() => {
    const open = apps.openIds();
    const key = open.slice().sort().join(',');
    if (key !== lastOpen) {
      lastOpen = key;
      send('telemetry:apps', open);
    }
  }, 1000);

  win.on('closed', () => {
    clearInterval(systemTimer);
    clearInterval(radioTimer);
    clearInterval(appTimer);
  });
}

module.exports = { registerHandlers, startTelemetry };
