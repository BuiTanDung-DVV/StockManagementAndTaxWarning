import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import 'package:flutter/material.dart';

class TagModel {
  final int id;
  final String name;
  final String color;

  TagModel({required this.id, required this.name, required this.color});

  factory TagModel.fromJson(Map<String, dynamic> json) {
    return TagModel(
      id: json['id'] as int,
      name: json['name'] as String,
      color: json['color'] as String? ?? '#3B82F6',
    );
  }

  Color get uiColor {
    final hex = color.replaceAll('#', '');
    if (hex.length == 6) {
      return Color(int.parse('FF$hex', radix: 16));
    }
    return const Color(0xFF3B82F6);
  }
}

class TagRepository {
  final ApiClient _api;
  TagRepository(this._api);

  Future<List<TagModel>> getAll() async {
    final res = await _api.get('/tags');
    final data = res['data'] as List? ?? [];
    return data.map((e) => TagModel.fromJson(e)).toList();
  }

  Future<TagModel> create(String name, String color) async {
    final res = await _api.post('/tags', data: {'name': name, 'color': color});
    return TagModel.fromJson(res['data']);
  }

  Future<TagModel> update(int id, String name, String color) async {
    final res = await _api.put('/tags/$id', data: {'name': name, 'color': color});
    return TagModel.fromJson(res['data']);
  }

  Future<void> delete(int id) async {
    await _api.delete('/tags/$id');
  }
}

final tagRepoProvider = Provider<TagRepository>((ref) => TagRepository(ref.read(apiClientProvider)));

final tagListProvider = FutureProvider<List<TagModel>>((ref) async {
  return await ref.read(tagRepoProvider).getAll();
});
