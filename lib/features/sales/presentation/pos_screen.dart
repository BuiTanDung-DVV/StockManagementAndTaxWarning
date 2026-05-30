import '../../../core/guides/feature_guide_sheet.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/type_parser.dart';
import '../../../core/widgets/app_animations.dart';
import '../../customers/providers/customer_provider.dart';
import '../../products/providers/product_provider.dart';
import '../../settings/providers/system_provider.dart';
import '../../inventory/providers/inventory_provider.dart';
import '../../finance/providers/finance_provider.dart';
import '../providers/sales_provider.dart';
import 'qr_payment_screen.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/widgets/app_confirm_modal.dart';
import '../../../core/utils/toast_service.dart';

final _currFmt = NumberFormat.currency(
  locale: 'vi_VN',
  symbol: '₫',
  decimalDigits: 0,
);
final _tts = FlutterTts();



/// Cart item model
class CartItem {
  final int productId;
  final String name;
  final double price;
  final int quantity;
  const CartItem({
    required this.productId,
    required this.name,
    required this.price,
    this.quantity = 1,
  });
  double get subtotal => price * quantity;
  CartItem copyWith({int? quantity}) => CartItem(
    productId: productId,
    name: name,
    price: price,
    quantity: quantity ?? this.quantity,
  );
}

/// Cart state
class CartState {
  final List<CartItem> items;
  final int? customerId;
  final String? customerName;

  const CartState({
    this.items = const [],
    this.customerId,
    this.customerName,
  });

  double get total => items.fold(0.0, (sum, i) => sum + i.subtotal);
  int get itemCount => items.fold(0, (sum, i) => sum + i.quantity);

  CartState copyWith({
    List<CartItem>? items,
    int? customerId,
    String? customerName,
    bool clearCustomer = false,
  }) {
    return CartState(
      items: items ?? this.items,
      customerId: clearCustomer ? null : (customerId ?? this.customerId),
      customerName: clearCustomer ? null : (customerName ?? this.customerName),
    );
  }
}

/// Cart notifier (Riverpod v3 Notifier pattern)
class CartNotifier extends Notifier<CartState> {
  @override
  CartState build() => const CartState();

  void add(int productId, String name, double price) {
    final existing = state.items
        .where((i) => i.productId == productId)
        .firstOrNull;
    if (existing != null) {
      state = state.copyWith(
        items: state.items
            .map(
              (i) => i.productId == productId
                  ? i.copyWith(quantity: i.quantity + 1)
                  : i,
            )
            .toList(),
      );
    } else {
      state = state.copyWith(
        items: [
          ...state.items,
          CartItem(productId: productId, name: name, price: price),
        ]
      );
    }
  }

  void increment(int productId) {
    state = state.copyWith(
      items: state.items
          .map(
            (i) => i.productId == productId
                ? i.copyWith(quantity: i.quantity + 1)
                : i,
          )
          .toList(),
    );
  }

  void decrement(int productId) {
    final item = state.items.firstWhere((i) => i.productId == productId);
    if (item.quantity > 1) {
      state = state.copyWith(
        items: state.items
            .map(
              (i) => i.productId == productId
                  ? i.copyWith(quantity: i.quantity - 1)
                  : i,
            )
            .toList(),
      );
    } else {
      state = state.copyWith(
        items: state.items.where((i) => i.productId != productId).toList(),
      );
    }
  }

  void remove(int productId) {
    state = state.copyWith(
      items: state.items.where((i) => i.productId != productId).toList(),
    );
  }

  void clear() => state = const CartState();

  void setCustomer(int? id, String? name) {
    state = state.copyWith(
      customerId: id,
      customerName: name,
      clearCustomer: id == null,
    );
  }
}

final _cartProvider = NotifierProvider<CartNotifier, CartState>(
  CartNotifier.new,
);

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
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final cart = ref.watch(_cartProvider);
    final productsAsync = ref.watch(
      productListProvider((page: 1, search: _search.isEmpty ? null : _search)),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bán hàng'),
        actions: [
          featureGuideButton(context, 'pos'),
          if (cart.items.isNotEmpty)
            Badge(
              label: Text('${cart.itemCount}'),
              child: IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: () => _showCart(context),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Tìm sản phẩm...',
                prefixIcon: Icon(Icons.search, color: c.textMuted),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, size: 18, color: c.textSecondary),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _search = '');
                        },
                      )
                    : null,
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
                  return AppEmpty(
                    message: _search.isEmpty
                        ? 'Chưa có sản phẩm'
                        : 'Không tìm thấy "$_search"',
                    subtitle: _search.isEmpty
                        ? 'Thêm sản phẩm để bắt đầu bán hàng'
                        : null,
                    action: _search.isEmpty
                        ? ElevatedButton.icon(
                            onPressed: () => context.push('/products/form'),
                            icon: const Icon(Icons.inventory_2),
                            label: const Text('Thêm sản phẩm'),
                          )
                        : null,
                  );
                }
                return ListView.builder(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    bottom: cart.items.isNotEmpty ? 120 : 24,
                    top: 8,
                  ),
                  itemCount: products.length,
                  itemBuilder: (_, i) {
                    final p = products[i];
                    final id = p['id'] as int;
                    final name = p['name'] ?? 'SP';
                    final price = TypeParser.asDouble(
                      p['sellingPrice'] ?? p['selling_price'] ?? 0,
                    );
                    final stock =
                        p['currentStock'] ?? p['stockQuantity'] ?? p['stock_quantity'] ?? '—';
                    final cartItem = cart.items
                        .where((ci) => ci.productId == id)
                        .firstOrNull;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: c.card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: c.divider.withValues(alpha: 0.3),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.015),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(
                              child: HugeIcon(
                                icon: HugeIcons.strokeRoundedPackage,
                                color: AppColors.primary,
                                size: 24,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      _currFmt.format(price),
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: c.surface,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Kho: $stock',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: c.textSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (cartItem != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _qtyButton(
                                  Icons.remove,
                                  () => ref
                                      .read(_cartProvider.notifier)
                                      .decrement(id),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  child: Text(
                                    '${cartItem.quantity}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                _qtyButton(
                                  Icons.add,
                                  () => ref
                                      .read(_cartProvider.notifier)
                                      .increment(id),
                                ),
                              ],
                            )
                          else
                            SizedBox(
                              width: 44,
                              height: 44,
                              child: IconButton(
                                onPressed: () {
                                  ref
                                      .read(_cartProvider.notifier)
                                      .add(id, name, price);
                                  HapticFeedback.lightImpact();
                                },
                                icon: Icon(
                                  Icons.add_shopping_cart,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                                style: IconButton.styleFrom(
                                  backgroundColor: AppColors.primary.withValues(
                                    alpha: 0.08,
                                  ),
                                  shape: const CircleBorder(),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  'Lỗi: $e',
                  style: TextStyle(color: AppColors.danger),
                ),
              ),
            ),
          ),

          // Bottom bar
          if (cart.items.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: c.card.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: c.divider.withValues(alpha: 0.5)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${cart.itemCount} sản phẩm',
                            style: TextStyle(
                              fontSize: 12,
                              color: c.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _currFmt.format(cart.total),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _creating
                          ? null
                          : () => _showCheckout(context),
                      icon: const Icon(Icons.payment, size: 18),
                      label: const Text('Thanh toán'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: 36,
      height: 36,
      child: IconButton(
        onPressed: () {
          onTap();
          HapticFeedback.lightImpact();
        },
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
    showModalBottomSheet(useSafeArea: true,
      context: context,
      backgroundColor: c.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Consumer(
        builder: (ctx, ref, _) {
          final cart = ref.watch(_cartProvider);
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.5,
            maxChildSize: 0.85,
            builder: (_, scrollCtrl) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Giỏ hàng (${cart.itemCount})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final confirm = await AppConfirmModal.show(
                            context,
                            title: 'Xóa giỏ hàng',
                            message: 'Bạn có chắc chắn muốn xóa toàn bộ sản phẩm trong giỏ?',
                            confirmText: 'Xóa tất cả',
                            cancelText: 'Hủy',
                            isDestructive: true,
                          );
                          if (confirm == true) {
                            ref.read(_cartProvider.notifier).clear();
                            ToastService.showSuccess('Đã xóa toàn bộ giỏ hàng');
                            if (ctx.mounted) Navigator.pop(ctx);
                          }
                        },
                        child: const Text(
                          'Xóa tất cả',
                          style: TextStyle(color: AppColors.danger),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollCtrl,
                    itemCount: cart.items.length,
                    itemBuilder: (_, i) {
                      final item = cart.items[i];
                      return ListTile(
                        title: Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${_currFmt.format(item.price)} × ${item.quantity} = ${_currFmt.format(item.subtotal)}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: AppColors.danger,
                          ),
                          onPressed: () async {
                            final confirm = await AppConfirmModal.show(
                              context,
                              title: 'Xóa sản phẩm',
                              message: 'Xóa ${item.name} khỏi giỏ hàng?',
                              confirmText: 'Xóa',
                              cancelText: 'Hủy',
                              isDestructive: true,
                            );
                            if (confirm == true) {
                              ref
                                  .read(_cartProvider.notifier)
                                  .remove(item.productId);
                              ToastService.showSuccess('Đã xóa ${item.name} khỏi giỏ hàng');
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Tổng:', style: TextStyle(fontSize: 16)),
                      Text(
                        _currFmt.format(cart.total),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showCheckout(BuildContext context) {
    final c = AppThemeColors.of(context);
    final cart = ref.read(_cartProvider);
    showModalBottomSheet(useSafeArea: true,
      context: context,
      backgroundColor: c.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final cart = ref.watch(_cartProvider);
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.9),
              child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              Text(
                'Xác nhận thanh toán',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${cart.itemCount} sản phẩm',
                    style: TextStyle(fontSize: 14, color: c.textSecondary),
                  ),
                  Text(
                    _currFmt.format(cart.total),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Phương thức thanh toán:',
                style: TextStyle(color: c.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showCashConfirm(context);
                        },
                        icon: const Icon(Icons.money),
                        label: const Text('Tiền mặt'),
                        style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _processPayment('BANK_TRANSFER');
                        },
                        icon: const Icon(Icons.qr_code_2),
                        label: const Text('Chuyển khoản'),
                        style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (cart.customerId == null) {
                            ToastService.showError('Vui lòng chọn khách hàng để thực hiện bán nợ');
                            return;
                          }
                          Navigator.pop(ctx);
                          _processPayment('DEBT');
                        },
                        icon: const Icon(Icons.credit_score),
                        label: const Text('Ghi nợ'),
                        style: ElevatedButton.styleFrom(padding: EdgeInsets.zero),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _showCustomerPicker(context),
                icon: const Icon(Icons.person_search),
                label: Text(
                  cart.customerName == null
                      ? 'Chọn khách hàng (mua chịu)'
                      : 'Khách: ${cart.customerName}',
                ),
              ),
              if (cart.customerName != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      ref.read(_cartProvider.notifier).setCustomer(null, null);
                    },
                    child: const Text('Bỏ chọn khách'),
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      ),
      ),
      );
      },
      ),
    );
  }

  void _showCustomerPicker(BuildContext context) {
    showModalBottomSheet(useSafeArea: true,
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final customersAsync = ref.watch(
            customerListProvider((page: 1, search: null)),
          );
          return customersAsync.when(
            loading: () => const SizedBox(
              height: 220,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SizedBox(
              height: 220,
              child: Center(child: Text('Lỗi tải khách hàng: $e')),
            ),
            data: (data) {
              final customers = (data['items'] as List?) ?? [];
              return SizedBox(
                height: 360,
                child: Column(
                  children: [
                    // Add new customer button
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showQuickAddCustomer(context);
                          },
                          icon: const Icon(Icons.person_add_alt_1),
                          label: const Text('+ Thêm khách hàng mới'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: BorderSide(color: AppColors.primary),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    if (customers.isEmpty)
                      const Expanded(
                        child: Center(
                          child: Text('Chưa có khách hàng. Hãy thêm mới!'),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.builder(
                          itemCount: customers.length,
                          itemBuilder: (_, i) {
                            final c = customers[i];
                            return ListTile(
                              title: Text(
                                c['name']?.toString() ?? 'Khách hàng',
                              ),
                              subtitle: Text(c['phone']?.toString() ?? ''),
                              onTap: () {
                                final newId = TypeParser.asInt(c['id']);
                                final newName = c['name']?.toString() ?? 'Khách hàng';
                                ref.read(_cartProvider.notifier).setCustomer(newId == 0 ? null : newId, newName);
                                Navigator.pop(ctx);
                                if (newId != 0) {
                                  ToastService.showSuccess('Đã chọn khách hàng: $newName');
                                }
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showQuickAddCustomer(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Thêm khách hàng nhanh'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Tên khách hàng *',
                prefixIcon: const Icon(Icons.person),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Vui lòng nhập tên khách hàng'),
                    ),
                  );
                  return;
                }
                try {
                  final result = await ref.read(customerRepoProvider).create({
                    'name': name,
                    if (phoneCtrl.text.trim().isNotEmpty)
                      'phone': phoneCtrl.text.trim(),
                  });
                  final newId = TypeParser.asInt(result['id']);
                  ref.read(_cartProvider.notifier).setCustomer(newId == 0 ? null : newId, name);
                  ref.invalidate(customerListProvider);
                  if (context.mounted) {
                    Navigator.pop(ctx);
                    if (newId != 0) {
                      ToastService.showSuccess('Đã chọn khách hàng: $name');
                    }
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đã thêm khách hàng thành công'),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
                  }
                }
              },
              decoration: InputDecoration(
                labelText: 'Số điện thoại',
                prefixIcon: const Icon(Icons.phone),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Vui lòng nhập tên khách hàng')),
                );
                return;
              }
              try {
                final result = await ref.read(customerRepoProvider).create({
                  'name': name,
                  if (phoneCtrl.text.trim().isNotEmpty)
                    'phone': phoneCtrl.text.trim(),
                });
                final newId = int.tryParse(result['id'].toString());
                ref.read(_cartProvider.notifier).setCustomer(newId, name);
                ref.invalidate(customerListProvider);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text('Đã thêm khách hàng: $name'),
                        ],
                      ),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Lỗi: $e'),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                }
              }
            },
            child: const Text('Thêm'),
          ),
        ],
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
      final orderCode =
          'SO${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
      final items = cart.items
          .map(
            (i) => {
              'productId': i.productId,
              'quantity': i.quantity,
              'unitPrice': i.price,
            },
          )
          .toList();

      final result = await ref.read(salesRepoProvider).create({
        'orderCode': orderCode,
        'items': items,
        if (cart.customerId != null) 'customerId': cart.customerId,
        'paymentMethod': method,
        'status': method == 'CASH' ? 'DELIVERED' : 'PENDING',
        'paidAmount': method == 'CASH' ? cart.total : 0,
      });

      final orderId = result['id'] as int;

      if (method == 'CASH' || method == 'DEBT') {
        // Cash or Debt payment — done immediately
        ref.read(_cartProvider.notifier).clear();

        // Trigger UI updates across the app (Inventory, Finance, Sales Summary, Sales List)
        ref.invalidate(salesListProvider);
        ref.invalidate(salesSummaryProvider);
        ref.invalidate(productListProvider);
        ref.invalidate(lowStockProvider);
        ref.invalidate(taxObligationsProvider);
        ref.invalidate(customerListProvider); // to update customer debt

        await _tts.setLanguage('vi-VN');
        await _tts.setSpeechRate(0.45);
        
        final msg = method == 'CASH' ? 'Thanh toán tiền mặt thành công' : 'Đã ghi nợ thành công';
        await _tts.speak(msg);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(method == 'CASH' ? 'Thanh toán tiền mặt thành công!' : 'Tạo đơn hàng ghi nợ thành công!'),
                ],
              ),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else if (method == 'BANK_TRANSFER') {
        // Bank transfer — navigate to QR screen
        final shop = await ref.read(shopProfileProvider.future);
        final bankId = (shop['bankId'] ?? '').toString();
        final accountNo = (shop['bankAccount'] ?? '').toString();
        final accountName = (shop['accountHolder'] ?? '').toString();

        if (bankId.isEmpty || accountNo.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Chưa cấu hình ngân hàng!\nVào Cài đặt → Phương thức TT để thiết lập.',
                      ),
                    ),
                  ],
                ),
                backgroundColor: AppColors.warning,
                duration: Duration(seconds: 4),
              ),
            );
          }
          return;
        }

        if (mounted) {
          final paid = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => QrPaymentScreen(
                orderId: orderId,
                orderCode: orderCode,
                totalAmount: cart.total,
                bankId: bankId,
                accountNo: accountNo,
                accountName: accountName,
              ),
            ),
          );
          if (paid == true) {
            ref.read(_cartProvider.notifier).clear();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppColors.danger),
        );
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
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.money, color: AppColors.success),
          const SizedBox(width: 8),
          const Text('Xác nhận tiền mặt'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Đã nhận đủ tiền mặt?',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          Text(
            _currFmt.format(widget.total),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            widget.onConfirm();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check, size: 18),
              SizedBox(width: 6),
              Text('Xác nhận'),
            ],
          ),
        ),
      ],
    );
  }
}

