import 'prepare_offline_resources_io.dart'
    if (dart.library.js_interop) 'prepare_offline_resources_web.dart'
    as platform;

Future<void> prepareOfflineResources() => platform.prepareOfflineResources();
