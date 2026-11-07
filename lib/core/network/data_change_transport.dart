import 'data_change_transport_stub.dart'
    if (dart.library.js_interop) 'data_change_transport_web.dart'
    as platform;

typedef DataChangeTransport = ({
  void Function(String) publish,
  void Function() dispose,
});

DataChangeTransport openDataChangeTransport(void Function(String) receive) =>
    platform.openTransport(receive);
