/* Precompiles the design kit for offline use.
 *
 * The design project loads React, Babel and Lucide from a CDN and compiles JSX
 * in the browser. The shell blocks all network access, so none of that can
 * work there. This script does the same job ahead of time:
 *
 *   - copies React / ReactDOM / Lucide UMD builds out of node_modules
 *   - transforms every .jsx in kit/ from JSX to plain JS with esbuild
 *   - concatenates them in dependency order into one file
 *
 * The kit files are deliberately left as-is otherwise. They define globals
 * (window.Dashboard, window.Taskbar, ...) rather than ES modules, which means
 * the same sources render both in the browser preview and in the shell.
 */

import { build, transform } from 'esbuild';
import { readFile, writeFile, mkdir, copyFile, readdir } from 'fs/promises';
import { existsSync } from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const RENDERER = path.join(ROOT, 'src/renderer');
const OUT = path.join(RENDERER, 'build');

/* Load order matters: Dashboard references the others at render time, and the
   design system bundle must define its namespace before anything reads it. */
const KIT_ORDER = [
  'Live.jsx',
  'Hologram.jsx',
  'MicroReadout.jsx',
  'DataRail.jsx',
  'Waveform.jsx',
  'ScanThumbs.jsx',
  'ProcessList.jsx',
  'NetworkPanel.jsx',
  'ArcReactor.jsx',
  'DesktopIcons.jsx',
  'SettingsApp.jsx',
  'Taskbar.jsx',
  'AppLauncher.jsx',
  'Dashboard.jsx'
];

const VENDOR = [
  ['react/umd/react.production.min.js', 'react.js'],
  ['react-dom/umd/react-dom.production.min.js', 'react-dom.js'],
  ['lucide/dist/umd/lucide.min.js', 'lucide.js']
];

const CSS_ORDER = ['colors.css', 'typography.css', 'spacing.css', 'effects.css', 'kit.css'];

async function main() {
  await mkdir(OUT, { recursive: true });

  // 1. vendor libraries
  for (const [from, to] of VENDOR) {
    const src = path.join(ROOT, 'node_modules', from);
    if (!existsSync(src)) throw new Error(`missing vendor file: ${from} (run npm install)`);
    await copyFile(src, path.join(OUT, to));
  }
  console.log(`vendored ${VENDOR.length} libraries`);

  // 2. the design system's own component bundle — already compiled, no CDN
  await copyFile(path.join(RENDERER, 'vendor/ds-bundle.js'), path.join(OUT, 'ds-bundle.js'));

  // 3. transform the kit
  const present = (await readdir(path.join(RENDERER, 'kit'))).filter((f) => f.endsWith('.jsx'));
  const missing = KIT_ORDER.filter((f) => !present.includes(f));
  if (missing.length) throw new Error(`kit files listed but not found: ${missing.join(', ')}`);
  const extra = present.filter((f) => !KIT_ORDER.includes(f));
  if (extra.length) console.warn(`W: not in load order, skipping: ${extra.join(', ')}`);

  const chunks = [];
  for (const file of KIT_ORDER) {
    const source = await readFile(path.join(RENDERER, 'kit', file), 'utf8');
    const { code } = await transform(source, {
      loader: 'jsx',
      jsx: 'transform',           // classic React.createElement, matching the CDN setup
      jsxFactory: 'React.createElement',
      jsxFragment: 'React.Fragment',
      target: 'es2020'
    });
    // Each kit file assigns to window and declares top-level consts; wrapping
    // keeps those consts from colliding across files.
    chunks.push(`/* ${file} */\n(function(){\n${code}\n})();\n`);
  }
  await writeFile(path.join(OUT, 'kit.js'), chunks.join('\n'));
  console.log(`compiled ${KIT_ORDER.length} kit components`);

  // 4. the live-data adapter, bundled so it can import cleanly
  await build({
    entryPoints: [path.join(RENDERER, 'live-hud.js')],
    outfile: path.join(OUT, 'live-hud.js'),
    bundle: true,
    format: 'iife',
    target: 'es2020'
  });

  // 5. one stylesheet, in cascade order
  const css = [];
  for (const file of CSS_ORDER) {
    css.push(`/* ${file} */\n` + (await readFile(path.join(RENDERER, 'css', file), 'utf8')));
  }
  await writeFile(path.join(OUT, 'styles.css'), css.join('\n'));
  console.log(`merged ${CSS_ORDER.length} stylesheets`);
}

main().catch((err) => {
  console.error('renderer build failed:', err.message);
  process.exit(1);
});
