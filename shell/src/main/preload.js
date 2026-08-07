'use strict';
/* The only thing bridging renderer and system. Explicit allowlist — the
   renderer cannot reach ipcRenderer directly, so it can only call what's here. */

const { contextBridge, ipcRenderer } = require('electron');

const invoke = (channel, ...args) => ipcRenderer.invoke(channel, ...args);

/** Subscribe helper that returns an unsubscribe function. */
function on(channel, handler) {
  const listener = (_event, payload) => handler(payload);
  ipcRenderer.on(channel, listener);
  return () => ipcRenderer.removeListener(channel, listener);
}

contextBridge.exposeInMainWorld('symbiote', {
  system: {
    snapshot: () => invoke('system:snapshot'),
    onTelemetry: (handler) => on('telemetry:system', handler)
  },

  wifi: {
    status: () => invoke('wifi:status'),
    scan: () => invoke('wifi:scan'),
    connect: (ssid, passphrase) => invoke('wifi:connect', ssid, passphrase),
    disconnect: () => invoke('wifi:disconnect'),
    setEnabled: (on) => invoke('wifi:enable', on)
  },

  bluetooth: {
    status: () => invoke('bt:status'),
    setPowered: (on) => invoke('bt:power', on),
    setDiscovering: (on) => invoke('bt:discover', on),
    pair: (path) => invoke('bt:pair', path),
    connect: (path) => invoke('bt:connect', path),
    disconnect: (path) => invoke('bt:disconnect', path),
    forget: (path) => invoke('bt:forget', path)
  },

  power: {
    status: () => invoke('power:status')
  },

  security: {
    status: () => invoke('security:status'),
    onChange: (handler) => on('telemetry:security', handler)
  },

  processes: {
    top: (limit) => invoke('processes:top', limit),
    onChange: (handler) => on('telemetry:processes', handler)
  },

  ui: {
    // 'auto' re-runs the density heuristic; a number forces a zoom factor.
    setScale: (factor) => invoke('ui:scale', factor)
  },

  apps: {
    launch: (id) => invoke('app:launch', id),
    close: (id) => invoke('app:close', id),
    open: () => invoke('app:open'),
    available: () => invoke('app:available'),
    onChange: (handler) => on('telemetry:apps', handler)
  },

  onRadios: (handler) => on('telemetry:radios', handler),
  onError: (handler) => on('telemetry:error', handler)
});
