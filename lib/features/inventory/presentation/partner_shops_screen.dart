import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../settings/providers/shop_provider.dart';

const _partnerPath = '/inventory/partner-shops';

final _partnersProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, int>((ref, shopId) async {
      final api = ref.read(apiClientProvider);
      final result = await api.getOnlineInShop(
        _partnerPath,
        '$shopId',
        isCurrentScope: () =>
            ref.mounted && ref.read(shopProvider).currentShopId == shopId,
      );
      return (result as List).map((item) {
        return Map<String, dynamic>.from(item as Map);
      }).toList();
    });

class PartnerShopsScreen extends ConsumerStatefulWidget {
  const PartnerShopsScreen({super.key});

  @override
  ConsumerState<PartnerShopsScreen> createState() => _PartnerShopsScreenState();
}

class _PartnerShopsScreenState extends ConsumerState<PartnerShopsScreen> {
  final _code = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit(int shopId, {int? partnershipId, String? status}) async {
    if (_saving || ref.read(shopProvider).currentShopId != shopId) return;
    final api = ref.read(apiClientProvider);
    bool isCurrentScope() =>
        mounted && ref.read(shopProvider).currentShopId == shopId;
    setState(() => _saving = true);
    try {
      if (partnershipId == null) {
        await api.postInShop(_partnerPath, '$shopId', {
          'shopCode': _code.text.trim(),
        }, isCurrentScope: isCurrentScope);
      } else {
        await api.putInShop(
          '$_partnerPath/$partnershipId',
          '$shopId',
          data: {'status': status},
          isCurrentScope: isCurrentScope,
        );
      }
      if (!mounted || ref.read(shopProvider).currentShopId != shopId) return;
      if (partnershipId == null) _code.clear();
      ref.invalidate(_partnersProvider(shopId));
    } catch (error) {
      if (!mounted || ref.read(shopProvider).currentShopId != shopId) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shop = ref.watch(shopProvider);
    final shopId = shop.currentShopId;
    return Scaffold(
      appBar: AppBar(title: const Text('Đối tác kho')),
      body: shopId == null || !shop.isOwner
          ? const Center(child: Text('Chọn cửa hàng bạn đang quản lý.'))
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    TextField(
                      key: ValueKey(shopId),
                      controller: _code,
                      enabled: !_saving,
                      maxLength: 6,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Mã cửa hàng đối tác',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton(
                        onPressed: _saving ? null : () => _submit(shopId),
                        child: const Text('Gửi lời mời'),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ...ref
                        .watch(_partnersProvider(shopId))
                        .when(
                          loading: () => [
                            const Center(child: CircularProgressIndicator()),
                          ],
                          error: (_, _) => [
                            const Text('Không tải được danh sách đối tác.'),
                            TextButton(
                              onPressed: () =>
                                  ref.invalidate(_partnersProvider(shopId)),
                              child: const Text('Thử lại'),
                            ),
                          ],
                          data: (partners) => [
                            if (partners.isEmpty)
                              const Text('Chưa có đối tác kho.'),
                            for (final partner in partners)
                              _partnerCard(shopId, partner),
                          ],
                        ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _partnerCard(int shopId, Map<String, dynamic> partner) {
    final status = partner['status'];
    final id = partner['id'] as int;
    final outgoing = partner['outgoing'] == true;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(partner['partnerName'] as String),
            Text(switch (status) {
              'ACTIVE' => 'Đã liên kết',
              'REJECTED' => 'Đã từ chối',
              'CLOSED' => 'Đã đóng liên kết',
              _ => outgoing ? 'Đang chờ phản hồi' : 'Lời mời mới',
            }),
            if (status == 'PENDING' && !outgoing)
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => _submit(
                            shopId,
                            partnershipId: id,
                            status: 'REJECTED',
                          ),
                    child: const Text('Từ chối'),
                  ),
                  FilledButton(
                    onPressed: _saving
                        ? null
                        : () => _submit(
                            shopId,
                            partnershipId: id,
                            status: 'ACTIVE',
                          ),
                    child: const Text('Chấp nhận'),
                  ),
                ],
              ),
            if (status == 'ACTIVE')
              TextButton(
                onPressed: _saving
                    ? null
                    : () =>
                          _submit(shopId, partnershipId: id, status: 'CLOSED'),
                child: const Text('Đóng liên kết'),
              ),
          ],
        ),
      ),
    );
  }
}
