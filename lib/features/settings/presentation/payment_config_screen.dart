import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_client.dart';
import '../providers/system_provider.dart';

/// Danh sách ngân hàng VietQR (mã bin + tên)
const _vietqrBanks = <Map<String, String>>[
  {'id': 'MB', 'name': 'MB Bank'},
  {'id': 'VCB', 'name': 'Vietcombank'},
  {'id': 'TCB', 'name': 'Techcombank'},
  {'id': 'ACB', 'name': 'ACB'},
  {'id': 'TPB', 'name': 'TPBank'},
  {'id': 'VPB', 'name': 'VPBank'},
  {'id': 'BIDV', 'name': 'BIDV'},
  {'id': 'VTB', 'name': 'VietinBank'},
  {'id': 'AGR', 'name': 'Agribank'},
  {'id': 'SHB', 'name': 'SHB'},
  {'id': 'STB', 'name': 'Sacombank'},
  {'id': 'HDB', 'name': 'HDBank'},
  {'id': 'MSB', 'name': 'MSB'},
  {'id': 'OCB', 'name': 'OCB'},
  {'id': 'LPB', 'name': 'LienVietPostBank'},
  {'id': 'EIB', 'name': 'Eximbank'},
  {'id': 'SCB', 'name': 'SCB'},
  {'id': 'NAB', 'name': 'Nam A Bank'},
  {'id': 'VAB', 'name': 'VietABank'},
  {'id': 'SEAB', 'name': 'SeABank'},
  {'id': 'BAB', 'name': 'Bac A Bank'},
  {'id': 'PVCB', 'name': 'PVcomBank'},
  {'id': 'KLB', 'name': 'KienlongBank'},
  {'id': 'ABB', 'name': 'ABBank'},
  {'id': 'WOO', 'name': 'Woori Bank VN'},
  {'id': 'CAKE', 'name': 'CAKE by VPBank'},
  {'id': 'UBANK', 'name': 'Ubank by VPBank'},
];

class PaymentConfigScreen extends ConsumerStatefulWidget {
  const PaymentConfigScreen({super.key});
  @override
  ConsumerState<PaymentConfigScreen> createState() => _PaymentConfigScreenState();
}

class _PaymentConfigScreenState extends ConsumerState<PaymentConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _bankId;
  final _accountNoCtrl = TextEditingController();
  final _accountNameCtrl = TextEditingController();
  bool _loading = false;
  bool _initialized = false;

  @override
  void dispose() {
    _accountNoCtrl.dispose();
    _accountNameCtrl.dispose();
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
      final bankName = _vietqrBanks.firstWhere((b) => b['id'] == _bankId, orElse: () => {})['name'] ?? '';
      await ref.read(apiClientProvider).post('/shop-profile', data: {
        'bankId': _bankId,
        'bankAccount': _accountNoCtrl.text,
        'bankName': bankName,
        'accountHolder': _accountNameCtrl.text,
      });
      ref.invalidate(shopProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu cấu hình'), backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppColors.danger));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final shopAsync = ref.watch(shopProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Cấu hình thanh toán')),
      body: shopAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (shop) {
          _initFromProfile(shop);
          final qrUrl = _buildQrUrl();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [AppColors.primary.withValues(alpha: 0.1), AppColors.info.withValues(alpha: 0.05)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    Icon(Icons.qr_code_2, size: 32, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('VietQR - Thanh toán QR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('Khách quét mã QR để chuyển khoản tự động', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                    ])),
                  ]),
                ),
                const SizedBox(height: 24),

                // Bank selector
                Text('Ngân hàng *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _bankId,
                  decoration: InputDecoration(
                    hintText: 'Chọn ngân hàng',
                    prefixIcon: Icon(Icons.account_balance, color: c.textMuted),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: _vietqrBanks.map((b) => DropdownMenuItem(value: b['id'], child: Text(b['name']!))).toList(),
                  onChanged: (v) => setState(() => _bankId = v),
                  validator: (v) => v == null ? 'Vui lòng chọn ngân hàng' : null,
                ),
                const SizedBox(height: 16),

                // Account number
                Text('Số tài khoản *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _accountNoCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Nhập số tài khoản',
                    prefixIcon: Icon(Icons.credit_card, color: c.textMuted),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (v) => (v == null || v.isEmpty) ? 'Vui lòng nhập số tài khoản' : null,
                ),
                const SizedBox(height: 16),

                // Account name
                Text('Tên chủ tài khoản *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _accountNameCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'Nhập tên chủ tài khoản (in hoa)',
                    prefixIcon: Icon(Icons.person, color: c.textMuted),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (v) => (v == null || v.isEmpty) ? 'Vui lòng nhập tên chủ tài khoản' : null,
                ),
                const SizedBox(height: 24),

                // QR Preview
                if (qrUrl.isNotEmpty) ...[
                  Text('Xem trước mã QR', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                      child: Image.network(qrUrl, width: 200, height: 200, errorBuilder: (_, e, s) => SizedBox(width: 200, height: 200, child: Center(child: Text('Không tải được QR', style: TextStyle(color: c.textMuted))))),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(child: Text('QR mẫu (chưa có số tiền)', style: TextStyle(fontSize: 11, color: c.textMuted))),
                  const SizedBox(height: 24),
                ],

                // Save button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _save,
                    icon: _loading ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save),
                    label: Text(_loading ? 'Đang lưu...' : 'Lưu cấu hình'),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }
}
