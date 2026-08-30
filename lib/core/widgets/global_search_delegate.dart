import 'dart:async';

import 'package:flutter/material.dart';

import '../assets/app_assets.dart';
import '../network/api_client.dart';
import '../theme/app_theme.dart';
import 'product_network_image.dart';

Future<String?> showGlobalSearchPanel(
  BuildContext context, {
  required ApiClient api,
}) {
  final compact = MediaQuery.sizeOf(context).width < 700;
  if (compact) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.9,
        child: _GlobalSearchPanel(api: api, compact: true),
      ),
    );
  }
  return showDialog<String>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 680),
        child: _GlobalSearchPanel(api: api, compact: false),
      ),
    ),
  );
}

class _GlobalSearchPanel extends StatefulWidget {
  final ApiClient api;
  final bool compact;

  const _GlobalSearchPanel({required this.api, required this.compact});

  @override
  State<_GlobalSearchPanel> createState() => _GlobalSearchPanelState();
}

class _GlobalSearchPanelState extends State<_GlobalSearchPanel> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  List<_SearchResult> _results = const [];
  String _query = '';
  String? _error;
  bool _loading = false;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final normalized = value.trim();
    setState(() {
      _query = normalized;
      _error = null;
      if (normalized.length < 2) {
        _loading = false;
        _results = const [];
      }
    });
    if (normalized.length < 2) {
      _requestId++;
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 320),
      () => _runSearch(normalized),
    );
  }

  Future<void> _runSearch(String keyword) async {
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    final batch = await _searchAll(widget.api, keyword);
    if (!mounted || requestId != _requestId) return;
    setState(() {
      _loading = false;
      _results = batch.results;
      _error = batch.successfulSources == 0
          ? 'Không thể kết nối dữ liệu tìm kiếm. Vui lòng thử lại.'
          : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(widget.compact ? 22 : AppRadius.card),
        bottom: Radius.circular(widget.compact ? 0 : AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.cardAlt,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: colors.divider),
                  ),
                  child: const AppAssetIcon(
                    assetPath: AppAssets.search,
                    semanticLabel: 'Tìm kiếm',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tìm kiếm toàn hệ thống',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'Sản phẩm, đơn hàng và khách hàng',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Đóng'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: TextField(
              key: const ValueKey('global-search-field'),
              controller: _controller,
              focusNode: _focusNode,
              onChanged: _onQueryChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Nhập tên, mã hàng, mã đơn hoặc khách hàng',
                prefixIcon: const Padding(
                  padding: EdgeInsets.all(13),
                  child: AppAssetIcon(
                    assetPath: AppAssets.search,
                    size: 18,
                    semanticLabel: 'Từ khóa tìm kiếm',
                  ),
                ),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : TextButton(
                        onPressed: () {
                          _controller.clear();
                          _onQueryChanged('');
                        },
                        child: const Text('Xóa'),
                      ),
                filled: true,
                fillColor: colors.cardAlt,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.control),
                  borderSide: BorderSide(color: colors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.control),
                  borderSide: BorderSide(color: colors.divider),
                ),
              ),
            ),
          ),
          Divider(height: 1, color: colors.divider),
          Expanded(child: _buildBody(context)),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final colors = AppThemeColors.of(context);
    if (_query.length < 2) {
      return const _SearchMessage(
        assetPath: AppAssets.search,
        title: 'Bạn cần tìm gì?',
        message: 'Nhập ít nhất 2 ký tự để bắt đầu tìm kiếm.',
      );
    }
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return _SearchMessage(
        assetPath: AppAssets.emptyGeneric,
        title: 'Chưa thể tìm kiếm',
        message: _error!,
        actionLabel: 'Thử lại',
        onAction: () => _runSearch(_query),
      );
    }
    if (_results.isEmpty) {
      return _SearchMessage(
        assetPath: AppAssets.emptyGeneric,
        title: 'Không tìm thấy kết quả',
        message: 'Không có dữ liệu phù hợp với “$_query”.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Text(
            '${_results.length} kết quả cho “$_query”',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            itemCount: _results.length,
            separatorBuilder: (_, _) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final result = _results[index];
              return Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.control),
                child: InkWell(
                  key: ValueKey('global-search-result-${result.route}'),
                  onTap: () => Navigator.of(context).pop(result.route),
                  borderRadius: BorderRadius.circular(AppRadius.control),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 9,
                    ),
                    child: Row(
                      children: [
                        _SearchResultVisual(result: result),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                result.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${result.typeLabel} · ${result.subtitle}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: colors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Mở',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SearchResultVisual extends StatelessWidget {
  final _SearchResult result;

  const _SearchResultVisual({required this.result});

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final fallback = Container(
      width: 44,
      height: 44,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: colors.cardAlt,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: colors.divider),
      ),
      child: AppAssetIcon(
        assetPath: result.assetPath,
        semanticLabel: result.typeLabel,
      ),
    );
    if (result.imageUrl == null || result.imageUrl!.isEmpty) return fallback;
    return SizedBox(
      width: 44,
      height: 44,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: ProductNetworkImage(
          imageUrl: result.imageUrl!,
          width: 44,
          height: 44,
          semanticLabel: 'Ảnh ${result.title}',
          fallback: fallback,
        ),
      ),
    );
  }
}

class _SearchBatch {
  final List<_SearchResult> results;
  final int successfulSources;

  const _SearchBatch({required this.results, required this.successfulSources});
}

class _EndpointBatch {
  final List<Map<String, dynamic>> items;
  final bool success;

  const _EndpointBatch({required this.items, required this.success});
}

Future<_SearchBatch> _searchAll(ApiClient api, String keyword) async {
  final batches = await Future.wait([
    _searchEndpoint(api, '/products', keyword),
    _searchEndpoint(api, '/sales-orders', keyword),
    _searchEndpoint(api, '/customers', keyword),
  ]);
  final results = <_SearchResult>[];
  for (final item in batches[0].items) {
    final id = item['id'];
    if (id == null) continue;
    results.add(
      _SearchResult(
        typeLabel: 'Sản phẩm',
        title: item['name']?.toString() ?? 'Sản phẩm #$id',
        subtitle: item['sku']?.toString() ?? 'Không có mã hàng',
        route: '/products/$id',
        assetPath: AppAssets.inventory,
        imageUrl: item['imageUrl']?.toString(),
      ),
    );
  }
  for (final item in batches[1].items) {
    final id = item['id'];
    if (id == null) continue;
    final customer = item['customer'];
    results.add(
      _SearchResult(
        typeLabel: 'Đơn hàng',
        title: item['orderCode']?.toString() ?? 'Đơn hàng #$id',
        subtitle: customer is Map
            ? customer['name']?.toString() ?? 'Khách lẻ'
            : 'Khách lẻ',
        route: '/sales/$id',
        assetPath: AppAssets.orders,
      ),
    );
  }
  for (final item in batches[2].items) {
    final id = item['id'];
    if (id == null) continue;
    results.add(
      _SearchResult(
        typeLabel: 'Khách hàng',
        title: item['name']?.toString() ?? 'Khách hàng #$id',
        subtitle: item['phone']?.toString() ?? 'Không có số điện thoại',
        route: '/customers/$id',
        assetPath: AppAssets.emptyPeople,
      ),
    );
  }
  return _SearchBatch(
    results: results,
    successfulSources: batches.where((batch) => batch.success).length,
  );
}

Future<_EndpointBatch> _searchEndpoint(
  ApiClient api,
  String endpoint,
  String keyword,
) async {
  try {
    final response = await api.get(
      endpoint,
      params: {'page': '1', 'limit': '6', 'search': keyword},
    );
    if (response is! Map || response['items'] is! List) {
      return const _EndpointBatch(items: [], success: false);
    }
    return _EndpointBatch(
      items: (response['items'] as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(),
      success: true,
    );
  } catch (_) {
    return const _EndpointBatch(items: [], success: false);
  }
}

class _SearchResult {
  final String typeLabel;
  final String title;
  final String subtitle;
  final String route;
  final String assetPath;
  final String? imageUrl;

  const _SearchResult({
    required this.typeLabel,
    required this.title,
    required this.subtitle,
    required this.route,
    required this.assetPath,
    this.imageUrl,
  });
}

class _SearchMessage extends StatelessWidget {
  final String assetPath;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SearchMessage({
    required this.assetPath,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppAssetIcon(assetPath: assetPath, size: 50, semanticLabel: title),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 14),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
