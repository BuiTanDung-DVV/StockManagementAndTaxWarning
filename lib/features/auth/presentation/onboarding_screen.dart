import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/utils/toast_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;
import '../../../core/assets/app_assets.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../settings/providers/shop_provider.dart';
import '../providers/auth_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _introController = PageController();
  final _usernameCtrl = TextEditingController();
  final _fullNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _shopNameCtrl = TextEditingController();
  final _ownerNameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _shopCodeCtrl = TextEditingController();
  final _shopSearchCtrl = TextEditingController();

  // Focus nodes for input glows
  final _usernameFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _fullNameFocus = FocusNode();
  final _shopNameFocus = FocusNode();
  final _ownerNameFocus = FocusNode();
  final _addressFocus = FocusNode();
  final _shopCodeFocus = FocusNode();
  final _shopSearchFocus = FocusNode();

  bool _usernameHasFocus = false;
  bool _phoneHasFocus = false;
  bool _fullNameHasFocus = false;
  bool _shopNameHasFocus = false;
  bool _ownerNameHasFocus = false;
  bool _addressHasFocus = false;
  bool _shopCodeHasFocus = false;
  bool _shopSearchHasFocus = false;

  bool _needsUsername = false;
  bool _needsPhone = false;
  bool _needsShop = true;
  bool _hasSelectedAccountType = false;
  int _introStep = 0;
  String _accountType = 'PERSONAL';

  Map<String, dynamic>? _selectedShop;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  List<Map<String, dynamic>> _addressSuggestions = [];
  bool _isSearchingAddress = false;
  double? _selectedLat;
  double? _selectedLon;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _usernameFocus.addListener(
      () => setState(() => _usernameHasFocus = _usernameFocus.hasFocus),
    );
    _phoneFocus.addListener(
      () => setState(() => _phoneHasFocus = _phoneFocus.hasFocus),
    );
    _fullNameFocus.addListener(
      () => setState(() => _fullNameHasFocus = _fullNameFocus.hasFocus),
    );
    _shopNameFocus.addListener(
      () => setState(() => _shopNameHasFocus = _shopNameFocus.hasFocus),
    );
    _ownerNameFocus.addListener(
      () => setState(() => _ownerNameHasFocus = _ownerNameFocus.hasFocus),
    );
    _addressFocus.addListener(
      () => setState(() => _addressHasFocus = _addressFocus.hasFocus),
    );
    _shopCodeFocus.addListener(
      () => setState(() => _shopCodeHasFocus = _shopCodeFocus.hasFocus),
    );
    _shopSearchFocus.addListener(
      () => setState(() => _shopSearchHasFocus = _shopSearchFocus.hasFocus),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider).user;
      final shopState = ref.read(shopProvider);
      if (user != null) {
        _fullNameCtrl.text = user['fullName'] ?? '';
        final savedAccountType = user['accountType'] as String?;
        _accountType = savedAccountType ?? 'PERSONAL';
        final username = user['username'] as String?;
        final phone = user['phone'] as String?;

        setState(() {
          _hasSelectedAccountType = savedAccountType != null;
          if (username != null && phone != null && username == phone) {
            _needsUsername = true;
          } else if (phone == null || phone.isEmpty) {
            _needsPhone = true;
          }
          if (_accountType == 'PERSONAL' && shopState.userShops.isNotEmpty) {
            _needsShop = false;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _introController.dispose();
    _usernameCtrl.dispose();
    _fullNameCtrl.dispose();
    _phoneCtrl.dispose();
    _shopNameCtrl.dispose();
    _ownerNameCtrl.dispose();
    _addressCtrl.dispose();
    _shopCodeCtrl.dispose();
    _shopSearchCtrl.dispose();

    _usernameFocus.dispose();
    _phoneFocus.dispose();
    _fullNameFocus.dispose();
    _shopNameFocus.dispose();
    _ownerNameFocus.dispose();
    _addressFocus.dispose();
    _shopCodeFocus.dispose();
    _shopSearchFocus.dispose();
    super.dispose();
  }

  void _goToIntroStep(int step) {
    final target = step.clamp(0, 2).toInt();
    _introController.animateToPage(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildOnboardingSlides(AppThemeColors c, ThemeData theme) {
    return Column(
      children: [
        Row(
          children: [
            Text(
              'Thiết lập tài khoản',
              style: GoogleFonts.manrope(
                color: c.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            Text(
              'Bước ${_introStep + 1}/3',
              style: GoogleFonts.inter(
                color: c.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: List.generate(3, (index) {
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                height: 4,
                margin: EdgeInsets.only(right: index == 2 ? 0 : 8),
                decoration: BoxDecoration(
                  color: index <= _introStep
                      ? theme.colorScheme.primary
                      : c.divider,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 286,
          child: PageView(
            controller: _introController,
            onPageChanged: (value) => setState(() => _introStep = value),
            children: [
              _buildIntroSlide(
                c: c,
                theme: theme,
                asset: AppAssets.appIcon,
                title: 'Chào mừng đến SmartStock',
                description:
                    'Một không gian thống nhất để quản lý bán hàng, tồn kho, dòng tiền và nghĩa vụ thuế.',
                points: const [
                  'Theo dõi hoạt động cửa hàng theo thời gian thực',
                  'Dữ liệu được phân tách an toàn theo từng cửa hàng',
                  'Cảnh báo những việc cần xử lý trước khi quá hạn',
                ],
              ),
              _buildIntroSlide(
                c: c,
                theme: theme,
                asset: AppAssets.inventory,
                title: 'Thiết lập theo đúng cách bạn làm việc',
                description:
                    'Thông tin ở bước tiếp theo quyết định luồng tạo cửa hàng hoặc xin tham gia cửa hàng.',
                points: const [
                  'Chủ cửa hàng tạo không gian quản lý mới',
                  'Nhân viên gửi yêu cầu và chờ chủ cửa hàng duyệt',
                  'Quyền quản trị không được cấp trực tiếp từ thiết bị',
                ],
              ),
              _buildRoleSlide(c, theme),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            if (_introStep > 0)
              TextButton(
                onPressed: () => _goToIntroStep(_introStep - 1),
                child: const Text('Quay lại'),
              )
            else
              const SizedBox(width: 84),
            const Spacer(),
            if (_introStep < 2)
              FilledButton(
                onPressed: () => _goToIntroStep(_introStep + 1),
                child: const Text('Tiếp tục'),
              )
            else
              Text(
                'Vuốt lên để nhập thông tin',
                style: GoogleFonts.inter(
                  color: c.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildIntroSlide({
    required AppThemeColors c,
    required ThemeData theme,
    required String asset,
    required String title,
    required String description,
    required List<String> points,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppAssetIcon(assetPath: asset, size: 42),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.manrope(
              color: c.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: GoogleFonts.inter(
              color: c.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          ...points.map(
            (point) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      point,
                      style: GoogleFonts.inter(
                        color: c.textPrimary,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSlide(AppThemeColors c, ThemeData theme) {
    Widget option({
      required String value,
      required String title,
      required String description,
      required String asset,
    }) {
      final selected = _hasSelectedAccountType && _accountType == value;
      return Expanded(
        child: InkWell(
          onTap: () => setState(() {
            _accountType = value;
            _hasSelectedAccountType = true;
          }),
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selected
                  ? theme.colorScheme.primary.withValues(alpha: 0.08)
                  : c.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? theme.colorScheme.primary : c.divider,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppAssetIcon(
                  assetPath: asset,
                  size: 32,
                  color: selected ? theme.colorScheme.primary : c.textSecondary,
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: GoogleFonts.manrope(
                    color: c.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    color: c.textSecondary,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bạn sử dụng SmartStock với vai trò nào?',
            style: GoogleFonts.manrope(
              color: c.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Lựa chọn này chỉ quyết định luồng thiết lập. Quyền truy cập thực tế vẫn do hệ thống và chủ cửa hàng kiểm soát.',
            style: GoogleFonts.inter(
              color: c.textSecondary,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                option(
                  value: 'SHOP',
                  title: 'Chủ cửa hàng',
                  description: 'Tạo cửa hàng mới và quản lý toàn bộ hoạt động.',
                  asset: AppAssets.home,
                ),
                const SizedBox(width: 12),
                option(
                  value: 'PERSONAL',
                  title: 'Nhân viên',
                  description: 'Tìm cửa hàng và gửi yêu cầu tham gia.',
                  asset: AppAssets.emptyPeople,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _searchAddress(String query) async {
    if (query.trim().length < 3) {
      setState(() => _addressSuggestions = []);
      return;
    }
    setState(() => _isSearchingAddress = true);

    try {
      final response = await ref
          .read(apiClientProvider)
          .get('/auth/address-suggestions', params: {'q': query.trim()});
      if (response is List) {
        final list = response
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        if (mounted) {
          setState(() {
            _addressSuggestions = list;
          });
        }
      }
    } catch (e) {
      debugPrint('Address search error: $e');
    } finally {
      if (mounted) setState(() => _isSearchingAddress = false);
    }
  }

  void _onAddressChanged(String val) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 600), () {
      _searchAddress(val);
    });
  }

  Future<void> _submit() async {
    final username = _usernameCtrl.text.trim();
    final fullName = _fullNameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final shopName = _shopNameCtrl.text.trim();
    final ownerName = _ownerNameCtrl.text.trim();
    final address = _addressCtrl.text.trim();
    final shopCode = _shopCodeCtrl.text.trim();

    if (!_hasSelectedAccountType) {
      ToastService.showError('Vui lòng chọn Chủ cửa hàng hoặc Nhân viên');
      return;
    }

    if (fullName.isEmpty ||
        (_needsUsername && username.isEmpty) ||
        (_needsPhone && phone.isEmpty)) {
      ToastService.showError('Vui lòng điền đầy đủ thông tin');
      return;
    }

    if (_accountType == 'SHOP' && shopName.isEmpty) {
      ToastService.showError('Vui lòng nhập Tên cửa hàng');
      return;
    }

    if (_accountType == 'PERSONAL' && _needsShop && shopCode.isEmpty) {
      ToastService.showError('Vui lòng nhập Mã cửa hàng muốn tham gia');
      return;
    }

    if (_needsUsername) {
      if (username.contains(' ') || username.length < 4) {
        ToastService.showError(
          'Tên đăng nhập không được có khoảng trắng và phải dài từ 4 ký tự.',
        );
        return;
      }
    }

    if (_needsPhone) {
      if (!RegExp(r'^(0|\+84)\d{8,9}$').hasMatch(phone)) {
        ToastService.showError('Số điện thoại không hợp lệ.');
        return;
      }
    }

    final success = await ref
        .read(authProvider.notifier)
        .completeOnboarding(
          accountType: _accountType,
          username: _needsUsername ? username : null,
          phone: _needsPhone ? phone : null,
          fullName: fullName,
          shopName: _accountType == 'SHOP' ? shopName : null,
          ownerName: _accountType == 'SHOP' ? ownerName : null,
          address: _accountType == 'SHOP' ? address : null,
          shopCode: (_accountType == 'PERSONAL' && _needsShop)
              ? shopCode
              : null,
          shopId:
              (_accountType == 'PERSONAL' &&
                  _needsShop &&
                  _selectedShop != null)
              ? _selectedShop!['id'].toString()
              : null,
        );
    if (success && mounted) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildOnboardingSlides(c, theme),
                  if (_introStep == 2) ...[
                    const SizedBox(height: 28),
                    Center(
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.15,
                            ),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.1,
                              ),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.person_pin_rounded,
                          size: 48,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Hoàn tất thông tin',
                      style: GoogleFonts.manrope(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                        color: c.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Bạn chưa hoàn thành thiết lập tài khoản. Vui lòng bổ sung các thông tin còn thiếu để tiếp tục sử dụng ứng dụng.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: c.textSecondary,
                        height: 1.45,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    if (_needsUsername) ...[
                      _buildGlowingField(
                        controller: _usernameCtrl,
                        focusNode: _usernameFocus,
                        hasFocus: _usernameHasFocus,
                        labelText: 'Tên đăng nhập mới *',
                        hintText: 'VD: nguyenvan_a123',
                        icon: Icons.account_circle_outlined,
                        c: c,
                        theme: theme,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_needsPhone) ...[
                      _buildGlowingField(
                        controller: _phoneCtrl,
                        focusNode: _phoneFocus,
                        hasFocus: _phoneHasFocus,
                        labelText: 'Số điện thoại *',
                        hintText: 'VD: 0987654321',
                        icon: Icons.phone_android_rounded,
                        keyboardType: TextInputType.phone,
                        c: c,
                        theme: theme,
                      ),
                      const SizedBox(height: 16),
                    ],
                    _buildGlowingField(
                      controller: _fullNameCtrl,
                      focusNode: _fullNameFocus,
                      hasFocus: _fullNameHasFocus,
                      labelText: 'Họ và tên của bạn *',
                      icon: Icons.badge_outlined,
                      c: c,
                      theme: theme,
                    ),

                    if (_accountType == 'SHOP') ...[
                      const SizedBox(height: 16),
                      _buildGlowingField(
                        controller: _shopNameCtrl,
                        focusNode: _shopNameFocus,
                        hasFocus: _shopNameHasFocus,
                        labelText: 'Tên cửa hàng / Doanh nghiệp *',
                        icon: Icons.storefront_rounded,
                        c: c,
                        theme: theme,
                      ),
                      const SizedBox(height: 16),
                      _buildGlowingField(
                        controller: _ownerNameCtrl,
                        focusNode: _ownerNameFocus,
                        hasFocus: _ownerNameHasFocus,
                        labelText: 'Tên chủ cửa hàng / Đại diện',
                        icon: Icons.person_outline_rounded,
                        c: c,
                        theme: theme,
                      ),
                      const SizedBox(height: 16),
                      _buildGlowingField(
                        controller: _addressCtrl,
                        focusNode: _addressFocus,
                        hasFocus: _addressHasFocus,
                        labelText: 'Địa chỉ kinh doanh',
                        icon: Icons.location_on_outlined,
                        c: c,
                        theme: theme,
                        onChanged: _onAddressChanged,
                        suffixIcon: _isSearchingAddress
                            ? Padding(
                                padding: const EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      if (_addressSuggestions.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          decoration: BoxDecoration(
                            color: c.card.withValues(alpha: 0.95),
                            border: Border.all(color: c.divider),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          constraints: const BoxConstraints(maxHeight: 200),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const BouncingScrollPhysics(),
                              itemCount: _addressSuggestions.length,
                              separatorBuilder: (context, index) =>
                                  Divider(height: 1, color: c.divider),
                              itemBuilder: (context, index) {
                                final suggestion = _addressSuggestions[index];
                                return ListTile(
                                  leading: Icon(
                                    Icons.location_on_rounded,
                                    color: theme.colorScheme.primary,
                                    size: 20,
                                  ),
                                  title: Text(
                                    suggestion['display_name'] ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: c.textPrimary,
                                    ),
                                  ),
                                  onTap: () {
                                    setState(() {
                                      _addressCtrl.text =
                                          suggestion['display_name'] ?? '';
                                      _selectedLat = suggestion['lat'] != null
                                          ? double.tryParse(
                                              suggestion['lat'].toString(),
                                            )
                                          : 10.762622;
                                      _selectedLon = suggestion['lon'] != null
                                          ? double.tryParse(
                                              suggestion['lon'].toString(),
                                            )
                                          : 106.660172;
                                      _addressSuggestions = [];
                                    });
                                    FocusScope.of(context).unfocus();
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                      if (_selectedLat != null && _selectedLon != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.04,
                            ),
                            border: Border.all(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.15,
                              ),
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.map_rounded,
                                    color: theme.colorScheme.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Bản đồ vị trí',
                                    style: GoogleFonts.manrope(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: c.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  height: 120,
                                  width: double.infinity,
                                  color: c.card,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Positioned.fill(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                c.card,
                                                theme.colorScheme.primary
                                                    .withValues(alpha: 0.08),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                          ),
                                        ),
                                      ),
                                      FlutterMap(
                                        options: MapOptions(
                                          initialCenter: latlong.LatLng(
                                            _selectedLat!,
                                            _selectedLon!,
                                          ),
                                          initialZoom: 15.0,
                                          interactionOptions:
                                              const InteractionOptions(
                                                flags:
                                                    InteractiveFlag.all &
                                                    ~InteractiveFlag.rotate,
                                              ),
                                        ),
                                        children: [
                                          TileLayer(
                                            urlTemplate:
                                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                            userAgentPackageName:
                                                'com.sales_stock_management.app',
                                          ),
                                          MarkerLayer(
                                            markers: [
                                              Marker(
                                                point: latlong.LatLng(
                                                  _selectedLat!,
                                                  _selectedLon!,
                                                ),
                                                width: 40,
                                                height: 40,
                                                child: const Icon(
                                                  Icons.location_pin,
                                                  color: AppColors.danger,
                                                  size: 36,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ] else if (_accountType == 'PERSONAL' && _needsShop) ...[
                      const SizedBox(height: 16),
                      if (_selectedShop == null) ...[
                        _buildGlowingField(
                          controller: _shopSearchCtrl,
                          focusNode: _shopSearchFocus,
                          hasFocus: _shopSearchHasFocus,
                          labelText: 'Tìm Cửa hàng / Doanh nghiệp',
                          hintText: 'Nhập tên cửa hàng...',
                          icon: Icons.search_rounded,
                          c: c,
                          theme: theme,
                          onChanged: (val) async {
                            if (val.trim().length > 2) {
                              setState(() => _isSearching = true);
                              try {
                                final results = await ref
                                    .read(authProvider.notifier)
                                    .searchShops(val);
                                if (mounted) {
                                  setState(() => _searchResults = results);
                                }
                              } catch (error) {
                                if (mounted) {
                                  setState(() => _searchResults = []);
                                  ToastService.showError(
                                    'Không thể tải cửa hàng từ cơ sở dữ liệu',
                                  );
                                }
                              } finally {
                                if (mounted) {
                                  setState(() => _isSearching = false);
                                }
                              }
                            } else {
                              if (mounted) {
                                setState(() {
                                  _searchResults = [];
                                });
                              }
                            }
                          },
                          suffixIcon: _isSearching
                              ? Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        if (_searchResults.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            decoration: BoxDecoration(
                              color: c.card.withValues(alpha: 0.95),
                              border: Border.all(color: c.divider),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            constraints: const BoxConstraints(maxHeight: 200),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: ListView.separated(
                                shrinkWrap: true,
                                physics: const BouncingScrollPhysics(),
                                itemCount: _searchResults.length,
                                separatorBuilder: (context, index) =>
                                    Divider(height: 1, color: c.divider),
                                itemBuilder: (context, index) {
                                  final shop = _searchResults[index];
                                  return ListTile(
                                    leading: shop['logoUrl'] != null
                                        ? Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              image: DecorationImage(
                                                image: NetworkImage(
                                                  shop['logoUrl'],
                                                ),
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          )
                                        : Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              color: theme.colorScheme.primary
                                                  .withValues(alpha: 0.1),
                                              shape: BoxShape.circle,
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              shop['shopName']?[0] ?? 'S',
                                              style: TextStyle(
                                                color:
                                                    theme.colorScheme.primary,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                    title: Text(
                                      shop['shopName'] ?? '',
                                      style: GoogleFonts.manrope(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: c.textPrimary,
                                      ),
                                    ),
                                    subtitle: Text(
                                      shop['address'] ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: c.textSecondary,
                                      ),
                                    ),
                                    onTap: () {
                                      setState(() {
                                        _selectedShop = shop;
                                        _searchResults = [];
                                        _shopSearchCtrl.text =
                                            shop['shopName'] ?? '';
                                      });
                                    },
                                  );
                                },
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: Divider(color: c.divider)),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Text(
                                'Hoặc',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: c.textMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Expanded(child: Divider(color: c.divider)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildGlowingField(
                          controller: _shopCodeCtrl,
                          focusNode: _shopCodeFocus,
                          hasFocus: _shopCodeHasFocus,
                          labelText: 'Mã cửa hàng *',
                          hintText: 'Nhập mã 6 ký tự được cung cấp',
                          icon: Icons.qr_code_rounded,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                          c: c,
                          theme: theme,
                        ),
                      ] else ...[
                        // Shop Selected UI
                        Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.05,
                            ),
                            border: Border.all(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.15,
                              ),
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              _selectedShop!['logoUrl'] != null
                                  ? Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        image: DecorationImage(
                                          image: NetworkImage(
                                            _selectedShop!['logoUrl'],
                                          ),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    )
                                  : Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        _selectedShop!['shopName']?[0] ?? 'S',
                                        style: TextStyle(
                                          color: theme.colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedShop!['shopName'] ?? '',
                                      style: GoogleFonts.manrope(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: c.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _selectedShop!['address'] ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: c.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: c.textMuted,
                                ),
                                onPressed: () => setState(() {
                                  _selectedShop = null;
                                  _shopCodeCtrl.clear();
                                  _shopSearchCtrl.clear();
                                }),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildGlowingField(
                          controller: _shopCodeCtrl,
                          focusNode: _shopCodeFocus,
                          hasFocus: _shopCodeHasFocus,
                          labelText: 'Xác thực Mã cửa hàng *',
                          hintText: 'Nhập mã 6 ký tự được cung cấp',
                          icon: Icons.security_rounded,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                          c: c,
                          theme: theme,
                        ),
                      ],
                    ],

                    if (state.error != null) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.danger.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: AppColors.danger,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                state.error!,
                                style: GoogleFonts.inter(
                                  color: AppColors.danger,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 36),
                    ElevatedButton(
                      onPressed: state.isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: state.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _accountType == 'SHOP'
                                  ? 'Tạo cửa hàng & Bắt đầu'
                                  : !_needsShop
                                  ? 'Hoàn tất & Bắt đầu'
                                  : 'Gửi yêu cầu tham gia',
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlowingField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool hasFocus,
    required String labelText,
    required IconData icon,
    required AppThemeColors c,
    required ThemeData theme,
    String? hintText,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.next,
    void Function(String)? onSubmitted,
    void Function(String)? onChanged,
    Widget? suffixIcon,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (hasFocus)
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.15),
              blurRadius: 12,
              spreadRadius: 2,
            ),
        ],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        onChanged: onChanged,
        style: GoogleFonts.inter(fontSize: 13, color: c.textPrimary),
        decoration: InputDecoration(
          labelText: labelText,
          hintText: hintText,
          prefixIcon: Icon(icon, color: c.textMuted, size: 20),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: c.card,
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
            borderSide: BorderSide(
              color: theme.colorScheme.primary,
              width: 1.5,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}
