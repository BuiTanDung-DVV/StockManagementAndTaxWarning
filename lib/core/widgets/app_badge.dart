import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const AppBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Specialized badge for payment status (Paid, Partial, Unpaid)
class PaymentStatusBadge extends StatelessWidget {
  final bool isPaid;
  final bool isPartiallyPaid;

  const PaymentStatusBadge({
    super.key,
    required this.isPaid,
    this.isPartiallyPaid = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isPaid) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFA7F3D0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              size: 12,
              color: Color(0xFF059669),
            ),
            const SizedBox(width: 4),
            Text(
              'Đã thanh toán',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF065F46),
              ),
            ),
          ],
        ),
      );
    }

    if (isPartiallyPaid) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.hourglass_bottom_rounded,
              size: 12,
              color: Color(0xFFD97706),
            ),
            const SizedBox(width: 4),
            Text(
              'Thanh toán 1 phần',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF92400E),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 12,
            color: Color(0xFFDC2626),
          ),
          const SizedBox(width: 4),
          Text(
            'Chưa thanh toán',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF991B1B),
            ),
          ),
        ],
      ),
    );
  }
}

/// Specialized badge for stock levels (In stock, Low, Out of stock)
class StockStatusBadge extends StatelessWidget {
  final int stockQuantity;
  final int minThreshold;
  final String unit;

  const StockStatusBadge({
    super.key,
    required this.stockQuantity,
    this.minThreshold = 10,
    this.unit = '',
  });

  @override
  Widget build(BuildContext context) {
    final unitSuffix = unit.isNotEmpty ? ' $unit' : '';

    if (stockQuantity <= 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.remove_circle_outline_rounded,
              size: 12,
              color: Color(0xFFDC2626),
            ),
            const SizedBox(width: 4),
            Text(
              'Hết hàng',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF991B1B),
              ),
            ),
          ],
        ),
      );
    }

    if (stockQuantity <= minThreshold) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              size: 12,
              color: Color(0xFFD97706),
            ),
            const SizedBox(width: 4),
            Text(
              'Sắp hết: $stockQuantity$unitSuffix',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF92400E),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            size: 12,
            color: Color(0xFF059669),
          ),
          const SizedBox(width: 4),
          Text(
            'Còn tồn: $stockQuantity$unitSuffix',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF065F46),
            ),
          ),
        ],
      ),
    );
  }
}
