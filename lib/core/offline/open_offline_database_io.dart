import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';

Future<Database> openOfflineDatabase() async {
  final directory = await getApplicationSupportDirectory();
  await directory.create(recursive: true);
  return databaseFactoryIo.openDatabase(
    '${directory.path}${Platform.pathSeparator}smartstock_offline_v1.db',
  );
}
