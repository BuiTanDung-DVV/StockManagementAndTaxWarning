import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

class SystemRepository {
  final ApiClient _api;
  SystemRepository(this._api);

  Future<Map<String, dynamic>> getShopProfile() async => await _api.get('/shop-profile');
  Future<Map<String, dynamic>> saveShopProfile(Map<String, dynamic> dto) async => await _api.post('/shop-profile', data: dto);

  Future<Map<String, dynamic>> getLogs({int page = 1, int limit = 50}) async =>
      await _api.get('/activity-logs', params: {'page': '$page', 'limit': '$limit'});
}

final systemRepoProvider = Provider<SystemRepository>((ref) => SystemRepository(ref.read(apiClientProvider)));

final shopProfileProvider = FutureProvider<Map<String, dynamic>>((ref) {
  return ref.read(systemRepoProvider).getShopProfile();
});

final activityLogsProvider = FutureProvider.family<Map<String, dynamic>, int>((ref, page) {
  return ref.read(systemRepoProvider).getLogs(page: page);
});
