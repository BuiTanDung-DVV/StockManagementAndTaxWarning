import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/toast_service.dart';
import '../../providers/auth_provider.dart';

class JoinShopDialog extends ConsumerStatefulWidget {
  const JoinShopDialog({super.key});

  @override
  ConsumerState<JoinShopDialog> createState() => _JoinShopDialogState();
}

class _JoinShopDialogState extends ConsumerState<JoinShopDialog> {
  final _searchCtrl = TextEditingController();
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];
  Map<String, dynamic>? _selectedShop;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String query) async {
    if (query.trim().length > 2) {
      setState(() => _isSearching = true);
      final results = await ref.read(authProvider.notifier).searchShops(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _submitJoinRequest() async {
    if (_selectedShop == null) return;
    setState(() => _isSubmitting = true);
    final success = await ref.read(authProvider.notifier).requestJoinShop(_selectedShop!['id']);
    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        ToastService.showSuccess('Đã gửi yêu cầu gia nhập thành công. Vui lòng chờ phê duyệt.');
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: c.bg,
      child: Container(
        width: 450,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.storefront_rounded, color: theme.colorScheme.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Gia nhập cửa hàng',
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: c.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: c.textMuted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_selectedShop == null) ...[
              TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  labelText: 'Tìm Cửa hàng / Doanh nghiệp',
                  hintText: 'Nhập tên hoặc mã cửa hàng...',
                  prefixIcon: Icon(Icons.search_rounded, color: c.textMuted),
                  suffixIcon: _isSearching
                      ? Padding(
                          padding: const EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary),
                          ),
                        )
                      : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: _onSearch,
              ),
              const SizedBox(height: 16),
              if (_searchResults.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxHeight: 250),
                  decoration: BoxDecoration(
                    color: c.card,
                    border: Border.all(color: c.divider),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _searchResults.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: c.divider),
                    itemBuilder: (context, index) {
                      final shop = _searchResults[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                          child: Text(
                            shop['shopName']?[0] ?? 'S',
                            style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(shop['shopName'] ?? '', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600)),
                        subtitle: Text('Mã: ${shop['shopCode']}', style: TextStyle(color: c.textSecondary)),
                        onTap: () {
                          setState(() {
                            _selectedShop = shop;
                          });
                        },
                      );
                    },
                  ),
                ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                      child: Text(
                        _selectedShop!['shopName']?[0] ?? 'S',
                        style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 20),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedShop!['shopName'],
                            style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text('Mã cửa hàng: ${_selectedShop!['shopCode']}', style: TextStyle(color: c.textSecondary)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: c.textMuted),
                      onPressed: () => setState(() => _selectedShop = null),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitJoinRequest,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmitting
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Gửi yêu cầu tham gia', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
