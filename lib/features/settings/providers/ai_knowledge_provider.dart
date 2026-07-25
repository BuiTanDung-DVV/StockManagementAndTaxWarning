import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

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
    id: json['id'] ?? '',
    title: json['title'] ?? '',
    category: json['category'] ?? 'Chung',
    content: json['content'] ?? '',
    isActive: json['isActive'] ?? true,
    createdAt: json['createdAt'] != null
        ? DateTime.parse(json['createdAt'])
        : DateTime.now(),
  );
}

class AiKnowledgeNotifier extends Notifier<List<AiDocument>> {
  static const _storageKey = 'smartstock_ai_knowledge_docs';

  @override
  List<AiDocument> build() {
    _loadFromStorage();
    return _defaultDocuments;
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final List list = jsonDecode(raw);
        final currentTaxDocument = _defaultDocuments.firstWhere(
          (document) => document.id == 'DOC_TAX_01',
        );
        state = list.map((e) {
          final document = AiDocument.fromJson(e);
          if (document.id == currentTaxDocument.id) {
            return currentTaxDocument.copyWith(isActive: document.isActive);
          }
          return document;
        }).toList();
        await _saveToStorage();
      } else {
        state = _defaultDocuments;
        await _saveToStorage();
      }
    } catch (_) {
      state = _defaultDocuments;
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(state.map((e) => e.toJson()).toList());
      await prefs.setString(_storageKey, raw);
    } catch (_) {}
  }

  Future<void> addDocument({
    required String title,
    required String category,
    required String content,
  }) async {
    final doc = AiDocument(
      id: 'DOC_${DateTime.now().millisecondsSinceEpoch}',
      title: title.trim(),
      category: category.trim(),
      content: content.trim(),
      isActive: true,
      createdAt: DateTime.now(),
    );
    state = [doc, ...state];
    await _saveToStorage();
  }

  Future<void> removeDocument(String id) async {
    state = state.where((d) => d.id != id).toList();
    await _saveToStorage();
  }

  Future<void> toggleDocument(String id) async {
    state = state.map((d) {
      if (d.id == id) {
        return d.copyWith(isActive: !d.isActive);
      }
      return d;
    }).toList();
    await _saveToStorage();
  }

  static final List<AiDocument> _defaultDocuments = [
    AiDocument(
      id: 'DOC_TAX_01',
      title: 'Nghị định 141/2026/NĐ-CP về Thuế Hộ Kinh Doanh',
      category: 'Thuế HKD',
      content: '''
- Ngưỡng doanh thu hiện hành: Hộ, cá nhân kinh doanh có doanh thu năm từ 1 tỷ đồng trở xuống không phải nộp thuế GTGT và thuế TNCN.
- Tỷ lệ thuế trên doanh thu ngành Thương mại (bán lẻ hàng hóa): 1% GTGT + 0.5% TNCN.
- Tỷ lệ thuế ngành Dịch vụ: 5% GTGT + 2% TNCN.
- Hóa đơn điện tử: Hộ, cá nhân kinh doanh có doanh thu năm trên 1 tỷ đồng thuộc diện phải áp dụng theo Nghị định 141/2026/NĐ-CP.
- Nguồn chính thức: https://vanban.chinhphu.vn/?classid=1&docid=217960&pageid=27160&typegroupid=4
- Nội dung chỉ hỗ trợ tham khảo; cần đối chiếu ngành nghề, phương pháp tính và hồ sơ thực tế trước khi kê khai.
''',
      isActive: true,
      createdAt: DateTime.now(),
    ),
    AiDocument(
      id: 'DOC_DEBT_01',
      title: 'Quy Định Quản Lý Nợ Mua Thiếu & Nhắc Nợ Cửa Hàng',
      category: 'Bán Hàng & Sổ Nợ',
      content: '''
- Khách quen mua thiếu phải được ghi rõ tên, SĐT và lý do nợ trên sổ nợ SmartStock POS.
- Thời hạn nợ tối đa là 30 ngày kể từ ngày mua.
- Đối với nợ quá 30 ngày: Sử dụng tính năng [Nhắc Nợ Zalo 1-Click] để gửi tin nhắn thông báo số dư công nợ lịch sự.
- Thu nợ theo từng đợt: Ghi nhận chính xác số tiền khách trả và yêu cầu tải ảnh chụp biên nhận/chuyển khoản QR.
''',
      isActive: true,
      createdAt: DateTime.now(),
    ),
    AiDocument(
      id: 'DOC_STOCK_01',
      title: 'Nội Quy Kiểm Kê Kho & Chốt Két Tiền Mặt Cuối Ngày',
      category: 'Kho & Tài Chính',
      content: '''
- Kiểm kê kho định kỳ: Thực hiện kiểm kê thực tế hàng tuần. Sản phẩm dưới định mức tối thiểu phải lập đơn mua PO ngay.
- Chốt két thu ngân cuối ngày: Kiểm tra tiền mặt thực tế trong két so với số dư lý thuyết trên phần mềm.
- Trường hợp chênh lệch quỹ: Nếu thiếu tiền phải ghi rõ nguyên nhân vào sổ chốt ca trước khi bàn giao ca.
''',
      isActive: true,
      createdAt: DateTime.now(),
    ),
  ];
}

final aiKnowledgeProvider =
    NotifierProvider<AiKnowledgeNotifier, List<AiDocument>>(
      AiKnowledgeNotifier.new,
    );
