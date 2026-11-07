import 'dart:js_interop';
import 'data_change_transport.dart' show DataChangeTransport;

@JS('BroadcastChannel')
extension type _Channel._(JSObject _) implements JSObject {
  external factory _Channel(String name);
  external set onmessage(JSFunction? callback);
  external void postMessage(JSAny? message);
  external void close();
}

extension type _MessageEvent._(JSObject _) implements JSObject {
  external JSAny? get data;
}

DataChangeTransport openTransport(void Function(String) receive) {
  try {
    final channel = _Channel('smartstock-data-changed-v1');
    channel.onmessage = ((_MessageEvent event) {
      final value = event.data.dartify();
      if (value is String) receive(value);
    }).toJS;
    return (
      publish: (message) {
        try {
          channel.postMessage(message.toJS);
        } catch (_) {
          /* Saving already succeeded. */
        }
      },
      dispose: () => channel.close(),
    );
  } catch (_) {
    // Browser without BroadcastChannel: keep normal in-session refresh working.
    return (publish: (_) {}, dispose: () {});
  }
}
