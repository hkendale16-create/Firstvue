{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
  config: {
    // Prefer the CanvasKit shipped in build/web so CSP does not have to
    // allow https://www.gstatic.com/flutter-canvaskit for the app to paint.
    useLocalCanvasKit: true,
  },
}).catch(function (error) {
  var boot = document.getElementById('fv-boot');
  if (boot) {
    boot.textContent = 'FirstVue failed to load. Please refresh.';
  }
  console.error(error);
});
