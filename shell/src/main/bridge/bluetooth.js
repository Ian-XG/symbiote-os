'use strict';
/* Bluetooth via BlueZ over the system bus.
   BlueZ exposes everything through ObjectManager: adapters are org.bluez.Adapter1,
   devices are org.bluez.Device1, both hanging off /org/bluez. */

const dbus = require('dbus-next');

const BLUEZ = 'org.bluez';
const OBJECT_MANAGER = 'org.freedesktop.DBus.ObjectManager';
const PROPS = 'org.freedesktop.DBus.Properties';

let bus = null;
function systemBus() {
  if (!bus) bus = dbus.systemBus();
  return bus;
}

function unwrap(variantMap) {
  const out = {};
  for (const [k, v] of Object.entries(variantMap || {})) out[k] = v.value;
  return out;
}

async function managedObjects() {
  const obj = await systemBus().getProxyObject(BLUEZ, '/');
  return obj.getInterface(OBJECT_MANAGER).GetManagedObjects();
}

async function iface(path, name) {
  const obj = await systemBus().getProxyObject(BLUEZ, path);
  return obj.getInterface(name);
}

async function setProp(path, name, prop, signature, value) {
  const obj = await systemBus().getProxyObject(BLUEZ, path);
  await obj.getInterface(PROPS).Set(name, prop, new dbus.Variant(signature, value));
}

/** First adapter (hci0 on most machines), or null if the host has no radio. */
async function adapter() {
  const objects = await managedObjects();
  for (const [path, ifaces] of Object.entries(objects)) {
    if (ifaces['org.bluez.Adapter1']) {
      return { path, ...unwrap(ifaces['org.bluez.Adapter1']) };
    }
  }
  return null;
}

/** Known devices: paired ones plus anything discovery has turned up. */
async function devices() {
  const objects = await managedObjects();
  const list = [];
  for (const [path, ifaces] of Object.entries(objects)) {
    const d = ifaces['org.bluez.Device1'];
    if (!d) continue;
    const p = unwrap(d);
    list.push({
      path,
      address: p.Address,
      name: p.Name || p.Alias || p.Address,
      paired: !!p.Paired,
      trusted: !!p.Trusted,
      connected: !!p.Connected,
      // RSSI is only present while the device is in range during discovery
      rssi: typeof p.RSSI === 'number' ? p.RSSI : null,
      icon: p.Icon || null
    });
  }
  // Connected first, then paired, then by signal.
  return list.sort((a, b) =>
    (b.connected - a.connected) || (b.paired - a.paired) || ((b.rssi ?? -999) - (a.rssi ?? -999))
  );
}

async function setPowered(on) {
  const a = await adapter();
  if (!a) throw new Error('no bluetooth adapter');
  await setProp(a.path, 'org.bluez.Adapter1', 'Powered', 'b', !!on);
}

async function startDiscovery() {
  const a = await adapter();
  if (!a) throw new Error('no bluetooth adapter');
  if (a.Discovering) return;
  await (await iface(a.path, 'org.bluez.Adapter1')).StartDiscovery();
}

async function stopDiscovery() {
  const a = await adapter();
  if (!a || !a.Discovering) return;
  try {
    await (await iface(a.path, 'org.bluez.Adapter1')).StopDiscovery();
  } catch { /* another client may still hold discovery open */ }
}

/**
 * Pair then connect. Pairing needs an agent registered for anything that
 * requires a PIN or confirmation — see agent.js, registered at shell startup.
 */
async function pair(devicePath) {
  const d = await iface(devicePath, 'org.bluez.Device1');
  await d.Pair();
  await setProp(devicePath, 'org.bluez.Device1', 'Trusted', 'b', true);
  await d.Connect();
}

async function connect(devicePath) {
  await (await iface(devicePath, 'org.bluez.Device1')).Connect();
}

async function disconnect(devicePath) {
  await (await iface(devicePath, 'org.bluez.Device1')).Disconnect();
}

/** Forget: BlueZ removes the device from the adapter, dropping its keys. */
async function remove(devicePath) {
  const a = await adapter();
  if (!a) return;
  await (await iface(a.path, 'org.bluez.Adapter1')).RemoveDevice(devicePath);
}

/* Whether the kernel has a bluetooth subsystem at all.
   This is checked before touching D-Bus because BlueZ, when it is not running,
   does not answer with ServiceUnknown — the call simply never returns, so the
   only thing that fires is the 6s timeout, and a machine with no radio ends up
   reporting a red ERROR when the truthful answer is "there is no hardware". */
async function subsystemPresent() {
  try {
    await require('fs/promises').access('/sys/class/bluetooth');
    return true;
  } catch {
    return false;
  }
}

async function status() {
  if (!(await subsystemPresent())) {
    return { available: false, powered: false, discovering: false, devices: [], noHardware: true };
  }

  let a;
  try {
    a = await adapter();
  } catch (err) {
    // BlueZ not running is the normal case on a machine with no radio (a VM,
    // most servers). That is not an error, and reporting it as one made the
    // panel look broken when it was telling the truth.
    const msg = String((err && err.message) || err);
    if (/ServiceUnknown|NameHasNoOwner|not provided by any|was not provided/i.test(msg)) {
      return { available: false, powered: false, discovering: false, devices: [], serviceDown: true };
    }
    throw err;
  }
  if (!a) return { available: false, powered: false, discovering: false, devices: [] };
  return {
    available: true,
    powered: !!a.Powered,
    discovering: !!a.Discovering,
    name: a.Alias || a.Name,
    address: a.Address,
    devices: a.Powered ? await devices() : []
  };
}

module.exports = {
  adapter, devices, setPowered, startDiscovery, stopDiscovery,
  pair, connect, disconnect, remove, status
};
