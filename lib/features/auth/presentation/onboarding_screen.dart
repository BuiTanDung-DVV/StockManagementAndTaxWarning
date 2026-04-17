import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
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

  bool _needsUsername = false;
  bool _needsPhone = false;
  String _accountType = 'PERSONAL';
  
  Map<String, dynamic>? _selectedShop;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider).user;
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

    if (_accountType == 'PERSONAL' && shopCode.isEmpty) {
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
      shopName: shopName,
      ownerName: ownerName,
      address: address,
      shopCode: shopCode,
      shopId: _selectedShop?['id']?.toString(),
    );
    if (success && mounted) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final state = ref.watch(authProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.person_pin, size: 80, color: AppColors.primary),
                  const SizedBox(height: 24),
                  const Text('Hoàn tất thông tin', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text('Bạn chưa hoàn thành thiết lập tài khoản. Vui lòng bổ sung các thông tin còn thiếu để tiếp tục sử dụng ứng dụng.',
                      style: TextStyle(fontSize: 14, color: c.textSecondary), textAlign: TextAlign.center),
                  const SizedBox(height: 32),
                  if (_needsUsername) ...[
                    TextField(
                      controller: _usernameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Tên đăng nhập mới',
                        hintText: 'VD: nguyenvan_a123',
                        prefixIcon: Icon(Icons.account_circle, color: c.textMuted),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_needsPhone) ...[
                    TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Số điện thoại',
                        hintText: 'VD: 0987654321',
                        prefixIcon: Icon(Icons.phone, color: c.textMuted),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: _fullNameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Họ và tên của bạn',
                      prefixIcon: Icon(Icons.badge, color: c.textMuted),
                    ),
                  ),
                  if (_accountType == 'SHOP') ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _shopNameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Tên cửa hàng / Doanh nghiệp *',
                        prefixIcon: Icon(Icons.store, color: c.textMuted),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _ownerNameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Tên chủ cửa hàng / Đại diện',
                        prefixIcon: Icon(Icons.person, color: c.textMuted),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _addressCtrl,
                      decoration: InputDecoration(
                        labelText: 'Địa chỉ kinh doanh',
                        prefixIcon: Icon(Icons.location_on, color: c.textMuted),
                      ),
                    ),
                  ] else if (_accountType == 'PERSONAL') ...[
                    const SizedBox(height: 16),
                    if (_selectedShop == null) ...[
                      TextField(
                        controller: _shopSearchCtrl,
                        onChanged: (val) async {
                          if (val.trim().length > 2) {
                            setState(() => _isSearching = true);
                            final results = await ref.read(authProvider.notifier).searchShops(val);
                            if (mounted) setState(() { _searchResults = results; _isSearching = false; });
                          } else {
                            if (mounted) setState(() { _searchResults = []; });
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'Tìm Cửa hàng / Doanh nghiệp',
                          hintText: 'Nhập tên cửa hàng...',
                          prefixIcon: Icon(Icons.search, color: c.textMuted),
                          suffixIcon: _isSearching ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                          ) : null,
                        ),
                      ),
                      if (_searchResults.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: c.border),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          constraints: const BoxConstraints(maxHeight: 200),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: _searchResults.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final shop = _searchResults[index];
                              return ListTile(
                                leading: shop['logoUrl'] != null 
                                    ? CircleAvatar(backgroundImage: NetworkImage(shop['logoUrl']))
                                    : CircleAvatar(child: Text(shop['shopName']?[0] ?? 'S')),
                                title: Text(shop['shopName'] ?? ''),
                                subtitle: Text(shop['address'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
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
                      const SizedBox(height: 16),
                      const Center(child: Text('Hoặc', style: TextStyle(color: Colors.grey))),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _shopCodeCtrl,
                        decoration: InputDecoration(
                          labelText: 'Mã cửa hàng (Tra cứu trực tiếp qua mã) *',
                          hintText: 'Nhập mã 6 ký tự được cung cấp',
                          prefixIcon: Icon(Icons.qr_code, color: c.textMuted),
                        ),
                      ),
                    ] else ...[
                      // Shop Selected UI
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(color: c.border),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          leading: _selectedShop!['logoUrl'] != null 
                              ? CircleAvatar(backgroundImage: NetworkImage(_selectedShop!['logoUrl']))
                              : CircleAvatar(child: Text(_selectedShop!['shopName']?[0] ?? 'S')),
                          title: Text(_selectedShop!['shopName'] ?? ''),
                          subtitle: Text(_selectedShop!['address'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(() {
                              _selectedShop = null;
                              _shopCodeCtrl.clear();
                              _shopSearchCtrl.clear();
                            }),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _shopCodeCtrl,
                        decoration: InputDecoration(
                          labelText: 'Xác thực Mã cửa hàng *',
                          hintText: 'Nhập mã 6 ký tự được cung cấp',
                          prefixIcon: Icon(Icons.security, color: c.textMuted),
                        ),
                      ),
                    ],
                  ],
                  if (state.error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                      child: Row(children: [
                        const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text(state.error!, style: const TextStyle(color: AppColors.danger, fontSize: 13))),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: state.isLoading ? null : _submit,
                    child: state.isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(_accountType == 'SHOP' ? 'Tạo cửa hàng' : 'Gửi yêu cầu tham gia'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
