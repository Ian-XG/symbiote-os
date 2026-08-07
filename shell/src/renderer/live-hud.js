/* Renderer entry point: mounts the HUD onto the 1920x1080 stage and scales it
   to whatever resolution the display actually is. */

/* The design preview scales a fixed 1920x1080 artboard to fit. The OS must not:
   scaling a 0.67 factor onto 8px type renders it at 5px and it turns to mush.
   Here the shell lays out at the display's real size, so text is drawn at its
   true pixel size and stays sharp on any panel. */
function fitStage() {
  const stage = document.getElementById('stage');
  if (!stage) return;
  stage.style.transform = 'none';
  stage.style.width = '100vw';
  stage.style.height = '100vh';
  stage.style.left = '0';
  stage.style.top = '0';
}

function mount() {
  const root = document.getElementById('root');

  if (!window.Dashboard) {
    root.innerHTML =
      '<pre style="color:#ff1744;font:12px monospace;padding:24px">' +
      'Dashboard failed to load.\n\n' +
      'Design system errors:\n' +
      JSON.stringify(
        (window.SymbioteOSDesignSystem_5d2af6 && window.SymbioteOSDesignSystem_5d2af6.__errors) || [],
        null,
        2
      ) +
      '</pre>';
    return;
  }

  ReactDOM.createRoot(root).render(React.createElement(window.Dashboard, { fill: true }));
  fitStage();
}

window.addEventListener('resize', fitStage);
window.addEventListener('load', fitStage);

// Surface a renderer crash on screen instead of leaving a black display.
window.addEventListener('error', (e) => {
  const bar = document.getElementById('crash');
  if (bar) {
    bar.style.display = 'block';
    bar.textContent = `renderer error: ${e.message}`;
  }
});

mount();
