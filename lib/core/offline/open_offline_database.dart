import 'package:sembast/sembast.dart';
import 'open_offline_database_io.dart'
    if (dart.library.js_interop) 'open_offline_database_web.dart'
    as platform;

Future<Database> openOfflineDatabase() => platform.openOfflineDatabase();
