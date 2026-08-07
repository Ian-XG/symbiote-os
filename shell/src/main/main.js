'use strict';
/* Symbiote Shell — Electron main process.
   Runs fullscreen and frameless as the session's only window, under the `cage`
   Wayland kiosk compositor. There is no window manager behind it, so this
   process IS the desktop. */

const path = require('path');
const { app, BrowserWindow, session, shell, screen, ipcMain } = require('electron');
const { registerHandlers, startTelemetry } = require('./bridge');

const DEV = !!process.env.SYMBIOTE_DEV;

// Electron needs to be told explicitly to use Wayland when there's no X server.
if (process.env.XDG_SESSION_TYPE === 'wayland' || process.env.WAYLAND_DISPLAY) {
  app.commandLine.appendSwitch('ozone-platform-hint', 'auto');
  app.commandLine.appendSwitch('enable-features', 'WaylandWindowDecorations');
}

// symbiote-session sets this when it could not bring up hardware GL (a VM with
// no 3D acceleration). Chromium blocklists most software GL drivers, so point
// it at SwiftShader — its own rasteriser — rather than let it fail to find one
// and fall back to a blank window.
if (process.env.SYMBIOTE_SOFTWARE_GL === '1') {
  app.commandLine.appendSwitch('use-gl', 'angle');
  app.commandLine.appendSwitch('use-angle', 'swiftshader');
  app.commandLine.appendSwitch('in-process-gpu');
  app.disableHardwareAcceleration();
}

let win = null;

/* HiDPI.
 *
 * Linux hands us the panel's raw resolution with no scaling of its own, and the
 * shell lays out at the display's real size. On a Retina panel (2880x1800 in
 * 15") that renders the HUD's 8-11px type at half its intended physical size —
 * technically sharp, practically unreadable.
 *
 * Zooming the page rather than forcing a device scale factor keeps the layout
 * in charge: at zoom 2 a 2880px panel reports 1440 CSS px, so the rails, the
 * hologram and the taskbar all size themselves for that, and text is drawn at
 * 2x device pixels. A 4K panel lands on exactly 1920x1080 — the size the design
 * was built at.
 */
function chooseScale() {
  const override = Number(process.env.SYMBIOTE_SCALE);
  if (Number.isFinite(override) && override > 0) return { factor: override, source: 'env' };

  const d = screen.getPrimaryDisplay();
  const pixels = Math.round(d.size.width * (d.scaleFactor || 1));
  // Below this a display is a normal 1080p-ish panel and the design fits 1:1.
  const factor = pixels >= 2200 ? 2 : 1;
  return { factor, source: 'auto', pixels };
}

function applyScale(factor) {
  if (win && !win.isDestroyed()) win.webContents.setZoomFactor(factor);
}

function createWindow() {
  win = new BrowserWindow({
    width: 1920,
    height: 1080,
    fullscreen: !DEV,
    frame: DEV,
    backgroundColor: '#080808',
    show: false,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      // The renderer is our own UI, but it still gets no Node and no remote
      // access — everything privileged goes through the bridge's IPC channels.
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
      spellcheck: false
    }
  });

  // Kiosk: nothing may navigate away or spawn a second window. Real links open
  // in the browser app instead.
  win.webContents.setWindowOpenHandler(({ url }) => {
    if (/^https?:/.test(url)) shell.openExternal(url);
    return { action: 'deny' };
  });
  win.webContents.on('will-navigate', (event, url) => {
    if (url !== win.webContents.getURL()) event.preventDefault();
  });

  win.once('ready-to-show', () => win.show());
  win.loadFile(path.join(__dirname, '../renderer/index.html'));

  // Zoom only takes effect once there is a document to apply it to.
  win.webContents.on('did-finish-load', () => {
    const { factor, source, pixels } = chooseScale();
    applyScale(factor);
    if (DEV || source === 'auto') {
      console.log(`[symbiote] display ${pixels || '?'}px wide, ui scale ${factor}x (${source})`);
    }
  });

  // An external monitor plugged in later can have a very different density.
  screen.on('display-metrics-changed', () => applyScale(chooseScale().factor));

  startTelemetry(win);
  return win;
}

function hardenSession() {
  // The shell is entirely local; block any outbound request from the renderer.
  session.defaultSession.webRequest.onBeforeRequest((details, callback) => {
    const allowed = details.url.startsWith('file://') || details.url.startsWith('devtools://');
    callback({ cancel: !allowed });
  });

  // Deny every permission prompt by default; apps that need one ask explicitly.
  session.defaultSession.setPermissionRequestHandler((_wc, _permission, callback) => callback(false));
}

app.on('ready', () => {
  hardenSession();
  const channels = registerHandlers();

  /* Exposed so Settings can correct the automatic choice without a rebuild.
     Getting this wrong on unseen hardware would otherwise mean reflashing. */
  ipcMain.handle('ui:scale', (_e, factor) => {
    try {
      if (factor === 'auto' || factor == null) {
        const auto = chooseScale();
        applyScale(auto.factor);
        return { ok: true, data: { factor: auto.factor, mode: 'auto' } };
      }
      const f = Number(factor);
      if (!Number.isFinite(f) || f < 0.5 || f > 4) throw new Error(`scale out of range: ${factor}`);
      applyScale(f);
      return { ok: true, data: { factor: f, mode: 'manual' } };
    } catch (err) {
      return { ok: false, error: String(err.message || err) };
    }
  });
  if (DEV) console.log(`[symbiote] ${channels.length} IPC channels registered`);
  createWindow();
});

// Single instance: a second launch focuses the existing shell.
if (!app.requestSingleInstanceLock()) {
  app.quit();
} else {
  app.on('second-instance', () => {
    if (win && !win.isDestroyed()) win.focus();
  });
}

app.on('window-all-closed', () => app.quit());
