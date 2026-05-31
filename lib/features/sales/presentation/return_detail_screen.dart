import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/parse_utils.dart';

final _currFmt = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

class ReturnDetailScreen extends ConsumerWidget {
  final Map<dynamic, dynamic> returnInfo;

  const ReturnDetailScreen({
    super.key,
    required this.returnInfo,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);

    final returnCode = returnInfo['returnCode'] ?? 'RET-${returnInfo['id']}';
    final reason = returnInfo['reason'] ?? 'Không có lý do';
    final refundedAmount = asDouble(returnInfo['refundedAmount']);
    final createdAt = returnInfo['createdAt']?.toString() ?? returnInfo['date']?.toString() ?? '';
    final returnItems = (returnInfo['items'] as List?) ?? [];

    String dateLabel = createdAt;
    if (createdAt.isNotEmpty && createdAt.contains('T')) {
      try {
        final dt = DateTime.parse(createdAt).toLocal();
        dateLabel = DateFormat('dd/MM/yyyy HH:mm').format(dt);
      } catch (_) {}
    }

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Chi Tiết Đơn Trả Hàng',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: c.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // General Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: c.divider.withValues(alpha: 0.5)),
              ),
              child: Column(
                children: [
                  _buildInfoRow('Mã trả hàng', returnCode.toString(), c),
                  if (dateLabel.isNotEmpty) _buildInfoRow('Thời gian', dateLabel, c),
                  _buildInfoRow('Lý do', reason, c, isMultiLine: true),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Tiền hoàn lại', style: GoogleFonts.inter(color: c.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                      Text(
                        _currFmt.format(refundedAmount),
                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                      )
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Danh sách sản phẩm trả',
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary),
            ),
            const SizedBox(height: 12),
            if (returnItems.isEmpty)
              Text('Không có thông tin sản phẩm cụ thể.', style: GoogleFonts.inter(color: c.textSecondary, fontSize: 13))
            else
              ...returnItems.map((item) {
                final itemName = item['product']?['name'] ?? item['productName'] ?? 'Sản phẩm ${item['productId'] ?? ''}';
                final qty = asDouble(item['quantity']);
                final unitPrice = asDouble(item['unitPrice'] ?? item['price'] ?? 0);
                final subtotal = qty * unitPrice;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: c.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: c.divider.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(itemName, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: c.textPrimary)),
                            const SizedBox(height: 2),
                            if (unitPrice > 0)
                              Text('SL: $qty x ${_currFmt.format(unitPrice)}', style: GoogleFonts.inter(fontSize: 11, color: c.textSecondary, fontWeight: FontWeight.w500))
                            else
                              Text('SL: $qty', style: GoogleFonts.inter(fontSize: 11, color: c.textSecondary, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (unitPrice > 0)
                        Text(
                          _currFmt.format(subtotal),
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: c.textPrimary, fontSize: 14),
                        ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, AppThemeColors c, {bool isMultiLine = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: isMultiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: GoogleFonts.inter(color: c.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: GoogleFonts.inter(color: c.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
              textAlign: TextAlign.right,
              maxLines: isMultiLine ? null : 1,
              overflow: isMultiLine ? null : TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
