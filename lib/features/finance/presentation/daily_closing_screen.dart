import '../../../core/assets/app_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/guides/feature_guide_sheet.dart';
import '../../../core/utils/finance_display.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/parse_utils.dart';
import '../../../core/utils/toast_service.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/widgets/app_navigation_back_button.dart';
import '../domain/closing_cash_assessment.dart';
import '../providers/finance_provider.dart';

class DailyClosingScreen extends ConsumerStatefulWidget {
  const DailyClosingScreen({super.key});

  @override
  ConsumerState<DailyClosingScreen> createState() => _DailyClosingScreenState();
}

class _DailyClosingScreenState extends ConsumerState<DailyClosingScreen> {
  final _closingCashController = TextEditingController();
  final _notesController = TextEditingController();
  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _closingCashController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _fmt(num v) => NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  ).format(v);

  Future<void> _submitClosing(
    double expectedCash,
    double openingCash,
    double cashIncome,
    double cashExpense,
    double totalIncome,
    double totalExpense,
    double totalSales,
    double totalReturns,
    int orderCount,
    String today,
    double explanationThreshold,
  ) async {
    final assessment = assessClosingCash(
      rawActualCash: _closingCashController.text,
      expectedCash: expectedCash,
    );
    if (!assessment.canSubmit) {
      setState(() {
        _errorMessage = 'Vui lòng nhập số tiền mặt thực tế hợp lệ.';
      });
      return;
    }
    final closingCash = assessment.actualCash!;

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    final cashDifference = closingCash - expectedCash;

    if (cashDifference.abs() > explanationThreshold &&
        _notesController.text.trim().isEmpty) {
      setState(() {
        _submitting = false;
        _errorMessage =
            'Chênh lệch két lớn hơn ${_fmt(explanationThreshold)}. Vui lòng nhập lý do giải trình vào phần ghi chú.';
      });
      return;
    }

    try {
      final repo = ref.read(financeRepoProvider);
      final dto = {
        'closingDate': today,
        'openingCash': openingCash,
        'closingCash': closingCash,
        'expectedCash': expectedCash,
        'cashDifference': cashDifference,
        'totalIncome': totalIncome,
        'totalExpense': totalExpense,
        'totalSales': totalSales,
        'totalReturns': totalReturns,
        'orderCount': orderCount,
        'notes': _notesController.text.trim(),
        'closedAt': DateTime.now().toIso8601String(),
      };

      final res = await repo.createDailyClosing(dto);
      if (res['success'] == true || res['id'] != null) {
        ref.invalidate(dailyClosingProvider(today));
        ref.invalidate(dailyClosingsListProvider(1)); // Refresh the list
        if (mounted) {
          ToastService.showSuccess(
            'Đã thực hiện chốt ca thành công và khóa sổ ngày hôm nay!',
          );
        }
      } else {
        final msg = res['message']?.toString() ?? 'Chốt ca thất bại';
        setState(() => _errorMessage = msg);
        ToastService.showError(msg);
      }
    } catch (e) {
      final err = e.toString().replaceAll('Exception: ', '');
      setState(() => _errorMessage = err);
      ToastService.showError(err);
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);
    final today = DateTime.now().toIso8601String().split('T').first;
    final closingAsync = ref.watch(dailyClosingProvider(today));

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: Navigator.of(context).canPop() ? 60 : null,
        leading: Navigator.of(context).canPop()
            ? AppNavigationBackLeading(
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: Text(
          'Kết ca & Khóa sổ',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: c.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [featureGuideButton(context, 'daily_closing')],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: closingAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: AppInlineError(
                  message:
                      'Không thể tải dữ liệu kết ca. Vui lòng thử lại sau.',
                  onRetry: () async {
                    ref.invalidate(dailyClosingProvider(today));
                    ref.invalidate(dailyClosingsListProvider(1));
                  },
                ),
              ),
            ),
            data: (data) {
              final totalIncome = asNum(data['totalIncome']);
              final totalExpense = asNum(data['totalExpense']);
              final cashIncome = asNum(data['cashIncome']);
              final cashExpense = asNum(data['cashExpense']);
              final bankIncome = asNum(data['bankIncome']);
              final bankExpense = asNum(data['bankExpense']);
              final totalSales = asNum(data['totalSales']);
              final totalReturns = asNum(data['totalReturns']);
              final netCashFlow = totalIncome - totalExpense;
              final orderCount = (data['orderCount'] as num?)?.toInt() ?? 0;
              final closed = data['closed'] == true;
              final transactions = data['transactions'] as List? ?? [];
              final orders = data['orders'] as List? ?? [];
              final returns = data['returns'] as List? ?? [];

              // Opening & expected cash calculations from backend
              final openingCash = asNum(data['openingCash']);
              final expectedCash = asNum(data['expectedCash']);
              final explanationThreshold = asNum(data['explanationThreshold']);

              // Calculated local variables
              final closingAssessment = assessClosingCash(
                rawActualCash: _closingCashController.text,
                expectedCash: expectedCash.toDouble(),
                explanationThreshold: explanationThreshold.toDouble(),
              );
              final localDifference = closingAssessment.difference;
              final differenceValue = localDifference ?? 0;
              final hasAssessment = localDifference != null;
              final needsNotes = closingAssessment.needsExplanation;

              if (closed) {
                final closedOpeningCash = asNum(data['openingCash']);
                final closedClosingCash = asNum(data['closingCash']);
                final closedExpectedCash = asNum(data['expectedCash']);
                final closedDifference = asNum(data['cashDifference']);
                final closedNotes = data['notes'] ?? '';

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(dailyClosingProvider(today));
                    ref.invalidate(dailyClosingsListProvider(1));
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Closed Badge Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.success,
                                AppColors.success.withValues(alpha: 0.8),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.success.withValues(
                                  alpha: 0.25,
                                ),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Text(
                                today,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _fmt(netCashFlow),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text(
                                'Chênh lệch thu – chi trong ngày',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Bao gồm mọi khoản thu, chi đã ghi nhận. Xem lợi nhuận tại Kết quả kinh doanh.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    AppIcon(
                                      Icons.check_circle_outline,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'ĐÃ KẾT CA & KHÓA SỔ',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Cash summary details
                        Text(
                          'Chi tiết két tiền mặt vật lý',
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: c.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _DetailRow(
                          'Tiền mặt đầu ca (A)',
                          _fmt(closedOpeningCash),
                          true,
                          onTap: () => _showOpeningCashDetail(
                            context: context,
                            openingCash: closedOpeningCash.toDouble(),
                          ),
                        ),
                        _DetailRow(
                          'Thu tiền mặt trong ca (+)',
                          _fmt(cashIncome),
                          true,
                          onTap: () => _showCashTransactionsDetail(
                            context: context,
                            title: 'Chi tiết thu tiền mặt trong ca',
                            isIncome: true,
                            total: cashIncome.toDouble(),
                            transactions: transactions,
                          ),
                        ),
                        _DetailRow(
                          'Chi tiền mặt trong ca (-)',
                          _fmt(cashExpense),
                          false,
                          onTap: () => _showCashTransactionsDetail(
                            context: context,
                            title: 'Chi tiết chi tiền mặt trong ca',
                            isIncome: false,
                            total: cashExpense.toDouble(),
                            transactions: transactions,
                          ),
                        ),
                        _DetailRow(
                          'Tiền mặt sổ sách dự kiến (B)',
                          _fmt(closedExpectedCash),
                          true,
                          onTap: () => _showExpectedCashDetail(
                            context: context,
                            expectedCash: closedExpectedCash.toDouble(),
                            openingCash: closedOpeningCash.toDouble(),
                            cashIncome: cashIncome.toDouble(),
                            cashExpense: cashExpense.toDouble(),
                            explanationThreshold: explanationThreshold
                                .toDouble(),
                          ),
                        ),
                        _DetailRow(
                          'Tiền mặt thực tế kiểm kê (C)',
                          _fmt(closedClosingCash),
                          true,
                        ),

                        // Difference item
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: closedDifference == 0
                                ? c.card
                                : (closedDifference > 0
                                      ? AppColors.success.withValues(
                                          alpha: 0.05,
                                        )
                                      : AppColors.danger.withValues(
                                          alpha: 0.05,
                                        )),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: closedDifference == 0
                                  ? c.divider.withValues(alpha: 0.4)
                                  : (closedDifference > 0
                                        ? AppColors.success.withValues(
                                            alpha: 0.2,
                                          )
                                        : AppColors.danger.withValues(
                                            alpha: 0.2,
                                          )),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Chênh lệch két (C - B)',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: c.textPrimary,
                                ),
                              ),
                              Text(
                                _fmt(closedDifference),
                                style: GoogleFonts.manrope(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: closedDifference == 0
                                      ? c.textPrimary
                                      : (closedDifference > 0
                                            ? AppColors.success
                                            : AppColors.danger),
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (closedNotes.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            'Giải trình chênh lệch',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: c.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: c.card,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: c.divider.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Text(
                              closedNotes,
                              style: TextStyle(
                                fontSize: 13,
                                color: c.textPrimary,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),
                        Text(
                          'Thống kê tài khoản chuyển khoản',
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: c.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _DetailRow(
                          'Thu chuyển khoản (Bank/Wallet)',
                          _fmt(bankIncome),
                          true,
                        ),
                        _DetailRow(
                          'Chi chuyển khoản (Bank/Wallet)',
                          _fmt(bankExpense),
                          false,
                        ),

                        const SizedBox(height: 24),
                        if (transactions.isNotEmpty) ...[
                          Text(
                            'Giao dịch chi tiết hôm nay',
                            style: GoogleFonts.manrope(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: c.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...transactions.map<Widget>(
                            (t) => Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: c.card,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: c.divider.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        financeCategoryLabel(
                                          t['category']?.toString(),
                                        ),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${t['paymentMethod'] ?? 'CASH'} • ${t['counterparty'] ?? ''}',
                                        style: TextStyle(
                                          color: c.textSecondary,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    _fmt(asNum(t['amount'])),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: t['type'] == 'INCOME'
                                          ? AppColors.success
                                          : AppColors.danger,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }

              // Case: Not closed yet, display the wizard / form
              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(dailyClosingProvider(today));
                  ref.invalidate(dailyClosingsListProvider(1));
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Expected Summary Cards
                      Material(
                        color: Colors.transparent,
                        child: Ink(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.08,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.15,
                              ),
                            ),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: () => _showExpectedCashDetail(
                              context: context,
                              expectedCash: expectedCash.toDouble(),
                              openingCash: openingCash.toDouble(),
                              cashIncome: cashIncome.toDouble(),
                              cashExpense: cashExpense.toDouble(),
                              explanationThreshold: explanationThreshold
                                  .toDouble(),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(22),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'TIỀN MẶT DỰ KIẾN HÔM NAY',
                                        style: GoogleFonts.manrope(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      AppIcon(
                                        Icons.info_outline,
                                        size: 15,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _fmt(expectedCash),
                                    style: GoogleFonts.manrope(
                                      fontSize: 30,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Tiền đầu ngày + Thu tiền mặt − Chi tiền mặt',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: c.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Bấm để xem cơ cấu đối soát dòng tiền két',
                                          style: TextStyle(
                                            color: theme.colorScheme.primary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        AppIcon(
                                          Icons.chevron_right,
                                          size: 14,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Cash breakdown metrics
                      _ClosingMetricGroup(
                        children: [
                          _SummaryTile(
                            'Tiền đầu ngày',
                            _fmt(openingCash),
                            c.textPrimary,
                            Icons.account_balance_wallet,
                            onTap: () => _showOpeningCashDetail(
                              context: context,
                              openingCash: openingCash.toDouble(),
                            ),
                          ),
                          _SummaryTile(
                            'Thu tiền mặt',
                            _fmt(cashIncome),
                            AppColors.success,
                            Icons.add_circle_outline,
                            onTap: () => _showCashTransactionsDetail(
                              context: context,
                              title: 'Chi tiết thu tiền mặt trong ca',
                              isIncome: true,
                              total: cashIncome.toDouble(),
                              transactions: transactions,
                            ),
                          ),
                          _SummaryTile(
                            'Chi tiền mặt',
                            _fmt(cashExpense),
                            AppColors.danger,
                            Icons.remove_circle_outline,
                            onTap: () => _showCashTransactionsDetail(
                              context: context,
                              title: 'Chi tiết chi tiền mặt trong ca',
                              isIncome: false,
                              total: cashExpense.toDouble(),
                              transactions: transactions,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Hoạt động bán hàng trong ngày',
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: c.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _ClosingMetricGroup(
                        children: [
                          _SummaryTile(
                            'Giá trị đơn lập',
                            _fmt(totalSales),
                            theme.colorScheme.primary,
                            Icons.receipt_long_outlined,
                            onTap: () => _showOrdersDetail(
                              context: context,
                              totalSales: totalSales.toDouble(),
                              orderCount: orderCount,
                              orders: orders,
                            ),
                          ),
                          _SummaryTile(
                            'Giá trị hàng trả',
                            _fmt(totalReturns),
                            AppColors.warning,
                            Icons.assignment_return_outlined,
                            onTap: () => _showReturnsDetail(
                              context: context,
                              totalReturns: totalReturns.toDouble(),
                              returns: returns,
                            ),
                          ),
                          _SummaryTile(
                            'Đơn hợp lệ',
                            NumberFormat.decimalPattern(
                              'vi_VN',
                            ).format(orderCount),
                            c.textPrimary,
                            Icons.shopping_bag_outlined,
                            onTap: () => _showOrdersDetail(
                              context: context,
                              totalSales: totalSales.toDouble(),
                              orderCount: orderCount,
                              orders: orders,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      Text(
                        'Đơn lập trong ngày chưa trừ hàng trả. Hàng trả tính sau giảm giá, gồm thuế hàng hóa; không gồm phí giao. Tiền hoàn đã tính trong chi.',
                        style: TextStyle(fontSize: 13, color: c.textSecondary),
                      ),
                      const SizedBox(height: 20),

                      // Count input
                      Text(
                        'Đối soát tiền mặt thực tế',
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: c.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: _closingCashController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                        ],
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: c.textPrimary,
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: c.card,
                          hintText: 'Nhập số tiền mặt thực tế tại két',
                          helperText:
                              hasAssessment &&
                                  closingAssessment.actualCash != null &&
                                  closingAssessment.actualCash! > 0
                              ? 'Đã nhận dạng: ${_fmt(closingAssessment.actualCash!)}'
                              : null,
                          helperStyle: GoogleFonts.manrope(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                          prefixIcon: AppIcon(
                            Icons.calculate,
                            color: theme.colorScheme.primary,
                          ),
                          suffixText: 'VNĐ',
                          suffixStyle: GoogleFonts.manrope(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(
                              color: c.divider.withValues(alpha: 0.6),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(
                              color: theme.colorScheme.primary,
                              width: 2,
                            ),
                          ),
                        ),
                        onChanged: (v) {
                          setState(() {
                            _errorMessage = null;
                          });
                        },
                      ),
                      const SizedBox(height: 18),

                      // Difference indicator
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: !hasAssessment || differenceValue == 0
                              ? c.card
                              : (differenceValue > 0
                                    ? AppColors.success.withValues(alpha: 0.05)
                                    : AppColors.danger.withValues(alpha: 0.05)),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: !hasAssessment || differenceValue == 0
                                ? c.divider.withValues(alpha: 0.5)
                                : (differenceValue > 0
                                      ? AppColors.success.withValues(
                                          alpha: 0.25,
                                        )
                                      : AppColors.danger.withValues(
                                          alpha: 0.25,
                                        )),
                          ),
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            const label = Text(
                              'Chênh lệch két (Thực tế − Dự kiến)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                            final value = Text(
                              !hasAssessment
                                  ? 'Chưa đối soát'
                                  : differenceValue == 0
                                  ? 'Khớp quỹ (${_fmt(0)})'
                                  : _fmt(differenceValue),
                              textAlign: TextAlign.right,
                              style: GoogleFonts.manrope(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: !hasAssessment || differenceValue == 0
                                    ? c.textSecondary
                                    : differenceValue > 0
                                    ? AppColors.success
                                    : AppColors.danger,
                              ),
                            );
                            if (constraints.maxWidth < 500 ||
                                MediaQuery.textScalerOf(context).scale(14) >
                                    18) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  label,
                                  const SizedBox(height: 8),
                                  value,
                                ],
                              );
                            }
                            return Row(
                              children: [
                                const Expanded(child: label),
                                const SizedBox(width: 12),
                                value,
                              ],
                            );
                          },
                        ),
                      ),

                      // Error Message if any
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.danger.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              const AppIcon(
                                Icons.error_outline,
                                color: AppColors.danger,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: AppColors.danger,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Dynamic Notes input based on discrepancy warning
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Text(
                            'Ghi chú / Giải trình',
                            style: GoogleFonts.manrope(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: c.textPrimary,
                            ),
                          ),
                          if (needsNotes) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.danger.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'BẮT BUỘC',
                                style: TextStyle(
                                  color: AppColors.danger,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _notesController,
                        maxLines: 3,
                        style: TextStyle(fontSize: 13, color: c.textPrimary),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: c.card,
                          hintText: needsNotes
                              ? 'Giải trình chênh lệch két tiền mặt tại đây...'
                              : 'Nhập ghi chú chốt ca (nếu có)...',
                          contentPadding: const EdgeInsets.all(16),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(
                              color: needsNotes
                                  ? AppColors.danger.withValues(alpha: 0.5)
                                  : c.divider.withValues(alpha: 0.6),
                              width: needsNotes ? 1.5 : 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(
                              color: needsNotes
                                  ? AppColors.danger
                                  : theme.colorScheme.primary,
                              width: 2,
                            ),
                          ),
                        ),
                        onChanged: (v) {
                          if (needsNotes && v.trim().isNotEmpty) {
                            setState(() {
                              _errorMessage = null;
                            });
                          }
                        },
                      ),

                      // Action Submit Button
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _submitting || !closingAssessment.canSubmit
                              ? null
                              : () => _submitClosing(
                                  expectedCash.toDouble(),
                                  openingCash.toDouble(),
                                  cashIncome.toDouble(),
                                  cashExpense.toDouble(),
                                  totalIncome.toDouble(),
                                  totalExpense.toDouble(),
                                  totalSales.toDouble(),
                                  totalReturns.toDouble(),
                                  orderCount,
                                  today,
                                  explanationThreshold.toDouble(),
                                ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 0,
                          ),
                          child: _submitting
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const AppIcon(Icons.lock_outline, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Chốt ca & Khóa sổ',
                                      style: GoogleFonts.manrope(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ClosingMetricGroup extends StatelessWidget {
  final List<_SummaryTile> children;
  const _ClosingMetricGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            constraints.maxWidth < 640 ||
            MediaQuery.textScalerOf(context).scale(14) > 18;
        if (stacked) {
          return Container(
            decoration: BoxDecoration(
              color: c.card,
              border: Border.all(color: c.divider),
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: c.divider),
                  _SummaryTile(
                    children[i].label,
                    children[i].value,
                    children[i].color,
                    children[i].icon,
                    compact: true,
                    onTap: children[i].onTap,
                  ),
                ],
              ],
            ),
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: children[i]),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;
  final bool compact;
  final VoidCallback? onTap;

  const _SummaryTile(
    this.label,
    this.value,
    this.color,
    this.icon, {
    this.compact = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final labelWidget = Row(
      children: [
        AppIcon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: c.textSecondary, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (onTap != null)
          AppIcon(
            Icons.chevron_right,
            size: 16,
            color: c.textSecondary.withValues(alpha: 0.5),
          ),
      ],
    );
    final valueWidget = Text(
      value,
      textAlign: compact ? TextAlign.right : TextAlign.left,
      style: GoogleFonts.manrope(
        fontWeight: FontWeight.w700,
        fontSize: 16,
        color: color,
      ),
    );

    final innerChild = compact
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Expanded(flex: 6, child: labelWidget),
                const SizedBox(width: 12),
                Expanded(flex: 5, child: valueWidget),
              ],
            ),
          )
        : Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [labelWidget, const SizedBox(height: 10), valueWidget],
            ),
          );

    final cardDecoration = BoxDecoration(
      color: c.card,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: c.divider),
    );

    if (compact) {
      if (onTap != null) {
        return Tooltip(
          message: 'Bấm để xem chi tiết $label',
          child: InkWell(onTap: onTap, child: innerChild),
        );
      }
      return innerChild;
    }

    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: 'Bấm để xem chi tiết $label',
        child: Ink(
          decoration: cardDecoration,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: innerChild,
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label, amount;
  final bool isIncome;
  final VoidCallback? onTap;

  const _DetailRow(this.label, this.amount, this.isIncome, {this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final content = Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.divider.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: c.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            amount,
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: isIncome ? AppColors.success : AppColors.danger,
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 6),
            AppIcon(
              Icons.chevron_right,
              size: 16,
              color: c.textSecondary.withValues(alpha: 0.4),
            ),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: content,
      );
    }
    return content;
  }
}

void _showDailyClosingDetailModal(
  BuildContext context, {
  required String title,
  required IconData icon,
  required Widget content,
  Widget? bottomAction,
}) {
  final c = AppThemeColors.of(context);
  final isDesktop = MediaQuery.sizeOf(context).width >= 600;

  Widget buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: AppIcon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: c.textPrimary,
              ),
            ),
          ),
          IconButton(
            icon: const AppIcon(Icons.close, size: 20),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Đóng',
          ),
        ],
      ),
    );
  }

  Widget buildBody() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildHeader(),
        Divider(height: 1, color: c.divider.withValues(alpha: 0.6)),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: content,
          ),
        ),
        if (bottomAction != null) ...[
          Divider(height: 1, color: c.divider.withValues(alpha: 0.6)),
          Padding(padding: const EdgeInsets.all(16), child: bottomAction),
        ],
      ],
    );
  }

  if (isDesktop) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        backgroundColor: c.card,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 580,
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.85,
          ),
          child: buildBody(),
        ),
      ),
    );
  } else {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: c.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.85,
        ),
        child: buildBody(),
      ),
    );
  }
}

void _showExpectedCashDetail({
  required BuildContext context,
  required double expectedCash,
  required double openingCash,
  required double cashIncome,
  required double cashExpense,
  required double explanationThreshold,
}) {
  final c = AppThemeColors.of(context);
  final theme = Theme.of(context);
  final fmt = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  );

  _showDailyClosingDetailModal(
    context,
    title: 'Cơ cấu Tiền mặt Dự kiến Tại Két',
    icon: Icons.calculate_outlined,
    content: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            children: [
              Text(
                'TIỀN MẶT DỰ KIẾN TRONG KÉT',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                fmt.format(expectedCash),
                style: GoogleFonts.manrope(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Số dư lý thuyết trên sổ sách cần có trong két khi kết ca',
                style: TextStyle(fontSize: 12, color: c.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Công thức tính đối soát',
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: c.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        _buildFormulaRow(
          context,
          icon: Icons.account_balance_wallet_outlined,
          iconColor: c.textPrimary,
          label: 'Tiền mặt đầu ngày (A)',
          sub: 'Số dư thực tế bàn giao từ ca trước',
          amount: fmt.format(openingCash),
          amountColor: c.textPrimary,
          prefix: '+ ',
        ),
        const SizedBox(height: 8),
        _buildFormulaRow(
          context,
          icon: Icons.add_circle_outline,
          iconColor: AppColors.success,
          label: 'Thu tiền mặt trong ca (+)',
          sub: 'Tổng các khoản tiền mặt đã thu trong ngày',
          amount: fmt.format(cashIncome),
          amountColor: AppColors.success,
          prefix: '+ ',
        ),
        const SizedBox(height: 8),
        _buildFormulaRow(
          context,
          icon: Icons.remove_circle_outline,
          iconColor: AppColors.danger,
          label: 'Chi tiền mặt trong ca (-)',
          sub: 'Tổng các khoản tiền mặt đã chi trong ngày',
          amount: fmt.format(cashExpense),
          amountColor: AppColors.danger,
          prefix: '- ',
        ),
        const SizedBox(height: 12),
        Divider(color: c.divider),
        const SizedBox(height: 8),
        _buildFormulaRow(
          context,
          icon: Icons.savings_outlined,
          iconColor: theme.colorScheme.primary,
          label: 'Tiền mặt dự kiến (B = A + Thu - Chi)',
          sub: 'Số tiền đối chiếu với két kiểm kê thực tế',
          amount: fmt.format(expectedCash),
          amountColor: theme.colorScheme.primary,
          prefix: '= ',
          isTotal: true,
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.divider.withValues(alpha: 0.5)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppIcon(
                Icons.info_outline,
                size: 18,
                color: AppColors.warning,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Khi kết ca, vui lòng kiểm kê tiền mặt thực tế trong két và nhập vào ô đối soát. Nếu chênh lệch > ${fmt.format(explanationThreshold)}, hệ thống sẽ yêu cầu nhập giải trình lý do trước khi khóa sổ.',
                  style: TextStyle(
                    fontSize: 12,
                    color: c.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

void _showOpeningCashDetail({
  required BuildContext context,
  required double openingCash,
}) {
  final c = AppThemeColors.of(context);
  final fmt = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  );

  _showDailyClosingDetailModal(
    context,
    title: 'Chi tiết Tiền Mặt Đầu Ngày',
    icon: Icons.account_balance_wallet,
    content: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.divider),
          ),
          child: Column(
            children: [
              AppIcon(
                Icons.account_balance_wallet,
                size: 36,
                color: AppColors.primary,
              ),
              const SizedBox(height: 10),
              Text(
                'Số dư tiền mặt đầu ngày',
                style: TextStyle(fontSize: 13, color: c.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                fmt.format(openingCash),
                style: GoogleFonts.manrope(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: c.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Quy tắc xác định số dư đầu ngày',
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: c.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        _buildInfoBullet(
          context,
          title: 'Kết chuyển từ ca trước:',
          desc:
              'Số tiền mặt đầu ngày được chuyển tiếp trực tiếp từ số tiền mặt kiểm kê thực tế tại két khi chốt ca hôm trước.',
        ),
        const SizedBox(height: 10),
        _buildInfoBullet(
          context,
          title: 'Đảm bảo tính liên tục:',
          desc:
              'Dòng tiền két được xâu chuỗi liên tục giữa các phiên làm việc, giúp phát hiện sớm chênh lệch hoặc thất thoát tiền mặt.',
        ),
        const SizedBox(height: 10),
        _buildInfoBullet(
          context,
          title: 'Khởi tạo số dư ban đầu:',
          desc:
              'Nếu là ngày đầu tiên sử dụng phần mềm, số tiền này được lấy từ Số dư đầu kỳ thiết lập tại phân hệ Sổ quỹ.',
        ),
      ],
    ),
    bottomAction: OutlinedButton.icon(
      onPressed: () {
        Navigator.of(context).pop();
        context.push('/finance');
      },
      icon: const AppIcon(Icons.account_balance_wallet_outlined, size: 18),
      label: const Text('Xem Sổ quỹ chi tiết'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
}

void _showCashTransactionsDetail({
  required BuildContext context,
  required String title,
  required bool isIncome,
  required double total,
  required List<dynamic> transactions,
}) {
  final c = AppThemeColors.of(context);
  final color = isIncome ? AppColors.success : AppColors.danger;
  final icon = isIncome
      ? Icons.arrow_downward_rounded
      : Icons.arrow_upward_rounded;
  final fmt = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  );

  final list = transactions.where((t) {
    final type = t['type']?.toString().toUpperCase();
    final method = (t['paymentMethod'] ?? 'CASH').toString().toUpperCase();
    final matchesType = isIncome ? type == 'INCOME' : type == 'EXPENSE';
    final matchesMethod = method == 'CASH';
    return matchesType && matchesMethod;
  }).toList();

  _showDailyClosingDetailModal(
    context,
    title: title,
    icon: icon,
    content: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isIncome ? 'Tổng thu tiền mặt' : 'Tổng chi tiền mặt',
                    style: TextStyle(fontSize: 12, color: c.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fmt.format(total),
                    style: GoogleFonts.manrope(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${list.length} giao dịch',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (list.isEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(
              children: [
                AppIcon(
                  Icons.receipt_long_outlined,
                  size: 48,
                  color: c.textSecondary.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 12),
                Text(
                  isIncome
                      ? 'Chưa ghi nhận khoản thu tiền mặt nào hôm nay'
                      : 'Chưa ghi nhận khoản chi tiền mặt nào hôm nay',
                  style: TextStyle(fontSize: 13, color: c.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ] else ...[
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, idx) {
              final item = list[idx];
              final amount = asNum(item['amount']);
              final category = item['category']?.toString();
              final counterparty = item['counterparty']?.toString();
              final desc = item['description']?.toString();
              final refCode = item['referenceCode']?.toString();
              final dateStr =
                  item['createdAt']?.toString() ??
                  item['transactionDate']?.toString();

              String timeDisplay = '';
              if (dateStr != null && dateStr.isNotEmpty) {
                try {
                  final dt = DateTime.parse(dateStr).toLocal();
                  timeDisplay = DateFormat('HH:mm').format(dt);
                } catch (_) {
                  timeDisplay = '';
                }
              }

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: c.divider.withValues(alpha: 0.6)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: AppIcon(icon, color: color, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            financeCategoryLabel(category),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [
                              if (timeDisplay.isNotEmpty) timeDisplay,
                              if (counterparty != null &&
                                  counterparty.isNotEmpty)
                                counterparty,
                              if (refCode != null && refCode.isNotEmpty)
                                refCode,
                            ].join(' • '),
                            style: TextStyle(
                              fontSize: 11,
                              color: c.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (desc != null &&
                              desc.isNotEmpty &&
                              desc != counterparty) ...[
                            const SizedBox(height: 2),
                            Text(
                              desc,
                              style: TextStyle(
                                fontSize: 11,
                                color: c.textSecondary.withValues(alpha: 0.8),
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${isIncome ? '+' : '-'}${fmt.format(amount)}',
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ],
    ),
    bottomAction: ElevatedButton.icon(
      onPressed: () {
        Navigator.of(context).pop();
        context.push('/finance');
      },
      icon: const AppIcon(Icons.account_balance_wallet_outlined, size: 18),
      label: const Text('Xem tất cả tại Sổ Quỹ'),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
}

void _showOrdersDetail({
  required BuildContext context,
  required double totalSales,
  required int orderCount,
  required List<dynamic> orders,
}) {
  final c = AppThemeColors.of(context);
  final theme = Theme.of(context);
  final fmt = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  );

  _showDailyClosingDetailModal(
    context,
    title: 'Hoạt Động Đơn Hàng Hôm Nay',
    icon: Icons.receipt_long_outlined,
    content: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tổng giá trị đơn lập',
                    style: TextStyle(fontSize: 12, color: c.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fmt.format(totalSales),
                    style: GoogleFonts.manrope(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$orderCount đơn hợp lệ',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (orders.isEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(
              children: [
                AppIcon(
                  Icons.shopping_bag_outlined,
                  size: 48,
                  color: c.textSecondary.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 12),
                Text(
                  'Chưa có đơn hàng nào được lập trong ngày hôm nay',
                  style: TextStyle(fontSize: 13, color: c.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ] else ...[
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: orders.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, idx) {
              final o = orders[idx];
              final code = o['orderCode']?.toString() ?? 'Đơn hàng';
              final customer = o['customerName']?.toString() ?? 'Khách lẻ';
              final time = o['time']?.toString() ?? '';
              final amount = asNum(o['totalAmount']);
              final method = o['paymentMethod']?.toString() ?? 'CASH';

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: c.divider.withValues(alpha: 0.6)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: AppIcon(
                        Icons.receipt_outlined,
                        color: theme.colorScheme.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                code,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (time.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Text(
                                  '• $time',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: c.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$customer • ${method == 'CASH' ? 'Tiền mặt' : 'Chuyển khoản'}',
                            style: TextStyle(
                              fontSize: 11,
                              color: c.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      fmt.format(amount),
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
        const SizedBox(height: 14),
        Text(
          'Đơn lập trong ngày chưa trừ hàng trả. Không tính các đơn đã hủy.',
          style: TextStyle(
            fontSize: 11,
            color: c.textSecondary,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ),
    bottomAction: ElevatedButton.icon(
      onPressed: () {
        Navigator.of(context).pop();
        context.push('/sales');
      },
      icon: const AppIcon(Icons.list_alt_rounded, size: 18),
      label: const Text('Xem Quản lý Đơn hàng'),
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
}

void _showReturnsDetail({
  required BuildContext context,
  required double totalReturns,
  required List<dynamic> returns,
}) {
  final c = AppThemeColors.of(context);
  final fmt = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  );

  _showDailyClosingDetailModal(
    context,
    title: 'Hàng Khách Trả Hôm Nay',
    icon: Icons.assignment_return_outlined,
    content: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tổng giá trị hàng trả',
                    style: TextStyle(fontSize: 12, color: c.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fmt.format(totalReturns),
                    style: GoogleFonts.manrope(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${returns.length} phiếu trả',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (returns.isEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(
              children: [
                AppIcon(
                  Icons.assignment_turned_in_outlined,
                  size: 48,
                  color: c.textSecondary.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 12),
                Text(
                  'Hôm nay không có phát sinh trả hàng',
                  style: TextStyle(fontSize: 13, color: c.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ] else ...[
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: returns.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, idx) {
              final r = returns[idx];
              final code = r['returnCode']?.toString() ?? 'Phiếu trả';
              final orderCode = r['orderCode']?.toString();
              final reason = r['reason']?.toString() ?? 'Khách trả hàng';
              final time = r['time']?.toString() ?? '';
              final amount = asNum(r['refundAmount']);
              final method = r['refundMethod']?.toString() ?? 'CASH';

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: c.divider.withValues(alpha: 0.6)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const AppIcon(
                        Icons.assignment_return_outlined,
                        color: AppColors.warning,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                code,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (time.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Text(
                                  '• $time',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: c.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [
                              if (orderCode != null && orderCode.isNotEmpty)
                                'Đơn: $orderCode',
                              reason,
                              method == 'CASH' ? 'Tiền mặt' : 'Chuyển khoản',
                            ].join(' • '),
                            style: TextStyle(
                              fontSize: 11,
                              color: c.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      fmt.format(amount),
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.warning,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
        const SizedBox(height: 14),
        Text(
          'Hàng trả tính sau giảm giá, gồm thuế hàng hóa; không gồm phí giao. Tiền hoàn đã tính trong chi.',
          style: TextStyle(
            fontSize: 11,
            color: c.textSecondary,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ),
    bottomAction: ElevatedButton.icon(
      onPressed: () {
        Navigator.of(context).pop();
        context.push('/sales');
      },
      icon: const AppIcon(Icons.assignment_return_outlined, size: 18),
      label: const Text('Xem Quản lý Đơn hàng & Trả hàng'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.warning,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
}

Widget _buildFormulaRow(
  BuildContext context, {
  required IconData icon,
  required Color iconColor,
  required String label,
  required String sub,
  required String amount,
  required Color amountColor,
  required String prefix,
  bool isTotal = false,
}) {
  final c = AppThemeColors.of(context);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: isTotal
        ? BoxDecoration(
            color: iconColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          )
        : null,
    child: Row(
      children: [
        AppIcon(icon, size: 18, color: iconColor),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(sub, style: TextStyle(fontSize: 11, color: c.textSecondary)),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$prefix$amount',
          style: GoogleFonts.manrope(
            fontSize: isTotal ? 16 : 14,
            fontWeight: FontWeight.bold,
            color: amountColor,
          ),
        ),
      ],
    ),
  );
}

Widget _buildInfoBullet(
  BuildContext context, {
  required String title,
  required String desc,
}) {
  final c = AppThemeColors.of(context);
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: c.card,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: c.divider.withValues(alpha: 0.5)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          desc,
          style: TextStyle(fontSize: 12, color: c.textSecondary, height: 1.4),
        ),
      ],
    ),
  );
}
