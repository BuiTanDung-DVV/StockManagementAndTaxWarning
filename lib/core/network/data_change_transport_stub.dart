import 'data_change_transport.dart' show DataChangeTransport;

DataChangeTransport openTransport(void Function(String) receive) =>
    (publish: (_) {}, dispose: () {});
