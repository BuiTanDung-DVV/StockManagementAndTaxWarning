import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/guides/feature_guide_sheet.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/parse_utils.dart';
import '../providers/finance_provider.dart';

class DailyClosingScreen extends ConsumerStatefulWidget {
  const DailyClosingScreen({super.key});

  @override
  ConsumerState<DailyClosingScreen> createState() => _DailyClosingScreenState();
}

class _DailyClosingScreenState extends ConsumerState<DailyClosingScreen> {
  final _closingCashController = TextEditingController();
  final _notesController = TextEditingController();
  double _closingCash = 0;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _closingCashController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _fmt(num v) => NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0).format(v);

  Future<void> _submitClosing(double expectedCash, double openingCash, double cashIncome, double cashExpense, double totalIncome, double totalExpense, int orderCount, String today) async {
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    final cashDifference = _closingCash - expectedCash;

    if (cashDifference.abs() > 50000 && _notesController.text.trim().isEmpty) {
      setState(() {
        _submitting = false;
        _errorMessage = 'Chênh lệch két vượt quá 50,000đ. Vui lòng nhập lý do giải trình vào phần ghi chú.';
      });
      return;
    }

    try {
      final repo = ref.read(financeRepoProvider);
      final dto = {
        'closingDate': today,
        'openingCash': openingCash,
        'closingCash': _closingCash,
        'expectedCash': expectedCash,
        'cashDifference': cashDifference,
        'totalIncome': totalIncome,
        'totalExpense': totalExpense,
        'totalSales': totalIncome, // Assuming sales match total income here or from POS
        'orderCount': orderCount,
        'notes': _notesController.text.trim(),
        'closedAt': DateTime.now().toIso8601String(),
      };

      final res = await repo.createDailyClosing(dto);
      if (res['success'] == true || res['id'] != null) {
        ref.invalidate(dailyClosingProvider(today));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã thực hiện chốt ca thành công và khóa sổ ngày hôm nay!')),
          );
        }
      } else {
        setState(() {
          _errorMessage = res['message'] ?? 'Chốt ca thất bại';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Kết ca & Khóa sổ',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20, color: c.textPrimary),
        ),
        centerTitle: true,
        actions: [featureGuideButton(context, 'daily_closing')],
      ),
      body: closingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e', style: TextStyle(color: AppColors.danger))),
        data: (data) {
          final totalIncome = asNum(data['totalIncome']);
          final totalExpense = asNum(data['totalExpense']);
          final cashIncome = asNum(data['cashIncome']);
          final cashExpense = asNum(data['cashExpense']);
          final bankIncome = asNum(data['bankIncome']);
          final bankExpense = asNum(data['bankExpense']);
          final netProfit = totalIncome - totalExpense;
          final orderCount = (data['orderCount'] as num?)?.toInt() ?? 0;
          final closed = data['closed'] == true;
          final transactions = data['transactions'] as List? ?? [];

          // Opening & expected cash calculations from backend
          final openingCash = asNum(data['openingCash']);
          final expectedCash = asNum(data['expectedCash']);
          
          // Calculated local variables
          final localDifference = _closingCash - expectedCash;
          final needsNotes = localDifference.abs() > 50000;

          if (closed) {
            final closedOpeningCash = asNum(data['openingCash']);
            final closedClosingCash = asNum(data['closingCash']);
            final closedExpectedCash = asNum(data['expectedCash']);
            final closedDifference = asNum(data['cashDifference']);
            final closedNotes = data['notes'] ?? '';

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
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
                        colors: [AppColors.success, AppColors.success.withValues(alpha: 0.8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.success.withValues(alpha: 0.25),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(today, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 10),
                        Text(_fmt(netProfit), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                        const Text('Lợi nhuận ròng trong ngày', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_outline, color: Colors.white, size: 16),
                              SizedBox(width: 6),
                              Text('ĐÃ KẾT CA & KHÓA SỔ', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Cash summary details
                  Text('Chi tiết két tiền mặt vật lý', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary)),
                  const SizedBox(height: 12),
                  _DetailRow('Tiền mặt đầu ca (A)', _fmt(closedOpeningCash), true),
                  _DetailRow('Thu tiền mặt trong ca (+)', _fmt(cashIncome), true),
                  _DetailRow('Chi tiền mặt trong ca (-)', _fmt(cashExpense), false),
                  _DetailRow('Tiền mặt sổ sách dự kiến (B)', _fmt(closedExpectedCash), true),
                  _DetailRow('Tiền mặt thực tế kiểm kê (C)', _fmt(closedClosingCash), true),
                  
                  // Difference item
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: closedDifference == 0 
                          ? c.card 
                          : (closedDifference > 0 ? AppColors.success.withValues(alpha: 0.05) : AppColors.danger.withValues(alpha: 0.05)),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: closedDifference == 0 
                            ? c.divider.withValues(alpha: 0.4) 
                            : (closedDifference > 0 ? AppColors.success.withValues(alpha: 0.2) : AppColors.danger.withValues(alpha: 0.2)),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Chênh lệch két (C - B)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: c.textPrimary)),
                        Text(
                          _fmt(closedDifference),
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: closedDifference == 0 
                                ? c.textPrimary 
                                : (closedDifference > 0 ? AppColors.success : AppColors.danger),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (closedNotes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('Giải trình chênh lệch', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: c.textSecondary)),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: c.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: c.divider.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        closedNotes,
                        style: TextStyle(fontSize: 13, color: c.textPrimary, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  Text('Thống kê tài khoản chuyển khoản', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary)),
                  const SizedBox(height: 12),
                  _DetailRow('Thu chuyển khoản (Bank/Wallet)', _fmt(bankIncome), true),
                  _DetailRow('Chi chuyển khoản (Bank/Wallet)', _fmt(bankExpense), false),

                  const SizedBox(height: 24),
                  if (transactions.isNotEmpty) ...[
                    Text('Giao dịch chi tiết hôm nay', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary)),
                    const SizedBox(height: 12),
                    ...transactions.map<Widget>((t) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: c.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: c.divider.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t['category'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(height: 2),
                              Text('${t['paymentMethod'] ?? 'CASH'} • ${t['counterparty'] ?? ''}', style: TextStyle(color: c.textSecondary, fontSize: 11)),
                            ],
                          ),
                          Text(
                            _fmt(asNum(t['amount'])),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: t['type'] == 'INCOME' ? AppColors.success : AppColors.danger,
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                ],
              ),
            );
          }

          // Case: Not closed yet, display the wizard / form
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Expected Summary Cards
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.15)),
                  ),
                  child: Column(
                    children: [
                      Text('SỔ SÁCH TIỀN MẶT HÔM NAY', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                      const SizedBox(height: 8),
                      Text(_fmt(expectedCash), style: GoogleFonts.outfit(fontSize: 30, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                      const SizedBox(height: 4),
                      Text('Tiền mặt két dự kiến (Đầu ca + Thu - Chi tiền mặt)', style: TextStyle(color: c.textSecondary, fontSize: 11)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Cash breakdown metrics
                Row(
                  children: [
                    Expanded(child: _SummaryTile('Đầu ca', _fmt(openingCash), c.textPrimary, Icons.account_balance_wallet)),
                    const SizedBox(width: 12),
                    Expanded(child: _SummaryTile('Thu mặt', _fmt(cashIncome), AppColors.success, Icons.add_circle_outline)),
                    const SizedBox(width: 12),
                    Expanded(child: _SummaryTile('Chi mặt', _fmt(cashExpense), AppColors.danger, Icons.remove_circle_outline)),
                  ],
                ),
                const SizedBox(height: 24),

                // Count input
                Text('Đối soát tiền mặt thực tế', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary)),
                const SizedBox(height: 12),
                
                TextField(
                  controller: _closingCashController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: c.card,
                    hintText: 'Nhập số tiền mặt thực tế tại két',
                    prefixIcon: Icon(Icons.calculate, color: theme.colorScheme.primary),
                    suffixText: 'VNĐ',
                    suffixStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: c.divider.withValues(alpha: 0.6)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                    ),
                  ),
                  onChanged: (v) {
                    setState(() {
                      _closingCash = double.tryParse(v) ?? 0;
                    });
                  },
                ),
                const SizedBox(height: 18),

                // Difference indicator
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: localDifference == 0 
                        ? c.card 
                        : (localDifference > 0 ? AppColors.success.withValues(alpha: 0.05) : AppColors.danger.withValues(alpha: 0.05)),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: localDifference == 0 
                          ? c.divider.withValues(alpha: 0.5) 
                          : (localDifference > 0 ? AppColors.success.withValues(alpha: 0.25) : AppColors.danger.withValues(alpha: 0.25)),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Chênh lệch két (Thực tế - Dự kiến):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      Text(
                        _fmt(localDifference),
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: localDifference == 0 
                              ? c.textPrimary 
                              : (localDifference > 0 ? AppColors.success : AppColors.danger),
                        ),
                      ),
                    ],
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
                      border: Border.all(color: AppColors.danger.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.w500),
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
                    Text('Ghi chú / Giải trình', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: c.textPrimary)),
                    if (needsNotes) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                        child: const Text('BẮT BUỘC', style: TextStyle(color: AppColors.danger, fontSize: 9, fontWeight: FontWeight.bold)),
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
                        ? 'Giải trình chênh lệch két tiền mặt > 50,000đ tại đây...'
                        : 'Nhập ghi chú chốt ca (nếu có)...',
                    contentPadding: const EdgeInsets.all(16),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(
                        color: needsNotes ? AppColors.danger.withValues(alpha: 0.5) : c.divider.withValues(alpha: 0.6),
                        width: needsNotes ? 1.5 : 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(
                        color: needsNotes ? AppColors.danger : theme.colorScheme.primary,
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
                    onPressed: _submitting 
                        ? null 
                        : () => _submitClosing(expectedCash.toDouble(), openingCash.toDouble(), cashIncome.toDouble(), cashExpense.toDouble(), totalIncome.toDouble(), totalExpense.toDouble(), orderCount, today),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 0,
                    ),
                    child: _submitting 
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.lock_outline, size: 18),
                              const SizedBox(width: 8),
                              Text('Chốt ca & Khóa sổ', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;
  const _SummaryTile(this.label, this.value, this.color, this.icon);

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.divider.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(color: c.textSecondary, fontSize: 10, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label, amount;
  final bool isIncome;
  const _DetailRow(this.label, this.amount, this.isIncome);

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    return Container(
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
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: c.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            amount,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: isIncome ? AppColors.success : AppColors.danger,
            ),
          ),
        ],
      ),
    );
  }
}
