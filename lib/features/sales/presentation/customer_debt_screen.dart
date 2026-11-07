import '../../settings/providers/shop_provider.dart';
import '../../../core/assets/app_icon.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import '../../../core/providers/data_freshness_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/excel_export_service.dart';
import '../../../core/utils/parse_utils.dart';
import '../../../core/utils/toast_service.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/app_pagination_bar.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../customers/providers/customer_provider.dart';
import '../../customers/models/receivable_balance.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/sales_provider.dart';

final _debtCurrencyFormat = NumberFormat.currency(
  locale: 'vi_VN',
  symbol: '₫',
  decimalDigits: 2,
)..minimumFractionDigits = 0;

Map<String, dynamic> customerDebtListQuery({
  int page = 1,
  int limit = 20,
  String search = '',
  String status = 'ALL',
  String sort = 'DUE_DATE_ASC',
}) {
  return {
    'page': page,
    'limit': limit,
    'status': status,
    'sort': sort,
    if (search.trim().isNotEmpty) 'search': search.trim(),
  };
}

double customerDebtRemaining(Map<String, dynamic> debt) {
  return customerReceivableRemaining(debt);
}

String? customerDebtAdjustmentLabel(Map<String, dynamic> debt) {
  final adjustment = num.tryParse(
    debt['openingAdjustmentAmount']?.toString() ?? '0',
  );
  if (adjustment == null || !adjustment.isFinite || adjustment == 0) {
    return null;
  }
  return 'Điều chỉnh đầu kỳ: ${adjustment > 0 ? '+' : '−'}${_debtCurrencyFormat.format(adjustment.abs())}';
}

({int orderId, int receivableId}) customerDebtPaymentTarget(
  Map<String, dynamic> debt,
) {
  final orderId = num.tryParse(debt['orderId']?.toString() ?? '')?.toInt() ?? 0;
  final receivableId = num.tryParse(debt['id']?.toString() ?? '')?.toInt() ?? 0;
  if (orderId <= 0 && receivableId <= 0) {
    throw const FormatException('Khoản phải thu không hợp lệ');
  }
  return (orderId: orderId, receivableId: receivableId);
}

({double outstanding, double overdue, int customerCount, int receivableCount})
customerDebtOverview(Iterable<Map<String, dynamic>> debts) {
  var outstanding = 0.0;
  var overdue = 0.0;
  var fallbackIndex = 0;
  final customerKeys = <String>{};

  for (final debt in debts) {
    final remaining = customerDebtRemaining(debt);
    outstanding += remaining;
    final daysOverdue = int.tryParse(debt['daysOverdue']?.toString() ?? '0');
    if ((daysOverdue ?? 0) > 0 || debt['status'] == 'OVERDUE') {
      overdue += remaining;
    }

    final customerId = int.tryParse(debt['customerId']?.toString() ?? '');
    final phone = debt['customerPhone']?.toString().trim() ?? '';
    final name = debt['customerName']?.toString().trim().toLowerCase() ?? '';
    if (customerId != null && customerId > 0) {
      customerKeys.add('id:$customerId');
    } else if (phone.isNotEmpty) {
      customerKeys.add('phone:$phone');
    } else if (name.isNotEmpty && name != 'khách hàng') {
      customerKeys.add('name:$name');
    } else {
      customerKeys.add('unknown:${fallbackIndex++}');
    }
  }

  return (
    outstanding: outstanding,
    overdue: overdue,
    customerCount: customerKeys.length,
    receivableCount: debts.length,
  );
}

String customerDebtDueLabel(Map<String, dynamic> debt) {
  final daysOverdue = int.tryParse(debt['daysOverdue']?.toString() ?? '0') ?? 0;
  if (daysOverdue > 0 || debt['status'] == 'OVERDUE') {
    return daysOverdue > 0 ? 'Quá hạn $daysOverdue ngày' : 'Đã quá hạn';
  }
  final dueDate = DateTime.tryParse(debt['dueDate']?.toString() ?? '');
  if (dueDate == null) return 'Chưa có hạn thu';
  return 'Hạn ${DateFormat('dd/MM/yyyy').format(dueDate)}';
}

class CustomerDebtScreen extends ConsumerStatefulWidget {
  final String? initialStatus;

  const CustomerDebtScreen({super.key, this.initialStatus});

  @override
  ConsumerState<CustomerDebtScreen> createState() => _CustomerDebtScreenState();
}

class _CustomerDebtScreenState extends ConsumerState<CustomerDebtScreen> {
  List<Map<String, dynamic>> _debts = [];
  ({double outstanding, double overdue, int customerCount, int receivableCount})
  _overview = (
    outstanding: 0,
    overdue: 0,
    customerCount: 0,
    receivableCount: 0,
  );
  bool _isLoading = true;
  bool _isListLoading = false;
  bool _isRecordingPayment = false;
  bool _isExporting = false;
  String? _errorMessage;
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  int _page = 1;
  static const _limit = 20;
  int _total = 0;
  int _totalPages = 1;
  int _requestVersion = 0;
  int _exportScopeVersion = 0;
  String _status = 'ALL';
  String _sort = 'DUE_DATE_ASC';

  @override
  void initState() {
    super.initState();
    if (const {
      'OVERDUE',
      'CURRENT',
    }.contains(widget.initialStatus?.toUpperCase())) {
      _status = widget.initialStatus!.toUpperCase();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDebts());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  double _asDouble(dynamic value) =>
      num.tryParse(value?.toString() ?? '0')?.toDouble() ?? 0;

  Future<void> _loadDebts({
    bool showLoading = true,
    bool resetPage = false,
  }) async {
    if (resetPage) _page = 1;
    final requestVersion = ++_requestVersion;
    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    } else if (mounted) {
      setState(() {
        _isListLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final data = await ref
          .read(customerRepoProvider)
          .getOpenReceivablesPage(
            params: customerDebtListQuery(
              page: _page,
              limit: _limit,
              search: _searchController.text,
              status: _status,
              sort: _sort,
            ),
          );
      final rawItems = data['items'];
      final rawSummary = data['summary'];
      if (rawItems is! List || rawSummary is! Map) {
        throw const FormatException('Dữ liệu công nợ không đúng định dạng');
      }
      for (final key in [
        'outstanding',
        'overdue',
        'customerCount',
        'receivableCount',
      ]) {
        final value = rawSummary[key];
        if (value is! num ||
            !value.isFinite ||
            value < 0 ||
            (const {'customerCount', 'receivableCount'}.contains(key) &&
                value != value.truncate())) {
          throw const FormatException('Dữ liệu tổng hợp công nợ không đầy đủ');
        }
      }
      if ((rawSummary['overdue'] as num) > (rawSummary['outstanding'] as num)) {
        throw const FormatException('Dữ liệu tổng hợp công nợ không khớp');
      }

      final debts = rawItems
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      final total = paginationValue(data, 'total', fallback: debts.length);
      final totalPages = paginationValue(data, 'totalPages', fallback: 1);
      if (!mounted || requestVersion != _requestVersion) return;
      if (debts.isEmpty && total > 0 && _page > totalPages) {
        _page = totalPages;
        await _loadDebts(showLoading: false);
        return;
      }
      final summary = Map<String, dynamic>.from(rawSummary);
      setState(() {
        _debts = debts;
        _overview = (
          outstanding: _asDouble(summary['outstanding']),
          overdue: _asDouble(summary['overdue']),
          customerCount:
              int.tryParse(summary['customerCount']?.toString() ?? '') ?? 0,
          receivableCount:
              int.tryParse(summary['receivableCount']?.toString() ?? '') ?? 0,
        );
        _total = total;
        _totalPages = totalPages < 1 ? 1 : totalPages;
        _isLoading = false;
        _isListLoading = false;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted || requestVersion != _requestVersion) return;
      setState(() {
        _isLoading = false;
        _isListLoading = false;
        _errorMessage = error is ApiException
            ? error.message
            : 'Dữ liệu công nợ không hợp lệ. Vui lòng thử lại.';
      });
    }
  }

  Widget _buildPageHeader() {
    final shop = ref.watch(shopProvider);
    return AppPageHeader(
      title: 'Công nợ khách hàng',
      subtitle:
          'Theo dõi khoản cần thu, ghi nhận thanh toán và nhắc nợ theo từng đơn hàng.',
      action: OutlinedButton(
        onPressed:
            _isExporting ||
                _total == 0 ||
                shop.isAllShops ||
                shop.currentShopId == null ||
                !shop.hasPermission('customers')
            ? null
            : _exportDebts,
        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
        child: Text(_isExporting ? 'Đang xuất…' : 'Xuất Excel'),
      ),
    );
  }

  void _onSearchChanged(String _) {
    _exportScopeVersion++;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 400),
      () => _loadDebts(showLoading: false, resetPage: true),
    );
  }

  Widget _buildListFilters() {
    final colors = AppThemeColors.of(context);
    return AppCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lọc danh sách công nợ',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'Chỉ áp dụng cho danh sách bên dưới; các KPI phía trên luôn phản ánh toàn bộ công nợ.',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    if (_total > 0) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'Excel gồm tất cả $_total bản ghi theo bộ lọc hiện tại, kể cả các trang khác.',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (_searchController.text.isNotEmpty || _status != 'ALL')
                TextButton(
                  onPressed: () {
                    _searchDebounce?.cancel();
                    _searchController.clear();
                    setState(() {
                      _status = 'ALL';
                      _sort = 'DUE_DATE_ASC';
                      _exportScopeVersion++;
                    });
                    _loadDebts(showLoading: false, resetPage: true);
                  },
                  child: const Text('Đặt lại'),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final search = TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: const InputDecoration(
                  labelText: 'Tìm khách hàng, SĐT hoặc mã đơn',
                  prefixIcon: AppIcon(Icons.search),
                ),
              );
              final status = DropdownButtonFormField<String>(
                key: ValueKey('debt-status-$_status'),
                initialValue: _status,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Trạng thái'),
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('Tất cả')),
                  DropdownMenuItem(value: 'OVERDUE', child: Text('Đã quá hạn')),
                  DropdownMenuItem(
                    value: 'CURRENT',
                    child: Text('Chưa quá hạn'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null || value == _status) return;
                  setState(() {
                    _status = value;
                    _exportScopeVersion++;
                  });
                  _loadDebts(showLoading: false, resetPage: true);
                },
              );
              final sort = DropdownButtonFormField<String>(
                key: ValueKey('debt-sort-$_sort'),
                initialValue: _sort,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Sắp xếp'),
                items: const [
                  DropdownMenuItem(
                    value: 'DUE_DATE_ASC',
                    child: Text('Hạn thu gần nhất'),
                  ),
                  DropdownMenuItem(
                    value: 'REMAINING_DESC',
                    child: Text('Số nợ cao nhất'),
                  ),
                  DropdownMenuItem(
                    value: 'CUSTOMER_ASC',
                    child: Text('Tên khách hàng'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null || value == _sort) return;
                  setState(() {
                    _sort = value;
                    _exportScopeVersion++;
                  });
                  _loadDebts(showLoading: false, resetPage: true);
                },
              );

              if (constraints.maxWidth < 560) {
                return Column(
                  children: [
                    search,
                    const SizedBox(height: AppSpacing.sm),
                    status,
                    const SizedBox(height: AppSpacing.sm),
                    sort,
                  ],
                );
              }
              if (constraints.maxWidth < 720) {
                return Column(
                  children: [
                    search,
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(child: status),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: sort),
                      ],
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(flex: 2, child: search),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: status),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: sort),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    return AppPaginationBar(
      currentPage: _page,
      totalPages: _totalPages,
      totalItems: _total,
      itemLabel: 'khoản phù hợp',
      onPageChanged: (page) {
        if (page == _page) return;
        setState(() => _page = page);
        _loadDebts(showLoading: false);
      },
    );
  }

  Widget _buildStatePage(Widget state) {
    return SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return AppResponsiveContent(
            maxWidth: 1320,
            verticalPadding: AppSpacing.lg,
            child: SizedBox(
              height: constraints.maxHeight - (AppSpacing.lg * 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildPageHeader(),
                  Expanded(child: state),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    listenToDataChanges(
      ref,
      DataArea.customers,
      () => _loadDebts(showLoading: false),
    );
    ref.listen(
      authProvider.select(
        (state) => (state.isLoggedIn, state.user?['id']?.toString()),
      ),
      (previous, next) {
        if (previous != next) _exportScopeVersion++;
      },
    );
    ref.listen(shopProvider, (previous, next) {
      if (previous?.currentShopId != next.currentShopId ||
          previous?.isAllShops != next.isAllShops ||
          previous?.hasPermission('customers') !=
              next.hasPermission('customers')) {
        _exportScopeVersion++;
      }
    });
    ref.listen(shopProvider.select((state) => state.currentShopId), (
      previous,
      next,
    ) {
      if (previous != next) {
        _page = 1;
        _loadDebts();
      }
    });
    final colors = AppThemeColors.of(context);
    final overview = _overview;

    return Scaffold(
      backgroundColor: colors.bg,
      body: _isLoading
          ? _buildStatePage(
              const AppLoading(message: 'Đang tải công nợ khách hàng…'),
            )
          : _errorMessage != null
          ? _buildStatePage(
              AppError(message: _errorMessage!, onRetry: _loadDebts),
            )
          : RefreshIndicator(
              onRefresh: _loadDebts,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: AppResponsiveContent(
                  maxWidth: 1320,
                  verticalPadding: AppSpacing.lg,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPageHeader(),
                      AppFillGrid(
                        minItemWidth: 155,
                        maxColumns: 4,
                        itemHeight:
                            148 +
                            (MediaQuery.textScalerOf(context).scale(16) - 16)
                                    .clamp(0, 32) *
                                4,
                        children: [
                          AppKpiCard(
                            title: 'Tổng nợ cần thu',
                            value: _debtCurrencyFormat.format(
                              overview.outstanding,
                            ),
                            color: overview.outstanding > 0
                                ? AppColors.warning
                                : AppColors.success,
                            assetPath: AppAssets.cash,
                            badgeText: overview.outstanding > 0
                                ? 'Cần thu'
                                : 'Không có nợ',
                            compact: true,
                            titleMaxLines: 3,
                            badgeBelowValue: true,
                          ),
                          AppKpiCard(
                            title: 'Nợ quá hạn',
                            value: _debtCurrencyFormat.format(overview.overdue),
                            color: overview.overdue > 0
                                ? AppColors.danger
                                : AppColors.success,
                            assetPath: AppAssets.orders,
                            badgeText: overview.overdue > 0
                                ? 'Cần ưu tiên'
                                : 'Không quá hạn',
                            compact: true,
                            titleMaxLines: 3,
                            badgeBelowValue: true,
                          ),
                          AppKpiCard(
                            title: 'Khách hàng còn nợ',
                            value: '${overview.customerCount} khách',
                            color: AppColors.primary,
                            assetPath: AppAssets.orders,
                            badgeText: 'Không đếm trùng',
                            compact: true,
                            titleMaxLines: 3,
                            badgeBelowValue: true,
                          ),
                          AppKpiCard(
                            title: 'Khoản phải thu',
                            value: '${overview.receivableCount} khoản',
                            color: AppColors.primary,
                            assetPath: AppAssets.cash,
                            badgeText: 'Theo đơn hàng',
                            compact: true,
                            titleMaxLines: 3,
                            badgeBelowValue: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      _buildListFilters(),
                      if (_isListLoading)
                        const Padding(
                          padding: EdgeInsets.only(top: AppSpacing.xs),
                          child: LinearProgressIndicator(minHeight: 2),
                        ),
                      const SizedBox(height: AppSpacing.md),
                      if (_debts.isEmpty)
                        AppCardContainer(
                          child: AppEmpty(
                            visual: AppEmptyVisual.finance,
                            message:
                                _total == 0 &&
                                    (_searchController.text.isNotEmpty ||
                                        _status != 'ALL')
                                ? 'Không có khoản công nợ phù hợp bộ lọc'
                                : 'Không có khoản công nợ cần thu',
                            subtitle:
                                'Thử thay đổi bộ lọc hoặc tải lại dữ liệu từ máy chủ.',
                            action: TextButton(
                              onPressed: _loadDebts,
                              child: const Text('Tải lại dữ liệu'),
                            ),
                          ),
                        )
                      else
                        LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth < 760) {
                              return Column(
                                children: [
                                  _MobileDebtList(
                                    debts: _debts,
                                    isRecordingPayment: _isRecordingPayment,
                                    asDouble: _asDouble,
                                    onCollect: (item, remaining) =>
                                        _showRepayDialog(
                                          context,
                                          item,
                                          remaining,
                                        ),
                                    onRemind: _sendZaloReminder,
                                  ),
                                  _buildPagination(),
                                ],
                              );
                            }

                            return Column(
                              children: [
                                AppDataTable<Map<String, dynamic>>(
                                  title: 'Danh sách khoản phải thu',
                                  assetPath: AppAssets.cash,
                                  iconColor: AppColors.warning,
                                  columns: const [
                                    AppDataTableColumn(
                                      title: 'KHÁCH HÀNG / SĐT',
                                      flex: 3,
                                    ),
                                    AppDataTableColumn(
                                      title: 'MÃ ĐƠN',
                                      flex: 2,
                                    ),
                                    AppDataTableColumn(
                                      title: 'HẠN THU',
                                      flex: 2,
                                    ),
                                    AppDataTableColumn(
                                      title: 'NỢ GỐC',
                                      flex: 2,
                                      alignRight: true,
                                    ),
                                    AppDataTableColumn(
                                      title: 'ĐÃ THU',
                                      flex: 2,
                                      alignRight: true,
                                    ),
                                    AppDataTableColumn(
                                      title: 'CÒN NỢ',
                                      flex: 2,
                                      alignRight: true,
                                    ),
                                    AppDataTableColumn(
                                      title: 'THAO TÁC',
                                      flex: 3,
                                      alignRight: true,
                                    ),
                                  ],
                                  items: _debts,
                                  emptyMessage:
                                      'Chưa có khoản công nợ khách hàng cần thu.',
                                  rowBuilder: (context, item, index) {
                                    final total = _asDouble(
                                      item['totalAmount'],
                                    );
                                    final paid = _asDouble(item['paidAmount']);
                                    final remaining = customerDebtRemaining(
                                      item,
                                    );

                                    return _DesktopDebtRow(
                                      item: item,
                                      total: total,
                                      paid: paid,
                                      remaining: remaining,
                                      isRecordingPayment: _isRecordingPayment,
                                      onCollect: () => _showRepayDialog(
                                        context,
                                        item,
                                        remaining,
                                      ),
                                      onRemind: () =>
                                          _sendZaloReminder(item, remaining),
                                    );
                                  },
                                ),
                                _buildPagination(),
                              ],
                            );
                          },
                        ),
                      const SizedBox(height: AppSpacing.xxl),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Future<void> _exportDebts() async {
    if (_isExporting || _total == 0) return;
    final shop = ref.read(shopProvider);
    final shopId = shop.currentShopId;
    final userId = ref.read(authProvider).user?['id']?.toString();
    final version = _exportScopeVersion;
    final search = _searchController.text;
    final status = _status;
    final sort = _sort;
    bool current() {
      if (!mounted || version != _exportScopeVersion) return false;
      final auth = ref.read(authProvider);
      final selected = ref.read(shopProvider);
      return auth.isLoggedIn &&
          !auth.isOfflineSession &&
          userId != null &&
          auth.user?['id']?.toString() == userId &&
          !selected.isAllShops &&
          shopId != null &&
          selected.currentShopId == shopId &&
          selected.hasPermission('customers') &&
          _searchController.text == search &&
          _status == status &&
          _sort == sort;
    }

    if (!current()) return;
    setState(() => _isExporting = true);
    try {
      final raw = await ref
          .read(customerRepoProvider)
          .exportOpenReceivablesInShop(
            shopId!,
            params: customerDebtListQuery(
              search: search,
              status: status,
              sort: sort,
            ),
            isCurrentScope: current,
          );
      if (!current()) return;
      if (raw.any((item) => item is! Map)) {
        throw const FormatException('Dữ liệu xuất công nợ không đầy đủ');
      }
      final exportRows = raw
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
      if (exportRows.isEmpty) {
        throw const FormatException('Không có dữ liệu phù hợp để xuất');
      }
      final launched = await ExcelExportService.exportCustomerDebtsToExcel(
        exportRows,
        shopId: shopId,
        shopName: shop.currentShopName,
        filterDescription: [
          search.trim().isEmpty
              ? 'Tất cả khách hàng'
              : 'Từ khóa: ${search.trim()}',
          switch (status) {
            'OVERDUE' => 'Đã quá hạn',
            'CURRENT' => 'Chưa quá hạn',
            _ => 'Tất cả trạng thái',
          },
          switch (sort) {
            'REMAINING_DESC' => 'Số nợ cao nhất',
            'CUSTOMER_ASC' => 'Tên khách hàng',
            _ => 'Hạn thu gần nhất',
          },
        ].join(' · '),
      );
      if (!current()) return;
      if (launched) {
        ToastService.showSuccess(
          'Đã tạo tệp Excel gồm ${exportRows.length} bản ghi. Kiểm tra mục tải xuống.',
        );
      } else {
        ToastService.showError(
          'Trình duyệt không cho phép tải file. Vui lòng thử lại.',
        );
      }
    } catch (_) {
      if (current()) {
        ToastService.showError('Không thể xuất file sổ nợ. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _showRepayDialog(
    BuildContext context,
    Map<String, dynamic> item,
    double remaining,
  ) async {
    final controller = TextEditingController(
      text: remaining.toStringAsFixed(remaining % 1 == 0 ? 0 : 2),
    );
    var selectedMethod = 'CASH';
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          scrollable: true,
          title: const Text('Ghi nhận thu nợ'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['customerName']?.toString() ?? 'Khách hàng',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text('Đơn hàng: ${item['orderCode']?.toString() ?? '—'}'),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Còn phải thu: ${_debtCurrencyFormat.format(remaining)}',
                  style: const TextStyle(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (customerDebtAdjustmentLabel(item) case final String label)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text('$label. Khoản này không phải tiền đã thu.'),
                  ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => setDialogState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Số tiền thu lần này (VNĐ)',
                    helperText: controller.text.trim().isNotEmpty
                        ? _debtCurrencyFormat.format(
                            parseCurrency(controller.text),
                          )
                        : null,
                    helperStyle: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: selectedMethod,
                  decoration: const InputDecoration(
                    labelText: 'Phương thức thu tiền',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'CASH', child: Text('Tiền mặt')),
                    DropdownMenuItem(
                      value: 'TRANSFER',
                      child: Text('Chuyển khoản'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedMethod = value);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                final paid = parseCurrency(controller.text);
                if (paid <= 0 || paid > remaining) {
                  ToastService.showError(
                    'Số tiền phải lớn hơn 0 và không vượt quá số nợ còn lại.',
                  );
                  return;
                }
                Navigator.pop(dialogContext, {
                  'amount': paid,
                  'method': selectedMethod,
                });
              },
              child: const Text('Xác nhận thu nợ'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();

    if (result == null || !mounted) return;
    final paid = _asDouble(result['amount']);
    final method = result['method']?.toString() ?? 'CASH';
    final paymentTarget = customerDebtPaymentTarget(item);
    setState(() => _isRecordingPayment = true);
    try {
      final paymentData = {
        'amount': paid,
        'method': method,
        'notes': 'Thu nợ từ sổ theo dõi nợ khách hàng',
      };
      if (paymentTarget.orderId > 0) {
        await ref
            .read(salesRepoProvider)
            .addPayment(paymentTarget.orderId, paymentData);
      } else {
        await ref
            .read(customerRepoProvider)
            .collectReceivablePayment(paymentTarget.receivableId, paymentData);
      }
      await _loadDebts(showLoading: false);
      if (!mounted) return;
      ToastService.showSuccess(
        'Đã ghi nhận thu ${_debtCurrencyFormat.format(paid)}.',
      );
    } catch (_) {
      if (!mounted) return;
      ToastService.showError(
        'Không thể ghi nhận thu nợ. Vui lòng thử lại sau.',
      );
    } finally {
      if (mounted) {
        setState(() => _isRecordingPayment = false);
      }
    }
  }

  Future<void> _sendZaloReminder(
    Map<String, dynamic> item,
    double remaining,
  ) async {
    final phone = (item['customerPhone']?.toString() ?? '').replaceAll(
      RegExp(r'\D'),
      '',
    );
    if (phone.isEmpty) {
      ToastService.showError('Khách hàng chưa có số điện thoại.');
      return;
    }

    final message =
        'Xin chào ${item['customerName']}, cửa hàng xin gửi thông tin đơn '
        '${item['orderCode']} còn ${_debtCurrencyFormat.format(remaining)}. '
        'Xin vui lòng kiểm tra và thanh toán. Cảm ơn quý khách!';
    final uri = Uri.https('zalo.me', '/$phone', {'text': message});
    final launched = await launchUrl(uri);
    if (!launched) {
      ToastService.showError('Không thể mở Zalo để gửi nhắc nợ.');
    }
  }
}

class _DesktopDebtRow extends StatelessWidget {
  final Map<String, dynamic> item;
  final double total;
  final double paid;
  final double remaining;
  final bool isRecordingPayment;
  final VoidCallback onCollect;
  final VoidCallback onRemind;

  const _DesktopDebtRow({
    required this.item,
    required this.total,
    required this.paid,
    required this.remaining,
    required this.isRecordingPayment,
    required this.onCollect,
    required this.onRemind,
  });

  double _asDouble(dynamic value) =>
      num.tryParse(value?.toString() ?? '0')?.toDouble() ?? 0;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final canCollect =
        !isRecordingPayment &&
        (_asDouble(item['orderId']) > 0 || _asDouble(item['id']) > 0);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['customerName']?.toString() ?? 'Khách hàng',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  item['customerPhone']?.toString() ?? '',
                  style: TextStyle(color: colors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              item['orderCode']?.toString() ?? '—',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: AppStatusBadge(
                label: customerDebtDueLabel(item),
                color:
                    (int.tryParse(item['daysOverdue']?.toString() ?? '0') ??
                                0) >
                            0 ||
                        item['status'] == 'OVERDUE'
                    ? AppColors.danger
                    : AppColors.info,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _debtCurrencyFormat.format(total),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _debtCurrencyFormat.format(paid),
              textAlign: TextAlign.right,
              style: const TextStyle(color: AppColors.success, fontSize: 12),
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _debtCurrencyFormat.format(remaining),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                if (customerDebtAdjustmentLabel(item) case final String label)
                  Tooltip(
                    message: '$label. Không tính là tiền đã thu.',
                    child: Text(
                      label,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                OutlinedButton(
                  onPressed: canCollect ? onCollect : null,
                  child: const Text('Thu nợ'),
                ),
                TextButton(onPressed: onRemind, child: const Text('Nhắc nợ')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileDebtList extends StatelessWidget {
  final List<Map<String, dynamic>> debts;
  final bool isRecordingPayment;
  final double Function(dynamic value) asDouble;
  final void Function(Map<String, dynamic> item, double remaining) onCollect;
  final Future<void> Function(Map<String, dynamic> item, double remaining)
  onRemind;

  const _MobileDebtList({
    required this.debts,
    required this.isRecordingPayment,
    required this.asDouble,
    required this.onCollect,
    required this.onRemind,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return AppCardContainer(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              'Danh sách khoản phải thu',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Divider(height: 1, color: colors.divider),
          for (var index = 0; index < debts.length; index++)
            _MobileDebtRow(
              item: debts[index],
              isRecordingPayment: isRecordingPayment,
              asDouble: asDouble,
              showDivider: index < debts.length - 1,
              onCollect: onCollect,
              onRemind: onRemind,
            ),
        ],
      ),
    );
  }
}

class _MobileDebtRow extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isRecordingPayment;
  final double Function(dynamic value) asDouble;
  final bool showDivider;
  final void Function(Map<String, dynamic> item, double remaining) onCollect;
  final Future<void> Function(Map<String, dynamic> item, double remaining)
  onRemind;

  const _MobileDebtRow({
    required this.item,
    required this.isRecordingPayment,
    required this.asDouble,
    required this.showDivider,
    required this.onCollect,
    required this.onRemind,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final total = asDouble(item['totalAmount']);
    final paid = asDouble(item['paidAmount']);
    final remaining = customerDebtRemaining(item);
    final canCollect =
        !isRecordingPayment &&
        (asDouble(item['orderId']) > 0 || asDouble(item['id']) > 0);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(bottom: BorderSide(color: colors.divider))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['customerName']?.toString() ?? 'Khách hàng',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if ((item['customerPhone']?.toString() ?? '').isNotEmpty)
                      Text(
                        item['customerPhone'].toString(),
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                item['orderCode']?.toString() ?? '—',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppStatusBadge(
            label: customerDebtDueLabel(item),
            color:
                (int.tryParse(item['daysOverdue']?.toString() ?? '0') ?? 0) >
                        0 ||
                    item['status'] == 'OVERDUE'
                ? AppColors.danger
                : AppColors.info,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Còn phải thu',
            style: TextStyle(color: colors.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            _debtCurrencyFormat.format(remaining),
            style: const TextStyle(
              color: AppColors.warning,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _DebtValue(
                  label: 'Nợ gốc',
                  value: _debtCurrencyFormat.format(total),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _DebtValue(
                  label: 'Đã thu',
                  value: _debtCurrencyFormat.format(paid),
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          if (customerDebtAdjustmentLabel(item) case final String label)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                '$label · Không phải tiền đã thu.',
                style: TextStyle(color: colors.textSecondary, fontSize: 12),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: canCollect
                      ? () => onCollect(item, remaining)
                      : null,
                  child: const Text('Thu nợ'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextButton(
                  onPressed: () => onRemind(item, remaining),
                  child: const Text('Nhắc nợ'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DebtValue extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _DebtValue({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: colors.textSecondary, fontSize: 11),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color ?? colors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
