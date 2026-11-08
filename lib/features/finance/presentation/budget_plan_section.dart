import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/search_text.dart';
import '../../../core/utils/toast_service.dart';
import '../../../core/widgets/app_animations.dart';
import '../providers/finance_provider.dart';

enum BudgetStatusFilter {
  all('Tất cả'),
  active('Đang áp dụng'),
  upcoming('Sắp tới'),
  past('Đã kết thúc');

  final String label;
  const BudgetStatusFilter(this.label);
}

class BudgetPlanSection extends ConsumerStatefulWidget {
  final bool embedded;
  final String? initialStatus;
  final String? initialYear;

  const BudgetPlanSection({
    super.key,
    this.embedded = false,
    this.initialStatus,
    this.initialYear,
  });

  @override
  ConsumerState<BudgetPlanSection> createState() => _BudgetPlanSectionState();
}

class _BudgetPlanSectionState extends ConsumerState<BudgetPlanSection> {
  final TextEditingController _searchController = TextEditingController();
  late BudgetStatusFilter _statusFilter;
  late String _yearFilter;
  int _currentPage = 1;
  static const int _pageSize = 10;

  final NumberFormat _currencyFmt = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  );
  final DateFormat _dateFmt = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _statusFilter = _parseInitialStatus(widget.initialStatus);
    _yearFilter = widget.initialYear ?? 'ALL';
    _searchController.addListener(_onSearchChanged);
  }

  BudgetStatusFilter _parseInitialStatus(String? status) {
    if (status == null) return BudgetStatusFilter.all;
    switch (status.toUpperCase()) {
      case 'ACTIVE':
        return BudgetStatusFilter.active;
      case 'UPCOMING':
        return BudgetStatusFilter.upcoming;
      case 'PAST':
        return BudgetStatusFilter.past;
      default:
        return BudgetStatusFilter.all;
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _currentPage = 1;
    });
  }

  BudgetStatusFilter _resolvePlanStatus(DateTime? start, DateTime? end) {
    if (start == null || end == null) return BudgetStatusFilter.past;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDate = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day, 23, 59, 59);

    if (today.isBefore(startDate)) return BudgetStatusFilter.upcoming;
    if (today.isAfter(endDate)) return BudgetStatusFilter.past;
    return BudgetStatusFilter.active;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final budgetAsync = ref.watch(budgetPlansProvider);

    return budgetAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (err, _) => Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: AppInlineError(
          message: 'Không thể tải dữ liệu kế hoạch ngân sách.',
          onRetry: () => ref.invalidate(budgetPlansProvider),
        ),
      ),
      data: (rawBudgets) {
        final budgets = rawBudgets.whereType<Map>().map((b) => Map<String, dynamic>.from(b)).toList();

        if (budgets.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(budgetPlansProvider),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: 380,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const AppEmpty(
                        visual: AppEmptyVisual.finance,
                        message: 'Chưa có kế hoạch ngân sách nào',
                        subtitle: 'Hãy bấm nút bên dưới để tạo kế hoạch đầu tiên cho cửa hàng.',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      FilledButton.icon(
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Thêm kế hoạch ngân sách'),
                        onPressed: () => _showAddBudgetDialog(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        // Trích xuất danh sách năm từ dữ liệu
        final yearsSet = <String>{};
        for (final b in budgets) {
          final s = DateTime.tryParse(b['startDate']?.toString() ?? '');
          if (s != null) yearsSet.add(s.year.toString());
          final e = DateTime.tryParse(b['endDate']?.toString() ?? '');
          if (e != null) yearsSet.add(e.year.toString());
        }
        final sortedYears = yearsSet.toList()..sort((a, b) => b.compareTo(a));

        // Lọc dữ liệu
        final filtered = budgets.where((b) {
          final start = DateTime.tryParse(b['startDate']?.toString() ?? '');
          final end = DateTime.tryParse(b['endDate']?.toString() ?? '');
          final status = _resolvePlanStatus(start, end);

          // Lọc theo trạng thái
          if (_statusFilter != BudgetStatusFilter.all && status != _statusFilter) {
            return false;
          }

          // Lọc theo năm
          if (_yearFilter != 'ALL') {
            final startYear = start?.year.toString();
            final endYear = end?.year.toString();
            if (startYear != _yearFilter && endYear != _yearFilter) {
              return false;
            }
          }

          // Lọc theo tìm kiếm tên
          final query = _searchController.text.trim();
          if (query.isNotEmpty) {
            final name = b['name']?.toString() ?? '';
            final notes = b['notes']?.toString() ?? '';
            final searchTarget = '$name $notes';
            if (!foldSearchText(searchTarget).contains(foldSearchText(query))) {
              return false;
            }
          }

          return true;
        }).toList();

        // Sắp xếp: Ưu tiên ngày bắt đầu gần nhất lên đầu
        filtered.sort((a, b) {
          final dateA = DateTime.tryParse(a['startDate']?.toString() ?? '') ?? DateTime(1970);
          final dateB = DateTime.tryParse(b['startDate']?.toString() ?? '') ?? DateTime(1970);
          return dateB.compareTo(dateA);
        });

        // Phân trang
        final totalItems = filtered.length;
        final totalPages = (totalItems / _pageSize).ceil().clamp(1, 9999);
        if (_currentPage > totalPages) _currentPage = totalPages;
        final startIndex = (_currentPage - 1) * _pageSize;
        final pageItems = filtered.skip(startIndex).take(_pageSize).toList();

        // Tính toán tổng quan cho kỳ lọc
        num totalPlannedIncome = 0;
        num totalActualIncome = 0;
        num totalPlannedExpense = 0;
        num totalActualExpense = 0;
        for (final item in filtered) {
          totalPlannedIncome += num.tryParse(item['plannedIncome']?.toString() ?? '0') ?? 0;
          totalActualIncome += num.tryParse(item['actualIncome']?.toString() ?? '0') ?? 0;
          totalPlannedExpense += num.tryParse(item['plannedExpense']?.toString() ?? '0') ?? 0;
          totalActualExpense += num.tryParse(item['actualExpense']?.toString() ?? '0') ?? 0;
        }

        final incomePct = totalPlannedIncome > 0 ? (totalActualIncome / totalPlannedIncome * 100) : 0.0;
        final expensePct = totalPlannedExpense > 0 ? (totalActualExpense / totalPlannedExpense * 100) : 0.0;

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(budgetPlansProvider),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header & Thao tác thêm
              _buildHeader(context, colors, totalItems),
              const SizedBox(height: AppSpacing.md),

              // Thẻ thống kê tổng quan của kỳ lọc
              _buildSummaryCards(
                context,
                colors,
                totalPlannedIncome,
                totalActualIncome,
                incomePct,
                totalPlannedExpense,
                totalActualExpense,
                expensePct,
              ),
              const SizedBox(height: AppSpacing.md),

              // Thanh công cụ lọc & tìm kiếm
              _buildFilterBar(context, colors, sortedYears),
              const SizedBox(height: AppSpacing.sm),

              // Danh sách ngân sách
              if (pageItems.isEmpty)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(color: colors.divider),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const AppEmpty(
                          visual: AppEmptyVisual.finance,
                          message: 'Không tìm thấy kế hoạch ngân sách phù hợp',
                          subtitle: 'Vui lòng đổi từ khóa tìm kiếm hoặc chọn bộ lọc trạng thái/năm khác.',
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextButton.icon(
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('Đặt lại bộ lọc'),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _statusFilter = BudgetStatusFilter.all;
                              _yearFilter = 'ALL';
                              _currentPage = 1;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                )
              else if (widget.embedded)
                // Chế độ nhúng (khung cuộn giới hạn tối đa ~440px theo đề xuất)
                Container(
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(color: colors.divider),
                  ),
                  child: Column(
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 440),
                        child: Scrollbar(
                          thumbVisibility: true,
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(AppSpacing.md),
                            itemCount: pageItems.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (context, index) => _buildBudgetCard(
                              context,
                              colors,
                              pageItems[index],
                            ),
                          ),
                        ),
                      ),
                      if (totalPages > 1) ...[
                        Divider(height: 1, color: colors.divider),
                        _buildPaginationBar(colors, totalItems, totalPages),
                      ],
                    ],
                  ),
                )
              else
                // Chế độ toàn trang (full page)
                Column(
                  children: [
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: pageItems.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => _buildBudgetCard(
                        context,
                        colors,
                        pageItems[index],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _buildPaginationBar(colors, totalItems, totalPages),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, AppThemeColors colors, int totalItems) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 4,
          height: 20,
          margin: const EdgeInsets.only(right: AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Kế hoạch & Ngân sách',
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$totalItems kế hoạch',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Theo dõi mục tiêu thu, hạn mức chi và kiểm soát sử dụng ngân sách.',
                style: TextStyle(fontSize: 12, color: colors.textSecondary),
              ),
            ],
          ),
        ),
        FilledButton.icon(
          onPressed: () => _showAddBudgetDialog(context),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Thêm kế hoạch'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCards(
    BuildContext context,
    AppThemeColors colors,
    num planInc,
    num actInc,
    double incPct,
    num planExp,
    num actExp,
    double expPct,
  ) {
    final isDesktop = MediaQuery.of(context).size.width >= 760;

    final cards = [
      _buildStatCard(
        title: 'MỤC TIÊU THU',
        mainValue: _currencyFmt.format(actInc),
        subValue: 'Kế hoạch: ${_currencyFmt.format(planInc)}',
        progress: (incPct / 100).clamp(0, 1).toDouble(),
        badgeText: '${incPct.toStringAsFixed(1)}%',
        badgeColor: actInc >= planInc ? AppColors.success : AppColors.primary,
        colors: colors,
      ),
      _buildStatCard(
        title: 'HẠN MỨC CHI',
        mainValue: _currencyFmt.format(actExp),
        subValue: 'Kế hoạch: ${_currencyFmt.format(planExp)}',
        progress: (expPct / 100).clamp(0, 1).toDouble(),
        badgeText: expPct > 100 ? 'Vượt ${(expPct - 100).toStringAsFixed(1)}%' : '${expPct.toStringAsFixed(1)}%',
        badgeColor: actExp <= planExp ? AppColors.success : AppColors.danger,
        colors: colors,
      ),
    ];

    if (isDesktop) {
      return Row(
        children: [
          Expanded(child: cards[0]),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: cards[1]),
        ],
      );
    }
    return Column(
      children: [
        cards[0],
        const SizedBox(height: AppSpacing.sm),
        cards[1],
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String mainValue,
    required String subValue,
    required double progress,
    required String badgeText,
    required Color badgeColor,
    required AppThemeColors colors,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: colors.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            mainValue,
            style: GoogleFonts.manrope(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
          Text(
            subValue,
            style: TextStyle(fontSize: 12, color: colors.textSecondary),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: colors.surface,
              valueColor: AlwaysStoppedAnimation<Color>(badgeColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context, AppThemeColors colors, List<String> sortedYears) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: colors.divider),
      ),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Ô tìm kiếm
          SizedBox(
            width: 260,
            height: 38,
            child: TextField(
              controller: _searchController,
              style: TextStyle(fontSize: 13, color: colors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Tìm theo tên, ghi chú...',
                hintStyle: TextStyle(fontSize: 12, color: colors.textMuted),
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 16),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.control),
                  borderSide: BorderSide(color: colors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.control),
                  borderSide: BorderSide(color: colors.divider),
                ),
                filled: true,
                fillColor: colors.bg,
              ),
            ),
          ),

          // Dropdown Năm
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: colors.bg,
              borderRadius: BorderRadius.circular(AppRadius.control),
              border: Border.all(color: colors.divider),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: sortedYears.contains(_yearFilter) ? _yearFilter : 'ALL',
                style: TextStyle(fontSize: 13, color: colors.textPrimary),
                items: [
                  const DropdownMenuItem(value: 'ALL', child: Text('Tất cả các năm')),
                  ...sortedYears.map((y) => DropdownMenuItem(value: y, child: Text('Năm $y'))),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _yearFilter = val;
                      _currentPage = 1;
                    });
                  }
                },
              ),
            ),
          ),

          // Chips Lọc Trạng thái
          ...BudgetStatusFilter.values.map((st) {
            final isSelected = _statusFilter == st;
            return ChoiceChip(
              label: Text(st.label),
              selected: isSelected,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : colors.textSecondary,
              ),
              selectedColor: AppColors.primary,
              backgroundColor: colors.bg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.control),
                side: BorderSide(color: isSelected ? AppColors.primary : colors.divider),
              ),
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _statusFilter = st;
                    _currentPage = 1;
                  });
                }
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBudgetCard(
    BuildContext context,
    AppThemeColors colors,
    Map<String, dynamic> b,
  ) {
    final name = b['name']?.toString() ?? 'Kế hoạch ngân sách';
    final planInc = num.tryParse(b['plannedIncome']?.toString() ?? '0') ?? 0;
    final actInc = num.tryParse(b['actualIncome']?.toString() ?? '0') ?? 0;
    final planExp = num.tryParse(b['plannedExpense']?.toString() ?? '0') ?? 0;
    final actExp = num.tryParse(b['actualExpense']?.toString() ?? '0') ?? 0;

    final start = DateTime.tryParse(b['startDate']?.toString() ?? '');
    final end = DateTime.tryParse(b['endDate']?.toString() ?? '');
    final dateRange = (start != null && end != null)
        ? '${_dateFmt.format(start)} – ${_dateFmt.format(end)}'
        : 'Chưa có ngày';

    final status = _resolvePlanStatus(start, end);
    Color statusColor;
    String statusLabel;
    switch (status) {
      case BudgetStatusFilter.active:
        statusColor = AppColors.success;
        statusLabel = 'Đang áp dụng';
        break;
      case BudgetStatusFilter.upcoming:
        statusColor = AppColors.primary;
        statusLabel = 'Sắp tới';
        break;
      case BudgetStatusFilter.past:
        statusColor = colors.textMuted;
        statusLabel = 'Đã kết thúc';
        break;
      case BudgetStatusFilter.all:
        statusColor = colors.textMuted;
        statusLabel = '';
        break;
    }

    final incPct = planInc > 0 ? (actInc / planInc * 100) : 0.0;
    final expPct = planExp > 0 ? (actExp / planExp * 100) : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: colors.divider),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          mouseCursor: SystemMouseCursors.click,
          hoverColor: colors.cardAlt.withValues(alpha: 0.6),
          onTap: () => _showBudgetDetailDialog(context, b, statusLabel, statusColor),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hàng tiêu đề & Trạng thái
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.savings_outlined,
                        size: 18,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: colors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dateRange,
                            style: TextStyle(fontSize: 11, color: colors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.chevron_right, size: 18, color: colors.textMuted),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Divider(height: 1, color: colors.divider.withValues(alpha: 0.6)),
                const SizedBox(height: AppSpacing.sm),

                // 2 Cột chỉ số: Thu và Chi
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 480;
                    final incCol = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Kế hoạch thu: ${_currencyFmt.format(planInc)}',
                              style: TextStyle(fontSize: 11, color: colors.textSecondary),
                            ),
                            Text(
                              'Thực tế: ${_currencyFmt.format(actInc)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: actInc >= planInc ? AppColors.success : colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (incPct / 100).clamp(0, 1).toDouble(),
                            minHeight: 6,
                            backgroundColor: colors.surface,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              actInc >= planInc ? AppColors.success : AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Đạt ${incPct.toStringAsFixed(1)}% mục tiêu',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: actInc >= planInc ? AppColors.success : colors.textMuted,
                          ),
                        ),
                      ],
                    );

                    final expCol = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Hạn mức chi: ${_currencyFmt.format(planExp)}',
                              style: TextStyle(fontSize: 11, color: colors.textSecondary),
                            ),
                            Text(
                              'Thực tế chi: ${_currencyFmt.format(actExp)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: actExp <= planExp ? AppColors.success : AppColors.danger,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (expPct / 100).clamp(0, 1).toDouble(),
                            minHeight: 6,
                            backgroundColor: colors.surface,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              actExp <= planExp ? AppColors.success : AppColors.danger,
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          expPct > 100
                              ? 'Vượt hạn mức +${(expPct - 100).toStringAsFixed(1)}%'
                              : 'Đã dùng ${expPct.toStringAsFixed(1)}% ngân sách',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: actExp <= planExp ? colors.textMuted : AppColors.danger,
                          ),
                        ),
                      ],
                    );

                    if (isNarrow) {
                      return Column(
                        children: [
                          incCol,
                          const SizedBox(height: AppSpacing.sm),
                          expCol,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: incCol),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(child: expCol),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaginationBar(AppThemeColors colors, int totalItems, int totalPages) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Trang $_currentPage / $totalPages · $totalItems kế hoạch',
            style: TextStyle(fontSize: 12, color: colors.textSecondary, fontWeight: FontWeight.w500),
          ),
          Row(
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.chevron_left_rounded, size: 16),
                label: const Text('Trước'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                onPressed: _currentPage > 1
                    ? () => setState(() => _currentPage--)
                    : null,
              ),
              const SizedBox(width: AppSpacing.xs),
              OutlinedButton.icon(
                icon: const Icon(Icons.chevron_right_rounded, size: 16),
                label: const Text('Sau'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                onPressed: _currentPage < totalPages
                    ? () => setState(() => _currentPage++)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showBudgetDetailDialog(
    BuildContext context,
    Map<String, dynamic> b,
    String statusLabel,
    Color statusColor,
  ) {
    final colors = AppThemeColors.of(context);
    final name = b['name']?.toString() ?? 'Kế hoạch ngân sách';
    final planInc = num.tryParse(b['plannedIncome']?.toString() ?? '0') ?? 0;
    final actInc = num.tryParse(b['actualIncome']?.toString() ?? '0') ?? 0;
    final diffInc = actInc - planInc;
    final incPct = planInc > 0 ? (actInc / planInc * 100) : 0.0;

    final planExp = num.tryParse(b['plannedExpense']?.toString() ?? '0') ?? 0;
    final actExp = num.tryParse(b['actualExpense']?.toString() ?? '0') ?? 0;
    final diffExp = actExp - planExp;
    final expPct = planExp > 0 ? (actExp / planExp * 100) : 0.0;

    final planNet = planInc - planExp;
    final actNet = actInc - actExp;
    final diffNet = actNet - planNet;

    final start = DateTime.tryParse(b['startDate']?.toString() ?? '');
    final end = DateTime.tryParse(b['endDate']?.toString() ?? '');
    final dateRange = (start != null && end != null)
        ? '${_dateFmt.format(start)} – ${_dateFmt.format(end)}'
        : 'Chưa có ngày';
    final notes = b['notes']?.toString();

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.pie_chart_outline_rounded, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Expanded(
              child: Text(
                'Chi tiết kế hoạch ngân sách',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thông tin chung
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: colors.cardAlt,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(color: colors.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Thời gian: $dateRange · Kỳ: ${b['period'] ?? 'CUSTOM'}',
                        style: TextStyle(fontSize: 12, color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Bảng chỉ tiêu so sánh
                Text(
                  'Bảng đối soát chỉ tiêu ngân sách',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: colors.textPrimary),
                ),
                const SizedBox(height: 6),
                Table(
                  border: TableBorder.all(color: colors.divider, borderRadius: BorderRadius.circular(6)),
                  columnWidths: const {
                    0: FlexColumnWidth(3),
                    1: FlexColumnWidth(3),
                    2: FlexColumnWidth(3),
                    3: FlexColumnWidth(2.5),
                  },
                  children: [
                    TableRow(
                      decoration: BoxDecoration(color: colors.surface),
                      children: const [
                        Padding(
                          padding: EdgeInsets.all(8),
                          child: Text('Chỉ tiêu', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11)),
                        ),
                        Padding(
                          padding: EdgeInsets.all(8),
                          child: Text('Kế hoạch', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11)),
                        ),
                        Padding(
                          padding: EdgeInsets.all(8),
                          child: Text('Thực tế', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11)),
                        ),
                        Padding(
                          padding: EdgeInsets.all(8),
                          child: Text('Đạt / Tỷ lệ', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11)),
                        ),
                      ],
                    ),
                    TableRow(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(8),
                          child: Text('Thu (Tiền vào)', style: TextStyle(fontSize: 11)),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(_currencyFmt.format(planInc), style: const TextStyle(fontSize: 11)),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(_currencyFmt.format(actInc), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            '${incPct.toStringAsFixed(1)}%\n(${diffInc >= 0 ? '+' : ''}${_currencyFmt.format(diffInc)})',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: actInc >= planInc ? AppColors.success : AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    TableRow(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(8),
                          child: Text('Chi (Tiền ra)', style: TextStyle(fontSize: 11)),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(_currencyFmt.format(planExp), style: const TextStyle(fontSize: 11)),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(_currencyFmt.format(actExp), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            '${expPct.toStringAsFixed(1)}%\n(${diffExp >= 0 ? '+' : ''}${_currencyFmt.format(diffExp)})',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: actExp <= planExp ? AppColors.success : AppColors.danger,
                            ),
                          ),
                        ),
                      ],
                    ),
                    TableRow(
                      decoration: BoxDecoration(color: colors.cardAlt),
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(8),
                          child: Text('Dòng tiền thuần', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(_currencyFmt.format(planNet), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(_currencyFmt.format(actNet), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            diffNet >= 0 ? '+${_currencyFmt.format(diffNet)}' : _currencyFmt.format(diffNet),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: diffNet >= 0 ? AppColors.success : AppColors.danger,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (notes != null && notes.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text('Ghi chú:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textSecondary)),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: colors.bg,
                      borderRadius: BorderRadius.circular(AppRadius.control),
                      border: Border.all(color: colors.divider),
                    ),
                    child: Text(notes, style: TextStyle(fontSize: 12, color: colors.textPrimary)),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  void _showAddBudgetDialog(BuildContext context) {
    final nameC = TextEditingController();
    final incomeC = TextEditingController();
    final expenseC = TextEditingController();
    final notesC = TextEditingController();
    var startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
    var endDate = DateTime(DateTime.now().year, DateTime.now().month + 1, 0);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            'Thêm kế hoạch ngân sách',
            style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameC,
                    decoration: const InputDecoration(
                      labelText: 'Tên kế hoạch *',
                      hintText: 'Ví dụ: Ngân sách tháng 12/2026',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _BudgetDateField(
                          label: 'Từ ngày',
                          value: startDate,
                          onTap: () async {
                            final val = await showDatePicker(
                              context: dialogContext,
                              initialDate: startDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (val != null) setDialogState(() => startDate = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _BudgetDateField(
                          label: 'Đến ngày',
                          value: endDate,
                          onTap: () async {
                            final val = await showDatePicker(
                              context: dialogContext,
                              initialDate: endDate,
                              firstDate: startDate,
                              lastDate: DateTime(2100),
                            );
                            if (val != null) setDialogState(() => endDate = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: incomeC,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Mục tiêu thu (đồng)',
                      hintText: '0',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: expenseC,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Hạn mức chi (đồng)',
                      hintText: '0',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesC,
                    decoration: const InputDecoration(
                      labelText: 'Ghi chú (tùy chọn)',
                      hintText: 'Ghi chú điều kiện hoặc mục đích ngân sách...',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameC.text.trim();
                if (name.isEmpty) {
                  ToastService.showError('Vui lòng nhập tên kế hoạch');
                  return;
                }
                final plannedIncome = double.tryParse(incomeC.text.trim()) ?? 0;
                final plannedExpense = double.tryParse(expenseC.text.trim()) ?? 0;
                if (plannedIncome < 0 || plannedExpense < 0) {
                  ToastService.showError('Số tiền không được âm');
                  return;
                }

                try {
                  await ref.read(financeRepoProvider).createBudgetPlan({
                    'name': name,
                    'period': 'CUSTOM',
                    'startDate': startDate.toIso8601String().split('T').first,
                    'endDate': endDate.toIso8601String().split('T').first,
                    'plannedIncome': plannedIncome,
                    'plannedExpense': plannedExpense,
                    if (notesC.text.trim().isNotEmpty) 'notes': notesC.text.trim(),
                  });
                  ref.invalidate(budgetPlansProvider);
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                    ToastService.showSuccess('Đã lưu kế hoạch ngân sách thành công');
                  }
                } catch (e) {
                  ToastService.showError('Không thể tạo kế hoạch: $e');
                }
              },
              child: const Text('Lưu kế hoạch'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetDateField extends StatelessWidget {
  final String label;
  final DateTime value;
  final VoidCallback onTap;

  const _BudgetDateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.control),
          border: Border.all(color: colors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: colors.textSecondary)),
            const SizedBox(height: 2),
            Text(
              DateFormat('dd/MM/yyyy').format(value),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
