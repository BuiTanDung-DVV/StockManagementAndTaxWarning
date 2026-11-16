import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import '../../settings/providers/shop_provider.dart';

const _path = '/inventory/shelf-positions';

typedef _ShelfData = ({
  List<Map<String, dynamic>> positions,
  List<Map<String, dynamic>> warehouses,
});

final _shelvesProvider = FutureProvider.autoDispose.family<_ShelfData, int>((
  ref,
  shopId,
) async {
  final api = ref.read(apiClientProvider);
  bool current() =>
      ref.mounted && ref.read(shopProvider).currentShopId == shopId;
  final data = await Future.wait([
    api.getOnlineInShop(_path, '$shopId', isCurrentScope: current),
    api.getOnlineInShop(
      '/inventory/warehouses',
      '$shopId',
      isCurrentScope: current,
    ),
  ]);
  return (
    positions: List<Map<String, dynamic>>.from(data[0] as List),
    warehouses: List<Map<String, dynamic>>.from(data[1] as List),
  );
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

  Future<void> _assign(
    int shopId, {
    Map<String, dynamic>? position,
    int? warehouseId,
    String? rackCode,
  }) async {
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
                    params: {
                      'page': page,
                      'limit': 500,
                      'warehouseId': ?warehouseId,
                    },
                    isCurrentScope: current,
                  )
                  as Map;
          final items = data['items'] as List;
          choices.addAll(
            items
                .where(
                  (item) =>
                      warehouseId == null ||
                      (item as Map)['warehouseId'] == warehouseId,
                )
                .map((item) {
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
        builder: (_) => _PositionDialog(choices: choices, rackCode: rackCode),
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
    final theme = _warehouseTheme(Theme.of(context));
    return Theme(
      data: theme,
      child: Scaffold(
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
                        onPressed: () =>
                            ref.invalidate(_shelvesProvider(shopId)),
                        child: const Text('Không tải được sơ đồ. Thử lại'),
                      ),
                    ),
                    data: (data) {
                      final positions = data.positions;
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
                      final search = TextField(
                        textInputAction: TextInputAction.search,
                        onChanged: (value) => setState(() {
                          _search = value.trim().toLowerCase();
                          _selectedRack = null;
                        }),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Tìm theo tên mặt hàng hoặc SKU',
                        ),
                      );
                      final assign = OutlinedButton.icon(
                        onPressed: _editing ? null : () => _assign(shopId),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.onSurface,
                          backgroundColor:
                              theme.colorScheme.surfaceContainerLow,
                          disabledBackgroundColor:
                              theme.colorScheme.surfaceContainerLow,
                          side: BorderSide(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                        icon: const Icon(
                          Icons.add_location_alt_outlined,
                          size: 18,
                        ),
                        label: const Text('Gắn vị trí'),
                      );
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                        children: [
                          LayoutBuilder(
                            builder: (context, constraints) {
                              if (!canEdit) return search;
                              if (constraints.maxWidth < 520) {
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    search,
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: assign,
                                    ),
                                  ],
                                );
                              }
                              return Row(
                                children: [
                                  Expanded(child: search),
                                  const SizedBox(width: 12),
                                  assign,
                                ],
                              );
                            },
                          ),
                          if (data.warehouses.isEmpty)
                            const ListTile(
                              title: Text('Tạo kho trước khi bố trí mặt bằng.'),
                            ),
                          if (_search.isNotEmpty && !positions.any(matches))
                            const ListTile(
                              title: Text(
                                'Không tìm thấy mặt hàng trên sơ đồ.',
                              ),
                            ),
                          for (final warehouse in data.warehouses)
                            _RackFloor(
                              key: ValueKey((shopId, warehouse['id'])),
                              storageKey:
                                  'inventory.shelf.scene.$shopId.${warehouse['id']}',
                              canEdit: canEdit,
                              onAssignRack: (rack) => _assign(
                                shopId,
                                warehouseId: warehouse['id'] as int,
                                rackCode: rack,
                              ),
                              title: warehouse['name'] as String,
                              rackDetails: [
                                for (final entry in racks.entries)
                                  if (entry.key.$1 == warehouse['id'] &&
                                      (entry.key == _selectedRack ||
                                          (_selectedRack == null &&
                                              _search.isNotEmpty &&
                                              entry.value.any(matches))))
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Kệ ${entry.key.$3}',
                                            style: theme.textTheme.titleMedium,
                                          ),
                                          for (final level
                                              in entry.value
                                                  .map((p) => p['level'])
                                                  .toSet())
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 12,
                                              ),
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
                                                                p['level'] ==
                                                                level,
                                                          ))
                                                        ActionChip(
                                                          avatar: Icon(
                                                            matches(p) &&
                                                                    _search
                                                                        .isNotEmpty
                                                                ? Icons
                                                                      .location_on
                                                                : Icons
                                                                      .inventory_2_outlined,
                                                          ),
                                                          label: Text(
                                                            'Ô ${p['bin']} · ${p['productName']}',
                                                          ),
                                                          onPressed:
                                                              canEdit &&
                                                                  !_editing
                                                              ? () => _assign(
                                                                  shopId,
                                                                  position: p,
                                                                )
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
                              ],
                              racks: {
                                for (final entry in racks.entries)
                                  if (entry.key.$1 == warehouse['id'])
                                    entry.key.$3: _RackTile(
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
                                        _selectedRack =
                                            _selectedRack == entry.key
                                            ? null
                                            : entry.key;
                                      }),
                                    ),
                              },
                            ),
                        ],
                      );
                    },
                  ),
      ),
    );
  }
}

ThemeData _warehouseTheme(ThemeData base) {
  final colors =
      ColorScheme.fromSeed(
        seedColor: const Color(0xFFB87931),
        brightness: Brightness.dark,
      ).copyWith(
        primary: const Color(0xFFFFCB75),
        onPrimary: const Color(0xFF201407),
        primaryContainer: const Color(0xFF5C3C1E),
        onPrimaryContainer: const Color(0xFFFFE4B3),
        surface: const Color(0xFF26364B),
        surfaceContainerLow: const Color(0xFF172438),
        surfaceContainerLowest: const Color(0xFF101822),
        surfaceContainerHighest: const Color(0xFF343E47),
        onSurface: const Color(0xFFF1F4F6),
        onSurfaceVariant: const Color(0xFFBCC9D1),
        outlineVariant: const Color(0xFF50647C),
      );
  return base.copyWith(
    colorScheme: colors,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: colors.surfaceContainerLowest,
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: colors.surfaceContainerLowest,
      foregroundColor: colors.onSurface,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      shape: const RoundedRectangleBorder(),
      titleTextStyle: base.textTheme.titleLarge?.copyWith(
        color: colors.onSurface,
      ),
      iconTheme: IconThemeData(color: colors.onSurface),
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      filled: true,
      fillColor: colors.surfaceContainerLow,
      hintStyle: TextStyle(color: colors.onSurfaceVariant),
      labelStyle: TextStyle(color: colors.onSurfaceVariant),
      prefixIconColor: colors.onSurfaceVariant,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: colors.outlineVariant.withValues(alpha: .65),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: colors.primary),
      ),
    ),

    textTheme: base.textTheme.apply(
      bodyColor: colors.onSurface,
      displayColor: colors.onSurface,
    ),
    iconTheme: IconThemeData(color: colors.onSurfaceVariant),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? colors.onSurfaceVariant.withValues(alpha: .35)
              : colors.onSurfaceVariant,
        ),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        side: WidgetStatePropertyAll(BorderSide(color: colors.outlineVariant)),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colors.onPrimaryContainer
              : colors.onSurfaceVariant,
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colors.primaryContainer
              : colors.surfaceContainerLow,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        foregroundColor: colors.onPrimary,
        backgroundColor: colors.primary,
      ),
    ),
    dividerColor: colors.outlineVariant.withValues(alpha: .45),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: BorderSide(color: colors.outlineVariant),
      backgroundColor: colors.surfaceContainerLow,
      labelStyle: base.textTheme.labelMedium?.copyWith(
        color: colors.onSurface,
        fontSize: 12,
      ),
    ),
  );
}

class _RackFloor extends StatefulWidget {
  const _RackFloor({
    super.key,
    required this.storageKey,
    required this.canEdit,
    required this.onAssignRack,
    required this.title,
    required this.racks,
    required this.rackDetails,
  });

  final String storageKey;
  final bool canEdit;
  final ValueChanged<String> onAssignRack;
  final String title;
  final Map<String, _RackTile> racks;
  final List<Widget> rackDetails;

  @override
  State<_RackFloor> createState() => _RackFloorState();
}

enum _FixtureKind {
  rack('Kệ trống', Icons.view_in_ar_outlined),
  aisle('Lối đi', Icons.alt_route),
  door('Cửa ra vào', Icons.door_front_door_outlined),
  counter('Quầy', Icons.storefront_outlined),
  receiving('Khu nhận hàng', Icons.move_to_inbox_outlined),
  wall('Vách ngăn', Icons.view_week_outlined),
  pallet('Pallet', Icons.layers_outlined),
  coldStorage('Tủ mát', Icons.ac_unit_outlined),
  display('Bàn trưng bày', Icons.table_restaurant_outlined),
  bulk('Hàng cồng kềnh', Icons.inventory_2_outlined),
  dispatch('Khu giao hàng', Icons.local_shipping_outlined);

  const _FixtureKind(this.label, this.icon);
  final String label;
  final IconData icon;

  (int, int) get footprint => switch (this) {
    rack || pallet || coldStorage || display => (3, 2),
    aisle || wall => (4, 1),
    door => (2, 1),
    counter => (4, 2),
    receiving || dispatch || bulk => (4, 3),
  };
}

typedef _SceneDrag = ({String? id, _FixtureKind? kind});
typedef _GridBlock = ({int column, int row, int columns, int rows});
typedef _FloorSnapshot = ({
  Map<String, _FloorObject> objects,
  int columns,
  int rows,
});

class _FloorObject {
  const _FloorObject({
    required this.id,
    required this.kind,
    required this.x,
    required this.y,
    this.width = 1,
    this.height = 1,
    this.rotation = 0,
    this.manualRack = false,
    this.block,
  });

  factory _FloorObject.fromJson(Map<String, dynamic> json) {
    return _FloorObject(
      id: json['id'] as String,
      kind: _FixtureKind.values.byName(json['kind'] as String),
      x: (json['x'] as num).toDouble().clamp(0.0, 1.0),
      y: (json['y'] as num).toDouble().clamp(0.0, 1.0),
      width: (json['width'] as num).toDouble().clamp(.6, 1.8),
      height: (json['height'] as num).toDouble().clamp(.6, 1.8),
      rotation: (json['rotation'] as int) % 4,
      manualRack: json['manualRack'] == true,
      block: switch (json['block']) {
        [int column, int row, int columns, int rows] => (
          column: column,
          row: row,
          columns: columns,
          rows: rows,
        ),
        _ => null,
      },
    );
  }

  final String id;
  final _FixtureKind kind;
  final double x, y, width, height;
  final int rotation;
  final bool manualRack;
  final _GridBlock? block;
  bool get stockRack => id.startsWith('stock:');

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'rotation': rotation,
    if (manualRack) 'manualRack': true,
    if (block case final grid?)
      'block': [grid.column, grid.row, grid.columns, grid.rows],
  };

  _FloorObject copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    int? rotation,
    _GridBlock? block,
  }) => _FloorObject(
    id: id,
    kind: kind,
    x: x ?? this.x,
    y: y ?? this.y,
    width: width ?? this.width,
    height: height ?? this.height,
    rotation: rotation ?? this.rotation,
    manualRack: manualRack,
    block: block ?? this.block,
  );
}

class _RackFloorState extends State<_RackFloor> {
  static const _baseColumns = 20;
  static const _maxGridSize = 100;
  final _floorKey = GlobalKey();
  final _viewport = TransformationController();
  Map<String, _FloorObject> _objects = {};
  _FloorSnapshot? _undo;
  int _extraColumns = 0;
  int _extraRows = 0;
  _GridBlock? _resizeStart;
  _GridBlock? _resizePreview;
  Offset _resizeDelta = Offset.zero;
  String? _selection;
  bool _editing = false;
  bool _saving = false;
  bool _loading = true;
  bool _overhead = false;
  _FixtureKind? _placement;
  Offset? _placementPoint;
  int _angle = 0;

  int get _baseRows => math
      .max(10, ((widget.racks.length + 2) ~/ 3) * 3 + 1)
      .clamp(10, _maxGridSize);
  int get _columns => _baseColumns + _extraColumns;
  int get _rows => _objects.values.fold(
    math.min(_baseRows + _extraRows, _maxGridSize),
    (height, item) {
      final block = item.block;
      return block == null
          ? height
          : math.max(height, (block.row + block.rows).clamp(1, _maxGridSize));
    },
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(widget.storageKey);
      if (json != null) {
        final decoded = jsonDecode(json);
        final saved = decoded is Map<String, dynamic> ? decoded : null;
        final objects = ((saved?['objects'] ?? decoded) as List).map(
          (value) =>
              _FloorObject.fromJson(Map<String, dynamic>.from(value as Map)),
        );
        if (mounted) {
          setState(() {
            _objects = {for (final item in objects) item.id: item};
            _extraColumns = (saved?['extraColumns'] as int? ?? 0).clamp(
              0,
              _maxGridSize - _baseColumns,
            );
            _extraRows = (saved?['extraRows'] as int? ?? 0).clamp(
              0,
              _maxGridSize - 10,
            );
          });
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không đọc được bố trí kệ đã lưu.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _viewport.dispose();
    super.dispose();
  }

  Future<void> _save(
    Map<String, _FloorObject> next,
    String? selection, {
    bool undo = false,
    int? extraColumns,
    int? extraRows,
  }) async {
    if (_saving || _loading || !widget.canEdit) return;
    final previous = (
      objects: _objects,
      columns: _extraColumns,
      rows: _extraRows,
    );
    final oldSelection = _selection;
    setState(() {
      _objects = next;
      _extraColumns = extraColumns ?? _extraColumns;
      _extraRows = extraRows ?? _extraRows;
      _selection = selection;
      _saving = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(
        widget.storageKey,
        jsonEncode({
          'objects': next.values.toList(),
          'extraColumns': _extraColumns,
          'extraRows': _extraRows,
        }),
      )) {
        throw StateError('Không lưu được bố trí.');
      }
      if (mounted) setState(() => _undo = undo ? null : previous);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _objects = previous.objects;
        _extraColumns = previous.columns;
        _extraRows = previous.rows;
        _selection = oldSelection;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không lưu được bố trí kho.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _place(
    _SceneDrag drag,
    Offset position,
    Map<String, _FloorObject> layout,
  ) {
    final kind = drag.kind;
    final old = layout[drag.id];
    int rackNumber = 1;
    String rackId() => 'stock:K-${rackNumber.toString().padLeft(2, '0')}';
    if (old == null && kind == _FixtureKind.rack) {
      while (layout.containsKey(rackId())) {
        rackNumber++;
      }
    }
    final item = old == null
        ? _FloorObject(
            id: kind == _FixtureKind.rack
                ? rackId()
                : DateTime.now().microsecondsSinceEpoch.toString(),
            manualRack: kind == _FixtureKind.rack,
            kind: kind!,
            x: position.dx,
            y: position.dy,
          )
        : old.copyWith(x: position.dx, y: position.dy);
    final current = _blockFor(item);
    final block = _snap(
      (position.dx * _columns - current.columns / 2).floor(),
      (position.dy * _rows - current.rows / 2).floor(),
      current.columns,
      current.rows,
    );
    _updateBlock(item, block, layout);
  }

  _GridBlock _snap(int column, int row, int columns, int rows) {
    final width = columns.clamp(1, _columns);
    final height = rows.clamp(1, _rows);
    return (
      column: column.clamp(0, _columns - width),
      row: row.clamp(0, _rows - height),
      columns: width,
      rows: height,
    );
  }

  _GridBlock _blockFor(_FloorObject item) {
    if (item.block case final block?) {
      return _snap(block.column, block.row, block.columns, block.rows);
    }
    final (width, height) = item.kind.footprint;
    final columns = ((item.rotation.isEven ? width : height) * item.width)
        .round();
    final rows = ((item.rotation.isEven ? height : width) * item.height)
        .round();
    return _snap(
      (item.x * _baseColumns - columns / 2).round(),
      (item.y * _baseRows - rows / 2).round(),
      columns,
      rows,
    );
  }

  bool _overlaps(
    _GridBlock block,
    String id,
    Map<String, _FloorObject> layout,
  ) => layout.values.any((item) {
    if (item.id == id) return false;
    final other = _blockFor(item);
    return block.column < other.column + other.columns &&
        block.column + block.columns > other.column &&
        block.row < other.row + other.rows &&
        block.row + block.rows > other.row;
  });

  void _updateBlock(
    _FloorObject item,
    _GridBlock block,
    Map<String, _FloorObject> layout, {
    int? rotation,
  }) {
    if (_overlaps(block, item.id, layout)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vị trí này đã có khối khác.')),
      );
      return;
    }
    _save({
      ..._objects,
      item.id: item.copyWith(block: block, rotation: rotation),
    }, item.id);
  }

  void _chooseTool(_FixtureKind? kind) {
    setState(() {
      _placement = kind;
      _placementPoint = null;
    });
  }

  void _zoomBy(double factor) {
    final matrix = _viewport.value;
    final scale = matrix.getMaxScaleOnAxis();
    final adjustment = (scale * factor).clamp(.5, 2.5) / scale;
    _viewport.value = Matrix4.copy(matrix)
      ..scaleByDouble(adjustment, adjustment, 1, 1);
  }

  Future<void> _setGridSize() async {
    final formKey = GlobalKey<FormState>();
    var columns = _columns;
    var rows = _rows;
    final size = await showDialog<(int, int)>(
      context: context,
      builder: (context) {
        Widget countField(String label, int min, ValueChanged<int> onSaved) =>
            TextFormField(
              initialValue: '$min',
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: label),
              validator: (text) {
                final value = int.tryParse(text?.trim() ?? '');
                return value == null || value < min || value > _maxGridSize
                    ? 'Nhập từ $min đến $_maxGridSize.'
                    : null;
              },
              onSaved: (text) => onSaved(int.parse(text!.trim())),
            );
        return AlertDialog(
          title: const Text('Kích thước lưới'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  countField('Số cột', _columns, (value) => columns = value),
                  const SizedBox(height: 12),
                  countField('Số hàng', _rows, (value) => rows = value),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                final form = formKey.currentState!;
                if (!form.validate()) return;
                form.save();
                Navigator.pop(context, (columns, rows));
              },
              child: const Text('Áp dụng'),
            ),
          ],
        );
      },
    );
    if (!mounted || size == null) return;
    await _save(
      _objects,
      _selection,
      extraColumns: size.$1 - _baseColumns,
      extraRows: size.$2 - _baseRows,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final editing = _editing && widget.canEdit;
    final layout = Map<String, _FloorObject>.from(_objects)
      ..removeWhere(
        (key, value) =>
            value.stockRack &&
            !value.manualRack &&
            !widget.racks.containsKey(key.substring(6)),
      );
    final rackColumns = math.min(3, math.max(1, widget.racks.length));
    final rackRows = math.max(1, (widget.racks.length / rackColumns).ceil());
    for (final (index, name) in widget.racks.keys.indexed) {
      final id = 'stock:$name';
      layout.putIfAbsent(
        id,
        () => _FloorObject(
          id: id,
          kind: _FixtureKind.rack,
          x: ((index % rackColumns) + .5) / rackColumns,
          y: ((index ~/ rackColumns) + .7) / (rackRows + .55),
        ),
      );
    }
    final selected = layout[_selection];
    final canvas = LayoutBuilder(
      builder: (context, constraints) {
        final cellSize = (constraints.maxWidth / _baseColumns).clamp(
          16.0,
          80.0,
        );
        final width = _columns * cellSize;
        final height = _rows * cellSize;
        final visibleHeight = height.clamp(320.0, 540.0);
        return SizedBox(
          height: visibleHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(color: colors.surfaceContainerLowest),
            child: InteractiveViewer(
              transformationController: _viewport,
              constrained: false,
              minScale: .50,
              maxScale: 2.5,
              child: SizedBox(
                key: _floorKey,
                width: width,
                height: height,
                child: DragTarget<_SceneDrag>(
                  onWillAcceptWithDetails: (_) => editing && !_saving,
                  onAcceptWithDetails: (details) {
                    final box =
                        _floorKey.currentContext!.findRenderObject()
                            as RenderBox;
                    final point = box.globalToLocal(details.offset);
                    _chooseTool(null);
                    _place(
                      details.data,
                      Offset(
                        (point.dx / width).clamp(0.0, 1.0),
                        (point.dy / height).clamp(0.0, 1.0),
                      ),
                      layout,
                    );
                  },
                  builder: (_, candidates, _) => CustomPaint(
                    painter: editing || _overhead
                        ? _WarehouseGrid(
                            cellSize,
                            colors.outlineVariant,
                            colors.surfaceContainerLow,
                          )
                        : _WarehouseStage(
                            overhead: false,
                            placing: candidates.isNotEmpty,
                          ),
                    child: Stack(
                      children: [
                        if (layout.isEmpty)
                          Center(
                            child: Text(
                              widget.canEdit
                                  ? 'Chọn Bố trí kho để thêm kệ và các khu vực.'
                                  : 'Kho chưa có mặt bằng.',
                            ),
                          ),
                        for (final obj in layout.values)
                          if (obj.id != _selection)
                            _item(obj, cellSize, editing, colors, layout),
                        if (selected != null)
                          _item(selected, cellSize, editing, colors, layout),
                        if (editing &&
                            _placement != null &&
                            _placementPoint != null)
                          _item(
                            _FloorObject(
                              id: 'preview',
                              kind: _placement!,
                              x: _placementPoint!.dx,
                              y: _placementPoint!.dy,
                              block: _snap(
                                (_placementPoint!.dx * _columns -
                                        _placement!.footprint.$1 / 2)
                                    .floor(),
                                (_placementPoint!.dy * _rows -
                                        _placement!.footprint.$2 / 2)
                                    .floor(),
                                _placement!.footprint.$1,
                                _placement!.footprint.$2,
                              ),
                            ),
                            cellSize,
                            false,
                            colors,
                            layout,
                            ghost: true,
                          ),
                        if (editing && _placement != null)
                          Positioned.fill(
                            child: MouseRegion(
                              cursor: SystemMouseCursors.precise,
                              onHover: (event) {
                                setState(
                                  () => _placementPoint = Offset(
                                    (event.localPosition.dx / width).clamp(
                                      0.0,
                                      1.0,
                                    ),
                                    (event.localPosition.dy / height).clamp(
                                      0.0,
                                      1.0,
                                    ),
                                  ),
                                );
                              },
                              onExit: (_) {
                                if (_placementPoint != null) {
                                  setState(() => _placementPoint = null);
                                }
                              },
                              child: GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onSecondaryTap: () => _chooseTool(null),
                                onTapUp: (details) {
                                  final kind = _placement;
                                  if (kind == null || _saving) return;
                                  _chooseTool(null);
                                  _place(
                                    (id: null, kind: kind),
                                    Offset(
                                      (details.localPosition.dx / width).clamp(
                                        0.0,
                                        1.0,
                                      ),
                                      (details.localPosition.dy / height).clamp(
                                        0.0,
                                        1.0,
                                      ),
                                    ),
                                    layout,
                                  );
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    final palette = _palette(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(top: 10, bottom: 6),
      elevation: 0,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: .28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 14, 12),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 10,
              spacing: 12,
              children: [
                Text(widget.title, style: theme.textTheme.titleLarge),
                Wrap(
                  spacing: 4,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 152,
                      child: SegmentedButton<bool>(
                        expandedInsets: EdgeInsets.zero,
                        showSelectedIcon: false,
                        style: const ButtonStyle(
                          padding: WidgetStatePropertyAll(
                            EdgeInsets.symmetric(horizontal: 10),
                          ),
                          minimumSize: WidgetStatePropertyAll(Size(64, 36)),
                        ),
                        segments: const [
                          ButtonSegment(
                            value: true,
                            label: Text('2D', softWrap: false),
                            tooltip: 'Mặt bằng nhìn từ trên',
                            icon: Icon(Icons.grid_on, size: 16),
                          ),
                          ButtonSegment(
                            value: false,
                            label: Text('3D', softWrap: false),
                            tooltip: 'Góc nhìn nghiêng',
                            icon: Icon(Icons.view_in_ar_outlined, size: 16),
                          ),
                        ],
                        selected: {_overhead},
                        onSelectionChanged: (value) =>
                            setState(() => _overhead = value.single),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Xoay góc nhìn',
                      icon: const Icon(Icons.rotate_right),
                      onPressed: () =>
                          setState(() => _angle = (_angle + 1) % 8),
                    ),
                    IconButton(
                      tooltip: 'Phóng to',
                      icon: const Icon(Icons.zoom_in),
                      onPressed: () => _zoomBy(1.25),
                    ),
                    IconButton(
                      tooltip: 'Thu nhỏ',
                      icon: const Icon(Icons.zoom_out),
                      onPressed: () => _zoomBy(.8),
                    ),
                    IconButton(
                      tooltip: 'Đặt lại khung nhìn',
                      icon: const Icon(Icons.center_focus_strong),
                      onPressed: () => _viewport.value = Matrix4.identity(),
                    ),
                    if (editing)
                      IconButton(
                        tooltip: 'Hoàn tác',
                        icon: const Icon(Icons.undo),
                        onPressed: _saving || _undo == null
                            ? null
                            : () {
                                final last = _undo!;
                                _save(
                                  last.objects,
                                  null,
                                  undo: true,
                                  extraColumns: last.columns,
                                  extraRows: last.rows,
                                );
                              },
                      ),
                    if (widget.canEdit)
                      FilledButton.tonalIcon(
                        onPressed: _loading || _saving
                            ? null
                            : () => setState(() {
                                _editing = !editing;
                                if (_editing) _overhead = true;
                                _placement = null;
                                _placementPoint = null;
                              }),
                        icon: Icon(
                          editing ? Icons.check : Icons.open_with,
                          size: 18,
                        ),
                        label: Text(editing ? 'Xong' : 'Bố trí kho'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          canvas,
          if (editing) ...[const Divider(height: 1), palette],
          if (widget.rackDetails.isNotEmpty) ...[
            const Divider(height: 1),
            ColoredBox(
              color: colors.surfaceContainerLow,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: widget.rackDetails,
              ),
            ),
          ],
          if (editing && selected != null) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: _inspector(selected, layout),
            ),
          ],
        ],
      ),
    );
  }

  Widget _palette(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return ColoredBox(
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _saving ? null : _setGridSize,
                  icon: const Icon(Icons.grid_on, size: 16),
                  label: Text('$_columns × $_rows ô'),
                ),
                TextButton.icon(
                  onPressed: _saving || _columns >= _maxGridSize
                      ? null
                      : () => _save(
                          _objects,
                          _selection,
                          extraColumns: _extraColumns + 1,
                        ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Thêm cột'),
                ),
                TextButton.icon(
                  onPressed: _saving || _rows >= _maxGridSize
                      ? null
                      : () => _save(
                          _objects,
                          _selection,
                          extraRows: _rows - _baseRows + 1,
                        ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Thêm hàng'),
                ),
                if (_placement != null)
                  TextButton(
                    onPressed: () => _chooseTool(null),
                    child: const Text('Hủy đặt'),
                  ),
              ],
            ),
            Text(
              _placement == null
                  ? 'Kéo khối vào lưới. Chọn khối rồi kéo góc để đổi kích thước.'
                  : 'Chọn ô để đặt ${_placement!.label.toLowerCase()}.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    spacing: 8,
                    children: [
                      for (final kind in _FixtureKind.values)
                        _toolTile(kind, colors),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolTile(_FixtureKind kind, ColorScheme colors) {
    final active = _placement == kind;
    final art = CustomPaint(
      size: const Size(49, 31),
      painter: kind == _FixtureKind.rack
          ? _RackShape(colors.primary, colors.surface, 0, false, stocked: false)
          : kind != _FixtureKind.aisle
          ? _FixtureModel(kind, 0)
          : _FixtureShape(
              kind,
              active ? colors.primary : colors.onSurfaceVariant,
              0,
            ),
    );
    final tile = ConstrainedBox(
      constraints: const BoxConstraints.tightFor(width: 110, height: 70),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.all(4),
          foregroundColor: active ? colors.primary : colors.onSurface,
          backgroundColor: active ? colors.primaryContainer : colors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          side: BorderSide(
            color: active ? colors.primary : colors.outlineVariant,
          ),
        ),
        onPressed: _saving ? null : () => _chooseTool(active ? null : kind),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            art,
            const SizedBox(height: 4),
            Text(
              kind.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
    return Draggable<_SceneDrag>(
      data: (id: null, kind: kind),
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(opacity: .8, child: tile),
      ),
      child: Semantics(selected: active, child: tile),
    );
  }

  Widget _inspector(_FloorObject item, Map<String, _FloorObject> layout) {
    final block = _resizePreview ?? _blockFor(item);
    void resize(int columns, int rows, {int? rotation}) {
      _updateBlock(
        item,
        _snap(block.column, block.row, columns, rows),
        layout,
        rotation: rotation,
      );
    }

    return Wrap(
      spacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(item.stockRack ? 'Kệ ${item.id.substring(6)}' : item.kind.label),
        Text('${block.columns} × ${block.rows} ô'),
        if (item.stockRack)
          TextButton.icon(
            onPressed: _saving
                ? null
                : () => widget.onAssignRack(item.id.substring(6)),
            icon: const Icon(Icons.add_location_alt_outlined, size: 18),
            label: const Text('Gắn sản phẩm'),
          ),
        IconButton(
          tooltip: 'Xoay khối 90°',
          icon: const Icon(Icons.rotate_90_degrees_cw),
          onPressed: _saving
              ? null
              : () => resize(
                  block.rows,
                  block.columns,
                  rotation: (item.rotation + 1) % 4,
                ),
        ),
        IconButton(
          tooltip: 'Giảm chiều ngang',
          icon: const Icon(Icons.keyboard_arrow_left),
          onPressed: _saving
              ? null
              : () => resize(block.columns - 1, block.rows),
        ),
        IconButton(
          tooltip: 'Tăng chiều ngang',
          icon: const Icon(Icons.keyboard_arrow_right),
          onPressed: _saving
              ? null
              : () => resize(block.columns + 1, block.rows),
        ),
        IconButton(
          tooltip: 'Giảm chiều dọc',
          icon: const Icon(Icons.keyboard_arrow_up),
          onPressed: _saving
              ? null
              : () => resize(block.columns, block.rows - 1),
        ),
        IconButton(
          tooltip: 'Tăng chiều dọc',
          icon: const Icon(Icons.keyboard_arrow_down),
          onPressed: _saving
              ? null
              : () => resize(block.columns, block.rows + 1),
        ),
        if (!item.stockRack || !widget.racks.containsKey(item.id.substring(6)))
          IconButton(
            tooltip: 'Bỏ khối khỏi mặt bằng',
            icon: const Icon(Icons.delete_outline),
            onPressed: _saving
                ? null
                : () => _save({..._objects}..remove(item.id), null),
          ),
      ],
    );
  }

  Widget _item(
    _FloorObject item,
    double cellSize,
    bool editing,
    ColorScheme colors,
    Map<String, _FloorObject> layout, {
    bool ghost = false,
  }) {
    final rack = item.stockRack ? widget.racks[item.id.substring(6)] : null;
    final selected = editing && _selection == item.id;
    final block = (selected ? _resizePreview : null) ?? _blockFor(item);
    final invalid = ghost && _overlaps(block, item.id, layout);
    final angle = (_angle + item.rotation * 2) % 8;
    final card = rack == null
        ? _FixtureTile(
            kind: item.kind,
            selected: ghost || _selection == item.id,
            angle: angle,
            overhead: _overhead,
            label: item.stockRack
                ? 'Kệ ${item.id.substring(6)}'
                : item.kind.label,
          )
        : _RackPerspective(angle: angle, overhead: _overhead, child: rack);
    final visual = SizedBox(
      width: block.columns * cellSize,
      height: block.rows * cellSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: selected || invalid
              ? Border.all(
                  color: invalid ? colors.error : colors.primary,
                  width: 2,
                )
              : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: card,
      ),
    );
    final draggable = ghost
        ? Opacity(opacity: .60, child: visual)
        : editing
        ? Draggable<_SceneDrag>(
            data: (id: item.id, kind: null),
            dragAnchorStrategy: pointerDragAnchorStrategy,
            feedback: Material(
              color: Colors.transparent,
              child: IgnorePointer(child: visual),
            ),
            childWhenDragging: Opacity(opacity: .30, child: visual),
            child: Semantics(
              button: true,
              label: item.stockRack
                  ? 'Chọn kệ ${item.id.substring(6)}'
                  : item.kind.label,
              child: InkWell(
                onTap: () => setState(() => _selection = item.id),
                child: IgnorePointer(child: visual),
              ),
            ),
          )
        : visual;
    return Positioned(
      left: block.column * cellSize,
      top: block.row * cellSize,
      child: selected
          ? Stack(
              children: [
                draggable,
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: _resizeHandle(item, block, cellSize, colors, layout),
                ),
              ],
            )
          : draggable,
    );
  }

  Widget _resizeHandle(
    _FloorObject item,
    _GridBlock block,
    double cellSize,
    ColorScheme colors,
    Map<String, _FloorObject> layout,
  ) {
    return Tooltip(
      message: 'Kéo để đổi kích thước theo ô',
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeDownRight,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: _saving
              ? null
              : (_) {
                  _resizeStart = block;
                  _resizeDelta = Offset.zero;
                },
          onPanUpdate: (details) {
            final start = _resizeStart;
            if (start == null) return;
            _resizeDelta += details.delta;
            final columns =
                (start.columns + (_resizeDelta.dx / cellSize).round()).clamp(
                  1,
                  _columns - start.column,
                );
            final rows = (start.rows + (_resizeDelta.dy / cellSize).round())
                .clamp(1, _rows - start.row);
            final next = _snap(start.column, start.row, columns, rows);
            if (!_overlaps(next, item.id, layout)) {
              setState(() => _resizePreview = next);
            }
          },
          onPanCancel: () => setState(() {
            _resizeStart = null;
            _resizePreview = null;
          }),
          onPanEnd: (_) {
            final next = _resizePreview;
            setState(() {
              _resizeStart = null;
              _resizePreview = null;
            });
            if (next != null) _updateBlock(item, next, layout);
          },
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: colors.primary,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
              ),
            ),
            child: Icon(Icons.open_in_full, size: 14, color: colors.onPrimary),
          ),
        ),
      ),
    );
  }
}

class _FixtureTile extends StatelessWidget {
  const _FixtureTile({
    required this.kind,
    required this.selected,
    required this.angle,
    required this.overhead,
    required this.label,
  });
  final _FixtureKind kind;
  final bool selected;
  final int angle;
  final bool overhead;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fill = switch (kind) {
      _FixtureKind.aisle => colors.tertiaryContainer,
      _FixtureKind.door || _FixtureKind.receiving => colors.secondaryContainer,
      _FixtureKind.wall => colors.surfaceContainerHighest,
      _ => colors.primaryContainer,
    };
    final ink = switch (kind) {
      _FixtureKind.aisle => colors.onTertiaryContainer,
      _FixtureKind.door ||
      _FixtureKind.receiving => colors.onSecondaryContainer,
      _FixtureKind.wall => colors.onSurface,
      _ => colors.onPrimaryContainer,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: selected ? fill : fill.withValues(alpha: .24),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          if (!overhead)
            BoxShadow(
              color: colors.shadow.withValues(alpha: .16),
              offset: const Offset(2, 4),
              blurRadius: 4,
            ),
        ],
        border: Border.all(
          color: selected
              ? colors.primary
              : colors.outlineVariant.withValues(alpha: .6),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (kind == _FixtureKind.rack)
                CustomPaint(
                  size: const Size(74, 46),
                  painter: _RackShape(
                    colors.primary,
                    colors.surface,
                    angle,
                    overhead,
                    stocked: false,
                  ),
                )
              else
                CustomPaint(
                  size: const Size(72, 36),
                  painter: overhead || kind == _FixtureKind.aisle
                      ? _FixtureShape(
                          kind,
                          selected ? ink : colors.onSurface,
                          angle,
                        )
                      : _FixtureModel(kind, angle),
                ),
              const SizedBox(height: 3),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selected ? ink : colors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FixtureModel extends CustomPainter {
  const _FixtureModel(this.kind, this.angle);

  final _FixtureKind kind;
  final int angle;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 72, size.height / 36);
    final yaw = .48 + angle * math.pi / 4;
    final cos = math.cos(yaw);
    final sin = math.sin(yaw);
    ({Offset point, double depth}) project(double x, double y, double z) {
      final forward = x * sin + y * cos;
      return (
        point: Offset(36 + x * cos - y * sin, 25 + forward * .38 - z * .72),
        depth: forward + z * .45,
      );
    }

    final faces = <({Path path, Color shade, double depth})>[];
    void box(
      double x,
      double y,
      double z,
      double w,
      double d,
      double h,
      Color tone,
    ) {
      final points = [
        project(x, y, z),
        project(x + w, y, z),
        project(x + w, y + d, z),
        project(x, y + d, z),
        project(x, y, z + h),
        project(x + w, y, z + h),
        project(x + w, y + d, z + h),
        project(x, y + d, z + h),
      ];
      for (final (indices, shade) in [
        ([0, 1, 5, 4], .15),
        ([1, 2, 6, 5], .26),
        ([2, 3, 7, 6], .15),
        ([3, 0, 4, 7], .26),
        ([4, 5, 6, 7], 0.0),
      ]) {
        faces.add((
          path: Path()
            ..addPolygon(indices.map((i) => points[i].point).toList(), true),
          shade: Color.lerp(tone, Colors.black, shade)!,
          depth:
              indices.map((i) => points[i].depth).reduce((a, b) => a + b) / 4,
        ));
      }
    }

    const slate = Color(0xFF819BAC);
    const amber = Color(0xFFE6AD66);
    const steel = Color(0xFF527897);
    switch (kind) {
      case _FixtureKind.door:
        box(-24, -11, 0, 48, 23, 2, slate);
        box(-21, -7, 2, 4, 5, 24, steel);
        box(17, -7, 2, 4, 5, 24, steel);
        box(-21, -7, 24, 42, 5, 3, steel);
        box(-16, -7, 3, 4, 19, 20, amber);
      case _FixtureKind.counter:
        box(-23, -10, 0, 43, 15, 14, steel);
        box(-25, -12, 14, 47, 19, 3, const Color(0xFFD4DEDF));
        box(11, 4, 0, 11, 12, 13, steel);
        box(9, 4, 13, 15, 14, 3, const Color(0xFFD4DEDF));
        box(-10, -6, 17, 12, 5, 5, const Color(0xFF344A60));
      case _FixtureKind.receiving:
        for (final x in [-24.0, 1.0]) {
          box(x, -9, 0, 22, 18, 3, slate);
          box(x + 2, -7, 3, 17, 14, 9, amber);
          box(x + 5, -5, 12, 11, 10, 5, const Color(0xFFD18B52));
        }
      case _FixtureKind.wall:
        box(-25, -5, 0, 50, 10, 3, steel);
        box(-24, -3, 3, 48, 6, 19, slate);
        box(-24, -3, 22, 48, 6, 2, const Color(0xFFBDC9CB));
      case _FixtureKind.pallet:
        box(-22, -12, 0, 44, 24, 4, amber);
        box(-18, -9, 4, 36, 18, 11, const Color(0xFFD18B52));
      case _FixtureKind.coldStorage:
        box(-21, -11, 0, 42, 22, 24, const Color(0xFF6CA4CE));
        box(-18, -12, 3, 16, 2, 17, const Color(0xFFD9E9F3));
        box(1, -12, 3, 16, 2, 17, const Color(0xFFD9E9F3));
      case _FixtureKind.display:
        box(-23, -9, 0, 46, 18, 9, slate);
        box(-24, -10, 9, 48, 20, 3, const Color(0xFFBD946E));
        box(-18, -6, 12, 12, 10, 6, amber);
        box(4, -6, 12, 12, 10, 6, steel);
      case _FixtureKind.bulk:
        box(-25, -12, 0, 50, 24, 3, slate);
        box(-22, -10, 3, 21, 20, 15, amber);
        box(2, -9, 3, 22, 18, 10, const Color(0xFFD18B52));
      case _FixtureKind.dispatch:
        box(-23, -11, 0, 46, 22, 3, slate);
        box(-21, -8, 3, 25, 16, 12, steel);
        box(7, -8, 3, 13, 16, 8, const Color(0xFF83B58D));
      case _FixtureKind.rack || _FixtureKind.aisle:
        return;
    }
    canvas.drawOval(
      const Rect.fromLTWH(9, 24, 54, 9),
      Paint()..color = const Color(0x5507141E),
    );
    faces.sort((a, b) => a.depth.compareTo(b.depth));
    for (final face in faces) {
      canvas.drawPath(face.path, Paint()..color = face.shade);
    }
  }

  @override
  bool shouldRepaint(_FixtureModel oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.angle != angle;
}

class _FixtureShape extends CustomPainter {
  const _FixtureShape(this.kind, this.color, this.angle);
  final _FixtureKind kind;
  final Color color;
  final int angle;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 72, size.height / 36);
    canvas.translate(36, 18);
    canvas.rotate(angle * math.pi / 4);
    final stroke = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color.withValues(alpha: .16);
    switch (kind) {
      case _FixtureKind.aisle:
        for (final x in [-17.0, 0.0, 17.0]) {
          canvas.drawPath(
            Path()
              ..moveTo(x - 4, -6)
              ..lineTo(x + 2, 0)
              ..lineTo(x - 4, 6),
            stroke,
          );
        }
      case _FixtureKind.door:
        canvas.drawLine(const Offset(-13, 12), const Offset(13, 12), stroke);
        canvas.drawLine(const Offset(-13, 12), const Offset(-13, -13), stroke);
        canvas.drawArc(
          const Rect.fromLTWH(-38, -13, 50, 50),
          -math.pi / 2,
          math.pi / 2,
          false,
          stroke,
        );
      case _FixtureKind.wall:
        const rect = Rect.fromLTWH(-25, -4, 50, 8);
        canvas.drawRect(rect, fill);
        canvas.drawRect(rect, stroke);
      case _FixtureKind.counter:
        final counter = Path()
          ..moveTo(-24, -9)
          ..lineTo(22, -9)
          ..lineTo(22, 9)
          ..lineTo(14, 9)
          ..lineTo(14, -1)
          ..lineTo(-24, -1)
          ..close();
        canvas.drawPath(counter, fill);
        canvas.drawPath(counter, stroke);
      case _FixtureKind.receiving:
        for (final x in [-22.0, -7.0, 8.0]) {
          final rect = Rect.fromLTWH(x, -8, 12, 16);
          canvas.drawRect(rect, fill);
          canvas.drawRect(rect, stroke);
          canvas.drawLine(Offset(x, 0), Offset(x + 12, 0), stroke);
        }
      case _FixtureKind.pallet ||
          _FixtureKind.coldStorage ||
          _FixtureKind.display ||
          _FixtureKind.bulk ||
          _FixtureKind.dispatch:
        const rect = Rect.fromLTWH(-22, -11, 44, 22);
        canvas.drawRect(rect, fill);
        canvas.drawRect(rect, stroke);
        canvas.drawLine(const Offset(0, -11), const Offset(0, 11), stroke);
      case _FixtureKind.rack:
        break;
    }
  }

  @override
  bool shouldRepaint(_FixtureShape oldDelegate) =>
      oldDelegate.kind != kind ||
      oldDelegate.color != color ||
      oldDelegate.angle != angle;
}

class _WarehouseGrid extends CustomPainter {
  const _WarehouseGrid(this.cellSize, this.line, this.background);

  final double cellSize;
  final Color line;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(bounds, Paint()..color = background);
    final paint = Paint()
      ..color = line.withValues(alpha: .78)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += cellSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += cellSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    canvas.drawRect(bounds, paint..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(_WarehouseGrid oldDelegate) =>
      oldDelegate.cellSize != cellSize ||
      oldDelegate.line != line ||
      oldDelegate.background != background;
}

class _WarehouseStage extends CustomPainter {
  const _WarehouseStage({required this.overhead, required this.placing});

  final bool overhead;
  final bool placing;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final backdrop = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF202D43), Color(0xFF101822)],
      ).createShader(bounds);
    canvas.drawRect(bounds, backdrop);
    if (size.width < 120 || size.height < 130) return;

    final inset = size.width < 560 ? 13.0 : 44.0;
    final rear = overhead ? 15.0 : 42.0;
    final bottom = size.height - (overhead ? 16 : 23);
    final skew = overhead ? 0.0 : (size.width * .055).clamp(12.0, 68.0);
    final backLeft = Offset(inset + skew, rear);
    final backRight = Offset(size.width - inset, rear);
    final frontRight = Offset(size.width - inset - skew, bottom);
    final frontLeft = Offset(inset, bottom);
    const down = Offset(0, 10);

    Path polygon(List<Offset> points) => Path()..addPolygon(points, true);
    void face(List<Offset> points, Color color) {
      canvas.drawPath(polygon(points), Paint()..color = color);
    }

    if (!overhead) {
      final shadow = polygon([backLeft, backRight, frontRight, frontLeft]);
      canvas.save();
      canvas.translate(4, 13);
      canvas.drawPath(
        shadow,
        Paint()
          ..color = const Color(0x77000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
      canvas.restore();
      face([
        frontLeft,
        frontRight,
        frontRight + down,
        frontLeft + down,
      ], const Color(0xFF536477));
      face([
        backRight,
        frontRight,
        frontRight + down,
        backRight + down,
      ], const Color(0xFF3C4A60));
    }

    final floor = polygon([backLeft, backRight, frontRight, frontLeft]);
    canvas.drawPath(
      floor,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF364A60), Color(0xFF263547)],
        ).createShader(floor.getBounds()),
    );

    Offset project(double x, double y) => Offset.lerp(
      Offset.lerp(backLeft, backRight, x),
      Offset.lerp(frontLeft, frontRight, x),
      y,
    )!;

    final columns = ((size.width - inset * 2) / 40).floor().clamp(5, 38);
    final rows = ((bottom - rear) / 38).floor().clamp(4, 20);
    final ink = Paint()..color = const Color(0x435F8299);
    final joint = Paint()..color = const Color(0x8066889D);
    for (var i = 1; i < columns; i++) {
      final x = i / columns;
      canvas.drawLine(project(x, 0), project(x, 1), i % 4 == 0 ? joint : ink);
    }
    for (var j = 1; j < rows; j++) {
      final y = j / rows;
      canvas.drawLine(project(0, y), project(1, y), j % 4 == 0 ? joint : ink);
    }

    if (!overhead) {
      const wall = Offset(0, -28);
      face([
        backLeft,
        backRight,
        backRight + wall,
        backLeft + wall,
      ], const Color(0xFF526984));
      face([
        backLeft,
        frontLeft,
        frontLeft + wall,
        backLeft + wall,
      ], const Color(0xFF3D516A));
      final cap = Paint()
        ..color = const Color(0xFF7893A9)
        ..strokeWidth = 2;
      canvas.drawLine(backLeft + wall, backRight + wall, cap);
      canvas.drawLine(backLeft + wall, frontLeft + wall, cap);
      for (var i = 1; i < columns; i += 2) {
        final point = project(i / columns, 0);
        canvas.drawLine(point, point + wall, ink);
      }
    }

    final edge = Paint()
      ..color = placing ? const Color(0xFFFFC675) : const Color(0xFF7193A5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = placing ? 1.6 : 1;
    canvas.drawPath(floor, edge);
    final marking = Paint()
      ..color = const Color(0xFFC79A5B)
      ..strokeWidth = 1.5;
    for (var i = 0; i < 8; i++) {
      final x = .08 + i * .024;
      canvas.drawLine(project(x, .96), project(x + .012, .93), marking);
      canvas.drawLine(project(.9 - x, .96), project(.912 - x, .93), marking);
    }
  }

  @override
  bool shouldRepaint(_WarehouseStage oldDelegate) =>
      oldDelegate.overhead != overhead || oldDelegate.placing != placing;
}

class _RackPerspective extends InheritedWidget {
  const _RackPerspective({
    required this.angle,
    required this.overhead,
    required super.child,
  });

  final int angle;
  final bool overhead;

  @override
  bool updateShouldNotify(_RackPerspective oldWidget) =>
      angle != oldWidget.angle || overhead != oldWidget.overhead;
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
    final view = context.dependOnInheritedWidgetOfExactType<_RackPerspective>();
    return Semantics(
      selected: selected,
      child: Opacity(
        opacity: muted ? .55 : 1,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            backgroundColor: active
                ? colors.primaryContainer
                : Colors.transparent,
            foregroundColor: active
                ? colors.onPrimaryContainer
                : colors.onSurface,
            side: BorderSide(
              color: active ? colors.primary : Colors.transparent,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
          onPressed: onTap,
          child: SizedBox(
            width: 102,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomPaint(
                    size: const Size(104, 68),
                    painter: _RackShape(
                      active ? colors.primary : colors.secondary,
                      colors.surface,
                      view?.angle ?? 0,
                      view?.overhead ?? false,
                    ),
                  ),
                  SizedBox(
                    width: 94,
                    child: Text(
                      'Kệ $name',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text('$count mặt hàng', style: theme.textTheme.labelSmall),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RackShape extends CustomPainter {
  const _RackShape(
    this.color,
    this.surface,
    this.angle,
    this.overhead, {
    this.stocked = true,
  });
  final bool stocked;
  final Color color;
  final Color surface;
  final int angle;
  final bool overhead;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 104, size.height / 72);
    final yaw = ((overhead ? 0 : .52) + angle * math.pi / 4);
    final pitch = overhead ? math.pi / 2 : .59;
    final cy = math.cos(yaw);
    final sy = math.sin(yaw);
    final cp = math.cos(pitch);
    final sp = math.sin(pitch);

    ({Offset point, double depth}) project(double x, double y, double z) {
      final horizontal = x * cy - y * sy;
      final forward = x * sy + y * cy;
      return (
        point: Offset(52 + horizontal, 55 + forward * sp - z * cp),
        depth: forward * cp + z * sp,
      );
    }

    const steel = Color(0xFF254F65);
    const beam = Color(0xFFD98344);
    const deck = Color(0xFF8C9CA2);
    const cardboard = Color(0xFFCE9D61);
    if (overhead) {
      canvas.save();
      canvas.translate(52, 36);
      canvas.rotate(yaw);
      final boundary = RRect.fromRectAndRadius(
        const Rect.fromLTWH(-39, -17, 78, 34),
        const Radius.circular(3),
      );
      canvas.drawRRect(
        boundary,
        Paint()..color = Color.lerp(surface, color, .15)!,
      );
      canvas.drawRRect(
        boundary,
        Paint()
          ..color = steel
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      for (final x in [-35.0, -11.0, 13.0]) {
        final bin = Rect.fromLTWH(x, -12, 22, 24);
        canvas.drawRect(
          bin,
          Paint()
            ..color = stocked ? cardboard : Color.lerp(surface, steel, .14)!,
        );
        if (stocked) {
          canvas.drawLine(
            Offset(x + 11, -12),
            Offset(x + 11, 12),
            Paint()..color = beam,
          );
        }
      }
      canvas.restore();
      return;
    }
    canvas.drawOval(
      const Rect.fromLTWH(10, 51, 84, 16),
      Paint()..color = steel.withValues(alpha: .13),
    );

    final faces = <({double depth, Path path, Color color})>[];
    void box(
      double x1,
      double y1,
      double z1,
      double x2,
      double y2,
      double z2,
      Color fill,
    ) {
      final vertices = [
        project(x1, y1, z1),
        project(x2, y1, z1),
        project(x2, y2, z1),
        project(x1, y2, z1),
        project(x1, y1, z2),
        project(x2, y1, z2),
        project(x2, y2, z2),
        project(x1, y2, z2),
      ];
      final sides = [
        ([0, 1, 5, 4], .12),
        ([1, 2, 6, 5], .27),
        ([2, 3, 7, 6], .12),
        ([3, 0, 4, 7], .27),
        ([4, 5, 6, 7], 0.0),
      ];
      for (final (indices, shade) in sides) {
        faces.add((
          depth:
              indices.map((i) => vertices[i].depth).reduce((a, b) => a + b) /
              indices.length,
          path: Path()
            ..addPolygon(indices.map((i) => vertices[i].point).toList(), true),
          color: shade == 0
              ? Color.lerp(fill, surface, .40)!
              : Color.lerp(fill, Colors.black, shade)!,
        ));
      }
    }

    for (final z in [5.0, 24.0, 43.0]) {
      box(-36, -14, z, 36, 14, z + 2, deck);
      for (final y in [-15.0, 12.0]) {
        box(-38, y, z - 2, 38, y + 3, z + 2, beam);
      }
    }
    for (final x in [-38.0, 35.0]) {
      for (final y in [-15.0, 12.0]) {
        box(x, y, 0, x + 3, y + 3, 47, steel);
      }
    }
    if (stocked) {
      for (final (x, z, top) in [
        (-31.0, 7.0, 20.0),
        (-7.0, 7.0, 18.0),
        (16.0, 7.0, 21.0),
        (-30.0, 26.0, 38.0),
        (-4.0, 26.0, 37.0),
        (16.0, 26.0, 39.0),
      ]) {
        box(x, -10, z, x + 16, 9, top, cardboard);
        box(x + 6, -10.2, z, x + 9, -9.9, top + .1, const Color(0xFFE8C99B));
      }
    }
    faces.sort((a, b) => a.depth.compareTo(b.depth));
    for (final face in faces) {
      canvas.drawPath(face.path, Paint()..color = face.color);
    }
  }

  @override
  bool shouldRepaint(_RackShape oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.surface != surface ||
      oldDelegate.angle != angle ||
      oldDelegate.overhead != overhead ||
      oldDelegate.stocked != stocked;
}

class _PositionDialog extends StatefulWidget {
  const _PositionDialog({required this.choices, this.rackCode});
  final String? rackCode;
  final List<Map<String, dynamic>> choices;

  @override
  State<_PositionDialog> createState() => _PositionDialogState();
}

class _PositionDialogState extends State<_PositionDialog> {
  final _form = GlobalKey<FormState>();
  int _selected = 0;
  late String _rack =
      widget.rackCode ?? (widget.choices.first['rack'] as String?) ?? '';
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
              readOnly: widget.rackCode != null,
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
