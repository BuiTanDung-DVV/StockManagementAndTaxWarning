import '../../../core/guides/feature_guide_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/customer_provider.dart';
import '../../sales/providers/sales_provider.dart';
import 'customer_form_screen.dart';

final _currFmt = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

class CustomerDetailScreen extends ConsumerWidget {
  final int id;
  const CustomerDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customerAsync = ref.watch(customerDetailProvider(id));
    final ordersAsync = ref.watch(salesListProvider((page: 1, status: null, customerId: id)));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Khách hàng #$id'),
        actions: [featureGuideButton(context, 'customer_detail')],
      ),
      body: customerAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (c) {
          final name = c['name'] ?? 'Khách hàng $id';
          final phone = c['phone'] ?? '';
          final email = c['email'] ?? '';
          final address = c['address'] ?? '';
          final customerType = c['customerType'] ?? 'RETAIL';
          final balance = num.tryParse(c['balance']?.toString() ?? '') ?? 0;
          final creditLimit = num.tryParse(c['creditLimit']?.toString() ?? '') ?? 0;

          return SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(children: [
              CircleAvatar(radius: 40, backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                child: Text(name.isNotEmpty ? name[0] : '?', style: TextStyle(fontSize: 24, color: AppColors.primary, fontWeight: FontWeight.bold))),
              const SizedBox(height: 12),
              Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              if (customerType.isNotEmpty) Container(margin: EdgeInsets.only(top: 4), padding: EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(customerType, style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold))),
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

              const SizedBox(height: 16),
              const Align(alignment: Alignment.centerLeft, child: Text('Lịch sử đơn hàng gần đây', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
              const SizedBox(height: 8),
              ordersAsync.when(
                loading: () => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
                error: (e, _) => Padding(padding: const EdgeInsets.all(16), child: Text('Lỗi: $e')),
                data: (d) {
                  final items = (d['data']?['items'] as List?) ?? [];
                  if (items.isEmpty) return const Padding(padding: EdgeInsets.all(16), child: Text('Chưa có đơn hàng', style: TextStyle(color: Colors.grey, fontSize: 13)));
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final order = items[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(order['orderCode'] ?? ''),
                          subtitle: Text(order['orderDate']?.toString().substring(0, 10) ?? ''),
                          trailing: Text(_currFmt.format(num.tryParse(order['totalAmount']?.toString() ?? '0') ?? 0), style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                        ),
                      );
                    },
                  );
                },
              ),
            ]),
          );
        },
      ),
      floatingActionButton: customerAsync.hasValue ? FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CustomerFormScreen(customer: customerAsync.value!)),
          );
          ref.invalidate(customerDetailProvider(id));
        },
        icon: const Icon(Icons.edit_rounded),
        label: const Text('Chỉnh sửa', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ) : null,
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
