import '../../../core/guides/feature_guide_sheet.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/assets/app_assets.dart';
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
import '../../../core/widgets/app_confirm_modal.dart';
import '../../../core/utils/toast_service.dart';
import '../../../core/widgets/app_badge.dart';

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
  final int? availableStock;

  const CartItem({
    required this.productId,
    required this.name,
    required this.price,
    this.quantity = 1,
    this.availableStock,
  });

  double get subtotal => price * quantity;

  CartItem copyWith({int? quantity, int? availableStock}) => CartItem(
    productId: productId,
    name: name,
    price: price,
    quantity: quantity ?? this.quantity,
    availableStock: availableStock ?? this.availableStock,
  );
}

int? availableStockOf(Map<String, dynamic> product) {
  final raw =
      product['currentStock'] ??
      product['stockQuantity'] ??
      product['stock_quantity'];
  if (raw is num) return raw.floor();
  if (raw is String) return double.tryParse(raw)?.floor();
  return null;
}

bool canIncreaseQuantity({
  required int currentQuantity,
  required int? availableStock,
}) {
  return availableStock == null || currentQuantity < availableStock;
}

/// Cart state
class CartState {
  final List<CartItem> items;
  final int? customerId;
  final String? customerName;
  final double discountAmount;
  final String? notes;

  const CartState({
    this.items = const [],
    this.customerId,
    this.customerName,
    this.discountAmount = 0.0,
    this.notes,
  });

  double get total =>
      (items.fold<double>(0.0, (sum, i) => sum + i.subtotal) - discountAmount)
          .clamp(0.0, double.infinity);
  int get itemCount => items.fold(0, (sum, i) => sum + i.quantity);

  CartState copyWith({
    List<CartItem>? items,
    int? customerId,
    String? customerName,
    double? discountAmount,
    String? notes,
    bool clearCustomer = false,
    bool clearDiscount = false,
    bool clearNotes = false,
  }) {
    return CartState(
      items: items ?? this.items,
      customerId: clearCustomer ? null : (customerId ?? this.customerId),
      customerName: clearCustomer ? null : (customerName ?? this.customerName),
      discountAmount: clearDiscount
          ? 0.0
          : (discountAmount ?? this.discountAmount),
      notes: clearNotes ? null : (notes ?? this.notes),
    );
  }
}

/// Cart notifier (Riverpod v3 Notifier pattern)
class CartNotifier extends Notifier<CartState> {
  SharedPreferences? _prefs;

  @override
  CartState build() {
    _loadFromPrefs();
    return const CartState();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _prefs = prefs;
      final jsonStr = prefs.getString('pos_cart_state');
      if (jsonStr != null) {
        final Map<String, dynamic> data = json.decode(jsonStr);
        final List<dynamic> itemsJson = data['items'] ?? [];
        final items = itemsJson
            .map(
              (e) => CartItem(
                productId: e['productId'],
                name: e['name'],
                price: (e['price'] as num).toDouble(),
                quantity: e['quantity'],
                availableStock: e['availableStock'] as int?,
              ),
            )
            .toList();
        state = CartState(
          items: items,
          customerId: data['customerId'],
          customerName: data['customerName'],
          discountAmount: (data['discountAmount'] as num?)?.toDouble() ?? 0.0,
          notes: data['notes'] as String?,
        );
      }
    } catch (e) {
      debugPrint('Error loading cart: $e');
    }
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      _prefs = prefs;
      final data = {
        'customerId': state.customerId,
        'customerName': state.customerName,
        'discountAmount': state.discountAmount,
        'notes': state.notes,
        'items': state.items
            .map(
              (e) => {
                'productId': e.productId,
                'name': e.name,
                'price': e.price,
                'quantity': e.quantity,
                'availableStock': e.availableStock,
              },
            )
            .toList(),
      };
      await prefs.setString('pos_cart_state', json.encode(data));
    } catch (e) {
      debugPrint('Error saving cart: $e');
    }
  }

  bool add(int productId, String name, double price, {int? availableStock}) {
    final existing = state.items
        .where((i) => i.productId == productId)
        .firstOrNull;
    if (existing != null) {
      final stockLimit = availableStock ?? existing.availableStock;
      if (!canIncreaseQuantity(
        currentQuantity: existing.quantity,
        availableStock: stockLimit,
      )) {
        return false;
      }
      state = state.copyWith(
        items: state.items
            .map(
              (i) => i.productId == productId
                  ? i.copyWith(
                      quantity: i.quantity + 1,
                      availableStock: stockLimit,
                    )
                  : i,
            )
            .toList(),
      );
    } else {
      if (!canIncreaseQuantity(
        currentQuantity: 0,
        availableStock: availableStock,
      )) {
        return false;
      }
      state = state.copyWith(
        items: [
          ...state.items,
          CartItem(
            productId: productId,
            name: name,
            price: price,
            availableStock: availableStock,
          ),
        ],
      );
    }
    _saveToPrefs();
    return true;
  }

  bool increment(int productId, {int? availableStock}) {
    final item = state.items.firstWhere((i) => i.productId == productId);
    final stockLimit = availableStock ?? item.availableStock;
    if (!canIncreaseQuantity(
      currentQuantity: item.quantity,
      availableStock: stockLimit,
    )) {
      return false;
    }
    state = state.copyWith(
      items: state.items
          .map(
            (i) => i.productId == productId
                ? i.copyWith(
                    quantity: i.quantity + 1,
                    availableStock: stockLimit,
                  )
                : i,
          )
          .toList(),
    );
    _saveToPrefs();
    return true;
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
    _saveToPrefs();
  }

  void remove(int productId) {
    state = state.copyWith(
      items: state.items.where((i) => i.productId != productId).toList(),
    );
    _saveToPrefs();
  }

  void clear() {
    state = const CartState();
    _saveToPrefs();
  }

  void setCustomer(int? id, String? name) {
    state = state.copyWith(
      customerId: id,
      customerName: name,
      clearCustomer: id == null,
    );
    _saveToPrefs();
  }

  void setDiscount(double discount) {
    state = state.copyWith(
      discountAmount: discount,
      clearDiscount: discount <= 0,
    );
    _saveToPrefs();
  }

  void setNotes(String? notes) {
    state = state.copyWith(
      notes: notes,
      clearNotes: notes == null || notes.isEmpty,
    );
    _saveToPrefs();
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
  String _tag = '';
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
      productListProvider((
        page: 1,
        search: _search.isEmpty ? null : _search,
        tag: _tag.isEmpty ? null : _tag,
      )),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bán hàng'),
        actions: [
          featureGuideButton(context, 'pos'),
          if (cart.items.isNotEmpty)
            TextButton(
              onPressed: () => _showCart(context),
              child: Text('Giỏ (${cart.itemCount})'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isLargeScreen = constraints.maxWidth > 900;
          if (isLargeScreen) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 65,
                  child: _buildProductCatalog(
                    context,
                    true,
                    c,
                    cart,
                    productsAsync,
                  ),
                ),
                VerticalDivider(width: 1, color: c.divider),
                Expanded(
                  flex: 35,
                  child: Container(
                    color: c.surface,
                    child: _buildRightCartPanel(context),
                  ),
                ),
              ],
            );
          } else {
            return Column(
              children: [
                Expanded(
                  child: _buildProductCatalog(
                    context,
                    false,
                    c,
                    cart,
                    productsAsync,
                  ),
                ),
                if (cart.items.isNotEmpty)
                  Container(
                    // MainShell now reserves space for mobile navigation.
                    margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: c.card,
                      border: Border.all(color: c.divider),
                      borderRadius: BorderRadius.circular(AppRadius.card),
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
                                  cart.customerName != null
                                      ? '${cart.itemCount} sp • Khách: ${cart.customerName}'
                                      : '${cart.itemCount} sản phẩm',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: cart.customerName != null
                                        ? AppColors.info
                                        : c.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    _currFmt.format(cart.total),
                                    maxLines: 1,
                                    style: GoogleFonts.inter(
                                      fontSize: 23,
                                      fontWeight: FontWeight.w800,
                                      color: c.textPrimary,
                                      letterSpacing: -0.6,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: _creating
                                ? null
                                : () => _showCheckout(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: c.textPrimary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 18,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.control,
                                ),
                              ),
                            ),
                            child: Text(
                              'Thanh toán',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildProductCatalog(
    BuildContext context,
    bool isLargeScreen,
    AppThemeColors c,
    CartState cart,
    AsyncValue<Map<String, dynamic>> productsAsync,
  ) {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Tìm sản phẩm...',
              suffixIcon: _search.isNotEmpty
                  ? TextButton(
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _search = '');
                      },
                      child: const Text('Xóa'),
                    )
                  : null,
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
        ),

        // Tag Filter Bar
        Consumer(
          builder: (ctx, r, child) {
            final tagsAsync = r.watch(availableTagsProvider);
            return tagsAsync.when(
              data: (tags) {
                final visibleTags = tags
                    .where((tag) => !_isInternalTag(tag.name))
                    .toList();
                if (visibleTags.isEmpty) return const SizedBox.shrink();
                return SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: visibleTags.length,
                    itemBuilder: (ctx, i) {
                      final t = visibleTags[i];
                      final isSelected = _tag == t.name;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Semantics(
                          button: true,
                          label: isSelected
                              ? 'Bỏ lọc nhãn ${t.name}'
                              : 'Lọc theo nhãn ${t.name}',
                          selected: isSelected,
                          child: ChoiceChip(
                            label: Text(
                              t.name,
                              style: TextStyle(
                                fontSize: 12,
                                color: isSelected ? Colors.white : t.uiColor,
                              ),
                            ),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() => _tag = selected ? t.name : '');
                            },
                            selectedColor: t.uiColor,
                            backgroundColor: t.uiColor.withValues(alpha: 0.1),
                            side: BorderSide(
                              color: t.uiColor.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            );
          },
        ),
        const SizedBox(height: 8),

        // Product list
        Expanded(
          child: productsAsync.when(
            data: (data) {
              final products = (data['items'] as List?) ?? [];

              // Barcode auto-add logic
              if (products.length == 1 && _search.isNotEmpty) {
                final singleProduct = products.first;
                final barcode = singleProduct['barcode']?.toString() ?? '';
                if (barcode == _search.trim()) {
                  final id = singleProduct['id'] as int;
                  final name = singleProduct['name'] ?? 'SP';
                  final price = TypeParser.asDouble(
                    singleProduct['sellingPrice'] ??
                        singleProduct['selling_price'] ??
                        0,
                  );
                  final availableStock = availableStockOf(singleProduct);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    final added = ref
                        .read(_cartProvider.notifier)
                        .add(id, name, price, availableStock: availableStock);
                    _searchCtrl.clear();
                    setState(() => _search = '');
                    if (added) {
                      HapticFeedback.vibrate();
                      _tts.speak('Đã thêm $name');
                    } else {
                      ToastService.showError(
                        availableStock != null && availableStock <= 0
                            ? '$name đã hết hàng'
                            : '$name đã đạt số lượng tồn khả dụng',
                      );
                    }
                  });
                }
              }

              if (products.isEmpty) {
                return AppEmpty(
                  visual: AppEmptyVisual.inventory,
                  message: _search.isEmpty
                      ? 'Chưa có sản phẩm'
                      : 'Không tìm thấy "$_search"',
                  subtitle: _search.isEmpty
                      ? 'Thêm sản phẩm để bắt đầu bán hàng'
                      : null,
                  action: _search.isEmpty
                      ? FilledButton(
                          onPressed: () => context.push('/products/form'),
                          child: const Text('Thêm sản phẩm'),
                        )
                      : null,
                );
              }
              return ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(
                  bottom: (cart.items.isNotEmpty && !isLargeScreen) ? 140 : 88,
                ),
                itemCount: products.length,
                separatorBuilder: (_, _) =>
                    Divider(height: 1, color: c.divider.withValues(alpha: 0.5)),
                itemBuilder: (_, i) {
                  final p = products[i];
                  final id = p['id'] as int;
                  final name = p['name']?.toString() ?? 'SP';
                  final price = TypeParser.asDouble(
                    p['sellingPrice'] ?? p['selling_price'] ?? 0,
                  );
                  final availableStock = availableStockOf(p);
                  final stockLabel = availableStock == null
                      ? 'Chưa rõ tồn'
                      : availableStock <= 0
                      ? 'Hết hàng'
                      : 'Kho: $availableStock';
                  final isOutOfStock =
                      availableStock != null && availableStock <= 0;
                  final cartItem = cart.items
                      .where((ci) => ci.productId == id)
                      .firstOrNull;
                  final reachedAvailableStock =
                      cartItem != null &&
                      !canIncreaseQuantity(
                        currentQuantity: cartItem.quantity,
                        availableStock: availableStock,
                      );

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: const BoxDecoration(color: Colors.transparent),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: c.cardAlt,
                            borderRadius: BorderRadius.circular(
                              AppRadius.control,
                            ),
                            border: Border.all(color: c.divider),
                          ),
                          child: Center(
                            child: AppAssetIcon(
                              assetPath: AppAssets.inventory,
                              color: AppColors.primary,
                              size: 24,
                              semanticLabel: 'Sản phẩm',
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
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    _currFmt.format(price),
                                    style: TextStyle(
                                      color: c.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  AppBadge(
                                    label: stockLabel,
                                    color: isOutOfStock
                                        ? AppColors.danger
                                        : availableStock == null
                                        ? AppColors.warning
                                        : AppColors.success,
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
                                reachedAvailableStock
                                    ? null
                                    : () => ref
                                          .read(_cartProvider.notifier)
                                          .increment(
                                            id,
                                            availableStock: availableStock,
                                          ),
                                tooltip: reachedAvailableStock
                                    ? 'Đã đạt tồn khả dụng'
                                    : 'Tăng số lượng',
                              ),
                            ],
                          )
                        else
                          SizedBox(
                            width: 76,
                            height: 40,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                              ),
                              onPressed: isOutOfStock
                                  ? null
                                  : () {
                                      final added = ref
                                          .read(_cartProvider.notifier)
                                          .add(
                                            id,
                                            name,
                                            price,
                                            availableStock: availableStock,
                                          );
                                      if (added) {
                                        HapticFeedback.lightImpact();
                                      }
                                    },
                              child: const Text('Thêm', maxLines: 1),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
            loading: () =>
                const AppLoading(message: 'Đang tải danh sách sản phẩm…'),
            error: (_, _) => AppError(
              message: 'Không thể tải danh sách sản phẩm.',
              onRetry: () => ref.invalidate(productListProvider),
            ),
          ),
        ),
      ],
    );
  }

  bool _isInternalTag(String tag) =>
      tag.trim().toLowerCase().startsWith('sim_tag_');

  Widget _buildRightCartPanel(BuildContext context) {
    final c = AppThemeColors.of(context);
    final cart = ref.watch(_cartProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Cart Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Giỏ hàng (${cart.itemCount})',
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: c.textPrimary,
                ),
              ),
              if (cart.items.isNotEmpty)
                TextButton(
                  onPressed: () {
                    ref.read(_cartProvider.notifier).clear();
                    ToastService.showSuccess('Đã xóa toàn bộ giỏ hàng');
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger,
                  ),
                  child: const Text('Xóa giỏ'),
                ),
            ],
          ),
        ),
        Divider(height: 1, color: c.divider),

        // Cart items list or Empty state
        Expanded(
          child: cart.items.isEmpty
              ? const AppEmpty(
                  visual: AppEmptyVisual.sales,
                  message: 'Giỏ hàng đang trống',
                  subtitle: 'Chọn sản phẩm từ danh sách để bắt đầu đơn hàng.',
                  size: 64,
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: cart.items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) {
                    final item = cart.items[i];
                    return Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_currFmt.format(item.price)} × ${item.quantity}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: c.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _qtyButton(
                              Icons.remove,
                              () => ref
                                  .read(_cartProvider.notifier)
                                  .decrement(item.productId),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: Text(
                                '${item.quantity}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            _qtyButton(
                              Icons.add,
                              canIncreaseQuantity(
                                    currentQuantity: item.quantity,
                                    availableStock: item.availableStock,
                                  )
                                  ? () => ref
                                        .read(_cartProvider.notifier)
                                        .increment(item.productId)
                                  : null,
                              tooltip:
                                  canIncreaseQuantity(
                                    currentQuantity: item.quantity,
                                    availableStock: item.availableStock,
                                  )
                                  ? 'Tăng số lượng'
                                  : 'Đã đạt tồn khả dụng',
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
        ),
        Divider(height: 1, color: c.divider),

        // Customer selection section
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Khách hàng:',
                    style: TextStyle(fontSize: 12, color: c.textSecondary),
                  ),
                  if (cart.customerName != null)
                    TextButton(
                      onPressed: () {
                        ref
                            .read(_cartProvider.notifier)
                            .setCustomer(null, null);
                      },
                      child: Text(
                        'Hủy',
                        style: TextStyle(color: AppColors.danger, fontSize: 12),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              OutlinedButton(
                onPressed: () => _showCustomerPicker(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 12,
                  ),
                  alignment: Alignment.centerLeft,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  cart.customerName ?? 'Chọn khách hàng...',
                  style: TextStyle(
                    fontSize: 13,
                    color: cart.customerName == null
                        ? c.textSecondary
                        : c.textPrimary,
                    fontWeight: cart.customerName == null
                        ? FontWeight.normal
                        : FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Discount & Notes Section
        if (cart.items.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Chiết khấu:',
                      style: TextStyle(fontSize: 13, color: c.textSecondary),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => _showDiscountDialog(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    cart.discountAmount > 0
                        ? '-${_currFmt.format(cart.discountAmount)}'
                        : 'Thêm...',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: cart.discountAmount > 0
                          ? AppColors.danger
                          : AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Ghi chú đơn:',
                      style: TextStyle(fontSize: 13, color: c.textSecondary),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => _showNotesDialog(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    cart.notes != null && cart.notes!.isNotEmpty
                        ? 'Xem/Sửa'
                        : 'Thêm...',
                    style: TextStyle(
                      fontSize: 13,
                      color: cart.notes != null && cart.notes!.isNotEmpty
                          ? AppColors.primary
                          : c.textSecondary,
                      fontWeight: cart.notes != null && cart.notes!.isNotEmpty
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],

        // Bottom payment section
        Container(
          padding: const EdgeInsets.all(16),
          color: c.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tổng thanh toán:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    _currFmt.format(cart.total),
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: c.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: cart.items.isEmpty || _creating
                    ? null
                    : () => _showCheckout(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'XÁC NHẬN THANH TOÁN',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback? onTap, {String? tooltip}) {
    final enabled = onTap != null;
    return SizedBox(
      width: 44,
      height: 44,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap == null
            ? null
            : () {
                onTap();
                HapticFeedback.lightImpact();
              },
        icon: Icon(
          icon,
          size: 20,
          color: enabled
              ? AppColors.primary
              : AppThemeColors.of(context).textMuted,
        ),
        style: IconButton.styleFrom(
          backgroundColor: enabled
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppThemeColors.of(context).cardAlt,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        padding: EdgeInsets.zero,
      ),
    );
  }

  void _showCart(BuildContext context) {
    final c = AppThemeColors.of(context);
    showModalBottomSheet(
      useSafeArea: true,
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
                            message:
                                'Bạn có chắc chắn muốn xóa toàn bộ sản phẩm trong giỏ?',
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
                        trailing: TextButton(
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
                              ToastService.showSuccess(
                                'Đã xóa ${item.name} khỏi giỏ hàng',
                              );
                            }
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.danger,
                          ),
                          child: const Text('Xóa'),
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
    showModalBottomSheet(
      useSafeArea: true,
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
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.9,
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Xác nhận thanh toán',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${cart.itemCount} sản phẩm',
                              style: TextStyle(
                                fontSize: 14,
                                color: c.textSecondary,
                              ),
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
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              height: 48,
                              child: FilledButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _showCashConfirm(context);
                                },
                                child: const Text('Tiền mặt'),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 48,
                              child: OutlinedButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _processPayment('BANK_TRANSFER');
                                },
                                child: const Text('Chuyển khoản (QR)'),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 48,
                              child: OutlinedButton(
                                onPressed: () {
                                  if (cart.customerId == null) {
                                    ToastService.showError(
                                      'Vui lòng chọn khách hàng để thực hiện bán nợ',
                                    );
                                    return;
                                  }
                                  Navigator.pop(ctx);
                                  _processPayment('DEBT');
                                },
                                child: const Text('Ghi nợ'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: () => _showCustomerPicker(context),
                          child: Text(
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
                                ref
                                    .read(_cartProvider.notifier)
                                    .setCustomer(null, null);
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
    showModalBottomSheet(
      useSafeArea: true,
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
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showQuickAddCustomer(context);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: BorderSide(color: AppColors.primary),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Thêm khách hàng mới'),
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
                                final newName =
                                    c['name']?.toString() ?? 'Khách hàng';
                                ref
                                    .read(_cartProvider.notifier)
                                    .setCustomer(
                                      newId == 0 ? null : newId,
                                      newName,
                                    );
                                Navigator.pop(ctx);
                                if (newId != 0) {
                                  ToastService.showSuccess(
                                    'Đã chọn khách hàng: $newName',
                                  );
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
              decoration: const InputDecoration(labelText: 'Tên khách hàng *'),
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
                  ref
                      .read(_cartProvider.notifier)
                      .setCustomer(newId == 0 ? null : newId, name);
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
              decoration: const InputDecoration(labelText: 'Số điện thoại'),
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
                final newId = TypeParser.asInt(result['id']);
                ref
                    .read(_cartProvider.notifier)
                    .setCustomer(newId == 0 ? null : newId, name);
                ref.invalidate(customerListProvider);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Đã thêm khách hàng: $name'),
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

  void _showDiscountDialog(BuildContext context) {
    final cart = ref.read(_cartProvider);
    final ctrl = TextEditingController(
      text: cart.discountAmount > 0
          ? cart.discountAmount.toInt().toString()
          : '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Nhập chiết khấu (đ)'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Nhập số tiền giảm giá...',
            suffixText: 'đ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(ctrl.text) ?? 0.0;
              ref.read(_cartProvider.notifier).setDiscount(val);
              Navigator.pop(ctx);
            },
            child: const Text('Áp dụng'),
          ),
        ],
      ),
    );
  }

  void _showNotesDialog(BuildContext context) {
    final cart = ref.read(_cartProvider);
    final ctrl = TextEditingController(text: cart.notes ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Ghi chú đơn hàng'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Nhập ghi chú hoặc yêu cầu của khách...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(_cartProvider.notifier).setNotes(ctrl.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Lưu'),
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
        'discountAmount': cart.discountAmount,
        if (cart.notes != null) 'notes': cart.notes,
        'paymentMethod': method,
        'status': method == 'CASH' ? 'DELIVERED' : 'PENDING',
        'paidAmount': method == 'CASH' ? cart.total : 0,
      });

      final orderId = result['id'] as int;

      if (method == 'CASH' || method == 'DEBT') {
        // Cash or debt payment - done immediately.
        ref.read(_cartProvider.notifier).clear();

        // Trigger UI updates across the app (Inventory, Finance, Sales Summary, Sales List)
        ref.invalidate(salesListProvider);
        ref.invalidate(salesSummaryProvider);
        ref.invalidate(productListProvider);
        ref.invalidate(lowStockProvider);
        ref.invalidate(taxObligationsProvider);
        ref.invalidate(customerListProvider); // to update customer debt
        ref.invalidate(cashAccountsProvider);

        await _tts.setLanguage('vi-VN');
        await _tts.setSpeechRate(0.45);

        final msg = method == 'CASH'
            ? 'Thanh toán tiền mặt thành công'
            : 'Đã ghi nợ thành công';
        await _tts.speak(msg);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                method == 'CASH'
                    ? 'Thanh toán tiền mặt thành công!'
                    : 'Tạo đơn hàng ghi nợ thành công!',
              ),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else if (method == 'BANK_TRANSFER') {
        // Bank transfer - navigate to QR screen.
        final shop = await ref.read(shopProfileProvider.future);
        final bankId = (shop['bankId'] ?? '').toString();
        final accountNo = (shop['bankAccount'] ?? '').toString();
        final accountName = (shop['accountHolder'] ?? '').toString();

        if (bankId.isEmpty || accountNo.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Chưa cấu hình ngân hàng. Vào Cài đặt, chọn VietQR và tài khoản nhận tiền để thiết lập.',
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
  double _givenAmount = 0;

  @override
  void initState() {
    super.initState();
    _givenAmount = widget.total;
  }

  @override
  Widget build(BuildContext context) {
    final change = _givenAmount - widget.total;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          AppAssetIcon(
            assetPath: AppAssets.cash,
            color: AppColors.success,
            size: 22,
            semanticLabel: 'Tiền mặt',
          ),
          const SizedBox(width: 8),
          const Text('Xác nhận tiền mặt'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Tổng tiền đơn hàng:',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              _currFmt.format(widget.total),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 14),

            const Text(
              'Chọn nhanh tiền khách đưa:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [50000, 100000, 200000, 500000].map((amt) {
                final amtDouble = amt.toDouble();
                final isSel = _givenAmount == amtDouble;
                return ChoiceChip(
                  label: Text('${amt ~/ 1000}k'),
                  selected: isSel,
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: isSel ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _givenAmount = amtDouble);
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            if (change >= 0)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.success),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Tiền thừa thối lại:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
                    ),
                    Text(
                      _currFmt.format(change),
                      style: GoogleFonts.manrope(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
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
          child: const Text('Đã nhận tiền & Hoàn tất'),
        ),
      ],
    );
  }
}
