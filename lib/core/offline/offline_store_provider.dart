import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'offline_store.dart';
import 'open_offline_database.dart';

// Kept independent of auth so startup can restore a prepared local workspace.
final offlineStoreProvider = FutureProvider<OfflineStore>((ref) async {
  final database = await openOfflineDatabase();
  ref.onDispose(() => unawaited(database.close()));
  return OfflineStore(database);
});
