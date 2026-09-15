import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../assets/app_assets.dart';
import '../theme/app_theme.dart';
import 'app_navigation_back_button.dart';
import 'app_ui_components.dart';

/// Unified responsive scaffold for authentication and onboarding flows.
///
/// SmartStock UI v4 art direction:
/// - Desktop (width >= 960): Inset restrained navy-to-deep-teal brand field on light
///   canvas with concise headline, bespoke isometric storefront illustration (warm awning
///   accent, neutral/teal parcels), and clean capability markers. The right side is a calm,
///   focused form surface with clear legibility and no decorative title underlines.
/// - Mobile (< 960): Compact branded header with navy-to-teal gradient and neutral border,
///   keeping the authentication form primary and minimizing vertical clutter.
class AuthScaffold extends StatelessWidget {
  final Widget body;
  final String? title;
  final String? subtitle;
  final String brandHeadline;
  final String brandDescription;
  final List<String> brandCapabilities;
  final double maxWidth;
  final bool canPop;
  final VoidCallback? onPop;
  final Widget? footer;
  final Widget? headerTrailing;
  final Widget? customIllustration;

  const AuthScaffold({
    super.key,
    required this.body,
    this.title,
    this.subtitle,
    this.brandHeadline = 'Quản lý cửa hàng, rõ từng con số.',
    this.brandDescription =
        'Bán hàng, tồn kho và tài chính trong cùng một nơi.',
    this.brandCapabilities = const [
      'Bán hàng và công nợ khách hàng',
      'Quản lý kho hàng và giá vốn',
      'Sổ quỹ và dòng tiền',
    ],
    this.maxWidth = 460.0,
    this.canPop = false,
    this.onPop,
    this.footer,
    this.headerTrailing,
    this.customIllustration,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 960;

            Widget formCard({required bool isDesktop}) => AppCardContainer(
              padding: EdgeInsets.all(
                isDesktop ? AppSpacing.xl : AppSpacing.lg,
              ),
              borderRadius: AppRadius.card,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isDesktop && canPop && onPop != null) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: AppNavigationBackButton(onPressed: onPop!),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  if (title != null) ...[
                    Text(
                      title!,
                      style: GoogleFonts.manrope(
                        color: colors.textPrimary,
                        fontSize: isDesktop ? 28 : 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: isDesktop ? -0.5 : -0.4,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        subtitle!,
                        style: GoogleFonts.inter(
                          color: colors.textSecondary,
                          fontSize: isDesktop ? 13.5 : 13,
                          height: 1.45,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  body,
                  if (footer != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    footer!,
                  ],
                ],
              ),
            );

            if (!isDesktop) {
              return Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.lg,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _MobileBrandHeader(
                          canPop: canPop,
                          onPop: onPop,
                          trailing: headerTrailing,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        formCard(isDesktop: false),
                      ],
                    ),
                  ),
                ),
              );
            }

            return Row(
              children: [
                Expanded(
                  flex: 5,
                  child: _DesktopBrandSide(
                    headline: brandHeadline,
                    description: brandDescription,
                    capabilities: brandCapabilities,
                    customIllustration: customIllustration,
                  ),
                ),
                Expanded(
                  flex: 6,
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl,
                        vertical: AppSpacing.lg,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxWidth),
                        child: formCard(isDesktop: true),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MobileBrandHeader extends StatelessWidget {
  final bool canPop;
  final VoidCallback? onPop;
  final Widget? trailing;

  const _MobileBrandHeader({required this.canPop, this.onPop, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (canPop && onPop != null) ...[
          AppNavigationBackButton(onPressed: onPop!),
          const SizedBox(width: AppSpacing.xs),
        ],
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF0F8FA), Color(0xFFE2F0F6)],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFC7E2ED), width: 1.0),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0D0F766E),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFC7E2ED).withValues(alpha: 0.6),
                    ),
                  ),
                  child: const AppAssetIcon(
                    assetPath: AppAssets.parcelBox,
                    size: 24,
                    semanticLabel: 'SmartStock',
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'SmartStock',
                    style: GoogleFonts.manrope(
                      color: const Color(0xFF0F172A),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DesktopBrandSide extends StatelessWidget {
  final String headline;
  final String description;
  final List<String> capabilities;
  final Widget? customIllustration;

  const _DesktopBrandSide({
    required this.headline,
    required this.description,
    required this.capabilities,
    this.customIllustration,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      child: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF1F8FA), Color(0xFFE5F1F6), Color(0xFFD6EAF2)],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFC7E2ED)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x120F766E),
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xxxl,
              vertical: AppSpacing.xl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(
                              0xFFC7E2ED,
                            ).withValues(alpha: 0.6),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const AppAssetIcon(
                          assetPath: AppAssets.parcelBox,
                          size: 32,
                          semanticLabel: 'SmartStock',
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SmartStock',
                            style: GoogleFonts.manrope(
                              color: const Color(0xFF0F172A),
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                          ),
                          Text(
                            'Nền tảng quản lý cửa hàng chuẩn hóa',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF0F766E),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    headline,
                    style: GoogleFonts.manrope(
                      color: const Color(0xFF0F172A),
                      fontSize: 32,
                      height: 1.25,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF475569),
                      fontSize: 14,
                      height: 1.5,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  customIllustration ?? const _WarehouseHeroIllustration(),
                  const SizedBox(height: AppSpacing.xl),
                  for (final cap in capabilities)
                    _BrandCapabilityItem(title: cap),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WarehouseHeroIllustration extends StatelessWidget {
  const _WarehouseHeroIllustration();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFBCE0EC).withValues(alpha: 0.8),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0E0B353E),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        AppAssets.demoWarehouse,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const _BespokeStoreIllustration(),
      ),
    );
  }
}

class _BrandCapabilityItem extends StatelessWidget {
  final String title;

  const _BrandCapabilityItem({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            size: 18,
            color: Color(0xFF0F766E),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.inter(
                color: const Color(0xFF334155),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bespoke 3D isometric storefront and warehouse inventory illustration.
/// Pure geometric CustomPainter: three-dimensional stack of cardboard parcels
/// (cream, mint, warm muted gold faces) beside a recognizable shop facade
/// with striped awning, display window, and door, resting on a perspective platform.
/// Completely decorative, wrapped in ExcludeSemantics, with zero fake UI, bars, or text.
class _BespokeStoreIllustration extends StatelessWidget {
  const _BespokeStoreIllustration();

  @override
  Widget build(BuildContext context) {
    return const ExcludeSemantics(
      child: SizedBox(
        width: double.infinity,
        height: 170,
        child: CustomPaint(painter: _StorefrontWarehouseIsometricPainter()),
      ),
    );
  }
}

class _StorefrontWarehouseIsometricPainter extends CustomPainter {
  const _StorefrontWarehouseIsometricPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final scale = (size.width / 400.0).clamp(0.65, 1.15);
    canvas.save();
    canvas.translate(
      (size.width - 400.0 * scale) / 2,
      (size.height - 170.0 * scale) / 2,
    );
    canvas.scale(scale);

    // 1. Perspective platform / ground plinth
    final platformPath = Path()
      ..moveTo(200, 68)
      ..lineTo(378, 114)
      ..lineTo(200, 164)
      ..lineTo(22, 114)
      ..close();

    final platformFill = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..style = PaintingStyle.fill;
    canvas.drawPath(platformPath, platformFill);

    final platformStroke = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(platformPath, platformStroke);

    // Subtle platform depth rim
    final platformRim = Path()
      ..moveTo(22, 114)
      ..lineTo(200, 164)
      ..lineTo(378, 114)
      ..lineTo(378, 118)
      ..lineTo(200, 168)
      ..lineTo(22, 118)
      ..close();
    canvas.drawPath(
      platformRim,
      Paint()..color = Colors.black.withValues(alpha: 0.12),
    );

    // 2. Drop shadows on the platform
    final shopShadow = Path()
      ..moveTo(234, 118)
      ..lineTo(340, 94)
      ..lineTo(365, 126)
      ..lineTo(256, 150)
      ..close();
    canvas.drawPath(
      shopShadow,
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );

    final parcelsShadow = Path()
      ..moveTo(82, 124)
      ..lineTo(185, 112)
      ..lineTo(195, 146)
      ..lineTo(92, 154)
      ..close();
    canvas.drawPath(
      parcelsShadow,
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );

    // 3. Shop Facade (Right side)
    _drawShopFacade(canvas);

    // 4. Isometric Stack of Parcels (Left side)
    _drawParcelStack(canvas);

    canvas.restore();
  }

  static Offset _iso(Offset origin, double u, double v, double w) {
    const cos30 = 0.866025;
    const sin30 = 0.5;
    final x = origin.dx + (u - v) * cos30;
    final y = origin.dy + (u + v) * sin30 - w;
    return Offset(x, y);
  }

  void _drawIsoBox(
    Canvas canvas, {
    required Offset origin,
    required double L,
    required double D,
    required double H,
    required Color topColor,
    required Color leftColor,
    required Color rightColor,
    Color? tapeColor,
  }) {
    final pL00 = _iso(origin, L, 0, 0);
    final pLD0 = _iso(origin, L, D, 0);
    final p0D0 = _iso(origin, 0, D, 0);

    final p00H = _iso(origin, 0, 0, H);
    final pL0H = _iso(origin, L, 0, H);
    final pLDH = _iso(origin, L, D, H);
    final p0DH = _iso(origin, 0, D, H);

    // Left face (visible)
    final leftFace = Path()
      ..moveTo(p0DH.dx, p0DH.dy)
      ..lineTo(pLDH.dx, pLDH.dy)
      ..lineTo(pLD0.dx, pLD0.dy)
      ..lineTo(p0D0.dx, p0D0.dy)
      ..close();
    canvas.drawPath(leftFace, Paint()..color = leftColor);

    // Right face (visible)
    final rightFace = Path()
      ..moveTo(pLDH.dx, pLDH.dy)
      ..lineTo(pL0H.dx, pL0H.dy)
      ..lineTo(pL00.dx, pL00.dy)
      ..lineTo(pLD0.dx, pLD0.dy)
      ..close();
    canvas.drawPath(rightFace, Paint()..color = rightColor);

    // Top face (visible)
    final topFace = Path()
      ..moveTo(p00H.dx, p00H.dy)
      ..lineTo(pL0H.dx, pL0H.dy)
      ..lineTo(pLDH.dx, pLDH.dy)
      ..lineTo(p0DH.dx, p0DH.dy)
      ..close();
    canvas.drawPath(topFace, Paint()..color = topColor);

    // Edge accents
    final edgePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.75;
    canvas.drawPath(topFace, edgePaint);

    // Packaging tape ribbon
    if (tapeColor != null) {
      final tapePaint = Paint()..color = tapeColor;
      final tW = L * 0.22;
      final tStart = (L - tW) / 2;
      final tEnd = tStart + tW;

      final topTape = Path()
        ..moveTo(_iso(origin, tStart, 0, H).dx, _iso(origin, tStart, 0, H).dy)
        ..lineTo(_iso(origin, tEnd, 0, H).dx, _iso(origin, tEnd, 0, H).dy)
        ..lineTo(_iso(origin, tEnd, D, H).dx, _iso(origin, tEnd, D, H).dy)
        ..lineTo(_iso(origin, tStart, D, H).dx, _iso(origin, tStart, D, H).dy)
        ..close();
      canvas.drawPath(topTape, tapePaint);

      final frontTape = Path()
        ..moveTo(_iso(origin, tStart, D, H).dx, _iso(origin, tStart, D, H).dy)
        ..lineTo(_iso(origin, tEnd, D, H).dx, _iso(origin, tEnd, D, H).dy)
        ..lineTo(_iso(origin, tEnd, D, 0).dx, _iso(origin, tEnd, D, 0).dy)
        ..lineTo(_iso(origin, tStart, D, 0).dx, _iso(origin, tStart, D, 0).dy)
        ..close();
      canvas.drawPath(frontTape, tapePaint);
    }
  }

  void _drawShopFacade(Canvas canvas) {
    const origin = Offset(294, 98);
    const L = 38.0;
    const D = 82.0;
    const H = 72.0;

    // Building main mass
    _drawIsoBox(
      canvas,
      origin: origin,
      L: L,
      D: D,
      H: H,
      topColor: const Color(0xFF115E59),
      leftColor: const Color(0xFF0F5752),
      rightColor: const Color(0xFF0A3C38),
    );

    // Fascia signboard band along top of front wall
    final fasciaPath = Path()
      ..moveTo(_iso(origin, 0, D, H).dx, _iso(origin, 0, D, H).dy)
      ..lineTo(_iso(origin, L, D, H).dx, _iso(origin, L, D, H).dy)
      ..lineTo(_iso(origin, L, D, H - 10).dx, _iso(origin, L, D, H - 10).dy)
      ..lineTo(_iso(origin, 0, D, H - 10).dx, _iso(origin, 0, D, H - 10).dy)
      ..close();
    canvas.drawPath(
      fasciaPath,
      Paint()..color = const Color(0xFF14B8A6).withValues(alpha: 0.9),
    );

    // Entrance door on front wall (left portion of front wall)
    final doorPath = Path()
      ..moveTo(_iso(origin, 4, D + 0.5, 42).dx, _iso(origin, 4, D + 0.5, 42).dy)
      ..lineTo(
        _iso(origin, 14, D + 0.5, 42).dx,
        _iso(origin, 14, D + 0.5, 42).dy,
      )
      ..lineTo(_iso(origin, 14, D + 0.5, 0).dx, _iso(origin, 14, D + 0.5, 0).dy)
      ..lineTo(_iso(origin, 4, D + 0.5, 0).dx, _iso(origin, 4, D + 0.5, 0).dy)
      ..close();
    canvas.drawPath(doorPath, Paint()..color = const Color(0xFF062B28));
    canvas.drawPath(
      doorPath,
      Paint()
        ..color = const Color(0xFF5EEAD4).withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Door glass insert
    final doorGlass = Path()
      ..moveTo(_iso(origin, 6, D + 0.6, 38).dx, _iso(origin, 6, D + 0.6, 38).dy)
      ..lineTo(
        _iso(origin, 12, D + 0.6, 38).dx,
        _iso(origin, 12, D + 0.6, 38).dy,
      )
      ..lineTo(
        _iso(origin, 12, D + 0.6, 18).dx,
        _iso(origin, 12, D + 0.6, 18).dy,
      )
      ..lineTo(_iso(origin, 6, D + 0.6, 18).dx, _iso(origin, 6, D + 0.6, 18).dy)
      ..close();
    canvas.drawPath(
      doorGlass,
      Paint()..color = const Color(0xFF99F6E4).withValues(alpha: 0.45),
    );

    // Door brass handle
    final handlePos = _iso(origin, 12.5, D + 0.8, 20);
    canvas.drawCircle(handlePos, 1.8, Paint()..color = const Color(0xFFFDE68A));

    // Display window on front wall (right portion of front wall)
    final windowPath = Path()
      ..moveTo(
        _iso(origin, 18, D + 0.5, 44).dx,
        _iso(origin, 18, D + 0.5, 44).dy,
      )
      ..lineTo(
        _iso(origin, 34, D + 0.5, 44).dx,
        _iso(origin, 34, D + 0.5, 44).dy,
      )
      ..lineTo(
        _iso(origin, 34, D + 0.5, 10).dx,
        _iso(origin, 34, D + 0.5, 10).dy,
      )
      ..lineTo(
        _iso(origin, 18, D + 0.5, 10).dx,
        _iso(origin, 18, D + 0.5, 10).dy,
      )
      ..close();
    canvas.drawPath(windowPath, Paint()..color = const Color(0xFF04201E));

    // Warm glowing display window pane
    final windowGlass = Path()
      ..moveTo(
        _iso(origin, 19, D + 0.6, 42).dx,
        _iso(origin, 19, D + 0.6, 42).dy,
      )
      ..lineTo(
        _iso(origin, 33, D + 0.6, 42).dx,
        _iso(origin, 33, D + 0.6, 42).dy,
      )
      ..lineTo(
        _iso(origin, 33, D + 0.6, 12).dx,
        _iso(origin, 33, D + 0.6, 12).dy,
      )
      ..lineTo(
        _iso(origin, 19, D + 0.6, 12).dx,
        _iso(origin, 19, D + 0.6, 12).dy,
      )
      ..close();
    canvas.drawPath(
      windowGlass,
      Paint()..color = const Color(0xFFFEF3C7).withValues(alpha: 0.45),
    );

    // Window muntin grid lines
    final windowFramePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawLine(
      _iso(origin, 26, D + 0.7, 42),
      _iso(origin, 26, D + 0.7, 12),
      windowFramePaint,
    );
    canvas.drawLine(
      _iso(origin, 19, D + 0.7, 27),
      _iso(origin, 33, D + 0.7, 27),
      windowFramePaint,
    );

    // 3D Striped Awning extending over the storefront
    const awningDepth = 12.0;
    const awningDrop = 14.0;
    const stripeCount = 6;
    const stripeW = L / stripeCount;

    for (var i = 0; i < stripeCount; i++) {
      final uStart = i * stripeW;
      final uEnd = (i + 1) * stripeW;
      final isCream = i.isEven;
      final stripeColor = isCream
          ? const Color(0xFFFEF3C7)
          : const Color(0xFFF59E0B);

      final awningStripe = Path()
        ..moveTo(_iso(origin, uStart, D, 48).dx, _iso(origin, uStart, D, 48).dy)
        ..lineTo(_iso(origin, uEnd, D, 48).dx, _iso(origin, uEnd, D, 48).dy)
        ..lineTo(
          _iso(origin, uEnd, D + awningDepth, 48 - awningDrop).dx,
          _iso(origin, uEnd, D + awningDepth, 48 - awningDrop).dy,
        )
        ..lineTo(
          _iso(origin, uStart, D + awningDepth, 48 - awningDrop).dx,
          _iso(origin, uStart, D + awningDepth, 48 - awningDrop).dy,
        )
        ..close();
      canvas.drawPath(awningStripe, Paint()..color = stripeColor);

      // Awning front valance scallop/panel
      final valanceStripe = Path()
        ..moveTo(
          _iso(origin, uStart, D + awningDepth, 48 - awningDrop).dx,
          _iso(origin, uStart, D + awningDepth, 48 - awningDrop).dy,
        )
        ..lineTo(
          _iso(origin, uEnd, D + awningDepth, 48 - awningDrop).dx,
          _iso(origin, uEnd, D + awningDepth, 48 - awningDrop).dy,
        )
        ..lineTo(
          _iso(origin, uEnd, D + awningDepth, 48 - awningDrop - 5).dx,
          _iso(origin, uEnd, D + awningDepth, 48 - awningDrop - 5).dy,
        )
        ..lineTo(
          _iso(origin, uStart, D + awningDepth, 48 - awningDrop - 5).dx,
          _iso(origin, uStart, D + awningDepth, 48 - awningDrop - 5).dy,
        )
        ..close();
      canvas.drawPath(
        valanceStripe,
        Paint()
          ..color = isCream ? const Color(0xFFFDE68A) : const Color(0xFFD97706),
      );
    }
  }

  void _drawParcelStack(Canvas canvas) {
    // Box 1: Cardboard kraft parcel (Base left)
    _drawIsoBox(
      canvas,
      origin: const Offset(105, 115),
      L: 36,
      D: 38,
      H: 34,
      topColor: const Color(0xFFCBD5E1),
      leftColor: const Color(0xFF94A3B8),
      rightColor: const Color(0xFF64748B),
      tapeColor: Colors.white.withValues(alpha: 0.5),
    );

    // Box 2: Teal inventory parcel (Base right / beside box 1)
    _drawIsoBox(
      canvas,
      origin: const Offset(152, 108),
      L: 32,
      D: 34,
      H: 30,
      topColor: const Color(0xFF5EEAD4),
      leftColor: const Color(0xFF14B8A6),
      rightColor: const Color(0xFF0F766E),
      tapeColor: Colors.white.withValues(alpha: 0.6),
    );

    // Box 3: Deep teal inventory parcel resting on top of Box 1 & 2
    _drawIsoBox(
      canvas,
      origin: const Offset(120, 78),
      L: 30,
      D: 30,
      H: 26,
      topColor: const Color(0xFF99F6E4),
      leftColor: const Color(0xFF2DD4BF),
      rightColor: const Color(0xFF115E59),
      tapeColor: Colors.white.withValues(alpha: 0.6),
    );

    // Box 4: Small neutral parcel in foreground
    _drawIsoBox(
      canvas,
      origin: const Offset(164, 126),
      L: 20,
      D: 22,
      H: 18,
      topColor: const Color(0xFFF1F5F9),
      leftColor: const Color(0xFFCBD5E1),
      rightColor: const Color(0xFF94A3B8),
      tapeColor: Colors.white.withValues(alpha: 0.5),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
