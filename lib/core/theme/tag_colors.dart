import 'package:flutter/material.dart';

/// The same tag keeps its configured color in filters, tables and cards.
abstract final class TagColors {
  static Color resolve(String name, {Color? configured}) {
    if (name == 'Hết hàng') return const Color(0xFFDC2626);
    if (name == 'Sắp hết') return const Color(0xFFD97706);
    if (configured != null) return configured;
    if (name == 'Bán chạy') return const Color(0xFF7C3AED);
    if (name == 'Mới') return const Color(0xFF2563EB);
    const palette = [
      Color(0xFF2563EB),
      Color(0xFF7C3AED),
      Color(0xFF047857),
      Color(0xFF0E7490),
      Color(0xFFBE185D),
      Color(0xFFB45309),
      Color(0xFF4338CA),
      Color(0xFF9F1239),
    ];
    final index = name.runes.fold(
      0,
      (sum, value) => (sum * 31 + value) % palette.length,
    );
    return palette[index];
  }

  static Color surface(
    Color accent,
    Color background, {
    bool selected = false,
  }) => Color.alphaBlend(
    accent.withValues(alpha: selected ? 0.22 : 0.10),
    background,
  );

  static Color foreground(Color accent, Color background) {
    final target = background.computeLuminance() < 0.3
        ? Colors.white
        : Colors.black;
    var text = accent;
    for (var step = 0; step < 20; step++) {
      final a = text.computeLuminance(), b = background.computeLuminance();
      final ratio = a > b ? (a + 0.05) / (b + 0.05) : (b + 0.05) / (a + 0.05);
      if (ratio >= 4.5) break;
      text = Color.lerp(text, target, 0.12)!;
    }
    return text;
  }
}
