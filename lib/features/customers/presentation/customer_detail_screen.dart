import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/customer_provider.dart';

final _currFmt = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

class CustomerDetailScreen extends ConsumerWidget {
  final int id;
  const CustomerDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customerAsync = ref.watch(customerDetailProvider(id));

    return Scaffold(
      appBar: AppBar(title: Text('Khách hàng #$id')),
      body: customerAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (c) {
          final name = c['name'] ?? 'Khách hàng $id';
          final phone = c['phone'] ?? '';
          final email = c['email'] ?? '';
          final address = c['address'] ?? '';
          final customerType = c['customerType'] ?? 'RETAIL';
          final balance = (c['balance'] as num?) ?? 0;
          final creditLimit = (c['creditLimit'] as num?) ?? 0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              CircleAvatar(radius: 40, backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                child: Text(name.isNotEmpty ? name[0] : '?', style: const TextStyle(fontSize: 24, color: AppColors.primary, fontWeight: FontWeight.bold))),
              const SizedBox(height: 12),
              Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              if (customerType.isNotEmpty) Container(margin: const EdgeInsets.only(top: 4), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(customerType, style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold))),
              const SizedBox(height: 24),
              _Card([
                if (phone.isNotEmpty) _Row('SĐT', phone),
                if (email.isNotEmpty) _Row('Email', email),
                if (address.isNotEmpty) _Row('Địa chỉ', address),
                _Row('Mã KH', c['code'] ?? ''),
                if (c['taxCode'] != null) _Row('MST', c['taxCode']),
              ]),
              const SizedBox(height: 12),
              _Card([
                _Row('Công nợ', _currFmt.format(balance)),
                _Row('Hạn mức tín dụng', _currFmt.format(creditLimit)),
              ]),
              const SizedBox(height: 12),
              if (phone.isEmpty && email.isEmpty && address.isEmpty)
                const Padding(padding: EdgeInsets.all(16), child: Text('Thông tin liên hệ chưa được cập nhật', style: TextStyle(color: Colors.grey, fontSize: 13))),
            ]),
          );
        },
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card(this.children);
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppThemeColors.of(context).card, borderRadius: BorderRadius.circular(12)),
    child: Column(children: children));
}

class _Row extends StatelessWidget {
  final String label, value;
  const _Row(this.label, this.value);
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(color: AppThemeColors.of(context).textSecondary, fontSize: 13)),
      Flexible(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13), textAlign: TextAlign.right)),
    ]));
}
