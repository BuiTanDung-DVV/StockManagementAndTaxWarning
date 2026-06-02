import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/guides/feature_guide_sheet.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/widgets/app_shimmer.dart';
import '../providers/sales_provider.dart';

final _currFmt = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

class SalesListScreen extends ConsumerStatefulWidget {
  const SalesListScreen({super.key});
  @override
  ConsumerState<SalesListScreen> createState() => _SalesListScreenState();
}

class _SalesListScreenState extends ConsumerState<SalesListScreen> {
  int _page = 1;
  String? _status;
  bool _searching = false;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);
    final listAsync = ref.watch(salesListProvider((page: _page, status: _status, customerId: null)));

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: Text(
          'Lịch Sử Đơn Hàng',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: c.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          featureGuideButton(context, 'sales_list'),
          IconButton(
            icon: Icon(_searching ? Icons.close_rounded : Icons.search_rounded, color: c.textSecondary),
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) _searchCtrl.clear();
            }),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          if (_searching)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: GoogleFonts.inter(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Tìm theo mã đơn, khách hàng...',
                  prefixIcon: Icon(Icons.search_rounded, color: c.textMuted, size: 20),
                  filled: true,
                  fillColor: c.card,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: c.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: c.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                  ),
                ),
              ),
            ),
          
          // Stepper Chips for filtering states
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [null, 'PENDING', 'COMPLETED', 'CANCELLED'].map((s) {
                final label = s == null ? 'Tất cả' : s == 'PENDING' ? 'Chờ xử lý' : s == 'COMPLETED' ? 'Hoàn thành' : 'Đã hủy';
                final selected = _status == s;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(label),
                    selected: selected,
                    onSelected: (_) => setState(() {
                      _status = s;
                      _page = 1;
                    }),
                    selectedColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                    checkmarkColor: theme.colorScheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    labelStyle: GoogleFonts.outfit(
                      color: selected ? theme.colorScheme.primary : c.textSecondary,
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                    ),
                    side: BorderSide(
                      color: selected ? theme.colorScheme.primary : c.divider.withValues(alpha: 0.8),
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          
          Expanded(
            child: listAsync.when(
              data: (data) {
                final items = (data['items'] as List?) ?? [];
                if (items.isEmpty) {
                  return const AppEmpty(
                    message: 'Không tìm thấy đơn hàng nào.',
                    subtitle: 'Hãy bắt đầu tạo đơn hàng mới từ màn hình máy POS bán hàng.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(salesListProvider),
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    itemCount: items.length,
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 450,
                      mainAxisExtent: 92,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 0,
                    ),
                    itemBuilder: (_, i) {
                      final order = items[i];
                      final orderStatus = order['status'] ?? 'PENDING';
                      
                      Color statusColor;
                      String statusLabel;
                      switch (orderStatus) {
                        case 'COMPLETED':
                        case 'DELIVERED':
                          statusColor = AppColors.success;
                          statusLabel = 'Hoàn thành';
                          break;
                        case 'PENDING':
                          statusColor = AppColors.warning;
                          statusLabel = 'Chờ xử lý';
                          break;
                        case 'CANCELLED':
                        default:
                          statusColor = AppColors.danger;
                          statusLabel = 'Đã hủy';
                          break;
                      }

                      final total = double.tryParse(order['totalAmount']?.toString() ?? '0') ?? 0.0;
                      final paid = double.tryParse(order['amountPaid']?.toString() ?? order['paidAmount']?.toString() ?? '0') ?? 0.0;
                      final customerName = order['customer']?['name'] ?? 'Khách mua lẻ';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: c.card,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: c.divider.withValues(alpha: 0.5)),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => context.push('/sales/${order['id']}'),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      Icons.receipt_long_rounded,
                                      color: theme.colorScheme.primary,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Mã: ${order['orderCode'] ?? 'DH-${order['id']}'}',
                                          style: GoogleFonts.outfit(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: c.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          customerName,
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: c.textSecondary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        _buildTagsRow(order, paid, total, c, theme),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        _currFmt.format(total),
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.w800,
                                          color: theme.colorScheme.primary,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: statusColor.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          statusLabel,
                                          style: GoogleFonts.inter(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: statusColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const ShimmerList(),
              error: (e, _) => AppError(
                message: 'Lỗi tải dữ liệu: $e',
                onRetry: () => ref.invalidate(salesListProvider),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/pos'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 3,
        icon: const Icon(Icons.point_of_sale_rounded, color: Colors.white, size: 20),
        label: Text(
          'Màn POS Bán Hàng',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 14,
          ),
        ),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Widget _buildTagsRow(Map<String, dynamic> order, double paid, double total, AppThemeColors c, ThemeData theme) {
    List<String> tags = [];
    final tagsRaw = order['tags'];
    if (tagsRaw is List) {
      tags = tagsRaw.map((e) => e.toString()).toList();
    } else if (tagsRaw is String && tagsRaw.isNotEmpty) {
      tags = tagsRaw.split(',').where((e) => e.trim().isNotEmpty).toList();
    }

    // Auto tags
    if (order['status'] != 'CANCELLED') {
      if (paid < total) {
        if (!tags.contains('Còn nợ')) tags.insert(0, 'Còn nợ');
      } else if (paid > 0 && paid >= total) {
        if (!tags.contains('Đã TT')) tags.insert(0, 'Đã TT');
      }
    }
    
    if (order['customer'] == null) {
      if (!tags.contains('Khách lẻ')) tags.insert(0, 'Khách lẻ');
    }

    if (tags.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tags.take(3).map((t) {
          Color bgColor = theme.colorScheme.primary.withValues(alpha: 0.1);
          Color textColor = theme.colorScheme.primary;

          if (t == 'Còn nợ') {
            bgColor = AppColors.warning.withValues(alpha: 0.1);
            textColor = AppColors.warning;
          } else if (t == 'Khách lẻ') {
            bgColor = Colors.blueGrey.withValues(alpha: 0.1);
            textColor = Colors.blueGrey;
          } else if (t == 'Đã TT') {
            bgColor = AppColors.success.withValues(alpha: 0.1);
            textColor = AppColors.success;
          }

          return Container(
            margin: const EdgeInsets.only(right: 4),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: textColor.withValues(alpha: 0.2)),
            ),
            child: Text(
              t,
              style: GoogleFonts.inter(fontSize: 9, color: textColor, fontWeight: FontWeight.bold),
            ),
          );
        }).toList(),
      ),
    );
  }
}
