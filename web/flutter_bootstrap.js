{{flutter_js}}
{{flutter_build_config}}

// Drop a stale PWA worker from earlier deploys. Waiting for it to
// precache ~5MB of JS/WASM is what made first load feel stuck on phones.
if (typeof navigator !== 'undefined' && navigator.serviceWorker) {
  navigator.serviceWorker.getRegistrations().then(function (regs) {
    regs.forEach(function (reg) {
      reg.unregister();
    });
  });
}

_flutter.loader.load({
  config: {
    // Load CanvasKit from this deploy instead of www.gstatic.com.
    canvasKitBaseUrl: 'canvaskit/',
  },
  onEntrypointLoaded: async function (engineInitializer) {
    var appRunner = await engineInitializer.initializeEngine({
      canvasKitBaseUrl: 'canvaskit/',
    });
    var boot = document.getElementById('fv-boot');
    if (boot) boot.remove();
    await appRunner.runApp();
  },
}).catch(function (error) {
  var boot = document.getElementById('fv-boot');
  if (boot) {
    boot.textContent = 'FirstVue failed to load. Please refresh.';
  }
  console.error(error);
});
