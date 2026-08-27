import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../settings/providers/shop_provider.dart';

enum DashboardActionSeverity { critical, warning, info, healthy }

class DashboardActionItem {
  final String actionKey;
  final DashboardActionSeverity severity;
  final int priorityScore;
  final String title;
  final String detail;
  final String badge;
  final int? count;
  final double? amount;
  final DateTime? dueAt;
  final DateTime? sourceUpdatedAt;

  const DashboardActionItem({
    required this.actionKey,
    required this.severity,
    required this.priorityScore,
    required this.title,
    required this.detail,
    required this.badge,
    this.count,
    this.amount,
    this.dueAt,
    this.sourceUpdatedAt,
  });

  factory DashboardActionItem.fromJson(Map<String, dynamic> json) {
    final key = json['actionKey']?.toString().trim() ?? '';
    final title = json['title']?.toString().trim() ?? '';
    final detail = json['detail']?.toString().trim() ?? '';
    final badge = json['badge']?.toString().trim() ?? '';
    final score = num.tryParse(json['priorityScore']?.toString() ?? '');
    final severity = switch (json['severity']) {
      'CRITICAL' => DashboardActionSeverity.critical,
      'WARNING' => DashboardActionSeverity.warning,
      'INFO' => DashboardActionSeverity.info,
      'HEALTHY' => DashboardActionSeverity.healthy,
      _ => null,
    };
    if (key.isEmpty ||
        title.isEmpty ||
        detail.isEmpty ||
        badge.isEmpty ||
        score == null ||
        !score.isFinite ||
        severity == null) {
      throw const FormatException('Action item từ API không đầy đủ');
    }
    return DashboardActionItem(
      actionKey: key,
      severity: severity,
      priorityScore: score.round(),
      title: title,
      detail: detail,
      badge: badge,
      count: json['count'] == null
          ? null
          : num.tryParse(json['count'].toString())?.round(),
      amount: json['amount'] == null
          ? null
          : num.tryParse(json['amount'].toString())?.toDouble(),
      dueAt: DateTime.tryParse(json['dueAt']?.toString() ?? ''),
      sourceUpdatedAt: DateTime.tryParse(
        json['sourceUpdatedAt']?.toString() ?? '',
      ),
    );
  }

  String get destination {
    if (actionKey.startsWith('INVENTORY_')) {
      if (actionKey.contains('EXPIRED')) return '/inventory?issue=expired';
      if (actionKey.contains('EXPIRING')) return '/inventory?issue=expiring';
      return '/inventory?issue=low-stock';
    }
    if (actionKey.startsWith('RECEIVABLE_')) {
      return '/customer-debts?status=overdue';
    }
    if (actionKey.startsWith('TAX_CONFIG_')) return '/tax-config';
    if (actionKey.startsWith('TAX_')) return '/tax-obligations?status=pending';
    return '/notifications?filter=actionable';
  }
}

class DashboardActionData {
  final DateTime asOf;
  final List<DashboardActionItem> items;
  final List<DashboardActionItem> healthySummary;

  const DashboardActionData({
    required this.asOf,
    required this.items,
    required this.healthySummary,
  });

  factory DashboardActionData.fromJson(Map<String, dynamic> json) {
    final asOf = DateTime.tryParse(json['asOf']?.toString() ?? '');
    final rawItems = json['items'];
    final rawHealthy = json['healthySummary'];
    if (asOf == null || rawItems is! List || rawHealthy is! List) {
      throw const FormatException('Dữ liệu Action Center không hợp lệ');
    }
    final items = rawItems
        .map(
          (item) => DashboardActionItem.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList(growable: false);
    final healthy = rawHealthy
        .map(
          (item) => DashboardActionItem.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList(growable: false);
    if (items.any((item) => item.severity == DashboardActionSeverity.healthy) ||
        healthy.any(
          (item) => item.severity != DashboardActionSeverity.healthy,
        )) {
      throw const FormatException('Nhóm ưu tiên từ API không hợp lệ');
    }
    return DashboardActionData(
      asOf: asOf,
      items: items,
      healthySummary: healthy,
    );
  }
}

final dashboardActionProvider = FutureProvider<DashboardActionData>((
  ref,
) async {
  ref.watch(shopProvider);
  final response = await ref
      .read(apiClientProvider)
      .get('/dashboard/action-items');
  if (response is! Map) {
    throw const FormatException('Action Center không trả về object');
  }
  return DashboardActionData.fromJson(Map<String, dynamic>.from(response));
});
