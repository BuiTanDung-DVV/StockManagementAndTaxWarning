import 'dart:js_interop';

@JS('SmartStockOffline.prepare')
external JSPromise<JSAny?> _prepare();

Future<void> prepareOfflineResources() async {
  await _prepare().toDart;
}
