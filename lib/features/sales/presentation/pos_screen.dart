import '../../../core/guides/feature_guide_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../products/providers/product_provider.dart';
import '../../settings/providers/system_provider.dart';
import '../providers/sales_provider.dart';
import 'qr_payment_screen.dart';

final _currFmt = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
final _tts = FlutterTts();

/// Cart item model
class CartItem {
  final int productId;
  final String name;
  final double price;
  final int quantity;
  const CartItem({required this.productId, required this.name, required this.price, this.quantity = 1});
  double get subtotal => price * quantity;
  CartItem copyWith({int? quantity}) => CartItem(productId: productId, name: name, price: price, quantity: quantity ?? this.quantity);
}

/// Cart state
class CartState {
  final List<CartItem> items;
  const CartState([this.items = const []]);
  double get total => items.fold(0.0, (sum, i) => sum + i.subtotal);
  int get itemCount => items.fold(0, (sum, i) => sum + i.quantity);
}

/// Cart notifier (Riverpod v3 Notifier pattern)
class CartNotifier extends Notifier<CartState> {
  @override
  CartState build() => const CartState();

  void add(int productId, String name, double price) {
    final existing = state.items.where((i) => i.productId == productId).firstOrNull;
    if (existing != null) {
      state = CartState(state.items.map((i) => i.productId == productId ? i.copyWith(quantity: i.quantity + 1) : i).toList());
    } else {
      state = CartState([...state.items, CartItem(productId: productId, name: name, price: price)]);
    }
  }

  void increment(int productId) {
    state = CartState(state.items.map((i) => i.productId == productId ? i.copyWith(quantity: i.quantity + 1) : i).toList());
  }

  void decrement(int productId) {
    final item = state.items.firstWhere((i) => i.productId == productId);
    if (item.quantity > 1) {
      state = CartState(state.items.map((i) => i.productId == productId ? i.copyWith(quantity: i.quantity - 1) : i).toList());
    } else {
      state = CartState(state.items.where((i) => i.productId != productId).toList());
    }
  }

  void remove(int productId) {
    state = CartState(state.items.where((i) => i.productId != productId).toList());
  }

  void clear() => state = const CartState();
}

final _cartProvider = NotifierProvider<CartNotifier, CartState>(CartNotifier.new);

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});
  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  bool _creating = false;

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final cart = ref.watch(_cartProvider);
    final productsAsync = ref.watch(productListProvider((page: 1, search: _search.isEmpty ? null : _search)));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bán hàng'),
        actions: [
          featureGuideButton(context, 'pos'),
          if (cart.items.isNotEmpty)
            Badge(
              label: Text('${cart.itemCount}'),
              child: IconButton(icon: const Icon(Icons.shopping_cart), onPressed: () => _showCart(context)),
            ),
        ],
      ),
      body: Column(children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Tìm sản phẩm...',
              prefixIcon: Icon(Icons.search, color: c.textMuted),
              suffixIcon: _search.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { _searchCtrl.clear(); setState(() => _search = ''); }) : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
        ),

        // Product list
        Expanded(
          child: productsAsync.when(
            data: (data) {
              final products = (data['items'] as List?) ?? [];
              if (products.isEmpty) {
                return Center(child: Text(_search.isEmpty ? 'Chưa có sản phẩm' : 'Không tìm thấy "$_search"', style: TextStyle(color: c.textMuted)));
              }
              return ListView.builder(
                padding: EdgeInsets.only(left: 12, right: 12, bottom: cart.items.isNotEmpty ? 100 : 16),
                itemCount: products.length,
                itemBuilder: (_, i) {
                  final p = products[i];
                  final id = p['id'] as int;
                  final name = p['name'] ?? 'SP';
                  final price = (p['sellingPrice'] ?? p['selling_price'] ?? 0).toDouble();
                  final stock = p['stockQuantity'] ?? p['stock_quantity'] ?? '—';
                  final cartItem = cart.items.where((ci) => ci.productId == id).firstOrNull;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.inventory_2, color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Row(children: [
                          Text(_currFmt.format(price), style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Text('Kho: $stock', style: TextStyle(fontSize: 11, color: c.textMuted)),
                        ]),
                      ])),
                      if (cartItem != null)
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          _qtyButton(Icons.remove, () => ref.read(_cartProvider.notifier).decrement(id)),
                          Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('${cartItem.quantity}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                          _qtyButton(Icons.add, () => ref.read(_cartProvider.notifier).increment(id)),
                        ])
                      else
                        SizedBox(
                          width: 44, height: 44,
                          child: IconButton(
                            onPressed: () {
                              ref.read(_cartProvider.notifier).add(id, name, price);
                              HapticFeedback.lightImpact();
                            },
                            icon: const Icon(Icons.add_shopping_cart, color: AppColors.primary, size: 22),
                            style: IconButton.styleFrom(backgroundColor: AppColors.primary.withValues(alpha: 0.1)),
                          ),
                        ),
                    ]),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Lỗi: $e', style: TextStyle(color: AppColors.danger))),
          ),
        ),

        // Bottom bar
        if (cart.items.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2))],
            ),
            child: SafeArea(
              top: false,
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text('${cart.itemCount} sản phẩm', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                  Text(_currFmt.format(cart.total), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
                ])),
                ElevatedButton.icon(
                  onPressed: _creating ? null : () => _showCheckout(context),
                  icon: const Icon(Icons.payment),
                  label: const Text('Thanh toán'),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
                ),
              ]),
            ),
          ),
      ]),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: 36, height: 36,
      child: IconButton(
        onPressed: () { onTap(); HapticFeedback.lightImpact(); },
        icon: Icon(icon, size: 18, color: AppColors.primary),
        style: IconButton.styleFrom(
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        padding: EdgeInsets.zero,
      ),
    );
  }

  void _showCart(BuildContext context) {
    final c = AppThemeColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Consumer(builder: (ctx, ref, _) {
        final cart = ref.watch(_cartProvider);
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.5,
          maxChildSize: 0.85,
          builder: (_, scrollCtrl) => Column(children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Giỏ hàng (${cart.itemCount})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                TextButton(onPressed: () { ref.read(_cartProvider.notifier).clear(); Navigator.pop(ctx); }, child: const Text('Xóa tất cả', style: TextStyle(color: AppColors.danger))),
              ]),
            ),
            Expanded(child: ListView.builder(
              controller: scrollCtrl,
              itemCount: cart.items.length,
              itemBuilder: (_, i) {
                final item = cart.items[i];
                return ListTile(
                  title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${_currFmt.format(item.price)} × ${item.quantity} = ${_currFmt.format(item.subtotal)}'),
                  trailing: IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.danger), onPressed: () => ref.read(_cartProvider.notifier).remove(item.productId)),
                );
              },
            )),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Tổng:', style: TextStyle(fontSize: 16)),
                Text(_currFmt.format(cart.total), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ]),
            ),
          ]),
        );
      }),
    );
  }

  void _showCheckout(BuildContext context) {
    final c = AppThemeColors.of(context);
    final cart = ref.read(_cartProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Xác nhận thanh toán', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('${cart.itemCount} sản phẩm', style: TextStyle(fontSize: 14, color: c.textSecondary)),
            Text(_currFmt.format(cart.total), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary)),
          ]),
          const SizedBox(height: 24),
          Text('Phương thức thanh toán:', style: TextStyle(color: c.textSecondary, fontSize: 13)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: SizedBox(height: 52, child: OutlinedButton.icon(
              onPressed: () { Navigator.pop(ctx); _showCashConfirm(context); },
              icon: const Icon(Icons.money),
              label: const Text('Tiền mặt'),
            ))),
            const SizedBox(width: 12),
            Expanded(child: SizedBox(height: 52, child: ElevatedButton.icon(
              onPressed: () { Navigator.pop(ctx); _processPayment('BANK_TRANSFER'); },
              icon: const Icon(Icons.qr_code_2),
              label: const Text('Chuyển khoản'),
            ))),
          ]),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  void _showCashConfirm(BuildContext context) {
    final cart = ref.read(_cartProvider);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CashConfirmDialog(
        total: cart.total,
        onConfirm: () => _processPayment('CASH'),
      ),
    );
  }

  Future<void> _processPayment(String method) async {
    final cart = ref.read(_cartProvider);
    if (cart.items.isEmpty) return;

    setState(() => _creating = true);
    try {
      final orderCode = 'SO${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
      final items = cart.items.map((i) => {'productId': i.productId, 'quantity': i.quantity, 'unitPrice': i.price}).toList();

      final result = await ref.read(salesRepoProvider).create({
        'orderCode': orderCode,
        'items': items,
        'paymentMethod': method,
        'status': method == 'CASH' ? 'PAID' : 'PENDING',
        'paidAmount': method == 'CASH' ? cart.total : 0,
      });

      final orderId = result['id'] as int;

      if (method == 'CASH') {
        // Cash payment — done immediately
        ref.read(_cartProvider.notifier).clear();
        await _tts.setLanguage('vi-VN');
        await _tts.setSpeechRate(0.45);
        await _tts.speak('Thanh toán tiền mặt thành công');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Thanh toán tiền mặt thành công!'), backgroundColor: AppColors.success));
        }
      } else {
        // Bank transfer — navigate to QR screen
        final shop = await ref.read(shopProfileProvider.future);
        final bankId = shop['bankId'] ?? '';
        final accountNo = shop['bankAccount'] ?? '';
        final accountName = shop['accountHolder'] ?? '';

        if (bankId.isEmpty || accountNo.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('⚠ Chưa cấu hình ngân hàng!\nVào Cài đặt → Phương thức TT để thiết lập.'),
              backgroundColor: AppColors.warning,
              duration: Duration(seconds: 4),
            ));
          }
          return;
        }

        if (mounted) {
          final paid = await Navigator.of(context).push<bool>(MaterialPageRoute(
            builder: (_) => QrPaymentScreen(orderId: orderId, orderCode: orderCode, totalAmount: cart.total, bankId: bankId, accountNo: accountNo, accountName: accountName),
          ));
          if (paid == true) ref.read(_cartProvider.notifier).clear();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppColors.danger));
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }
}

// ── Cash Confirm Dialog with 5s countdown ──
class _CashConfirmDialog extends StatefulWidget {
  final double total;
  final VoidCallback onConfirm;
  const _CashConfirmDialog({required this.total, required this.onConfirm});
  @override
  State<_CashConfirmDialog> createState() => _CashConfirmDialogState();
}

class _CashConfirmDialogState extends State<_CashConfirmDialog> {
  int _seconds = 5;
  late final _timer = Stream.periodic(const Duration(seconds: 1), (i) => 4 - i).take(5).listen((s) {
    if (mounted) setState(() => _seconds = s);
  });

  @override
  void dispose() { _timer.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final done = _seconds <= 0;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(children: [
        Icon(Icons.money, color: AppColors.success),
        const SizedBox(width: 8),
        const Text('Xác nhận tiền mặt'),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Đã nhận đủ tiền mặt?', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
        const SizedBox(height: 16),
        Text(_currFmt.format(widget.total), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primary)),
        const SizedBox(height: 20),
        if (!done)
          SizedBox(
            width: 56, height: 56,
            child: Stack(alignment: Alignment.center, children: [
              CircularProgressIndicator(value: _seconds / 5, strokeWidth: 4, color: AppColors.primary, backgroundColor: Colors.grey.shade200),
              Text('$_seconds', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ]),
          ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        ElevatedButton(
          onPressed: done ? () { Navigator.pop(context); widget.onConfirm(); } : null,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
          child: Text(done ? '✅ Xác nhận' : 'Chờ ${_seconds}s...'),
        ),
      ],
    );
  }
}
