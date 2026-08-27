import 'package:flutter/material.dart';
import '../../../core/utils/toast_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/app_navigation_back_button.dart';
import '../providers/system_provider.dart';

class PaymentConfigScreen extends ConsumerStatefulWidget {
  const PaymentConfigScreen({super.key});
  @override
  ConsumerState<PaymentConfigScreen> createState() =>
      _PaymentConfigScreenState();
}

class _PaymentConfigScreenState extends ConsumerState<PaymentConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _bankId;
  final _accountNoCtrl = TextEditingController();
  final _accountNameCtrl = TextEditingController();

  final _accountNoFocus = FocusNode();
  final _accountNameFocus = FocusNode();

  bool _accountNoHasFocus = false;
  bool _accountNameHasFocus = false;

  bool _loading = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _accountNoFocus.addListener(
      () => setState(() => _accountNoHasFocus = _accountNoFocus.hasFocus),
    );
    _accountNameFocus.addListener(
      () => setState(() => _accountNameHasFocus = _accountNameFocus.hasFocus),
    );
  }

  @override
  void dispose() {
    _accountNoCtrl.dispose();
    _accountNameCtrl.dispose();
    _accountNoFocus.dispose();
    _accountNameFocus.dispose();
    super.dispose();
  }

  void _initFromProfile(Map<String, dynamic> shop) {
    if (_initialized) return;
    _initialized = true;
    _bankId = shop['bankId'] as String?;
    _accountNoCtrl.text = shop['bankAccount'] ?? '';
    _accountNameCtrl.text = shop['accountHolder'] ?? '';
  }

  String _buildQrUrl() {
    if (_bankId == null || _accountNoCtrl.text.isEmpty) return '';
    final name = Uri.encodeComponent(_accountNameCtrl.text);
    return 'https://img.vietqr.io/image/$_bankId-${_accountNoCtrl.text}-compact2.png?accountName=$name';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref
          .read(apiClientProvider)
          .post(
            '/shop-profile',
            data: {
              'bankId': _bankId,
              'bankAccount': _accountNoCtrl.text,
              'accountHolder': _accountNameCtrl.text,
            },
          );
      ref.invalidate(shopProfileProvider);
      if (mounted) {
        ToastService.showSuccess('Đã lưu cấu hình thanh toán thành công');
      }
    } catch (e) {
      if (mounted) {
        ToastService.showError('Lỗi: $e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);
    final shopAsync = ref.watch(shopProfileProvider);
    final banksAsync = ref.watch(paymentBanksProvider);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: Text(
          'Cấu hình thanh toán',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: c.textPrimary,
          ),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        leadingWidth: Navigator.of(context).canPop() ? 60 : null,
        leading: Navigator.of(context).canPop()
            ? AppNavigationBackLeading(
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: shopAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'Lỗi: $e',
            style: GoogleFonts.inter(color: AppColors.danger),
          ),
        ),
        data: (shop) {
          _initFromProfile(shop);
          if (banksAsync.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (banksAsync.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Không thể tải danh mục ngân hàng từ cơ sở dữ liệu.\n${banksAsync.error}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: AppColors.danger),
                ),
              ),
            );
          }
          final banks = banksAsync.value ?? const <Map<String, String>>[];
          final selectedBankExists = banks.any((bank) => bank['id'] == _bankId);
          final qrUrl = _buildQrUrl();

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Premium Gradient Header Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary.withValues(alpha: 0.12),
                          AppColors.info.withValues(alpha: 0.06),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.15,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.qr_code_2_rounded,
                            size: 32,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'VietQR - Thanh toán QR tự động',
                                style: GoogleFonts.manrope(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: c.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Khách hàng có thể quét mã QR ngân hàng để tự động điền thông tin chuyển khoản tại quầy.',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: c.textSecondary,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Bank selector label
                  Text(
                    'Ngân hàng thụ hưởng *',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedBankExists ? _bankId : null,
                    decoration: InputDecoration(
                      hintText: 'Chọn ngân hàng',
                      prefixIcon: Icon(
                        Icons.account_balance_rounded,
                        color: c.textMuted,
                        size: 20,
                      ),
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
                    items: banks
                        .map(
                          (b) => DropdownMenuItem(
                            value: b['id'],
                            child: Text(
                              b['name']!,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: c.textPrimary,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _bankId = v),
                    validator: (v) =>
                        v == null ? 'Vui lòng chọn ngân hàng' : null,
                  ),
                  const SizedBox(height: 20),

                  // Account number
                  Text(
                    'Số tài khoản ngân hàng *',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildGlowingField(
                    controller: _accountNoCtrl,
                    focusNode: _accountNoFocus,
                    hasFocus: _accountNoHasFocus,
                    hintText: 'Nhập số tài khoản thụ hưởng',
                    icon: Icons.credit_card_rounded,
                    keyboardType: TextInputType.number,
                    c: c,
                    theme: theme,
                    onChanged: (_) => setState(() {}),
                    validator: (v) => (v == null || v.isEmpty)
                        ? 'Vui lòng nhập số tài khoản'
                        : null,
                  ),
                  const SizedBox(height: 20),

                  // Account name
                  Text(
                    'Tên chủ tài khoản *',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildGlowingField(
                    controller: _accountNameCtrl,
                    focusNode: _accountNameFocus,
                    hasFocus: _accountNameHasFocus,
                    hintText: 'Nhập tên chủ tài khoản (VIẾT IN HOA)',
                    icon: Icons.person_pin_rounded,
                    c: c,
                    theme: theme,
                    textCapitalization: TextCapitalization.characters,
                    onChanged: (_) => setState(() {}),
                    validator: (v) => (v == null || v.isEmpty)
                        ? 'Vui lòng nhập tên chủ tài khoản'
                        : null,
                  ),
                  const SizedBox(height: 36),

                  // QR Preview
                  if (qrUrl.isNotEmpty) ...[
                    Text(
                      'Bản xem trước mã QR chuyển khoản',
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: c.divider),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            qrUrl,
                            width: 200,
                            height: 200,
                            fit: BoxFit.cover,
                            errorBuilder: (_, e, s) => SizedBox(
                              width: 200,
                              height: 200,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.broken_image_rounded,
                                      size: 40,
                                      color: c.textMuted,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Không tải được QR',
                                      style: GoogleFonts.inter(
                                        color: c.textMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'VietQR mẫu (quét để kiểm tra thông tin tài khoản)',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: c.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),
                  ],

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _loading || !selectedBankExists ? null : _save,
                      icon: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.check_circle_outline_rounded,
                              size: 20,
                            ),
                      label: Text(
                        _loading ? 'Đang lưu...' : 'Lưu cấu hình thanh toán',
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGlowingField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool hasFocus,
    required String hintText,
    required IconData icon,
    required AppThemeColors c,
    required ThemeData theme,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    void Function(String)? onChanged,
    String? Function(String?)? validator,
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
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        onChanged: onChanged,
        validator: validator,
        style: GoogleFonts.inter(fontSize: 13, color: c.textPrimary),
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: Icon(icon, color: c.textMuted, size: 20),
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
