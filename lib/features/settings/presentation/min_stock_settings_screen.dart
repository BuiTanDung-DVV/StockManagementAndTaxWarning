import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/assets/app_icon.dart';
import '../../../core/network/api_client.dart';
import '../../../core/providers/data_freshness_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../providers/shop_provider.dart';

class MinStockSettingsScreen extends ConsumerStatefulWidget {
  const MinStockSettingsScreen({super.key});
  @override
  ConsumerState<MinStockSettingsScreen> createState() =>
      _MinStockSettingsScreenState();
}

class _MinStockSettingsScreenState
    extends ConsumerState<MinStockSettingsScreen> {
  final _search = TextEditingController();
  Future<Map<String, dynamic>>? _future;
  int _page = 1;

  bool _sameShop(int id) {
    final shop = ref.read(shopProvider);
    return mounted &&
        !shop.isAllShops &&
        shop.currentShopId == id &&
        shop.hasPermission('products');
  }

  void _reload() {
    final id = ref.read(shopProvider).currentShopId;
    if (id == null) return;
    setState(() {
      _future = ref
          .read(apiClientProvider)
          .getOnlineInShop(
            '/products',
            '$id',
            params: {
              'page': '$_page',
              'limit': '20',
              'search': _search.text.trim(),
            },
            isCurrentScope: () => _sameShop(id),
          )
          .then((value) => Map<String, dynamic>.from(value as Map));
    });
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _edit(Map item) async {
    final shopId = ref.read(shopProvider).currentShopId;
    if (shopId == null ||
        !ref.read(shopProvider).hasPermission('products', 'edit')) {
      return;
    }
    final ctrl = TextEditingController(text: '${item['minStock'] ?? 0}');
    var busy = false;
    String? error;
    final route = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setModal) => PopScope(
          canPop: !busy,
          child: AlertDialog(
            title: const Text('Định mức tồn tối thiểu'),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${item['name']}'),
                    const SizedBox(height: 20),
                    TextField(
                      controller: ctrl,
                      enabled: !busy,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Tối thiểu (${item['unit'] ?? ''})',
                        helperText: 'Nhập 0 để không cảnh báo theo định mức.',
                        errorText: error,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Chỉ đổi ngưỡng cảnh báo; không thay đổi số lượng đang tồn.',
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(dialogContext),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        final value = int.tryParse(ctrl.text.trim());
                        if (value == null || value < 0) {
                          setModal(() => error = 'Nhập số nguyên không âm.');
                          return;
                        }
                        bool current() =>
                            _sameShop(shopId) &&
                            ref
                                .read(shopProvider)
                                .hasPermission('products', 'edit');
                        if (!current()) {
                          setModal(
                            () => error =
                                'Cửa hàng hoặc quyền đã thay đổi. Hãy đóng và mở lại.',
                          );
                          return;
                        }
                        setModal(() {
                          busy = true;
                          error = null;
                        });
                        try {
                          await ref
                              .read(apiClientProvider)
                              .putInShop(
                                '/products/${item['id']}',
                                '$shopId',
                                data: {'minStock': value},
                                isCurrentScope: current,
                              );
                          if (!dialogContext.mounted) return;
                          Navigator.pop(dialogContext);
                          if (current()) _reload();
                        } catch (_) {
                          if (dialogContext.mounted)
                            setModal(() {
                              busy = false;
                              error =
                                  'Chưa lưu được. Kiểm tra kết nối rồi thử lại.';
                            });
                        }
                      },
                child: Text(busy ? 'Đang lưu…' : 'Lưu định mức'),
              ),
            ],
          ),
        ),
      ),
    );
    await Navigator.of(context, rootNavigator: true).push(route);
    await route.completed;
    ctrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(shopProvider.select((s) => s.currentShopId), (_, _) {
      _page = 1;
      _reload();
    });
    listenToDataChanges(ref, DataArea.products, _reload);
    final shop = ref.watch(shopProvider);
    final canEdit = shop.hasPermission('products', 'edit');
    return Scaffold(
      backgroundColor: AppThemeColors.of(context).bg,
      body: AppResponsiveContent(
        maxWidth: 1000,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppPageHeader(
              title: 'Định mức tồn tối thiểu',
              subtitle:
                  'Đặt ngưỡng riêng cho từng sản phẩm. Hàng chạm hoặc thấp hơn ngưỡng sẽ được cảnh báo.',
              showBackButton: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _search,
              onSubmitted: (_) {
                _page = 1;
                _reload();
              },
              decoration: InputDecoration(
                labelText: 'Tìm tên sản phẩm hoặc SKU',
                prefixIcon: const AppIcon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: 'Tìm kiếm',
                  onPressed: () {
                    _page = 1;
                    _reload();
                  },
                  icon: const AppIcon(Icons.arrow_forward),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<Map<String, dynamic>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done)
                    return const Center(child: CircularProgressIndicator());
                  if (snapshot.hasError)
                    return Center(
                      child: OutlinedButton(
                        onPressed: _reload,
                        child: const Text('Chưa tải được · Thử lại'),
                      ),
                    );
                  final data = snapshot.data ?? {};
                  final items = data['items'] as List? ?? [];
                  final pages = (data['totalPages'] as num?)?.toInt() ?? 1;
                  return Column(
                    children: [
                      Expanded(
                        child: items.isEmpty
                            ? const Center(
                                child: Text('Không có sản phẩm phù hợp.'),
                              )
                            : ListView.separated(
                                itemCount: items.length,
                                separatorBuilder: (_, _) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final item = items[index] as Map;
                                  return ListTile(
                                    title: Text('${item['name']}'),
                                    subtitle: Text('SKU: ${item['sku'] ?? ''}'),
                                    trailing: TextButton.icon(
                                      onPressed: canEdit
                                          ? () => _edit(item)
                                          : null,
                                      icon: const AppIcon(
                                        Icons.edit_outlined,
                                        size: 16,
                                      ),
                                      label: Text(
                                        '${item['minStock'] ?? 0} ${item['unit'] ?? ''}',
                                      ),
                                    ),
                                    onTap: canEdit ? () => _edit(item) : null,
                                  );
                                },
                              ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('Trang $_page/$pages'),
                          IconButton(
                            tooltip: 'Trang trước',
                            onPressed: _page > 1
                                ? () {
                                    _page--;
                                    _reload();
                                  }
                                : null,
                            icon: const AppIcon(Icons.chevron_left),
                          ),
                          IconButton(
                            tooltip: 'Trang sau',
                            onPressed: _page < pages
                                ? () {
                                    _page++;
                                    _reload();
                                  }
                                : null,
                            icon: const AppIcon(Icons.chevron_right),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
