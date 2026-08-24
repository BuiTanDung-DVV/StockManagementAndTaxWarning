import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../settings/providers/shop_provider.dart';

class TaxDeclarationFormReference {
  const TaxDeclarationFormReference({
    required this.code,
    required this.name,
    required this.description,
    required this.status,
    required this.iconKey,
  });

  final String code;
  final String name;
  final String description;
  final String status;
  final String iconKey;

  bool get isReady => status == 'READY';

  factory TaxDeclarationFormReference.fromJson(Map<String, dynamic> json) {
    return TaxDeclarationFormReference(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      iconKey: json['iconKey']?.toString() ?? '',
    );
  }
}

class TaxSupportLinkReference {
  const TaxSupportLinkReference({
    required this.title,
    required this.description,
    required this.url,
    required this.iconKey,
    required this.colorRole,
  });

  final String title;
  final String description;
  final String url;
  final String iconKey;
  final String colorRole;

  factory TaxSupportLinkReference.fromJson(Map<String, dynamic> json) {
    return TaxSupportLinkReference(
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      iconKey: json['iconKey']?.toString() ?? '',
      colorRole: json['colorRole']?.toString() ?? '',
    );
  }
}

class TaxReferenceData {
  const TaxReferenceData({required this.forms, required this.supportLinks});

  final List<TaxDeclarationFormReference> forms;
  final List<TaxSupportLinkReference> supportLinks;

  factory TaxReferenceData.fromJson(Map<String, dynamic> json) {
    final forms = (json['forms'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) => TaxDeclarationFormReference.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .where((item) => item.code.isNotEmpty && item.name.isNotEmpty)
        .toList(growable: false);
    final supportLinks = (json['supportLinks'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) => TaxSupportLinkReference.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .where((item) => item.title.isNotEmpty && item.url.isNotEmpty)
        .toList(growable: false);
    if (forms.isEmpty || supportLinks.isEmpty) {
      throw const FormatException('Dữ liệu tham chiếu thuế từ DB chưa đầy đủ');
    }
    return TaxReferenceData(forms: forms, supportLinks: supportLinks);
  }
}

final taxReferenceDataProvider = FutureProvider<TaxReferenceData>((ref) async {
  ref.watch(shopProvider);
  final response = await ref.read(apiClientProvider).get('/tax-reference-data');
  if (response is! Map) {
    throw const FormatException('API dữ liệu tham chiếu thuế sai định dạng');
  }
  return TaxReferenceData.fromJson(Map<String, dynamic>.from(response));
});
