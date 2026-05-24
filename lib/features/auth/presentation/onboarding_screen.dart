import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../settings/providers/shop_provider.dart';
import '../providers/auth_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
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
  String _accountType = 'PERSONAL';
  
  Map<String, dynamic>? _selectedShop;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _usernameFocus.addListener(() => setState(() => _usernameHasFocus = _usernameFocus.hasFocus));
    _phoneFocus.addListener(() => setState(() => _phoneHasFocus = _phoneFocus.hasFocus));
    _fullNameFocus.addListener(() => setState(() => _fullNameHasFocus = _fullNameFocus.hasFocus));
    _shopNameFocus.addListener(() => setState(() => _shopNameHasFocus = _shopNameFocus.hasFocus));
    _ownerNameFocus.addListener(() => setState(() => _ownerNameHasFocus = _ownerNameFocus.hasFocus));
    _addressFocus.addListener(() => setState(() => _addressHasFocus = _addressFocus.hasFocus));
    _shopCodeFocus.addListener(() => setState(() => _shopCodeHasFocus = _shopCodeFocus.hasFocus));
    _shopSearchFocus.addListener(() => setState(() => _shopSearchHasFocus = _shopSearchFocus.hasFocus));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider).user;
      final shopState = ref.read(shopProvider);
      if (user != null) {
        _fullNameCtrl.text = user['fullName'] ?? '';
        _accountType = user['accountType'] ?? 'PERSONAL';
        final username = user['username'] as String?;
        final phone = user['phone'] as String?;
        
        setState(() {
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

  Future<void> _submit() async {
    final username = _usernameCtrl.text.trim();
    final fullName = _fullNameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final shopName = _shopNameCtrl.text.trim();
    final ownerName = _ownerNameCtrl.text.trim();
    final address = _addressCtrl.text.trim();
    final shopCode = _shopCodeCtrl.text.trim();

    if (fullName.isEmpty || (_needsUsername && username.isEmpty) || (_needsPhone && phone.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng điền đầy đủ thông tin'), backgroundColor: AppColors.danger),
      );
      return;
    }

    if (_accountType == 'SHOP' && shopName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập Tên cửa hàng'), backgroundColor: AppColors.danger),
      );
      return;
    }

    if (_accountType == 'PERSONAL' && _needsShop && shopCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập Mã cửa hàng muốn tham gia'), backgroundColor: AppColors.danger),
      );
      return;
    }
    
    if (_needsUsername) {
      if (username.contains(' ') || username.length < 4) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tên đăng nhập không được có khoảng trắng và phải dài từ 4 ký tự.'), backgroundColor: AppColors.danger),
        );
        return;
      }
    }

    if (_needsPhone) {
      if (!RegExp(r'^(0|\+84)\d{8,9}$').hasMatch(phone)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Số điện thoại không hợp lệ.'), backgroundColor: AppColors.danger),
        );
        return;
      }
    }

    final success = await ref.read(authProvider.notifier).completeOnboarding(
      username: _needsUsername ? username : null,
      phone: _needsPhone ? phone : null,
      fullName: fullName,
      shopName: _accountType == 'SHOP' ? shopName : null,
      ownerName: _accountType == 'SHOP' ? ownerName : null,
      address: _accountType == 'SHOP' ? address : null,
      shopCode: (_accountType == 'PERSONAL' && _needsShop) ? shopCode : null,
      shopId: (_accountType == 'PERSONAL' && _needsShop && _selectedShop != null) ? _selectedShop!['id'].toString() : null,
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
                  Center(
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.15)),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(alpha: 0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(Icons.person_pin_rounded, size: 48, color: theme.colorScheme.primary),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Hoàn tất thông tin',
                    style: GoogleFonts.outfit(
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
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      c: c,
                      theme: theme,
                    ),
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
                            final results = await ref.read(authProvider.notifier).searchShops(val);
                            if (mounted) setState(() { _searchResults = results; _isSearching = false; });
                          } else {
                            if (mounted) setState(() { _searchResults = []; });
                          }
                        },
                        suffixIcon: _isSearching ? Padding(
                          padding: const EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary),
                          ),
                        ) : null,
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
                              separatorBuilder: (context, index) => Divider(height: 1, color: c.divider),
                              itemBuilder: (context, index) {
                                final shop = _searchResults[index];
                                return ListTile(
                                  leading: shop['logoUrl'] != null 
                                      ? Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            image: DecorationImage(image: NetworkImage(shop['logoUrl']), fit: BoxFit.cover),
                                          ),
                                        )
                                      : Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(shop['shopName']?[0] ?? 'S', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                                        ),
                                  title: Text(shop['shopName'] ?? '', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14, color: c.textPrimary)),
                                  subtitle: Text(shop['address'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 12, color: c.textSecondary)),
                                  onTap: () {
                                    setState(() {
                                      _selectedShop = shop;
                                      _searchResults = [];
                                      _shopSearchCtrl.text = shop['shopName'] ?? '';
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
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text('Hoặc', style: GoogleFonts.inter(fontSize: 13, color: c.textMuted, fontWeight: FontWeight.w500)),
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
                          color: theme.colorScheme.primary.withValues(alpha: 0.05),
                          border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.15)),
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
                                      image: DecorationImage(image: NetworkImage(_selectedShop!['logoUrl']), fit: BoxFit.cover),
                                    ),
                                  )
                                : Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(_selectedShop!['shopName']?[0] ?? 'S', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 18)),
                                  ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_selectedShop!['shopName'] ?? '', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: c.textPrimary)),
                                  const SizedBox(height: 2),
                                  Text(_selectedShop!['address'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 12, color: c.textSecondary)),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close_rounded, color: c.textMuted),
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
                        border: Border.all(color: AppColors.danger.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              state.error!,
                              style: GoogleFonts.inter(color: AppColors.danger, fontSize: 13, fontWeight: FontWeight.w500),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: state.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            _accountType == 'SHOP'
                                ? 'Tạo cửa hàng & Bắt đầu'
                                : !_needsShop
                                    ? 'Hoàn tất & Bắt đầu'
                                    : 'Gửi yêu cầu tham gia',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                  ),
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
            borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}
