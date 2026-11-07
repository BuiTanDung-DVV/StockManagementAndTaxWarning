import 'package:sembast_web/sembast_web.dart';

Future<Database> openOfflineDatabase() =>
    databaseFactoryWeb.openDatabase('smartstock_offline_v1');
