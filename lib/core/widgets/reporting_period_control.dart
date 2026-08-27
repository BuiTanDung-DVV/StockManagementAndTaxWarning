import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/reporting_period.dart';

class ReportingPeriodControl extends StatelessWidget {
  const ReportingPeriodControl({
    super.key,
    required this.selection,
    required this.currentLabel,
    required this.comparisonLabel,
    required this.onQuickPeriodChanged,
    required this.onOpenEditor,
  });

  final ReportingPeriodSelection selection;
  final String currentLabel;
  final String comparisonLabel;
  final ValueChanged<ReportingPeriodType> onQuickPeriodChanged;
  final VoidCallback onOpenEditor;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final periodName = reportingPeriodSelectionLabel(selection, DateTime.now());
    final comparisonName = reportingComparisonTypeLabel(
      selection.comparisonType,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 700;
        if (compact) {
          return Material(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: InkWell(
              key: const ValueKey('reporting-period-mobile-summary'),
              onTap: onOpenEditor,
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: colors.divider),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  boxShadow: const [AppTheme.diffusionShadow],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$periodName · $comparisonName',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$currentLabel · Đối chiếu $comparisonLabel',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Thay đổi',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: colors.divider),
            boxShadow: const [AppTheme.diffusionShadow],
          ),
          child: Row(
            children: [
              _QuickPeriodGroup(
                selection: selection,
                onChanged: onQuickPeriodChanged,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$periodName · $currentLabel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '$comparisonName · $comparisonLabel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              OutlinedButton(
                key: const ValueKey('reporting-period-open-editor'),
                onPressed: onOpenEditor,
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 11,
                  ),
                ),
                child: const Text('Tùy chỉnh'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QuickPeriodGroup extends StatelessWidget {
  const _QuickPeriodGroup({required this.selection, required this.onChanged});

  final ReportingPeriodSelection selection;
  final ValueChanged<ReportingPeriodType> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    const quickPeriods = [
      ReportingPeriodType.month,
      ReportingPeriodType.quarter,
      ReportingPeriodType.year,
    ];
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: colors.cardAlt,
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final type in quickPeriods)
            _PeriodChoice(
              type: type,
              selected: selection.periodType == type,
              onTap: () => onChanged(type),
            ),
        ],
      ),
    );
  }
}

class _PeriodChoice extends StatelessWidget {
  const _PeriodChoice({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final ReportingPeriodType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final label = reportingPeriodTypeLabel(type);
    return Semantics(
      button: true,
      selected: selected,
      label: 'Xem theo $label',
      child: Material(
        color: selected ? colors.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.control - 2),
        child: InkWell(
          key: ValueKey('reporting-period-${type.name}'),
          onTap: selected ? null : onTap,
          borderRadius: BorderRadius.circular(AppRadius.control - 2),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected ? colors.textPrimary : colors.textSecondary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<ReportingPeriodSelection?> showReportingPeriodEditor(
  BuildContext context, {
  required ReportingPeriodSelection selection,
  required DateTime today,
}) {
  final compact = MediaQuery.sizeOf(context).width < 700;
  final editor = _ReportingPeriodEditor(selection: selection, today: today);
  if (compact) {
    return showModalBottomSheet<ReportingPeriodSelection>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => editor,
    );
  }
  return showDialog<ReportingPeriodSelection>(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: editor,
      ),
    ),
  );
}

class _ReportingPeriodEditor extends StatefulWidget {
  const _ReportingPeriodEditor({required this.selection, required this.today});

  final ReportingPeriodSelection selection;
  final DateTime today;

  @override
  State<_ReportingPeriodEditor> createState() => _ReportingPeriodEditorState();
}

class _ReportingPeriodEditorState extends State<_ReportingPeriodEditor> {
  late ReportingPeriodType _periodType;
  late DateTime _anchorDate;
  late ReportingComparisonType _comparisonType;
  late DateTime _comparisonFrom;
  late DateTime _comparisonTo;

  @override
  void initState() {
    super.initState();
    _periodType = widget.selection.periodType;
    _anchorDate = widget.selection.anchorDate;
    _comparisonType = widget.selection.comparisonType;
    final initialComparison = reportingInitialCustomComparison(
      widget.selection,
      today: widget.today,
    );
    _comparisonFrom = initialComparison.from;
    _comparisonTo = initialComparison.to;
  }

  DateTime get _today =>
      DateTime(widget.today.year, widget.today.month, widget.today.day);

  Future<void> _pickAnchorDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _anchorDate.isAfter(_today) ? _today : _anchorDate,
      firstDate: DateTime(_today.year - 5),
      lastDate: _today,
      helpText: 'Chọn ngày thuộc kỳ cần xem',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
    );
    if (picked != null && mounted) setState(() => _anchorDate = picked);
  }

  Future<void> _pickComparisonDate({required bool start}) async {
    final initial = start ? _comparisonFrom : _comparisonTo;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(_today) ? _today : initial,
      firstDate: DateTime(_today.year - 5),
      lastDate: _today,
      helpText: start ? 'Chọn ngày bắt đầu' : 'Chọn ngày kết thúc',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (start) {
        _comparisonFrom = picked;
        if (_comparisonTo.isBefore(picked)) _comparisonTo = picked;
      } else {
        _comparisonTo = picked;
        if (_comparisonFrom.isAfter(picked)) _comparisonFrom = picked;
      }
    });
  }

  void _apply() {
    Navigator.of(context).pop(
      ReportingPeriodSelection(
        periodType: _periodType,
        anchorDate: _anchorDate,
        comparisonType: _comparisonType,
        customComparisonFrom: _comparisonType == ReportingComparisonType.custom
            ? _comparisonFrom
            : null,
        customComparisonTo: _comparisonType == ReportingComparisonType.custom
            ? _comparisonTo
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(AppRadius.dialog),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + bottomInset),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Phạm vi số liệu',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Chọn kỳ cần xem và mốc dùng để đối chiếu.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Xem theo', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final type in ReportingPeriodType.values)
                    ChoiceChip(
                      key: ValueKey('editor-period-${type.name}'),
                      label: Text(reportingPeriodTypeLabel(type)),
                      selected: _periodType == type,
                      onSelected: (_) => setState(() => _periodType = type),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _EditorField(
                label: 'Kỳ đang xem',
                value: reportingRangeLabel(
                  resolveReportingPeriods(
                    ReportingPeriodSelection(
                      periodType: _periodType,
                      anchorDate: _anchorDate,
                      comparisonType: ReportingComparisonType.previousPeriod,
                    ),
                    today: _today,
                  ).currentFrom,
                  resolveReportingPeriods(
                    ReportingPeriodSelection(
                      periodType: _periodType,
                      anchorDate: _anchorDate,
                      comparisonType: ReportingComparisonType.previousPeriod,
                    ),
                    today: _today,
                  ).currentTo,
                ),
                onTap: _pickAnchorDate,
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<ReportingComparisonType>(
                key: const ValueKey('editor-comparison-type'),
                initialValue: _comparisonType,
                decoration: const InputDecoration(labelText: 'So sánh với'),
                items: [
                  for (final type in ReportingComparisonType.values)
                    DropdownMenuItem(
                      value: type,
                      child: Text(reportingComparisonTypeLabel(type)),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _comparisonType = value);
                },
              ),
              if (_comparisonType == ReportingComparisonType.custom) ...[
                const SizedBox(height: AppSpacing.md),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 460;
                    final fields = [
                      _EditorField(
                        label: 'Từ ngày',
                        value: _formatDate(_comparisonFrom),
                        onTap: () => _pickComparisonDate(start: true),
                      ),
                      _EditorField(
                        label: 'Đến ngày',
                        value: _formatDate(_comparisonTo),
                        onTap: () => _pickComparisonDate(start: false),
                      ),
                    ];
                    if (compact) {
                      return Column(
                        children: [
                          fields.first,
                          const SizedBox(height: AppSpacing.sm),
                          fields.last,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: fields.first),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: fields.last),
                      ],
                    );
                  },
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Hủy'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton(
                    key: const ValueKey('reporting-period-apply'),
                    onPressed: _apply,
                    child: const Text('Áp dụng'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditorField extends StatelessWidget {
  const _EditorField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    return Material(
      color: colors.inputFill,
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            border: Border.all(color: colors.inputBorder),
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: colors.textMuted),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatDate(DateTime value) {
  String twoDigits(int part) => part.toString().padLeft(2, '0');
  return '${twoDigits(value.day)}/${twoDigits(value.month)}/${value.year}';
}
