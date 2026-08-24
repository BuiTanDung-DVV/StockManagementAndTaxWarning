import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../assets/app_assets.dart';
import '../theme/app_theme.dart';
import '../utils/data_freshness.dart';

class DataFreshnessBanner extends StatelessWidget {
  final DataFreshnessAssessment assessment;
  final String dataLabel;

  const DataFreshnessBanner({
    super.key,
    required this.assessment,
    required this.dataLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (!assessment.requiresAttention) return const SizedBox.shrink();
    final colors = AppThemeColors.of(context);
    final theme = Theme.of(context);
    final latestLabel = assessment.latestDate == null
        ? null
        : DateFormat('dd/MM/yyyy').format(assessment.latestDate!);
    final missingPeriod = assessment.state == DataFreshnessState.missingPeriod;
    final unavailable = assessment.state == DataFreshnessState.unavailable;
    final title = unavailable
        ? 'Chưa xác định được độ mới dữ liệu $dataLabel'
        : missingPeriod
        ? 'Chưa có dữ liệu $dataLabel trong kỳ đang xem'
        : 'Dữ liệu $dataLabel chưa cập nhật đến cuối kỳ';
    final detail = unavailable
        ? 'Backend chưa trả ngày phát sinh gần nhất từ DB. Không nên coi KPI bằng 0 là kết quả đã xác minh.'
        : 'Phát sinh gần nhất trong DB: $latestLabel'
              '${assessment.daysBehind > 0 ? ' · cách cuối kỳ ${assessment.daysBehind} ngày' : ''}. '
              '${missingPeriod ? 'KPI bằng 0 có thể do chưa có dữ liệu mới.' : 'Các ngày còn thiếu chưa được tính vào KPI.'}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: AppAssetIcon(
              assetPath: AppAssets.storage,
              size: 20,
              color: AppColors.warning,
              semanticLabel: 'Cảnh báo độ mới dữ liệu',
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
