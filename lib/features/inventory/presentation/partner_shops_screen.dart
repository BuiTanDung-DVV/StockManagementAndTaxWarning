import 'package:flutter/material.dart';
import '../../../core/widgets/app_page_header.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../settings/providers/shop_provider.dart';

const _partnerPath = '/inventory/partner-shops';
final _validShopCode = RegExp(r'^[A-Z0-9]{4,20}$');

final _partnersProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, int>((ref, shopId) async {
      final api = ref.read(apiClientProvider);
      final result = await api.getOnlineInShop(
        _partnerPath,
        '$shopId',
        isCurrentScope: () =>
            ref.mounted && ref.read(shopProvider).currentShopId == shopId,
      );
      return (result as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    });

enum _PartnerFilter {
  all('Tất cả'),
  pending('Lời mời'),
  active('Đã liên kết'),
  history('Lịch sử');

  const _PartnerFilter(this.label);
  final String label;

  bool matches(Map<String, dynamic> row) => switch (this) {
    all => true,
    pending => row['status'] == 'PENDING',
    active => row['status'] == 'ACTIVE',
    history => row['status'] == 'CLOSED' || row['status'] == 'REJECTED',
  };
}

class PartnerShopsScreen extends ConsumerStatefulWidget {
  const PartnerShopsScreen({super.key});

  @override
  ConsumerState<PartnerShopsScreen> createState() => _PartnerShopsScreenState();
}

class _PartnerShopsScreenState extends ConsumerState<PartnerShopsScreen> {
  final _code = TextEditingController();
  _PartnerFilter _filter = _PartnerFilter.all;
  String? _inviteError;
  bool _saving = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit(int shopId, {int? partnershipId, String? status}) async {
    if (_saving || ref.read(shopProvider).currentShopId != shopId) return;
    final code = _code.text.trim().toUpperCase();
    if (partnershipId == null && !_validShopCode.hasMatch(code)) {
      setState(
        () => _inviteError = 'Nhập mã từ 4 đến 20 ký tự, chỉ gồm chữ và số.',
      );
      return;
    }
    final api = ref.read(apiClientProvider);
    bool isCurrentScope() =>
        mounted && ref.read(shopProvider).currentShopId == shopId;
    setState(() {
      _saving = true;
      _inviteError = null;
    });
    try {
      if (partnershipId == null) {
        await api.postInShop(_partnerPath, '$shopId', {
          'shopCode': code,
        }, isCurrentScope: isCurrentScope);
      } else {
        await api.putInShop(
          '$_partnerPath/$partnershipId',
          '$shopId',
          data: {'status': status},
          isCurrentScope: isCurrentScope,
        );
      }
      if (!isCurrentScope()) return;
      if (partnershipId == null) {
        _code.clear();
        setState(() => _filter = _PartnerFilter.pending);
      } else if (status == 'ACTIVE') {
        setState(() => _filter = _PartnerFilter.active);
      }
      ref.invalidate(_partnersProvider(shopId));
      _notify(switch (status) {
        'ACTIVE' => 'Đã chấp nhận lời mời.',
        'REJECTED' => 'Đã từ chối lời mời.',
        'CLOSED' => 'Đã đóng liên kết.',
        _ => 'Đã gửi lời mời liên kết.',
      });
    } catch (error) {
      if (!isCurrentScope()) return;
      final message = error is ApiException
          ? error.message
          : 'Chưa thực hiện được. Vui lòng thử lại.';
      if (partnershipId == null) {
        setState(() => _inviteError = message);
      } else {
        _notify(message);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _notify(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _closePartnership(int shopId, int id, String partnerName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đóng liên kết đối tác?'),
        content: Text(
          'Bạn sẽ không thể lập phiếu mượn mới với $partnerName. '
          'Hai bên vẫn có thể xử lý các phiếu đang mở.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Đóng liên kết'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _submit(shopId, partnershipId: id, status: 'CLOSED');
    }
  }

  @override
  Widget build(BuildContext context) {
    final shop = ref.watch(shopProvider);
    final shopId = shop.currentShopId;
    ref.listen(shopProvider.select((shop) => shop.currentShopId), (old, next) {
      if (old == next) return;
      _code.clear();
      setState(() {
        _filter = _PartnerFilter.all;
        _inviteError = null;
      });
    });
    return Scaffold(
      appBar: AppBar(
        leading: const AppPageBackLeading(),
        title: const Text('Đối tác kho'),
      ),
      body: shopId == null || !shop.isOwner
          ? const Center(child: Text('Chọn cửa hàng bạn đang quản lý.'))
          : SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 960;
                  final list = _buildDirectory(shopId);
                  final invite = _buildInvitation(shopId, shop);
                  return ListView(
                    padding: EdgeInsets.fromLTRB(
                      wide ? 24 : 16,
                      20,
                      wide ? 24 : 16,
                      32,
                    ),
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1280),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildOverview(shop),
                              const SizedBox(height: 20),
                              if (wide)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: list),
                                    const SizedBox(width: 20),
                                    SizedBox(width: 344, child: invite),
                                  ],
                                )
                              else ...[
                                invite,
                                const SizedBox(height: 16),
                                list,
                              ],
                            ],
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

  Widget _buildOverview(ShopState shop) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        border: Border.all(
          color: colors.onPrimaryContainer.withValues(alpha: .24),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PartnerIcon(
              icon: Icons.handshake_outlined,
              foreground: colors.primary,
              background: colors.surface,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (shop.currentShopName case final String name)
                    Text(
                      name,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                  Text(
                    'Mượn và hoàn hàng giữa cửa hàng',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: colors.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Khi cả hai bên đồng ý liên kết, bạn có thể lập phiếu mượn và theo dõi số hàng cần hoàn.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvitation(int shopId, ShopState shop) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final shopCode = shop.shopCode?.trim();
    return _PartnerPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Mời đối tác', style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            'Nhập mã do cửa hàng đối tác cung cấp.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            key: ValueKey(shopId),
            controller: _code,
            enabled: !_saving,
            maxLength: 20,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _submit(shopId),
            onChanged: (_) {
              if (_inviteError != null) setState(() => _inviteError = null);
            },
            decoration: InputDecoration(
              labelText: 'Mã cửa hàng đối tác',
              prefixIcon: const Icon(Icons.storefront_outlined),
              border: const OutlineInputBorder(),
              counterText: '',
              errorText: _inviteError,
              errorMaxLines: 3,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _saving ? null : () => _submit(shopId),
            icon: const Icon(Icons.send_outlined, size: 18),
            label: const Text('Gửi lời mời'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
          ),
          if (shopCode != null && shopCode.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(),
            ),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mã cửa hàng của bạn',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 2),
                      SelectableText(
                        shopCode,
                        style: theme.textTheme.titleMedium?.copyWith(
                          letterSpacing: 1,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Sao chép mã cửa hàng',
                  onPressed: () async {
                    try {
                      await Clipboard.setData(ClipboardData(text: shopCode));
                      if (mounted) _notify('Đã sao chép mã cửa hàng.');
                    } on PlatformException {
                      if (mounted) _notify('Hãy chọn và sao chép mã cửa hàng.');
                    }
                  },
                  icon: const Icon(Icons.content_copy_outlined, size: 20),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDirectory(int shopId) {
    final theme = Theme.of(context);
    return _PartnerPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Text(
              'Danh sách đối tác',
              style: theme.textTheme.titleMedium,
            ),
          ),
          ref
              .watch(_partnersProvider(shopId))
              .when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, _) => Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Không tải được danh sách đối tác.'),
                      TextButton(
                        onPressed: () =>
                            ref.invalidate(_partnersProvider(shopId)),
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
                data: (partners) {
                  final visible = partners.where(_filter.matches).toList()
                    ..sort(
                      (a, b) =>
                          _partnerPriority(a).compareTo(_partnerPriority(b)),
                    );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            for (final filter in _PartnerFilter.values)
                              ChoiceChip(
                                label: Text(
                                  '${filter.label} (${partners.where(filter.matches).length})',
                                ),
                                selected: _filter == filter,
                                onSelected: (_) =>
                                    setState(() => _filter = filter),
                              ),
                          ],
                        ),
                      ),
                      if (visible.isEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                          child: Text(
                            partners.isEmpty
                                ? 'Chưa có đối tác kho. Gửi lời mời để bắt đầu liên kết.'
                                : 'Chưa có đối tác trong mục này.',
                            style: theme.textTheme.bodyMedium,
                          ),
                        )
                      else
                        for (final partner in visible) ...[
                          const Divider(height: 1),
                          _partnerRow(shopId, partner),
                        ],
                    ],
                  );
                },
              ),
        ],
      ),
    );
  }

  int _partnerPriority(Map<String, dynamic> row) => switch (row['status']) {
    'PENDING' when row['outgoing'] != true => 0,
    'ACTIVE' => 1,
    'PENDING' => 2,
    _ => 3,
  };

  Widget _partnerRow(int shopId, Map<String, dynamic> partner) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final id = partner['id'] as int;
    final name = partner['partnerName'] as String;
    final outgoing = partner['outgoing'] == true;
    final status = partner['status'];
    final date = DateTime.tryParse(partner['createdAt']?.toString() ?? '');
    final (label, color, icon) = switch (status) {
      'ACTIVE' => ('Đã liên kết', colors.primary, Icons.link_rounded),
      'REJECTED' => (
        'Đã từ chối',
        colors.onSurfaceVariant,
        Icons.block_outlined,
      ),
      'CLOSED' => (
        'Đã đóng liên kết',
        colors.onSurfaceVariant,
        Icons.link_off_rounded,
      ),
      _ when outgoing => (
        'Chờ phản hồi',
        colors.tertiary,
        Icons.schedule_outlined,
      ),
      _ => ('Lời mời đến', colors.tertiary, Icons.mail_outline),
    };
    final actions = [
      if (status == 'PENDING' && !outgoing) ...[
        TextButton(
          onPressed: _saving
              ? null
              : () => _submit(shopId, partnershipId: id, status: 'REJECTED'),
          child: const Text('Từ chối'),
        ),
        FilledButton(
          onPressed: _saving
              ? null
              : () => _submit(shopId, partnershipId: id, status: 'ACTIVE'),
          child: const Text('Chấp nhận'),
        ),
      ],
      if (status == 'ACTIVE')
        FilledButton.tonalIcon(
          icon: const Icon(Icons.swap_horiz, size: 18),
          label: const Text('Xem phiếu mượn'),
          onPressed: () => context.push(
            Uri(
              path: '/inventory/loans',
              queryParameters: {'partner': name},
            ).toString(),
          ),
        ),
      if (status == 'ACTIVE')
        TextButton(
          onPressed: _saving ? null : () => _closePartnership(shopId, id, name),
          child: const Text('Đóng liên kết'),
        ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final inline = constraints.maxWidth >= 520;
          final actionGroup = Wrap(
            spacing: 6,
            runSpacing: 4,
            children: actions,
          );
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PartnerIcon(
                icon: Icons.storefront_outlined,
                foreground: colors.primary,
                background: colors.surfaceContainerHighest,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 10,
                      runSpacing: 5,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: .11),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(icon, size: 14, color: color),
                                const SizedBox(width: 5),
                                Text(
                                  label,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (date != null)
                          Text(
                            'Mời ngày ${DateFormat('dd/MM/yyyy').format(date.toLocal())}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                    if (!inline && actions.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      actionGroup,
                    ],
                  ],
                ),
              ),
              if (inline && actions.isNotEmpty) ...[
                const SizedBox(width: 12),
                actionGroup,
              ],
            ],
          );
        },
      ),
    );
  }
}

class _PartnerPanel extends StatelessWidget {
  const _PartnerPanel({required this.child, this.padding = EdgeInsets.zero});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.onSurface.withValues(alpha: .19)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _PartnerIcon extends StatelessWidget {
  const _PartnerIcon({
    required this.icon,
    required this.foreground,
    required this.background,
  });

  final IconData icon;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Icon(icon, color: foreground, size: 22),
  );
}
