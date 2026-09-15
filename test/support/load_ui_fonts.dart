import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Resolve the actual application fonts before the test's fake async clock.
Future<void> loadUiFonts() async {
  GoogleFonts.config.allowRuntimeFetching = false;
  for (final weight in FontWeight.values) {
    GoogleFonts.inter(fontWeight: weight);
    GoogleFonts.manrope(fontWeight: weight);
  }
  await GoogleFonts.pendingFonts();
  final icons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await icons.load();
}
