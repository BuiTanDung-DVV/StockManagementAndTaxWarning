import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../../../core/assets/app_icon.dart';
import '../../../core/utils/search_text.dart';
import '../../../core/widgets/product_network_image.dart';
import '../../auth/providers/auth_provider.dart';
import '../../settings/providers/shop_provider.dart';
import '../models/purchase_order_suggestion.dart';
import '../models/replenishment_safety.dart';
import '../providers/inventory_provider.dart';

class ReplenishmentButton extends ConsumerStatefulWidget {
  const ReplenishmentButton({super.key});
  @override
  ConsumerState<ReplenishmentButton> createState() =>
      _ReplenishmentButtonState();
}

class _ReplenishmentButtonState extends ConsumerState<ReplenishmentButton> {
  bool _opening = false;

  @override
  Widget build(BuildContext context) {
    final shop = ref.watch(shopProvider);
    final auth = ref.watch(authProvider);
    final actor = int.tryParse('${auth.user?['id']}');
    final shopId = shop.currentShopId;
    if (actor == null ||
        shopId == null ||
        shop.isAllShops ||
        !auth.isLoggedIn ||
        auth.isOfflineSession ||
        !shop.hasPermission('inventory', 'edit') ||
        !shop.hasPermission('products') ||
        !shop.hasPermission('suppliers')) {
      return const SizedBox.shrink();
    }
    final rows = ref.watch(lowStockProvider).value ?? [];
    final seen = <int>{};
    final items = rows
        .map((row) => ReplenishmentLine.from(row, shopId))
        .whereType<ReplenishmentLine>()
        .where((row) => seen.add(row.productId))
        .toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return OutlinedButton.icon(
      icon: const AppIcon(Icons.playlist_add_outlined, size: 18),
      label: const Text('Đề xuất nhập'),
      onPressed: _opening
          ? null
          : () async {
              setState(() => _opening = true);
              bool isCurrentScope() {
                if (!mounted) return false;
                final current = ref.read(shopProvider);
                final auth = ref.read(authProvider);
                return current.currentShopId == shopId &&
                    !current.isAllShops &&
                    '${auth.user?['id']}' == '$actor' &&
                    auth.isLoggedIn &&
                    !auth.isOfflineSession &&
                    current.hasPermission('inventory', 'edit') &&
                    current.hasPermission('products') &&
                    current.hasPermission('suppliers');
              }

              try {
                final suggestion = await showDialog<PurchaseOrderSuggestion>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => ReplenishmentDialog(
                    userId: actor,
                    shopId: shopId,
                    items: items,
                    review: (selected) => ref
                        .read(inventoryRepoProvider)
                        .reviewReplenishmentInShop(
                          shopId,
                          selected,
                          isCurrentScope: isCurrentScope,
                        ),
                  ),
                );
                if (suggestion == null ||
                    !context.mounted ||
                    !isCurrentScope()) {
                  return;
                }
                context.push('/purchase-orders/form', extra: suggestion);
              } finally {
                if (mounted) setState(() => _opening = false);
              }
            },
    );
  }
}

class ReplenishmentDialog extends StatefulWidget {
  final int userId;
  final int shopId;
  final List<ReplenishmentLine> items;
  final Future<List<PendingPurchaseMatch>> Function(List<ReplenishmentLine>)
  review;
  const ReplenishmentDialog({
    super.key,
    required this.userId,
    required this.shopId,
    required this.items,
    required this.review,
  });
  @override
  State<ReplenishmentDialog> createState() => _ReplenishmentDialogState();
}

class _ReplenishmentDialogState extends State<ReplenishmentDialog> {
  final _selected = <int>{};
  final _quantities = <int, TextEditingController>{};
  final _search = TextEditingController();
  String? _error;
  bool _checking = false;
  @override
  void initState() {
    super.initState();
    for (final item in widget.items) {
      _quantities[item.productId] = TextEditingController(
        text: '${item.quantity}',
      );
    }
  }

  @override
  void dispose() {
    _search.dispose();
    for (final c in _quantities.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _continue() async {
    if (_checking) return;
    final chosen = <ReplenishmentLine>[];
    for (final item in widget.items.where(
      (item) => _selected.contains(item.productId),
    )) {
      final quantity = int.tryParse(_quantities[item.productId]!.text);
      if (quantity == null || quantity <= 0 || quantity > 1000000000000000) {
        setState(
          () => _error =
              'Số lượng nhập của ${item.name} phải là số nguyên dương trong giới hạn cho phép.',
        );
        return;
      }
      chosen.add(item.withQuantity(quantity));
    }
    if (chosen.isEmpty) return;
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final matches = await widget.review(chosen);
      if (!mounted) return;
      if (matches.isNotEmpty) {
        final proceed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Sản phẩm đã có phiếu nhập chờ'),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Kiểm tra các phiếu dưới đây để tránh đặt trùng. Số lượng đề xuất chưa trừ các phiếu này.',
                    ),
                    const SizedBox(height: 12),
                    for (final match in matches)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          '${match.orderCode} · ${match.productName}: ${NumberFormat.decimalPattern('vi_VN').format(match.quantity)}',
                        ),
                      ),
                    const Text(
                      'Tiếp tục chỉ điền vào biểu mẫu. Bạn vẫn cần kiểm tra và lưu phiếu nhập.',
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Quay lại kiểm tra'),
              ),
              OutlinedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Vẫn lập phiếu mới'),
              ),
            ],
          ),
        );
        if (!mounted || proceed != true) return;
      }
      if (!mounted) return;
      Navigator.of(context).pop(
        PurchaseOrderSuggestion(
          userId: widget.userId,
          shopId: widget.shopId,
          items: chosen,
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is StateError
              ? error.message
              : 'Chưa kiểm tra được tồn kho và phiếu nhập chờ. Lựa chọn được giữ nguyên; kiểm tra kết nối rồi thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = foldSearchText(_search.text);
    final visible = widget.items
        .where((i) => foldSearchText('${i.name} ${i.sku}').contains(query))
        .toList();
    final all =
        visible.isNotEmpty &&
        visible.every((i) => _selected.contains(i.productId));
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Đề xuất bổ sung hàng',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Gợi ý bù phần còn thiếu so với định mức, làm tròn lên. Chọn kho nhận và nhà cung cấp ở phiếu nhập.',
          ),
          const SizedBox(height: 8),
          const Text(
            'Khi tiếp tục, app kiểm tra lại tồn kho và cảnh báo hàng đã có phiếu nhập chờ. Đây là gợi ý; bạn quyết định số lượng và lưu phiếu.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Tìm tên hoặc SKU',
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Bỏ tìm kiếm',
                      icon: const AppIcon(Icons.close, size: 18),
                      onPressed: () {
                        _search.clear();
                        setState(() {});
                      },
                    ),
            ),
          ),
          Row(
            children: [
              Checkbox(
                value: all,
                onChanged: visible.isEmpty
                    ? null
                    : (value) => setState(() {
                        if (value == true) {
                          _selected.addAll(visible.map((i) => i.productId));
                        } else {
                          _selected.removeAll(visible.map((i) => i.productId));
                        }
                      }),
              ),
              const Expanded(child: Text('Chọn tất cả kết quả')),
              Text('${_selected.length} đã chọn'),
            ],
          ),
        ],
      ),
    );
    return PopScope(
      canPop: !_checking,
      child: Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: SizedBox(
          width: 680,
          height: math.min(
            MediaQuery.sizeOf(context).height * 0.85,
            420.0 + math.min(widget.items.length, 3) * 80,
          ),
          child: AbsorbPointer(
            absorbing: _checking,
            child: Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    itemCount: visible.isEmpty ? 2 : visible.length + 1,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      if (index == 0) return header;
                      if (visible.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('Không có sản phẩm khớp tìm kiếm.'),
                        );
                      }
                      final item = visible[index - 1];
                      final selected = _selected.contains(item.productId);
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Checkbox(
                              value: selected,
                              semanticLabel: 'Chọn ${item.name}',
                              onChanged: (value) => setState(() {
                                if (value == true) {
                                  _selected.add(item.productId);
                                } else {
                                  _selected.remove(item.productId);
                                }
                              }),
                            ),
                            ProductNetworkImage(
                              imageUrl: item.imageUrl,
                              width: 40,
                              height: 40,
                              fallback: const SizedBox(
                                width: 40,
                                height: 40,
                                child: AppIcon(
                                  Icons.inventory_2_outlined,
                                  size: 22,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${item.sku} · Tồn ${NumberFormat.decimalPattern('vi_VN').format(item.stock)} / Định mức ${NumberFormat.decimalPattern('vi_VN').format(item.minimum)} ${item.unit}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 104,
                              child: TextField(
                                controller: _quantities[item.productId],
                                enabled: selected,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Số lượng',
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 12,
                                  ),
                                ),
                                onChanged: (_) {
                                  if (_error != null) {
                                    setState(() => _error = null);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Hủy'),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: FilledButton(
                          onPressed: _selected.isEmpty ? null : _continue,
                          child: Text(
                            _checking ? 'Đang kiểm tra…' : 'Tiếp tục nhập hàng',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
