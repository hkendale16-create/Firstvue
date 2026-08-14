{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
  config: {
    // Load CanvasKit from this deploy instead of www.gstatic.com.
    canvasKitBaseUrl: 'canvaskit/',
  },
}).catch(function (error) {
  var boot = document.getElementById('fv-boot');
  if (boot) {
    boot.textContent = 'FirstVue failed to load. Please refresh.';
  }
  console.error(error);
});
