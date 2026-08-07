'use strict';
/* Wi-Fi via NetworkManager over the system bus.
   Nothing here is simulated: scan results, signal strength and connection state
   all come from org.freedesktop.NetworkManager. */

const dbus = require('dbus-next');

const NM = 'org.freedesktop.NetworkManager';
const NM_PATH = '/org/freedesktop/NetworkManager';
const PROPS = 'org.freedesktop.DBus.Properties';

const DEVICE_TYPE_WIFI = 2;

// NM_802_11_AP_SEC flags we care about
const SEC_NONE = 0x0;

let bus = null;
function systemBus() {
  if (!bus) bus = dbus.systemBus();
  return bus;
}

async function iface(path, name) {
  const obj = await systemBus().getProxyObject(NM, path);
  return obj.getInterface(name);
}

async function props(path, name) {
  const obj = await systemBus().getProxyObject(NM, path);
  return obj.getInterface(PROPS).GetAll(name);
}

function unwrap(variantMap) {
  const out = {};
  for (const [k, v] of Object.entries(variantMap)) out[k] = v.value;
  return out;
}

/** All Wi-Fi devices NM knows about, with their interface names. */
async function wifiDevices() {
  const nm = await iface(NM_PATH, NM);
  const paths = await nm.GetDevices();
  const found = [];
  for (const p of paths) {
    const d = unwrap(await props(p, 'org.freedesktop.NetworkManager.Device'));
    if (d.DeviceType === DEVICE_TYPE_WIFI) found.push({ path: p, iface: d.Interface, state: d.State });
  }
  return found;
}

/** Ask the adapter to re-scan. NM rate-limits this, so call it sparingly. */
async function scan(devicePath) {
  const w = await iface(devicePath, 'org.freedesktop.NetworkManager.Device.Wireless');
  try {
    await w.RequestScan({});
  } catch (e) {
    // NM throws if a scan is already running or was requested too recently.
    if (!/AllowedError|NotAllowed|Scanning/i.test(String(e.message))) throw e;
  }
}

/** Access points visible to a device, strongest first, deduplicated by SSID. */
async function accessPoints(devicePath) {
  const w = await iface(devicePath, 'org.freedesktop.NetworkManager.Device.Wireless');
  const apPaths = await w.GetAllAccessPoints();

  const active = await activeAccessPoint(devicePath);
  const seen = new Map();

  for (const p of apPaths) {
    let ap;
    try {
      ap = unwrap(await props(p, 'org.freedesktop.NetworkManager.AccessPoint'));
    } catch {
      continue; // AP vanished between listing and reading
    }
    const ssid = Buffer.from(ap.Ssid || []).toString('utf8');
    if (!ssid) continue; // hidden network

    const secure = !(ap.WpaFlags === SEC_NONE && ap.RsnFlags === SEC_NONE);
    const entry = {
      ssid,
      strength: ap.Strength,
      frequency: ap.Frequency,
      band: ap.Frequency > 4000 ? '5 GHz' : '2.4 GHz',
      secure,
      connected: p === active
    };
    // Same SSID on several APs: keep the strongest.
    const prev = seen.get(ssid);
    if (!prev || entry.strength > prev.strength) seen.set(ssid, entry);
  }

  return [...seen.values()].sort((a, b) => b.strength - a.strength);
}

async function activeAccessPoint(devicePath) {
  try {
    const d = unwrap(await props(devicePath, 'org.freedesktop.NetworkManager.Device.Wireless'));
    return d.ActiveAccessPoint;
  } catch {
    return null;
  }
}

/**
 * Connect to an SSID. Reuses a saved connection when NM already has one,
 * otherwise creates a WPA-PSK profile. Returns the active connection path.
 */
async function connect(devicePath, ssid, passphrase) {
  const nm = await iface(NM_PATH, NM);
  const { Variant } = dbus;

  const apPath = await findAccessPoint(devicePath, ssid);
  if (!apPath) throw new Error(`network not visible: ${ssid}`);

  const saved = await findSavedConnection(ssid);
  if (saved) return nm.ActivateConnection(saved, devicePath, apPath);

  const settings = {
    connection: {
      type: new Variant('s', '802-11-wireless'),
      id: new Variant('s', ssid),
      'autoconnect': new Variant('b', true)
    },
    '802-11-wireless': {
      ssid: new Variant('ay', Buffer.from(ssid, 'utf8'))
    },
    ipv4: { method: new Variant('s', 'auto') },
    ipv6: { method: new Variant('s', 'auto') }
  };

  if (passphrase) {
    settings['802-11-wireless-security'] = {
      'key-mgmt': new Variant('s', 'wpa-psk'),
      psk: new Variant('s', passphrase)
    };
  }

  const [, activePath] = await nm.AddAndActivateConnection(settings, devicePath, apPath);
  return activePath;
}

async function findAccessPoint(devicePath, ssid) {
  const w = await iface(devicePath, 'org.freedesktop.NetworkManager.Device.Wireless');
  for (const p of await w.GetAllAccessPoints()) {
    try {
      const ap = unwrap(await props(p, 'org.freedesktop.NetworkManager.AccessPoint'));
      if (Buffer.from(ap.Ssid || []).toString('utf8') === ssid) return p;
    } catch { /* gone */ }
  }
  return null;
}

async function findSavedConnection(ssid) {
  const s = await iface(
    '/org/freedesktop/NetworkManager/Settings',
    'org.freedesktop.NetworkManager.Settings'
  );
  for (const p of await s.ListConnections()) {
    try {
      const c = await iface(p, 'org.freedesktop.NetworkManager.Settings.Connection');
      const cfg = await c.GetSettings();
      if (cfg.connection && cfg.connection.id && cfg.connection.id.value === ssid) return p;
    } catch { /* unreadable profile */ }
  }
  return null;
}

async function disconnect(devicePath) {
  const d = await iface(devicePath, 'org.freedesktop.NetworkManager.Device');
  await d.Disconnect();
}

/** Radio kill switch — mirrors the Settings toggle. */
async function setWirelessEnabled(on) {
  const obj = await systemBus().getProxyObject(NM, NM_PATH);
  await obj.getInterface(PROPS).Set(NM, 'WirelessEnabled', new dbus.Variant('b', !!on));
}

async function status() {
  const devices = await wifiDevices();
  if (!devices.length) return { available: false, enabled: false, networks: [] };

  const nmProps = unwrap(await props(NM_PATH, NM));
  const dev = devices[0];
  const networks = nmProps.WirelessEnabled ? await accessPoints(dev.path) : [];

  return {
    available: true,
    enabled: !!nmProps.WirelessEnabled,
    device: dev.iface,
    devicePath: dev.path,
    connectivity: nmProps.Connectivity,
    networks
  };
}

module.exports = {
  wifiDevices, scan, accessPoints, connect, disconnect, setWirelessEnabled, status
};
