import 'dart:async';
import 'package:intl/intl.dart';
import '../../settings/providers/shop_provider.dart';
import '../../../core/assets/app_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/toast_service.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../providers/invoice_scan_provider.dart';

class InvoiceScanScreen extends ConsumerStatefulWidget {
  const InvoiceScanScreen({super.key});

  @override
  ConsumerState<InvoiceScanScreen> createState() => _InvoiceScanScreenState();
}

class _InvoiceScanScreenState extends ConsumerState<InvoiceScanScreen> {
  int page = 1;
  bool uploading = false;
  final _searchController = TextEditingController();
  Timer? _searchTimer;
  String _search = '';
  String? _statusFilter;
  DateTimeRange? _range;
  String _day(DateTime date) => DateFormat('yyyy-MM-dd').format(date);
  InvoiceScanFilter get _query => (
    page: page,
    search: _search,
    status: _statusFilter,
    from: _range == null ? null : _day(_range!.start),
    to: _range == null ? null : _day(_range!.end),
  );
  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _applySearch() {
    _searchTimer?.cancel();
    setState(() {
      _search = _searchController.text.trim();
      page = 1;
    });
  }

  void _clearFilters() {
    _searchTimer?.cancel();
    _searchController.clear();
    setState(() {
      _search = '';
      _statusFilter = null;
      _range = null;
      page = 1;
    });
  }

  Future<void> _chooseDates() async {
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _range,
      helpText: 'Lọc theo ngày quét',
    );
    if (selected != null && mounted) {
      setState(() {
        _range = selected;
        page = 1;
      });
    }
  }

  Widget _scanThumbnailPlaceholder() =>
      const Center(child: AppIcon(Icons.receipt_long_outlined, size: 22));

  Widget _filters() => AppCardContainer(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            maxLength: 120,
            onChanged: (_) {
              _searchTimer?.cancel();
              _searchTimer = Timer(
                const Duration(milliseconds: 400),
                _applySearch,
              );
            },
            onSubmitted: (_) => _applySearch(),
            decoration: InputDecoration(
              hintText: 'Tìm mã quét, số hóa đơn hoặc đối tác',
              counterText: '',
              prefixIcon: const AppIcon(Icons.search),
              suffixIcon: IconButton(
                tooltip: 'Tìm kiếm',
                onPressed: _applySearch,
                icon: const AppIcon(Icons.arrow_forward),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  key: ValueKey(_statusFilter),
                  initialValue: _statusFilter ?? '',
                  isExpanded: true,
                  decoration: const InputDecoration(isDense: true),
                  items: const [
                    DropdownMenuItem(
                      value: '',
                      child: Text('Tất cả trạng thái'),
                    ),
                    DropdownMenuItem(
                      value: 'REVIEW_REQUIRED',
                      child: Text('Cần kiểm tra'),
                    ),
                    DropdownMenuItem(
                      value: 'MANUAL_REQUIRED',
                      child: Text('Cần nhập tay'),
                    ),
                    DropdownMenuItem(
                      value: 'CONFIRMED',
                      child: Text('Đã tạo hóa đơn'),
                    ),
                    DropdownMenuItem(
                      value: 'PROCESSING',
                      child: Text('Đang nhận dạng'),
                    ),
                    DropdownMenuItem(
                      value: 'PENDING',
                      child: Text('Chờ xử lý'),
                    ),
                  ],
                  onChanged: (value) => setState(() {
                    _statusFilter = value == '' ? null : value;
                    page = 1;
                  }),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _chooseDates,
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                icon: const AppIcon(Icons.date_range_outlined),
                label: Text(
                  _range == null
                      ? 'Ngày quét: Tất cả'
                      : '${DateFormat('dd/MM/yyyy').format(_range!.start)} – ${DateFormat('dd/MM/yyyy').format(_range!.end)}',
                ),
              ),
              if (_search.isNotEmpty || _statusFilter != null || _range != null)
                TextButton.icon(
                  onPressed: _clearFilters,
                  icon: const AppIcon(Icons.filter_alt_off_outlined),
                  label: const Text('Bỏ lọc'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Tìm trên toàn bộ phiếu quét của cửa hàng · Mới thêm trước.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final query = _query;
    final scans = ref.watch(filteredInvoiceScanListProvider(query));
    final canEdit = ref.watch(shopProvider).hasPermission('finance', 'edit');

    return Scaffold(
      backgroundColor: c.bg,
      body: AppResponsiveContent(
        maxWidth: 1100,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppPageHeader(
              title: 'Quét hóa đơn',
              subtitle:
                  'Nhận dạng ảnh, kiểm tra thủ công rồi mới tạo hóa đơn đầu vào.',
              showBackButton: true,
              action: FilledButton.icon(
                onPressed: uploading || !canEdit ? null : _pick,
                icon: const AppIcon(Icons.document_scanner_outlined),
                label: Text(uploading ? 'Đang xử lý…' : 'Chọn ảnh hóa đơn'),
              ),
              compactAction: IconButton.filled(
                onPressed: uploading || !canEdit ? null : _pick,
                icon: const AppIcon(Icons.add_a_photo_outlined),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _filters(),
            const SizedBox(height: AppSpacing.md),
            if (uploading) const LinearProgressIndicator(),
            Expanded(
              child: scans.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: AppInlineError(
                      message:
                          'Không thể tải danh sách phiếu quét. Vui lòng thử lại sau.',
                      onRetry: () => ref.invalidate(
                        filteredInvoiceScanListProvider(query),
                      ),
                    ),
                  ),
                ),
                data: (data) {
                  final items = data['items'] as List? ?? const [];
                  if (items.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const AppIcon(Icons.receipt_long_outlined, size: 40),
                          const SizedBox(height: 12),
                          Text(
                            _search.isNotEmpty ||
                                    _statusFilter != null ||
                                    _range != null
                                ? 'Không có phiếu quét khớp bộ lọc.'
                                : 'Chưa có phiếu quét trong cửa hàng.',
                          ),
                          const SizedBox(height: 12),
                          if (_search.isNotEmpty ||
                              _statusFilter != null ||
                              _range != null)
                            TextButton(
                              onPressed: _clearFilters,
                              child: const Text('Xem tất cả phiếu quét'),
                            ),
                          if (canEdit)
                            FilledButton.icon(
                              onPressed: uploading ? null : _pick,
                              icon: const AppIcon(Icons.add_a_photo_outlined),
                              label: const Text('Chọn ảnh hóa đơn'),
                            ),
                        ],
                      ),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async =>
                        ref.invalidate(filteredInvoiceScanListProvider(query)),
                    child: Column(
                      children: [
                        Expanded(
                          child: ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: items.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: AppSpacing.sm),
                            itemBuilder: (_, index) {
                              final item = Map<String, dynamic>.from(
                                items[index],
                              );
                              final imgUrl = item['imageUrl']?.toString() ?? '';
                              final hasImg =
                                  imgUrl.isNotEmpty && imgUrl != 'null';
                              return AppCardContainer(
                                child: Material(
                                  color: Colors.transparent,
                                  child: ListTile(
                                    onTap: () async {
                                      await context.push(
                                        '/invoice-scans/${item['id']}',
                                      );
                                      if (mounted) {
                                        ref.invalidate(
                                          filteredInvoiceScanListProvider,
                                        );
                                      }
                                    },
                                    leading: SizedBox.square(
                                      dimension: 48,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: ColoredBox(
                                          color: c.surface,
                                          child: hasImg
                                              ? Image.network(
                                                  imgUrl,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, _, _) =>
                                                      _scanThumbnailPlaceholder(),
                                                )
                                              : _scanThumbnailPlaceholder(),
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      (item['invoice'] is Map
                                                  ? item['invoice']['invoiceNumber']
                                                  : null)
                                              ?.toString() ??
                                          item['scanCode']?.toString() ??
                                          'Phiếu quét',
                                    ),
                                    subtitle: Text(
                                      [
                                        if (item['invoice'] is Map)
                                          item['invoice']['partnerName']
                                                  ?.toString() ??
                                              '',
                                        '${item['scanCode'] ?? ''} · ${_status(item)}',
                                        if (DateTime.tryParse(
                                              '${item['scannedAt']}',
                                            )
                                            case final date?)
                                          'Quét: ${DateFormat('dd/MM/yyyy HH:mm').format(date.toLocal())}',
                                      ].where((value) => value.isNotEmpty).join('\n'),
                                    ),
                                    trailing: const AppIcon(
                                      Icons.chevron_right,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              '${data['total'] ?? items.length} phiếu · Trang $page/${data['totalPages'] ?? 1}',
                            ),
                            IconButton(
                              onPressed: page > 1
                                  ? () => setState(() => page--)
                                  : null,
                              icon: const AppIcon(Icons.chevron_left),
                            ),
                            IconButton(
                              onPressed: page < (data['totalPages'] ?? 1)
                                  ? () => setState(() => page++)
                                  : null,
                              icon: const AppIcon(Icons.chevron_right),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _status(Map<String, dynamic> item) => switch (item['status']) {
    'CONFIRMED' => 'Đã tạo hóa đơn',
    'REVIEW_REQUIRED' => 'Đã nhận dạng · Cần kiểm tra',
    'MANUAL_REQUIRED' => item['errorMessage']?.toString() ?? 'Cần nhập tay',
    'PROCESSING' => 'Đang nhận dạng ảnh',
    _ => 'Chờ xử lý',
  };

  Future<void> _pick() async {
    final shopId = ref.read(shopProvider).currentShopId;
    if (uploading ||
        shopId == null ||
        !ref.read(shopProvider).hasPermission('finance', 'edit')) {
      return;
    }
    bool current() =>
        mounted &&
        ref.read(shopProvider).currentShopId == shopId &&
        ref.read(shopProvider).hasPermission('finance', 'edit');
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const AppIcon(Icons.camera_alt_outlined),
              title: const Text('Chụp ảnh hóa đơn'),
              subtitle: const Text('Dùng máy ảnh chụp trực tiếp'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const AppIcon(Icons.photo_library_outlined),
              title: const Text('Chọn ảnh từ thư viện'),
              subtitle: const Text('Tải ảnh hóa đơn có sẵn từ máy'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !current()) return;

    final file = await ImagePicker().pickImage(
      source: source,
      imageQuality: 92,
    );
    if (file == null || !current()) return;
    final bytes = await file.readAsBytes();
    if (!current()) return;
    if (bytes.length > 4 * 1024 * 1024) {
      ToastService.showError('Ảnh phải nhỏ hơn 4 MB');
      return;
    }
    final ext = file.name.split('.').last.toLowerCase();
    final type = ext == 'png'
        ? 'image/png'
        : ext == 'webp'
        ? 'image/webp'
        : 'image/jpeg';
    setState(() => uploading = true);
    try {
      final scan = await ref
          .read(invoiceScanRepositoryProvider)
          .upload(bytes, file.name, type);
      if (!mounted || !current()) return;
      ref.invalidate(filteredInvoiceScanListProvider);
      ref.invalidate(invoiceScanListProvider);
      _clearFilters();
      context.push('/invoice-scans/${scan['id']}');
    } catch (error) {
      ToastService.showError(
        error is ApiException
            ? error.message
            : 'Không thể tải lên hóa đơn để quét. Vui lòng thử lại sau.',
      );
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }
}
