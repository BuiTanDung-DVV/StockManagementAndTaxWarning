import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import 'shop_provider.dart';

class AiDocument {
  final String id;
  final String title;
  final String category;
  final String content;
  final bool isActive;
  final DateTime createdAt;

  AiDocument({
    required this.id,
    required this.title,
    required this.category,
    required this.content,
    this.isActive = true,
    required this.createdAt,
  });

  AiDocument copyWith({
    String? title,
    String? category,
    String? content,
    bool? isActive,
  }) {
    return AiDocument(
      id: id,
      title: title ?? this.title,
      category: category ?? this.category,
      content: content ?? this.content,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'category': category,
    'content': content,
    'isActive': isActive,
    'createdAt': createdAt.toIso8601String(),
  };

  factory AiDocument.fromJson(Map<String, dynamic> json) => AiDocument(
    id: json['id'] != null ? json['id'].toString() : '',
    title: json['title'] ?? '',
    category: json['category'] ?? 'Chung',
    content: json['content'] ?? '',
    isActive: json['isActive'] ?? json['is_active'] ?? true,
    createdAt: json['createdAt'] != null
        ? DateTime.parse(json['createdAt'])
        : (json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : DateTime.now()),
  );
}

class AiKnowledgeNotifier extends AsyncNotifier<List<AiDocument>> {
  @override
  Future<List<AiDocument>> build() async {
    final shopState = ref.watch(shopProvider);
    if (shopState.isAllShops || shopState.currentShopId == null) {
      throw StateError('Vui lòng chọn một cửa hàng để tải kho tài liệu AI.');
    }
    final response = await _api.get('/ai-knowledge');
    if (response is! List) {
      throw const FormatException('Phản hồi kho tài liệu AI không hợp lệ.');
    }
    return response
        .whereType<Map>()
        .map((item) => AiDocument.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  ApiClient get _api => ref.read(apiClientProvider);

  Future<void> addDocument({
    required String title,
    required String category,
    required String content,
  }) async {
    final response = await _api.post(
      '/ai-knowledge',
      data: {
        'title': title.trim(),
        'category': category.trim(),
        'content': content.trim(),
      },
    );
    final doc = AiDocument.fromJson(Map<String, dynamic>.from(response as Map));
    final current = state.asData?.value ?? const <AiDocument>[];
    state = AsyncData([doc, ...current]);
  }

  Future<void> removeDocument(String id) async {
    await _api.delete('/ai-knowledge/$id');
    final current = state.asData?.value ?? const <AiDocument>[];
    state = AsyncData(current.where((d) => d.id != id).toList());
  }

  Future<void> toggleDocument(String id) async {
    final currentDocuments = state.asData?.value ?? const <AiDocument>[];
    final matches = currentDocuments.where((document) => document.id == id);
    if (matches.isEmpty) return;
    final current = matches.first;
    final response = await _api.put(
      '/ai-knowledge/$id',
      data: {'isActive': !current.isActive},
    );
    final updated = AiDocument.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
    state = AsyncData(
      currentDocuments.map((d) {
        return d.id == id ? updated : d;
      }).toList(),
    );
  }
}

final aiKnowledgeProvider =
    AsyncNotifierProvider<AiKnowledgeNotifier, List<AiDocument>>(
      AiKnowledgeNotifier.new,
      retry: (_, _) => null,
    );
