import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/excel_export_service.dart';
import '../../../core/utils/toast_service.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../../../core/widgets/responsive_layout.dart';

final _debtCurrencyFormat = NumberFormat.currency(
  locale: 'vi_VN',
  symbol: '₫',
  decimalDigits: 0,
);

class CustomerDebtScreen extends ConsumerStatefulWidget {
  const CustomerDebtScreen({super.key});

  @override
  ConsumerState<CustomerDebtScreen> createState() => _CustomerDebtScreenState();
}

class _CustomerDebtScreenState extends ConsumerState<CustomerDebtScreen> {
  List<Map<String, dynamic>> _debts = [];
  bool _isLoading = true;
  bool _isRecordingPayment = false;
  bool _isExporting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDebts());
  }

  double _asDouble(dynamic value) =>
      num.tryParse(value?.toString() ?? '0')?.toDouble() ?? 0;

  Future<void> _loadDebts({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final data = await ref
          .read(apiClientProvider)
          .get('/customer-receivables');
      if (data is! List) {
        throw const FormatException('Dữ liệu công nợ không đúng định dạng');
      }

      final debts = data
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      if (!mounted) return;
      setState(() {
        _debts = debts;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = error is ApiException
            ? error.message
            : 'Dữ liệu công nợ không hợp lệ. Vui lòng thử lại.';
      });
    }
  }

  Widget _buildPageHeader() {
    return AppPageHeader(
      title: 'Công nợ khách hàng',
      subtitle:
          'Theo dõi khoản cần thu, ghi nhận thanh toán và nhắc nợ theo từng đơn hàng.',
      action: OutlinedButton(
        onPressed: _isExporting || _debts.isEmpty ? null : _exportDebts,
        child: Text(_isExporting ? 'Đang xuất…' : 'Xuất Excel'),
      ),
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
    final colors = AppThemeColors.of(context);
    var totalPaid = 0.0;
    var totalRemaining = 0.0;

    for (final debt in _debts) {
      final total = _asDouble(debt['totalAmount']);
      final paid = _asDouble(debt['paidAmount']);
      totalPaid += paid;
      totalRemaining += (total - paid).clamp(0, double.infinity).toDouble();
    }

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
                        minItemWidth: 230,
                        maxColumns: 3,
                        itemHeight: 112,
                        children: [
                          AppKpiCard(
                            title: 'Tổng nợ cần thu',
                            value: _debtCurrencyFormat.format(totalRemaining),
                            color: AppColors.warning,
                            assetPath: AppAssets.cash,
                            badgeText: 'Cần thu',
                          ),
                          AppKpiCard(
                            title: 'Đã thu hồi',
                            value: _debtCurrencyFormat.format(totalPaid),
                            color: AppColors.success,
                            assetPath: AppAssets.profit,
                            badgeText: 'Đã thu',
                          ),
                          AppKpiCard(
                            title: 'Khách hàng còn nợ',
                            value: '${_debts.length} khách',
                            color: AppColors.primary,
                            assetPath: AppAssets.orders,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      if (_debts.isEmpty)
                        AppCardContainer(
                          child: AppEmpty(
                            message: 'Không có khoản công nợ cần thu',
                            subtitle:
                                'Các đơn bán chịu hoặc thanh toán chưa đủ sẽ xuất hiện tại đây.',
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
                              return _MobileDebtList(
                                debts: _debts,
                                isRecordingPayment: _isRecordingPayment,
                                asDouble: _asDouble,
                                onCollect: (item, remaining) =>
                                    _showRepayDialog(context, item, remaining),
                                onRemind: _sendZaloReminder,
                              );
                            }

                            return AppDataTable<Map<String, dynamic>>(
                              title: 'Danh sách khoản phải thu',
                              assetPath: AppAssets.cash,
                              iconColor: AppColors.warning,
                              columns: const [
                                AppDataTableColumn(
                                  title: 'KHÁCH HÀNG / SĐT',
                                  flex: 3,
                                ),
                                AppDataTableColumn(title: 'MÃ ĐƠN', flex: 2),
                                AppDataTableColumn(
                                  title: 'TỔNG NỢ',
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
                                final total = _asDouble(item['totalAmount']);
                                final paid = _asDouble(item['paidAmount']);
                                final remaining = (total - paid)
                                    .clamp(0, double.infinity)
                                    .toDouble();

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
    if (_isExporting || _debts.isEmpty) return;
    setState(() => _isExporting = true);
    try {
      final launched = await ExcelExportService.exportCustomerDebtsToExcel(
        _debts,
      );
      if (!mounted) return;
      if (launched) {
        ToastService.showSuccess('Đã tạo file Excel sổ nợ.');
      } else {
        ToastService.showError(
          'Trình duyệt không cho phép tải file. Vui lòng thử lại.',
        );
      }
    } catch (_) {
      if (mounted) {
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
      text: remaining.toStringAsFixed(0),
    );
    var selectedMethod = 'CASH';
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
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
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Số tiền thu lần này (VNĐ)',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
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
                final paid = double.tryParse(controller.text) ?? 0;
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
    final orderId = _asDouble(item['orderId']).toInt();
    setState(() => _isRecordingPayment = true);
    try {
      await ref
          .read(apiClientProvider)
          .post(
            '/sales-orders/$orderId/payments',
            data: {
              'amount': paid,
              'method': method,
              'notes': 'Thu nợ từ sổ theo dõi nợ khách hàng',
            },
          );
      await _loadDebts(showLoading: false);
      if (!mounted) return;
      ToastService.showSuccess(
        'Đã ghi nhận thu ${_debtCurrencyFormat.format(paid)}.',
      );
    } catch (error) {
      if (!mounted) return;
      ToastService.showError('Không thể ghi nhận thu nợ: $error');
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
    final canCollect = !isRecordingPayment && _asDouble(item['orderId']) > 0;

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
            child: Text(
              _debtCurrencyFormat.format(remaining),
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.warning,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
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
    final remaining = (total - paid).clamp(0, double.infinity).toDouble();
    final canCollect = !isRecordingPayment && asDouble(item['orderId']) > 0;

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
                  label: 'Tổng nợ',
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
