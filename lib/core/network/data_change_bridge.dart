import 'dart:convert';
import '../providers/data_freshness_provider.dart';

/// Invalidation only: no tokens, user details or business records cross tabs.
class DataChangeBridge {
  final String? Function() currentShop;
  final bool Function() isAuthenticated;
  final void Function(Set<DataArea>) invalidate;
  final void Function(String) send;

  DataChangeBridge({
    required this.currentShop,
    required this.isAuthenticated,
    required this.invalidate,
    required this.send,
  });

  void committed(Set<DataArea> areas) {
    final shop = currentShop();
    if (!isAuthenticated() || shop == null || areas.isEmpty) return;
    send(
      jsonEncode({
        'v': 1,
        'shop': shop,
        'areas': areas.map((a) => a.name).toList(),
      }),
    );
  }

  void receive(String message) {
    if (!isAuthenticated() || message.length > 2048) return;
    try {
      final value = jsonDecode(message);
      if (value is! Map ||
          value['v'] != 1 ||
          value['shop'] == null ||
          value['shop'] != currentShop() ||
          value['areas'] is! List) {
        return;
      }
      final names = value['areas'] as List;
      final areas = DataArea.values
          .where((a) => names.contains(a.name))
          .toSet();
      if (areas.isNotEmpty) invalidate(areas);
    } catch (_) {
      /* Ignore malformed or incompatible invalidation messages. */
    }
  }
}
