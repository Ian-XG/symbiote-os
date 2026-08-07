'use strict';
/* Battery and AC state via UPower. DisplayDevice is UPower's own aggregate of
   whatever batteries the machine has, so it works on laptops with two packs and
   returns "unknown" on desktops. */

const dbus = require('dbus-next');

const UPOWER = 'org.freedesktop.UPower';
const DISPLAY_DEVICE = '/org/freedesktop/UPower/devices/DisplayDevice';
const DEVICE_IFACE = 'org.freedesktop.UPower.Device';
const PROPS = 'org.freedesktop.DBus.Properties';

// UPower device state enum
const STATE = {
  0: 'unknown', 1: 'charging', 2: 'discharging', 3: 'empty',
  4: 'full', 5: 'pending-charge', 6: 'pending-discharge'
};

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

function humanSeconds(s) {
  if (!s || s <= 0) return null;
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  return h ? `${h}h ${m}m` : `${m}m`;
}

async function status() {
  try {
    const obj = await systemBus().getProxyObject(UPOWER, DISPLAY_DEVICE);
    const d = unwrap(await obj.getInterface(PROPS).GetAll(DEVICE_IFACE));

    // IsPresent is false on desktops — report AC rather than a fake battery.
    if (!d.IsPresent) return { present: false, onAc: true };

    const state = STATE[d.State] || 'unknown';
    const charging = state === 'charging' || state === 'full';

    return {
      present: true,
      percent: Math.round(d.Percentage),
      state,
      onAc: charging,
      remaining: humanSeconds(charging ? d.TimeToFull : d.TimeToEmpty),
      // Capacity degrades with age; useful in About.
      health: d.Capacity ? Math.round(d.Capacity) : null
    };
  } catch {
    // No UPower (minimal container) — don't invent a battery.
    return { present: false, onAc: true, unavailable: true };
  }
}

module.exports = { status };
