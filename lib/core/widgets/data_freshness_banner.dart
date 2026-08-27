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
    final missingDaysLabel = assessment.daysBehind == 1
        ? '1 ngày cuối kỳ'
        : '${assessment.daysBehind} ngày cuối kỳ';
    final title = unavailable
        ? 'Chưa thể kiểm tra tình trạng $dataLabel'
        : missingPeriod
        ? 'Chưa có số liệu $dataLabel trong kỳ đã chọn'
        : 'Số liệu $dataLabel tạm tính đến $latestLabel';
    final detail = unavailable
        ? 'Bạn vẫn có thể xem số liệu hiện có. Hãy tải lại trước khi chốt báo cáo.'
        : missingPeriod
        ? 'Nếu kỳ này không phát sinh hoạt động, bạn không cần xử lý. Nếu có, hãy ghi nhận trước khi chốt báo cáo.'
        : 'Hãy kiểm tra $missingDaysLabel trước khi chốt báo cáo.';

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
              semanticLabel: 'Thông tin cần kiểm tra',
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
