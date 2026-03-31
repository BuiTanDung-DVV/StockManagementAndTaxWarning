import '../../../core/guides/feature_guide_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/supplier_provider.dart';

final _currFmt = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

class SupplierDetailScreen extends ConsumerWidget {
  final int id;
  const SupplierDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(supplierDetailProvider(id));

    return Scaffold(
      appBar: AppBar(title: Text('NCC #$id'), actions: [featureGuideButton(context, 'supplier_detail')]),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          Text('Không tải được dữ liệu\n$e', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: () => ref.invalidate(supplierDetailProvider(id)), child: const Text('Thử lại')),
        ])),
        data: (s) {
          final name = s['name'] ?? 'Nhà cung cấp $id';
          final contactName = s['contactName'] ?? s['contact'] ?? '';
          final phone = s['phone'] ?? '';
          final email = s['email'] ?? '';
          final address = s['address'] ?? '';
          final taxCode = s['taxCode'] ?? '';
          final bankName = s['bankName'] ?? '';
          final bankAccount = s['bankAccount'] ?? '';
          final paymentTerms = s['paymentTerms'] ?? '';
          final balance = (s['balance'] as num?)?.toDouble() ?? 0;
          final totalPurchase = (s['totalPurchase'] as num?)?.toDouble() ?? 0;

          return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
            Container(width: 70, height: 70, decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16)),
              child: Text(name.isNotEmpty ? name[0] : '?', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.info)).let((w) => Center(child: w))),
            const SizedBox(height: 12),
            Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            _Card([
              if (taxCode.isNotEmpty) _R('MST', taxCode),
              if (contactName.isNotEmpty) _R('Liên hệ', contactName),
              if (phone.isNotEmpty) _R('SĐT', phone),
              if (email.isNotEmpty) _R('Email', email),
              if (address.isNotEmpty) _R('Địa chỉ', address),
              if (bankName.isNotEmpty) _R('Ngân hàng', bankName),
              if (bankAccount.isNotEmpty) _R('STK', bankAccount),
              if (paymentTerms.toString().isNotEmpty) _R('Kỳ TT', paymentTerms.toString()),
            ]),
            const SizedBox(height: 12),
            _Card([
              if (totalPurchase > 0) _R('Tổng nhập', _currFmt.format(totalPurchase)),
              _R('Công nợ NCC', _currFmt.format(balance)),
            ]),
            if (contactName.isEmpty && phone.isEmpty && email.isEmpty)
              const Padding(padding: EdgeInsets.all(16), child: Text('Thông tin liên hệ chưa được cập nhật', style: TextStyle(color: Colors.grey, fontSize: 13))),
          ]));
        },
      ),
    );
  }
}

extension _WidgetExt on Widget {
  Widget let(Widget Function(Widget) fn) => fn(this);
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card(this.children);
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppThemeColors.of(context).card, borderRadius: BorderRadius.circular(12)), child: Column(children: children));
}

class _R extends StatelessWidget {
  final String l, v;
  const _R(this.l, this.v);
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: TextStyle(color: AppThemeColors.of(context).textSecondary, fontSize: 13)), Flexible(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13), textAlign: TextAlign.end))]));
}
