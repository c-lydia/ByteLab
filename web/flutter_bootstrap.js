{{flutter_js}}
{{flutter_build_config}}
_flutter.loader.load({
  config: { canvasKitBaseUrl: 'canvaskit/' },
  onEntrypointLoaded: async function (engineInitializer) {
    try {
      const appRunner = await engineInitializer.initializeEngine();
      await appRunner.runApp();
      document.getElementById('loading')?.remove();
    } catch (error) {
      const loading = document.getElementById('loading');
      if (loading) loading.textContent = 'ByteLab could not start. Reload the page or try a browser with WebGL enabled.';
      console.error(error);
    }
  }
});
