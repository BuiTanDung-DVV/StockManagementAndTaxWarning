import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/excel_export_service.dart';
import '../../../core/utils/toast_service.dart';
import '../../../core/widgets/app_ui_components.dart';

final _currFmt = NumberFormat.currency(
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e is ApiException
            ? e.message
            : 'Dữ liệu công nợ không hợp lệ. Vui lòng thử lại.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final isMobile = MediaQuery.sizeOf(context).width < 700;

    double totalPaid = 0;
    double totalRemaining = 0;
    for (final d in _debts) {
      final total = _asDouble(d['totalAmount']);
      final paid = _asDouble(d['paidAmount']);
      totalPaid += paid;
      totalRemaining += (total - paid).clamp(0, double.infinity).toDouble();
    }

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: Text(
          isMobile ? 'Sổ nợ khách hàng' : 'Sổ Theo Dõi Nợ Khách Hàng',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: c.surface,
        elevation: 0,
        actions: [
          Padding(
            padding: EdgeInsets.only(right: isMobile ? 8 : 16),
            child: isMobile
                ? IconButton(
                    onPressed: _isLoading || _isExporting || _debts.isEmpty
                        ? null
                        : _exportDebts,
                    tooltip: 'Xuất Excel sổ nợ',
                    icon: _isExporting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.table_chart_rounded),
                  )
                : ElevatedButton.icon(
                    onPressed: _isLoading || _isExporting || _debts.isEmpty
                        ? null
                        : _exportDebts,
                    icon: _isExporting
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.table_chart_rounded, size: 16),
                    label: const Text(
                      'Xuất Excel Sổ Nợ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                    ),
                  ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? _buildErrorState(c)
          : RefreshIndicator(
              onRefresh: _loadDebts,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // KPI Summary Row using LayoutBuilder for Mobile
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isMobile = constraints.maxWidth < 600;
                        if (isMobile) {
                          return Column(
                            children: [
                              AppKpiCard(
                                title: 'Tổng Nợ Cần Thu',
                                value: _currFmt.format(totalRemaining),
                                color: Colors.orange,
                                assetPath: 'assets/icon/cash_icon.svg',
                                badgeText: 'Cần thu',
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: AppKpiCard(
                                      title: 'Đã Thu Hồi',
                                      value: _currFmt.format(totalPaid),
                                      color: AppColors.success,
                                      assetPath: 'assets/icon/profit_icon.svg',
                                      badgeText: 'Đã thu',
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: AppKpiCard(
                                      title: 'Số Khách Nợ',
                                      value: '${_debts.length} khách',
                                      color: AppColors.primary,
                                      assetPath: 'assets/icon/orders_icon.svg',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(
                              child: AppKpiCard(
                                title: 'Tổng Nợ Cần Thu',
                                value: _currFmt.format(totalRemaining),
                                color: Colors.orange,
                                assetPath: 'assets/icon/cash_icon.svg',
                                badgeText: 'Cần thu',
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: AppKpiCard(
                                title: 'Đã Thu Hồi',
                                value: _currFmt.format(totalPaid),
                                color: AppColors.success,
                                assetPath: 'assets/icon/profit_icon.svg',
                                badgeText: 'Đã thu',
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: AppKpiCard(
                                title: 'Số Khách Nợ',
                                value: '${_debts.length} khách',
                                color: AppColors.primary,
                                assetPath: 'assets/icon/orders_icon.svg',
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // Data Table Section using unified AppDataTable
                    AppDataTable<Map<String, dynamic>>(
                      title: 'Bảng Danh Sách Khách Hàng Nợ Mua Chịu',
                      icon: HugeIcons.strokeRoundedBookOpen01,
                      iconColor: Colors.orange,
                      columns: const [
                        AppDataTableColumn(title: 'KHÁCH HÀNG / SĐT', flex: 3),
                        AppDataTableColumn(title: 'MÃ ĐƠN NỢ', flex: 2),
                        AppDataTableColumn(
                          title: 'TỔNG NỢ',
                          flex: 2,
                          alignRight: true,
                        ),
                        AppDataTableColumn(
                          title: 'ĐÃ TRẢ',
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
                      emptyMessage: 'Chưa có khoản công nợ khách hàng cần thu.',
                      rowBuilder: (context, item, index) {
                        final total = _asDouble(item['totalAmount']);
                        final paid = _asDouble(item['paidAmount']);
                        final remaining = (total - paid)
                            .clamp(0, double.infinity)
                            .toDouble();

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['customerName']?.toString() ??
                                          'Khách hàng',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      item['customerPhone']?.toString() ?? '',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: c.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  item['orderCode']?.toString() ?? '',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  _currFmt.format(total),
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  _currFmt.format(paid),
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 12,
                                    color: AppColors.success,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  _currFmt.format(remaining),
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    OutlinedButton(
                                      onPressed:
                                          _isRecordingPayment ||
                                              _asDouble(item['orderId']) <= 0
                                          ? null
                                          : () => _showRepayDialog(
                                              context,
                                              item,
                                              remaining,
                                            ),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        side: const BorderSide(
                                          color: AppColors.success,
                                        ),
                                      ),
                                      child: const Text(
                                        'Thu nợ',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.success,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    IconButton(
                                      onPressed: () =>
                                          _sendZaloReminder(item, remaining),
                                      icon: const HugeIcon(
                                        icon: HugeIcons.strokeRoundedComment01,
                                        color: Colors.blue,
                                        size: 18,
                                      ),
                                      tooltip: 'Nhắc nợ qua Zalo/SMS',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 88), // UI Breathing Room Padding
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildErrorState(AppThemeColors c) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: c.textMuted),
            const SizedBox(height: 12),
            Text(
              'Không thể tải dữ liệu công nợ',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _errorMessage ?? 'Vui lòng thử lại',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadDebts,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử lại'),
            ),
          ],
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
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            'Thu Nợ Khách Hàng',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Khách: ${item['customerName']}'),
              Text('Đơn hàng: ${item['orderCode']}'),
              Text(
                'Số nợ còn lại: ${_currFmt.format(remaining)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Số tiền thu lần này (VNĐ)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedMethod,
                decoration: const InputDecoration(
                  labelText: 'Phương thức thu tiền',
                  border: OutlineInputBorder(),
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
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                final paid = double.tryParse(controller.text) ?? 0;
                if (paid <= 0 || paid > remaining) {
                  ToastService.showError(
                    'Số tiền phải lớn hơn 0 và không vượt quá số nợ còn lại',
                  );
                  return;
                }
                Navigator.pop(ctx, {'amount': paid, 'method': selectedMethod});
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
              ),
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
              'notes': 'Thu nợ từ Sổ theo dõi nợ khách hàng',
            },
          );
      await _loadDebts(showLoading: false);
      if (!mounted) return;
      ToastService.showSuccess(
        'Đã ghi nhận thu ${_currFmt.format(paid)} thành công!',
      );
    } catch (e) {
      if (!mounted) return;
      ToastService.showError('Không thể ghi nhận thu nợ: $e');
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
      ToastService.showError('Khách hàng chưa có số điện thoại');
      return;
    }
    final message =
        'Xin chào ${item['customerName']}, Cửa hàng xin gửi thông tin nợ đơn hàng ${item['orderCode']} còn ${_currFmt.format(remaining)}. Xin vui lòng kiểm tra và thanh toán. Cảm ơn quý khách!';
    final uri = Uri.https('zalo.me', '/$phone', {'text': message});
    final launched = await launchUrl(uri);
    if (!launched) {
      ToastService.showError('Không thể mở Zalo để gửi nhắc nợ');
    }
  }
}
