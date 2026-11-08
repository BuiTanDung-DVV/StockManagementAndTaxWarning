import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/assets/app_icon.dart';
import '../../../core/theme/app_theme.dart';

class CashflowPlanList extends StatefulWidget {
  final List plans;
  final String asOf;
  final String throughDate;
  final ValueChanged<int> onDelete;
  const CashflowPlanList({
    super.key,
    required this.plans,
    required this.asOf,
    required this.throughDate,
    required this.onDelete,
  });
  @override
  State<CashflowPlanList> createState() => _CashflowPlanListState();
}

class _CashflowPlanListState extends State<CashflowPlanList> {
  String _range = 'period';
  String _day(Map plan) => '${plan['forecastDate']}'.split('T').first;
  String _money(dynamic value) => NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  ).format(num.tryParse('$value') ?? 0);

  void _showPlanDetailDialog(BuildContext context, Map plan) {
    final colors =
        Theme.of(context).extension<AppThemeColors>() ?? AppThemeColors.light;
    final theme = Theme.of(context);
    final date = DateTime.tryParse(_day(plan));
    final dateStr = date == null
        ? _day(plan)
        : DateFormat('dd/MM/yyyy').format(date);
    final income = num.tryParse('${plan['expectedIncome']}') ?? 0;
    final expense = num.tryParse('${plan['expectedExpense']}') ?? 0;
    final net = income - expense;
    final notes = plan['notes']?.toString();

    final dayKey = _day(plan);
    final isPast = dayKey.compareTo(widget.asOf) <= 0;
    final isBeyond = dayKey.compareTo(widget.throughDate) > 0;

    final statusText = isPast
        ? 'Đã qua ngày dự kiến'
        : isBeyond
        ? 'Ngoài kỳ dự báo 30 ngày'
        : 'Trong kỳ dự báo';
    final statusColor = isPast
        ? AppColors.warning
        : isBeyond
        ? colors.textSecondary
        : AppColors.success;
    final statusBg = isPast
        ? AppColors.warning.withValues(alpha: 0.12)
        : isBeyond
        ? colors.cardAlt
        : AppColors.success.withValues(alpha: 0.12);

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.event_note_outlined,
                size: 20,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Expanded(
              child: Text(
                'Chi tiết kế hoạch bổ sung',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: colors.cardAlt,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(color: colors.divider),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ngày dự kiến: $dateStr',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Mã kế hoạch: #${plan['id']}',
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(
                            AppRadius.control,
                          ),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                // Stat cards: Thu, Chi
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: colors.bg,
                          borderRadius: BorderRadius.circular(
                            AppRadius.control,
                          ),
                          border: Border.all(color: colors.divider),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'THU DỰ KIẾN',
                              style: TextStyle(
                                color: colors.textMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _money(income),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: colors.bg,
                          borderRadius: BorderRadius.circular(
                            AppRadius.control,
                          ),
                          border: Border.all(color: colors.divider),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CHI DỰ KIẾN',
                              style: TextStyle(
                                color: colors.textMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _money(expense),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: AppColors.danger,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                // Net cashflow card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: colors.bg,
                    borderRadius: BorderRadius.circular(AppRadius.control),
                    border: Border.all(color: colors.divider),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'DÒNG TIỀN THUẦN (THU − CHI):',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${net >= 0 ? '+' : ''}${_money(net)}',
                        style: TextStyle(
                          color: net >= 0
                              ? AppColors.success
                              : AppColors.danger,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (notes != null && notes.trim().isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Ghi chú:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: colors.bg,
                      borderRadius: BorderRadius.circular(AppRadius.control),
                      border: Border.all(color: colors.divider),
                    ),
                    child: SelectableText(
                      notes,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Text(
                  isPast
                      ? 'ℹ️ Kế hoạch này đã qua ngày dự kiến, hệ thống không cộng vào dự báo 30 ngày tới.'
                      : isBeyond
                      ? 'ℹ️ Kế hoạch này nằm ngoài phạm vi 30 ngày của kỳ dự báo hiện tại.'
                      : 'ℹ️ Kế hoạch này nằm trong kỳ dự báo và đã được tính vào đường xu hướng số dư dự kiến.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          OutlinedButton.icon(
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text('Xóa kế hoạch'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger),
            ),
            onPressed: () {
              Navigator.pop(dialogCtx);
              widget.onDelete(int.parse('${plan['id']}'));
            },
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<AppThemeColors>() ?? AppThemeColors.light;
    final plans =
        widget.plans
            .whereType<Map>()
            .where(
              (p) =>
                  _range == 'all' ||
                  (_range == 'past'
                      ? _day(p).compareTo(widget.asOf) <= 0
                      : _day(p).compareTo(widget.asOf) > 0 &&
                            _day(p).compareTo(widget.throughDate) <= 0),
            )
            .toList()
          ..sort((a, b) => _day(a).compareTo(_day(b)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 250,
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _range,
                decoration: const InputDecoration(
                  labelText: 'Phạm vi kế hoạch',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'period',
                    child: Text('Trong kỳ dự báo'),
                  ),
                  DropdownMenuItem(
                    value: 'past',
                    child: Text('Đã qua ngày dự kiến'),
                  ),
                  DropdownMenuItem(
                    value: 'all',
                    child: Text('Tất cả thời gian'),
                  ),
                ],
                onChanged: (v) => setState(() => _range = v ?? 'period'),
              ),
            ),
            Text(
              '${plans.length}/${widget.plans.length} kế hoạch',
              style: TextStyle(
                color: colors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: colors.cardAlt,
                borderRadius: BorderRadius.circular(AppRadius.control),
                border: Border.all(color: colors.divider),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.touch_app_outlined,
                    size: 13,
                    color: colors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Nhấn dòng xem chi tiết',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (plans.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Chưa có kế hoạch bổ sung trong phạm vi này.'),
          )
        else
          SizedBox(
            height: 320,
            child: Scrollbar(
              child: ListView.separated(
                primary: false,
                itemCount: plans.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final p = plans[index];
                  final date = DateTime.tryParse(_day(p));
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _showPlanDetailDialog(context, p),
                      mouseCursor: SystemMouseCursors.click,
                      hoverColor: colors.cardAlt.withValues(alpha: 0.7),
                      child: ListTile(
                        title: Text(
                          date == null
                              ? _day(p)
                              : DateFormat('dd/MM/yyyy').format(date),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          'Thu ${_money(p['expectedIncome'])} · Chi ${_money(p['expectedExpense'])}${_day(p).compareTo(widget.asOf) <= 0
                              ? '\nĐã qua ngày dự kiến, không cộng vào kỳ tới.'
                              : _day(p).compareTo(widget.throughDate) > 0
                              ? '\nNgoài kỳ dự báo đang xem.'
                              : ''}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Xóa kế hoạch bổ sung',
                              icon: const AppIcon(Icons.delete_outline),
                              onPressed: () =>
                                  widget.onDelete(int.parse('${p['id']}')),
                            ),
                            Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: colors.textMuted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
