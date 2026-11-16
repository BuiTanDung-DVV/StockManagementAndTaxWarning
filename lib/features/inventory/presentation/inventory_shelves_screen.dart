import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../settings/providers/shop_provider.dart';

const _path = '/inventory/shelf-positions';

final _shelvesProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, int>((ref, shopId) async {
      final result = await ref
          .read(apiClientProvider)
          .getOnlineInShop(
            _path,
            '$shopId',
            isCurrentScope: () =>
                ref.mounted && ref.read(shopProvider).currentShopId == shopId,
          );
      return List<Map<String, dynamic>>.from(result as List);
    });

class InventoryShelvesScreen extends ConsumerStatefulWidget {
  const InventoryShelvesScreen({super.key});

  @override
  ConsumerState<InventoryShelvesScreen> createState() =>
      _InventoryShelvesScreenState();
}

class _InventoryShelvesScreenState
    extends ConsumerState<InventoryShelvesScreen> {
  String _search = '';
  (int, String, String)? _selectedRack;
  bool _editing = false;

  Future<void> _assign(int shopId, [Map<String, dynamic>? position]) async {
    if (_editing) return;
    setState(() => _editing = true);
    bool current() => mounted && ref.read(shopProvider).currentShopId == shopId;
    final api = ref.read(apiClientProvider);
    try {
      final choices = <Map<String, dynamic>>[];
      if (position == null) {
        for (var page = 1; current(); page++) {
          final data =
              await api.getOnlineInShop(
                    '/inventory/stock',
                    '$shopId',
                    params: {'page': page, 'limit': 500},
                    isCurrentScope: current,
                  )
                  as Map;
          final items = data['items'] as List;
          choices.addAll(
            items.map((item) {
              final row = item as Map;
              return <String, dynamic>{
                'warehouseId': row['warehouseId'],
                'productId': row['productId'],
                'warehouseName': row['warehouse']?['name'] ?? 'Kho',
                'productName': row['product']?['name'] ?? 'Sản phẩm',
                'sku': row['product']?['sku'] ?? '',
              };
            }),
          );
          if (items.length < 500) break;
        }
      } else {
        choices.add(position);
      }
      if (!mounted || !current()) return;
      if (choices.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kho chưa có sản phẩm để gắn vị trí.')),
        );
        return;
      }
      final data = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => _PositionDialog(choices: choices),
      );
      if (data == null || !current()) return;
      await api.putInShop(
        _path,
        '$shopId',
        data: data,
        isCurrentScope: current,
      );
      if (current()) ref.invalidate(_shelvesProvider(shopId));
    } catch (error) {
      if (mounted && current()) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _editing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shop = ref.watch(shopProvider);
    final shopId = shop.currentShopId;
    final canEdit = shop.hasPermission('inventory', 'edit');
    return Scaffold(
      appBar: AppBar(title: const Text('Sơ đồ kệ')),
      body: shopId == null || shopId < 1
          ? const Center(child: Text('Chọn một cửa hàng để xem sơ đồ kệ.'))
          : ref
                .watch(_shelvesProvider(shopId))
                .when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => Center(
                    child: TextButton(
                      onPressed: () => ref.invalidate(_shelvesProvider(shopId)),
                      child: const Text('Không tải được sơ đồ. Thử lại'),
                    ),
                  ),
                  data: (positions) {
                    final racks =
                        <(int, String, String), List<Map<String, dynamic>>>{};
                    for (final p in positions) {
                      final key = (
                        p['warehouseId'] as int,
                        p['warehouseName'] as String,
                        p['rack'] as String,
                      );
                      (racks[key] ??= []).add(p);
                    }
                    bool matches(Map<String, dynamic> p) =>
                        '${p['productName']} ${p['sku']}'
                            .toLowerCase()
                            .contains(_search);
                    return ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        TextField(
                          onChanged: (value) => setState(() {
                            _search = value.trim().toLowerCase();
                            _selectedRack = null;
                          }),
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            labelText: 'Tìm mặt hàng theo tên hoặc SKU',
                          ),
                        ),
                        if (canEdit)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: _editing
                                  ? null
                                  : () => _assign(shopId),
                              icon: const Icon(Icons.add_location_alt_outlined),
                              label: const Text('Gắn vị trí'),
                            ),
                          ),
                        if (positions.isEmpty)
                          const ListTile(title: Text('Chưa có vị trí kệ.')),
                        if (_search.isNotEmpty && !positions.any(matches))
                          const ListTile(
                            title: Text('Không tìm thấy mặt hàng trên sơ đồ.'),
                          ),
                        for (final warehouse
                            in racks.keys.map((key) => key.$1).toSet())
                          _RackFloor(
                            title: racks.keys
                                .firstWhere((key) => key.$1 == warehouse)
                                .$2,
                            racks: [
                              for (final entry in racks.entries)
                                if (entry.key.$1 == warehouse)
                                  _RackTile(
                                    name: entry.key.$3,
                                    count: entry.value.length,
                                    selected: _selectedRack == entry.key,
                                    highlighted:
                                        _search.isNotEmpty &&
                                        entry.value.any(matches),
                                    muted:
                                        _search.isNotEmpty &&
                                        !entry.value.any(matches),
                                    onTap: () => setState(() {
                                      _selectedRack = _selectedRack == entry.key
                                          ? null
                                          : entry.key;
                                    }),
                                  ),
                            ],
                          ),
                        for (final entry in racks.entries)
                          if (entry.key == _selectedRack ||
                              (_selectedRack == null &&
                                  _search.isNotEmpty &&
                                  entry.value.any(matches)))
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${entry.key.$2} · Kệ ${entry.key.$3}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    for (final level
                                        in entry.value
                                            .map((p) => p['level'])
                                            .toSet())
                                      Padding(
                                        padding: const EdgeInsets.only(top: 12),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text('Tầng $level'),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 6,
                                              children: [
                                                for (final p
                                                    in entry.value.where(
                                                      (p) =>
                                                          p['level'] == level,
                                                    ))
                                                  ActionChip(
                                                    avatar: Icon(
                                                      matches(p) &&
                                                              _search.isNotEmpty
                                                          ? Icons.location_on
                                                          : Icons
                                                                .inventory_2_outlined,
                                                    ),
                                                    label: Text(
                                                      'Ô ${p['bin']} · ${p['productName']}',
                                                    ),
                                                    onPressed:
                                                        canEdit && !_editing
                                                        ? () =>
                                                              _assign(shopId, p)
                                                        : null,
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                      ],
                    );
                  },
                ),
    );
  }
}

class _RackFloor extends StatelessWidget {
  const _RackFloor({required this.title, required this.racks});

  final String title;
  final List<Widget> racks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          border: Border.all(color: colors.outlineVariant),
          borderRadius: BorderRadius.circular(16),
        ),
        child: CustomPaint(
          painter: _FloorGrid(colors.outlineVariant.withValues(alpha: .48)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(spacing: 12, runSpacing: 12, children: racks),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FloorGrid extends CustomPainter {
  const _FloorGrid(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16)),
    );
    final paint = Paint()..color = color;
    for (double x = 20; x < size.width; x += 20) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 20; y < size.height; y += 20) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_FloorGrid oldDelegate) => oldDelegate.color != color;
}

class _RackTile extends StatelessWidget {
  const _RackTile({
    required this.name,
    required this.count,
    required this.selected,
    required this.highlighted,
    required this.muted,
    required this.onTap,
  });

  final String name;
  final int count;
  final bool selected;
  final bool highlighted;
  final bool muted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final active = selected || highlighted;
    return Semantics(
      selected: selected,
      child: Opacity(
        opacity: muted ? .55 : 1,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            backgroundColor: active ? colors.primaryContainer : colors.surface,
            foregroundColor: active
                ? colors.onPrimaryContainer
                : colors.onSurface,
            side: BorderSide(
              color: active ? colors.primary : colors.outlineVariant,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
          onPressed: onTap,
          child: SizedBox(
            width: 102,
            child: Column(
              children: [
                CustomPaint(
                  size: const Size(94, 58),
                  painter: _RackShape(
                    active ? colors.primary : colors.secondary,
                    colors.surface,
                  ),
                ),
                Text('Kệ $name', maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('$count mặt hàng', style: theme.textTheme.labelSmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RackShape extends CustomPainter {
  const _RackShape(this.color, this.surface);
  final Color color;
  final Color surface;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 94, size.height / 58);
    void face(Color fill, List<Offset> points) {
      final path = Path()..addPolygon(points, true);
      canvas.drawPath(path, Paint()..color = fill);
    }

    canvas.drawOval(
      const Rect.fromLTWH(6, 43, 84, 13),
      Paint()..color = color.withValues(alpha: .18),
    );
    face(color, const [
      Offset(10, 24),
      Offset(67, 24),
      Offset(67, 47),
      Offset(10, 47),
    ]);
    face(Color.lerp(color, Colors.black, .25)!, const [
      Offset(67, 24),
      Offset(84, 10),
      Offset(84, 33),
      Offset(67, 47),
    ]);
    face(Color.lerp(color, surface, .44)!, const [
      Offset(10, 24),
      Offset(27, 10),
      Offset(84, 10),
      Offset(67, 24),
    ]);
    final rail = Paint()
      ..color = surface.withValues(alpha: .72)
      ..strokeWidth = 1.5;
    for (final x in [27.0, 47.0]) {
      canvas.drawLine(Offset(x, 25), Offset(x, 46), rail);
      canvas.drawLine(Offset(x, 23), Offset(x + 17, 11), rail);
    }
    canvas.drawLine(const Offset(11, 35), const Offset(66, 35), rail);
  }

  @override
  bool shouldRepaint(_RackShape oldDelegate) =>
      oldDelegate.color != color || oldDelegate.surface != surface;
}

class _PositionDialog extends StatefulWidget {
  const _PositionDialog({required this.choices});
  final List<Map<String, dynamic>> choices;

  @override
  State<_PositionDialog> createState() => _PositionDialogState();
}

class _PositionDialogState extends State<_PositionDialog> {
  final _form = GlobalKey<FormState>();
  int _selected = 0;
  late String _rack = widget.choices.first['rack'] as String? ?? '';
  late int _level = widget.choices.first['level'] as int? ?? 1;
  late int _bin = widget.choices.first['bin'] as int? ?? 1;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Vị trí trên kệ'),
      scrollable: true,
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              initialValue: _selected,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Sản phẩm và kho'),
              items: [
                for (var i = 0; i < widget.choices.length; i++)
                  DropdownMenuItem(
                    value: i,
                    child: Text(
                      '${widget.choices[i]['sku']} · ${widget.choices[i]['productName']} · ${widget.choices[i]['warehouseName']}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) => _selected = value!,
            ),
            TextFormField(
              initialValue: _rack,
              maxLength: 24,
              decoration: const InputDecoration(labelText: 'Mã kệ'),
              validator: (value) => value!.trim().isEmpty ? 'Nhập mã kệ' : null,
              onSaved: (value) => _rack = value!.trim(),
            ),
            _numberField('Tầng', _level, 12, (value) => _level = value),
            _numberField('Ô', _bin, 16, (value) => _bin = value),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            _form.currentState!.save();
            final choice = widget.choices[_selected];
            Navigator.pop(context, {
              'warehouseId': choice['warehouseId'],
              'productId': choice['productId'],
              'rack': _rack,
              'level': _level,
              'bin': _bin,
            });
          },
          child: const Text('Lưu'),
        ),
      ],
    );
  }

  Widget _numberField(
    String label,
    int initial,
    int max,
    ValueChanged<int> save,
  ) {
    return TextFormField(
      initialValue: '$initial',
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        final number = int.tryParse(value ?? '');
        return number == null || number < 1 || number > max
            ? 'Nhập số từ 1 đến $max'
            : null;
      },
      onSaved: (value) => save(int.parse(value!)),
    );
  }
}
