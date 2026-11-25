import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../core/widgets/app_page_header.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/warehouse_display_name.dart';
import '../../../core/utils/search_text.dart';
import '../../../core/widgets/product_thumbnail.dart';
import '../../settings/providers/shop_provider.dart';

part 'shelf_floor_storage.dart';

part 'inventory_shelf_lookup_bar.dart';

const _path = '/inventory/shelf-positions';

AppThemeColors _appColors(BuildContext context) {
  return Theme.of(context).extension<AppThemeColors>() ??
      (Theme.of(context).brightness == Brightness.dark
          ? AppThemeColors.dark
          : AppThemeColors.light);
}

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

enum _FixtureKind {
  rack('Kệ trống', Icons.table_rows_outlined),
  door('Cửa ra vào', Icons.door_front_door_outlined),
  aisle('Lối đi', Icons.alt_route),
  receiving('Khu nhận hàng', Icons.move_to_inbox_outlined),
  dispatch('Khu giao hàng', Icons.local_shipping_outlined),
  wall('Vách ngăn', Icons.view_week_outlined),
  pallet('Pallet', Icons.layers_outlined),
  bulk('Hàng cồng kềnh', Icons.inventory_2_outlined),
  coldStorage('Tủ mát', Icons.ac_unit_outlined),
  display('Bàn trưng bày', Icons.table_restaurant_outlined),
  counter('Quầy', Icons.storefront_outlined);

  const _FixtureKind(this.label, this.icon);
  final String label;
  final IconData icon;

  bool get holdsProducts =>
      const {rack, coldStorage, display, pallet, bulk}.contains(this);

  String assetPath({bool occupied = false}) {
    final file = switch (this) {
      rack => occupied ? 'rack_loaded' : 'rack_empty',
      coldStorage => 'cold_storage',
      display => 'display',
      pallet => 'pallet',
      counter => 'counter',
      bulk => 'bulk',
      receiving => 'receiving',
      dispatch => 'dispatch',
      wall => 'wall',
      aisle => 'aisle',
      door => 'door',
    };
    return 'assets/warehouse/$file.webp';
  }

  (int, int) get footprint => switch (this) {
    rack => (3, 2),
    aisle => (4, 1),
    door => (2, 1),
    receiving || dispatch || bulk => (4, 3),
    wall => (4, 1),
    pallet => (3, 2),
    coldStorage || display => (3, 2),
    counter => (4, 2),
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
    this.width = 1.0,
    this.height = 1.0,
    this.rotation = 0,
    this.manualRack = false,
    this.name = '',
    this.note = '',
    this.block,
  });

  factory _FloorObject.fromJson(Map<String, dynamic> json) {
    final kind = _FixtureKind.values.byName(json['kind'] as String? ?? 'rack');
    final savedId = json['id'] as String;
    if (savedId.trim().isEmpty || savedId == 'stock:') {
      throw const FormatException('Thiếu mã vật thể.');
    }
    final storageId = kind.holdsProducts && !savedId.startsWith('stock:');
    return _FloorObject(
      id: storageId ? 'stock:V-$savedId' : savedId,
      kind: kind,
      x: (json['x'] as num?)?.toDouble().clamp(0.0, 1.0) ?? 0.0,
      y: (json['y'] as num?)?.toDouble().clamp(0.0, 1.0) ?? 0.0,
      width: (json['width'] as num?)?.toDouble().clamp(0.5, 3.0) ?? 1.0,
      height: (json['height'] as num?)?.toDouble().clamp(0.5, 3.0) ?? 1.0,
      rotation: ((json['rotation'] as int?) ?? 0) % 4,
      manualRack: storageId || json['manualRack'] == true,
      name: json['name'] as String? ?? '',
      note: json['note'] as String? ?? '',
      block: switch (json['block']) {
        [int column, int row, int columns, int rows] => (
          column: column,
          row: row,
          columns: columns,
          rows: rows,
        ),
        null => null,
        _ => throw const FormatException('Sai tọa độ vật thể.'),
      },
    );
  }

  final String id;
  final _FixtureKind kind;
  final double x, y, width, height;
  final int rotation;
  final bool manualRack;
  final String name;
  final String note;
  final _GridBlock? block;

  bool get stockRack => id.startsWith('stock:');
  String get rackCode => stockRack ? id.substring(6) : '';
  String get rackTitle => name.isNotEmpty
      ? name
      : kind == _FixtureKind.rack
      ? 'Kệ $rackCode'
      : kind.label;

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'rotation': rotation,
    if (manualRack) 'manualRack': true,
    if (name.isNotEmpty) 'name': name,
    if (note.isNotEmpty) 'note': note,
    if (block case final b?) 'block': [b.column, b.row, b.columns, b.rows],
  };

  _FloorObject copyWith({
    String? name,
    String? note,
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
    name: name ?? this.name,
    note: note ?? this.note,
    block: block ?? this.block,
  );
}

class InventoryShelvesScreen extends ConsumerWidget {
  const InventoryShelvesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopId = ref.watch(shopProvider.select((s) => s.currentShopId));
    return _ShopShelves(key: ValueKey(shopId));
  }
}

class _ShopShelves extends ConsumerStatefulWidget {
  const _ShopShelves({super.key});

  @override
  ConsumerState<_ShopShelves> createState() => _InventoryShelvesScreenState();
}

typedef _ShelfLookup = ({String rack, int level, int bin, int request});

class _InventoryShelvesScreenState extends ConsumerState<_ShopShelves> {
  final _searchController = TextEditingController();
  _ShelfLookup? _lookup;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _assigning = false;
  int? _activeWarehouseId;

  Future<void> _assign(
    int shopId, {
    Map<String, dynamic>? position,
    int? warehouseId,
    String? rackCode,
    int? initialLevel,
    int? initialBin,
  }) async {
    if (_assigning) return;
    setState(() => _assigning = true);
    bool current() => mounted && ref.read(shopProvider).currentShopId == shopId;
    final api = ref.read(apiClientProvider);
    try {
      final snapshot =
          (await api.getOnlineInShop(_path, '$shopId', isCurrentScope: current)
                  as List)
              .cast<Map<String, dynamic>>();
      if (!mounted || !current()) return;
      if (position != null) {
        final target = position;
        position = snapshot
            .where(
              (row) =>
                  row['warehouseId'] == target['warehouseId'] &&
                  row['productId'] == target['productId'],
            )
            .firstOrNull;
        if (position == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vị trí đã thay đổi. Hãy chọn lại sản phẩm.'),
            ),
          );
          ref.invalidate(_shelvesProvider(shopId));
          return;
        }
      }
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
                    'imageUrl': row['product']?['imageUrl'],
                  };
                }),
          );
          final totalPages = data['totalPages'] as int?;
          if (items.isEmpty ||
              (totalPages != null ? page >= totalPages : items.length < 500)) {
            break;
          }
        }
      } else {
        choices.add(position);
      }
      if (!mounted || choices.isEmpty || !current()) {
        if (mounted && current()) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Không có sản phẩm nào để gắn vị trí trong kho này.',
              ),
            ),
          );
        }
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      if (!mounted || !current()) return;
      final racksByWarehouse = <int, Map<String, _FloorObject?>>{};
      for (final id
          in choices.map((row) => row['warehouseId'] as int).toSet()) {
        final racks = racksByWarehouse[id] = {
          for (final row in snapshot)
            if (row['warehouseId'] == id) row['rack'] as String: null,
        };
        final saved = _readFloor(
          prefs.get('inventory.shelf.scene.$shopId.$id'),
        );
        for (final item in saved.objects.values) {
          if (item.stockRack) racks[item.rackCode] = item;
        }
        if (warehouseId == id && rackCode != null) {
          racks.putIfAbsent(rackCode, () => null);
        }
      }
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => _PositionDialog(
          choices: choices,
          positions: snapshot,
          racksByWarehouse: racksByWarehouse,
          rackCode: rackCode,
          initialLevel: initialLevel,
          initialBin: initialBin,
        ),
      );
      if (result == null || !current()) return;
      final rawPositions = await api.getOnlineInShop(
        _path,
        '$shopId',
        isCurrentScope: current,
      );
      if (!mounted || !current()) return;
      final previous = (rawPositions as List)
          .cast<Map<String, dynamic>>()
          .where(
            (row) =>
                row['warehouseId'] == result['warehouseId'] &&
                row['productId'] == result['productId'],
          )
          .firstOrNull;
      if (previous != null) {
        final moved = [
          'rack',
          'level',
          'bin',
        ].any((field) => previous[field] != result[field]);
        if (!moved) return;
        String address(Map<String, dynamic> row) =>
            'Kệ ${row['rack']} · Tầng ${row['level']} · Ô ${row['bin']}';
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Chuyển vị trí sản phẩm?'),
            content: Text(
              "${previous['productName']} đã có vị trí trong kho này.\n\n"
              'Vị trí hiện tại: ${address(previous)}\n'
              'Vị trí mới: ${address(result)}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Giữ vị trí cũ'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Chuyển vị trí'),
              ),
            ],
          ),
        );
        if (confirmed != true || !current()) return;
      }
      await api.putInShop(
        _path,
        '$shopId',
        data: {
          ...result,
          'expectedPosition': previous == null
              ? null
              : {
                  for (final field in ['rack', 'level', 'bin'])
                    field: previous[field],
                },
        },
        isCurrentScope: current,
      );
      if (mounted && current()) {
        ref.invalidate(_shelvesProvider(shopId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              previous == null
                  ? 'Đã gắn vị trí sản phẩm.'
                  : 'Đã chuyển vị trí sản phẩm.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted && current()) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _assigning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _appColors(context);
    final shop = ref.watch(shopProvider);
    final shopId = shop.currentShopId;
    final canEdit = shop.hasPermission('inventory', 'edit');
    final shelves = shopId == null || shopId < 1
        ? null
        : ref.watch(_shelvesProvider(shopId));
    final warehouses =
        shelves?.value?.warehouses ?? const <Map<String, dynamic>>[];
    final currentWarehouse =
        warehouses.where((w) => w['id'] == _activeWarehouseId).firstOrNull ??
        warehouses.firstOrNull;
    final warehouseId = currentWarehouse?['id'] as int?;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        leading: const AppPageBackLeading(),
        title: const Text('Sơ đồ kệ'),
        backgroundColor: c.surface,
        foregroundColor: c.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        actions: [
          if (shopId != null && warehouseId != null && canEdit)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: OutlinedButton.icon(
                onPressed: _assigning
                    ? null
                    : () => _assign(shopId, warehouseId: warehouseId),
                style: OutlinedButton.styleFrom(
                  foregroundColor: c.primary,
                  side: BorderSide(color: c.primary.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                label: const Text('Gắn vị trí'),
              ),
            ),
        ],
      ),
      body: shopId == null || shopId < 1
          ? Center(
              child: Text(
                'Chọn một cửa hàng để xem sơ đồ kệ.',
                style: TextStyle(color: c.textSecondary, fontSize: 15),
              ),
            )
          : shelves!.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: c.textMuted),
                    const SizedBox(height: 12),
                    Text(
                      'Không tải được sơ đồ.',
                      style: TextStyle(color: c.textSecondary, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      onPressed: () => ref.invalidate(_shelvesProvider(shopId)),
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
              data: (data) {
                final positions = data.positions;

                if (warehouseId == null || currentWarehouse == null) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.warehouse_outlined,
                          size: 56,
                          color: c.textMuted,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Tạo kho trước khi bố trí mặt bằng.',
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final warehousePositions = positions
                    .where((p) => p['warehouseId'] == warehouseId)
                    .toList();

                final racks = <String, List<Map<String, dynamic>>>{};
                for (final p in warehousePositions) {
                  final code = (p['rack'] as String?)?.trim() ?? '';
                  if (code.isNotEmpty) {
                    (racks[code] ??= []).add(p);
                  }
                }

                final query = foldSearchText(_searchController.text);
                final matches = query.isEmpty
                    ? const <Map<String, dynamic>>[]
                    : warehousePositions
                          .where(
                            (p) => ['productName', 'sku', 'rack'].any(
                              (key) => foldSearchText(p[key]).contains(query),
                            ),
                          )
                          .toList();
                final matchingRacks = {
                  for (final row in matches) (row['rack'] as String).trim(),
                };

                return Column(
                  children: [
                    _ShelfLookupBar(
                      warehouses: warehouses,
                      warehouseId: warehouseId,
                      rackCount: racks.length,
                      controller: _searchController,
                      query: query,
                      matches: matches,
                      onWarehouseChanged: (id) => setState(() {
                        _activeWarehouseId = id;
                        _lookup = null;
                      }),
                      onSearchChanged: () => setState(() {}),
                      onOpenPosition: (row) => setState(() {
                        _lookup = (
                          rack: row['rack'] as String,
                          level: row['level'] as int,
                          bin: row['bin'] as int,
                          request: (_lookup?.request ?? 0) + 1,
                        );
                      }),
                    ),
                    const Divider(height: 1),
                    // Canvas & Inspection Panel Area
                    Expanded(
                      child: _RackFloor(
                        key: ValueKey((shopId, warehouseId)),
                        storageKey:
                            'inventory.shelf.scene.$shopId.$warehouseId',
                        warehouseId: warehouseId,
                        warehouseName:
                            currentWarehouse['name'] as String? ?? 'Kho',
                        canEdit: canEdit,
                        racks: racks,
                        searchQuery: query,
                        matchingRacks: matchingRacks,
                        lookup: _lookup,
                        onEditPosition: (position) =>
                            _assign(shopId, position: position),
                        onOpenProduct: shop.hasPermission('products')
                            ? (id) =>
                                  context.push('/products/$id?from=inventory')
                            : null,
                        onAssignRack: (rack, level, bin) => _assign(
                          shopId,
                          warehouseId: warehouseId,
                          rackCode: rack,
                          initialLevel: level,
                          initialBin: bin,
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

class _RackFloor extends StatefulWidget {
  const _RackFloor({
    super.key,
    required this.storageKey,
    required this.warehouseId,
    required this.warehouseName,
    required this.canEdit,
    required this.racks,
    required this.searchQuery,
    required this.matchingRacks,
    this.lookup,
    required this.onAssignRack,
    required this.onEditPosition,
    this.onOpenProduct,
  });

  final String storageKey;
  final int warehouseId;
  final String warehouseName;
  final bool canEdit;
  final Map<String, List<Map<String, dynamic>>> racks;
  final String searchQuery;
  final Set<String> matchingRacks;
  final _ShelfLookup? lookup;
  final void Function(String rack, int? level, int? bin) onAssignRack;
  final ValueChanged<Map<String, dynamic>> onEditPosition;
  final ValueChanged<int>? onOpenProduct;

  @override
  State<_RackFloor> createState() => _RackFloorState();
}

class _RackFloorState extends State<_RackFloor> {
  static const double _cellSize = 44.0;
  static const int _baseColumns = 24;
  static const int _baseRows = 16;
  static const int _maxGridSize = 60;
  static const int _maxSavedRows = 4096;

  final _floorKey = GlobalKey();
  final _viewKey = GlobalKey();
  final _viewport = TransformationController();

  Map<String, _FloorObject> _objects = {};
  _FloorSnapshot? _undo;
  int _extraColumns = 0;
  int _extraRows = 0;
  String? _selection;
  bool _editing = false;
  bool _saving = false;
  bool _loading = true;
  String? _readWarning;
  Object? _damagedSource;
  int _rows = _baseRows;
  int _legacyRows = _baseRows;
  _FixtureKind? _placement;

  Offset? _strokeStart;
  _GridBlock? _preview;
  ({String id, Offset grab})? _moving;
  Timer? _edgePanTimer;
  Offset? _dragPointer;

  _GridBlock _stroke(Offset from, Offset to) {
    final x = (from.dx / _cellSize).floor();
    final y = (from.dy / _cellSize).floor();
    final dx = (to.dx / _cellSize).floor() - x;
    final dy = (to.dy / _cellSize).floor() - y;
    final horizontal = dx.abs() >= dy.abs();
    final endX = x + (horizontal ? dx.clamp(-19, 19) : 0);
    final endY = y + (horizontal ? 0 : dy.clamp(-19, 19));
    return (
      column: math.min(x, endX),
      row: math.min(y, endY),
      columns: (endX - x).abs() + 1,
      rows: (endY - y).abs() + 1,
    );
  }

  bool _available(
    _GridBlock b,
    Map<String, _FloorObject> layout, {
    String? movingId,
  }) =>
      b.column >= 0 &&
      b.row >= 0 &&
      b.column + b.columns <= _columns &&
      b.row + b.rows <= _rows &&
      b.row + b.rows <= _maxSavedRows &&
      !_overlaps(b, movingId ?? '', layout);

  Offset? _floorPoint(Offset global) {
    final box = _floorKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.globalToLocal(global);
  }

  void _panWhileDragging(_FloorObject item, Map<String, _FloorObject> layout) {
    final global = _dragPointer;
    final view = _viewKey.currentContext?.findRenderObject() as RenderBox?;
    if (global == null || view == null || _moving?.id != item.id) return;
    final point = view.globalToLocal(global);
    final size = view.size;
    if (!(Offset.zero & size).contains(point)) return;

    double step(double coordinate, double extent) {
      final edge = math.min(64.0, extent / 4);
      return ((edge - coordinate).clamp(0.0, edge) -
              (coordinate - extent + edge).clamp(0.0, edge)) *
          12 /
          edge;
    }

    final matrix = _viewport.value;
    final scale = matrix.storage[0];
    final x = matrix.storage[12], y = matrix.storage[13];
    double shift(double current, double delta, double scene, double visible) {
      if (delta == 0 || scene <= visible) return current;
      final limit = delta < 0 ? visible - scene : 0.0;
      if (delta < 0 && current <= limit || delta > 0 && current >= limit) {
        return current;
      }
      return delta < 0
          ? math.max(limit, current + delta)
          : math.min(limit, current + delta);
    }

    final nextX = shift(
      x,
      step(point.dx, size.width),
      (_columns * _cellSize + 80) * scale,
      size.width,
    );
    final nextY = shift(
      y,
      step(point.dy, size.height),
      (_rows * _cellSize + 80) * scale,
      size.height,
    );
    if (nextX == x && nextY == y) return;
    final block = _dropBlock(
      DragTargetDetails(
        data: (id: item.id, kind: null),
        offset: global - Offset(nextX - x, nextY - y),
      ),
      layout,
    );
    _viewport.value = Matrix4.copy(matrix)..setTranslationRaw(nextX, nextY, 0);
    if (block != _preview) setState(() => _preview = block);
  }

  _GridBlock? _dropBlock(
    DragTargetDetails<_SceneDrag> details,
    Map<String, _FloorObject> layout,
  ) {
    final point = _floorPoint(details.offset);
    if (point == null) return null;
    final item = layout[details.data.id];
    final kind = details.data.kind;
    if (item == null && kind == null) return null;
    final source = item == null ? null : _blockFor(item);
    final (columns, rows) = source == null
        ? kind!.footprint
        : (source.columns, source.rows);
    final grab = _moving?.id == item?.id && item != null
        ? _moving!.grab
        : Offset(columns * _cellSize / 2, rows * _cellSize / 2);
    final origin = point - grab;
    return (
      column: (origin.dx / _cellSize).round(),
      row: (origin.dy / _cellSize).round(),
      columns: columns,
      rows: rows,
    );
  }

  void _blockedDrop() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Vùng đích phải nằm trong sơ đồ và không chồng vật thể khác.',
        ),
      ),
    );
  }

  Widget _dropPreview(_GridBlock block, Map<String, _FloorObject> layout) {
    final valid = _available(block, layout, movingId: _moving?.id);
    final color = valid ? Colors.teal.shade600 : Colors.red.shade700;
    return Positioned(
      key: const ValueKey('warehouse-drop-preview'),
      left: block.column * _cellSize,
      top: block.row * _cellSize,
      width: block.columns * _cellSize,
      height: block.rows * _cellSize,
      child: IgnorePointer(
        child: Semantics(
          label: valid ? 'Vùng đích hợp lệ' : 'Vùng đích không hợp lệ',
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color.withValues(alpha: .28),
              border: Border.all(color: color, width: 3),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Icon(
                valid ? Icons.check_circle : Icons.block,
                color: color,
                size: 24,
                applyTextScaling: false,
              ),
            ),
          ),
        ),
      ),
    );
  }

  int get _columns =>
      (_baseColumns + _extraColumns).clamp(_baseColumns, _maxGridSize);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _RackFloor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final lookup = widget.lookup;
    if (lookup == null || lookup == oldWidget.lookup) return;
    _selection = 'stock:${lookup.rack}';
    _inspectionLevel = lookup.level;
    _inspectionBin = lookup.bin;
    _editing = false;
    _placement = null;
    _preview = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.lookup != lookup) return;
      _revealRack(lookup.rack);
      if (!_wideLayout) {
        _showMobileInspectionSheet(lookup.rack, _appColors(context));
      }
    });
  }

  bool _wideLayout = false;

  void _revealRack(String code) {
    final item = _effectiveLayout()['stock:$code'];
    if (item == null || _viewSize.isEmpty) return;
    final block = _blockFor(item);
    final center = Offset(
      40 + (block.column + block.columns / 2) * _cellSize,
      40 + (block.row + block.rows / 2) * _cellSize,
    );
    final scale = math.max(1.0, _viewport.value.getMaxScaleOnAxis());
    _centerOn(center, scale);
  }

  @override
  void dispose() {
    _edgePanTimer?.cancel();
    _viewport.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final raw = prefs.get(widget.storageKey);
      final saved = _readFloor(raw);
      setState(() {
        _objects = saved.objects;
        _extraColumns = saved.columns;
        _extraRows = saved.rows;
        _readWarning = saved.warning;
        _damagedSource = saved.warning == null ? null : raw;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _readWarning = 'Chưa thể đọc bố trí đã lưu trên thiết bị.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save(
    Map<String, _FloorObject> next,
    String? selection, {
    bool undo = false,
    int? extraColumns,
    int? extraRows,
  }) async {
    if (_saving || _loading || _readWarning != null || !widget.canEdit) return;
    if (next.values.any((item) {
      final block = item.block;
      return block != null && block.row + block.rows > _maxSavedRows;
    })) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vị trí vượt giới hạn lưu của mặt bằng.')),
      );
      return;
    }
    final previous = (
      objects: Map<String, _FloorObject>.from(_objects),
      columns: _extraColumns,
      rows: _extraRows,
    );
    final oldSelection = _selection;
    // Old snapshots used relative positions. Anchor those objects before the
    // edit changes the grid size to preserve the layout currently on screen.
    next = {
      for (final item in next.values)
        item.id: item.block == null
            ? item.copyWith(block: _blockFor(item))
            : item,
    };
    setState(() {
      _objects = next;
      _extraColumns = extraColumns ?? _extraColumns;
      _extraRows = extraRows ?? _extraRows;
      _selection = selection;
      _saving = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = _encodeFloor(next, _extraColumns, _extraRows);

      if (!await prefs.setString(widget.storageKey, jsonString)) {
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

  Future<void> _recoverFloor() async {
    final source = _damagedSource;
    if (source == null || !widget.canEdit || _saving) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Khôi phục mặt bằng?'),
        content: const Text(
          'Ứng dụng sẽ lưu một bản sao dữ liệu gốc trên thiết bị rồi dùng '
          'các vật thể đọc được làm mặt bằng để tiếp tục chỉnh sửa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Khôi phục'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true || !widget.canEdit || _saving) return;
    setState(() => _saving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      if (!mounted || !widget.canEdit) return;
      final key = widget.storageKey;
      if (jsonEncode(prefs.get(key)) != jsonEncode(source)) {
        await _load();
        return;
      }
      final backup = '$key.backup.${DateTime.now().microsecondsSinceEpoch}';
      final original = source is String ? source : jsonEncode(source);
      if (!await prefs.setString(backup, original)) throw StateError('backup');
      if (!mounted || !widget.canEdit) return;
      if (!await prefs.setString(
        key,
        _encodeFloor(_objects, _extraColumns, _extraRows),
      )) {
        throw StateError('restore');
      }
      if (mounted) {
        setState(() {
          _readWarning = null;
          _damagedSource = null;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chưa khôi phục được mặt bằng. Vui lòng thử lại.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
    final (w, h) = item.kind.footprint;
    final cols = (item.rotation.isEven ? w : h);
    final rows = (item.rotation.isEven ? h : w);
    return _snap(
      (item.x * _columns - cols / 2).round(),
      (item.y * _legacyRows - rows / 2).round().clamp(0, _legacyRows - rows),
      cols,
      rows,
    );
  }

  bool _overlaps(
    _GridBlock block,
    String id,
    Map<String, _FloorObject> layout,
  ) {
    return layout.values.any((item) {
      if (item.id == id) return false;
      final other = _blockFor(item);
      return block.column < other.column + other.columns &&
          block.column + block.columns > other.column &&
          block.row < other.row + other.rows &&
          block.row + block.rows > other.row;
    });
  }

  void _updateBlock(
    _FloorObject item,
    _GridBlock block,
    Map<String, _FloorObject> layout, {
    int? rotation,
    double? width,
    double? height,
  }) {
    if (_overlaps(block, item.id, layout)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vị trí này đã có vật khác.')),
      );
      return;
    }
    _save({
      ..._objects,
      item.id: item.copyWith(
        block: block,
        rotation: rotation,
        width: width,
        height: height,
      ),
    }, item.id);
  }

  void _place(
    _SceneDrag drag,
    _GridBlock block,
    Map<String, _FloorObject> layout,
  ) {
    final kind = drag.kind;
    final old = layout[drag.id];
    if (old != null && _blockFor(old) == block) return;
    int rackNumber = 1;
    String rackId() => 'stock:K-${rackNumber.toString().padLeft(2, '0')}';
    if (old == null && kind?.holdsProducts == true) {
      while (layout.containsKey(rackId())) {
        rackNumber++;
      }
    }

    final item =
        old ??
        _FloorObject(
          id: kind!.holdsProducts
              ? rackId()
              : DateTime.now().microsecondsSinceEpoch.toString(),
          manualRack: kind.holdsProducts,
          kind: kind,
          x: block.column / _columns,
          y: block.row / _rows,
        );
    _updateBlock(item, block, layout);
  }

  void _zoomBy(double factor) {
    if (_viewSize.isEmpty) return;
    final center = _viewport.toScene(_viewSize.center(Offset.zero));
    final scale = (_viewport.value.getMaxScaleOnAxis() * factor).clamp(
      _minZoom,
      2.5,
    );
    _centerOn(center, scale);
  }

  bool _framed = false;
  Size _viewSize = Size.zero;
  double get _fitZoom => math
      .min(
        _viewSize.width / (_columns * _cellSize + 80),
        _viewSize.height / (_rows * _cellSize + 80),
      )
      .clamp(0.000001, 2.5);
  double get _minZoom => math.min(0.5, _fitZoom);

  void _centerOn(Offset sceneCenter, double scale) {
    _viewport.value = Matrix4.identity()
      ..translateByDouble(
        _viewSize.width / 2 - sceneCenter.dx * scale,
        _viewSize.height / 2 - sceneCenter.dy * scale,
        0,
        1,
      )
      ..scaleByDouble(scale, scale, scale, 1);
  }

  void _resetZoom() {
    if (_viewSize.isEmpty) return;
    final w = _columns * _cellSize + 80, h = _rows * _cellSize + 80;
    _centerOn(Offset(w / 2, h / 2), _fitZoom);
  }

  Map<String, _FloorObject> _effectiveLayout() {
    final layout = Map<String, _FloorObject>.from(_objects);
    layout.removeWhere(
      (key, value) =>
          value.stockRack &&
          !value.manualRack &&
          !widget.racks.containsKey(key.substring(6)),
    );

    final savedEnd = _objects.values.fold(0, (end, item) {
      final b = item.block;
      return b == null ? end : math.max(end, b.row + b.rows);
    });
    _legacyRows = math
        .max(_baseRows + _extraRows, savedEnd + 1)
        .clamp(_baseRows, _maxGridSize);
    _rows = math.max(_legacyRows, savedEnd);

    // Fixed slots leave a one-cell aisle. Index occupied cells once so each
    // candidate is visited only once, including slots past the original floor.
    final occupied = <int>{};
    final columns = _columns;
    for (final item in layout.values) {
      final b = _blockFor(item);
      for (var y = b.row; y < b.row + b.rows; y++) {
        for (var x = b.column; x < b.column + b.columns; x++) {
          occupied.add(y * columns + x);
        }
      }
    }
    final slotsPerRow = columns ~/ 4;
    var slot = 0;
    for (final name in widget.racks.keys) {
      final id = 'stock:$name';
      if (layout.containsKey(id)) continue;
      int x, y;
      bool blocked;
      do {
        x = 1 + slot % slotsPerRow * 4;
        y = 1 + slot ~/ slotsPerRow * 3;
        slot++;
        blocked = false;
        for (var dy = 0; dy < 2 && !blocked; dy++) {
          for (var dx = 0; dx < 3; dx++) {
            if (occupied.contains((y + dy) * columns + x + dx)) {
              blocked = true;
              break;
            }
          }
        }
      } while (blocked);
      _rows = math.max(_rows, y + 2);
      layout[id] = _FloorObject(
        id: id,
        kind: _FixtureKind.rack,
        x: 0,
        y: 0,
        block: (column: x, row: y, columns: 3, rows: 2),
      );
    }
    return layout;
  }

  @override
  Widget build(BuildContext context) {
    final c = _appColors(context);
    final layout = _effectiveLayout();
    final selectedItem = _selection != null ? layout[_selection] : null;

    final width = _columns * _cellSize;
    final height = _rows * _cellSize;

    final floor = LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;
        _wideLayout = isDesktop;

        final inspected =
            isDesktop && !_editing && selectedItem?.stockRack == true;
        final directory =
            constraints.maxWidth >= 1100 &&
            !_editing &&
            !inspected &&
            widget.racks.isNotEmpty;
        _viewSize = Size(
          constraints.maxWidth -
              (inspected
                  ? 360
                  : directory
                  ? 280
                  : 0),
          constraints.maxHeight,
        );
        if (!_framed && !_loading && !_viewSize.isEmpty) {
          _framed = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _resetZoom();
          });
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Center Canvas Area
            Expanded(
              child: Stack(
                children: [
                  // Main Floor Interactive Viewer
                  Positioned.fill(
                    child: InteractiveViewer(
                      key: _viewKey,
                      transformationController: _viewport,
                      panEnabled: _placement == null && _moving == null,
                      scaleEnabled: _placement == null && _moving == null,
                      minScale: _minZoom,
                      maxScale: 2.5,
                      boundaryMargin: const EdgeInsets.all(250),
                      constrained: false,
                      child: Container(
                        width: width,
                        height: height,
                        margin: const EdgeInsets.all(40),
                        child: DragTarget<_SceneDrag>(
                          key: _floorKey,
                          onWillAcceptWithDetails: (_) =>
                              _editing && widget.canEdit && !_saving,
                          onMove: (details) {
                            if (details.data.id == _moving?.id) {
                              _dragPointer = details.offset;
                            }
                            final block = _dropBlock(details, layout);
                            if (block != _preview) {
                              setState(() => _preview = block);
                            }
                          },
                          onLeave: (_) {
                            if (_preview != null) {
                              setState(() => _preview = null);
                            }
                          },
                          onAcceptWithDetails: (details) {
                            final block = _dropBlock(details, layout);
                            setState(() => _preview = null);
                            if (block == null || !_editing || _saving) return;
                            if (!_available(
                              block,
                              layout,
                              movingId: details.data.id,
                            )) {
                              _blockedDrop();
                              return;
                            }
                            setState(() => _placement = null);
                            _place(details.data, block, layout);
                          },
                          builder: (context, candidateData, rejectedData) {
                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTapUp: _placement == null
                                  ? (_) {
                                      setState(() => _selection = null);
                                    }
                                  : null,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  _buildFloorSurface(layout, c, isDesktop),
                                  if (_placement != null && widget.canEdit)
                                    Listener(
                                      behavior: HitTestBehavior.opaque,
                                      onPointerDown: (e) {
                                        _strokeStart = e.localPosition;
                                        setState(
                                          () => _preview = _stroke(
                                            e.localPosition,
                                            e.localPosition,
                                          ),
                                        );
                                      },
                                      onPointerMove: (e) {
                                        if (_strokeStart != null) {
                                          setState(
                                            () => _preview = _stroke(
                                              _strokeStart!,
                                              e.localPosition,
                                            ),
                                          );
                                        }
                                      },
                                      onPointerCancel: (_) => setState(() {
                                        _strokeStart = null;
                                        _preview = null;
                                      }),
                                      onPointerUp: (e) {
                                        final start = _strokeStart;
                                        if (start == null) return;
                                        final block = _stroke(
                                          start,
                                          e.localPosition,
                                        );
                                        if (_available(block, layout)) {
                                          _place(
                                            (id: null, kind: _placement),
                                            block,
                                            layout,
                                          );
                                          _placement = null;
                                        } else {
                                          _blockedDrop();
                                        }
                                        setState(() {
                                          _strokeStart = null;
                                          _preview = null;
                                        });
                                      },
                                    ),
                                  if (_preview case final b?)
                                    _dropPreview(b, layout),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                  // Empty warehouse overlay
                  if (layout.isEmpty)
                    Positioned.fill(
                      child: IgnorePointer(
                        ignoring: true,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              color: c.card.withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: c.divider),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: c.primary,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  widget.canEdit
                                      ? 'Chọn Bố trí kho để thêm kệ và các khu vực.'
                                      : 'Kho chưa có mặt bằng.',
                                  style: TextStyle(
                                    color: c.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Floating Navigation & View Controls (Bottom Right)
                  Positioned(
                    right: 16,
                    bottom: _editing ? 100 : 16,
                    child: Container(
                      decoration: BoxDecoration(
                        color: c.card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: c.divider),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Phóng to',
                            icon: const Icon(Icons.add, size: 20),
                            onPressed: () => _zoomBy(1.25),
                          ),
                          const Divider(height: 1, indent: 4, endIndent: 4),
                          IconButton(
                            tooltip: 'Thu nhỏ',
                            icon: const Icon(Icons.remove, size: 20),
                            onPressed: () => _zoomBy(0.8),
                          ),
                          const Divider(height: 1, indent: 4, endIndent: 4),
                          IconButton(
                            tooltip: 'Căn giữa',
                            icon: const Icon(
                              Icons.center_focus_strong_outlined,
                              size: 20,
                            ),
                            onPressed: _resetZoom,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Edit Mode Toggle Button (Top Right)
                  if (widget.canEdit && _readWarning == null && !_loading)
                    Positioned(
                      top: 16,
                      right: 16,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: _editing
                              ? Colors.teal.shade700
                              : c.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 2,
                        ),
                        onPressed: () {
                          setState(() {
                            _editing = !_editing;
                            _placement = null;
                            if (!_editing) _selection = null;
                          });
                        },
                        icon: Icon(
                          _editing
                              ? Icons.check
                              : Icons.dashboard_customize_outlined,
                          size: 18,
                        ),
                        label: Text(_editing ? 'Xong' : 'Bố trí kho'),
                      ),
                    ),

                  // Floating Placement Notice
                  if (_placement != null)
                    Positioned(
                      top: isDesktop ? 16 : 64,
                      left: 16,
                      right: isDesktop ? null : 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: c.card,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: c.primary, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_placement!.icon, size: 18, color: c.primary),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Đang đặt: ${_placement!.label} · Chạm hoặc kéo theo ô',
                                style: TextStyle(
                                  color: c.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            TextButton(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                minimumSize: Size.zero,
                              ),
                              onPressed: () =>
                                  setState(() => _placement = null),
                              child: const Text('Hủy đặt'),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Selected fixture tools stay scrollable on narrow screens.
                  if (_editing &&
                      _placement == null &&
                      _moving == null &&
                      selectedItem != null)
                    Positioned(
                      bottom: 88,
                      left: 16,
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: math.max(1, _viewSize.width - 32),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: c.card,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: c.divider),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                selectedItem.stockRack
                                    ? selectedItem.rackTitle
                                    : selectedItem.kind.label,
                                style: TextStyle(
                                  color: c.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 12),
                              TextButton.icon(
                                label: const Text('Xoay'),
                                icon: const Icon(
                                  Icons.rotate_90_degrees_ccw_outlined,
                                  size: 18,
                                ),
                                onPressed: () {
                                  final nextRotation =
                                      (selectedItem.rotation + 1) % 4;
                                  final b = _blockFor(selectedItem);
                                  final newCols = b.rows;
                                  final newRows = b.columns;
                                  final nextBlock = _snap(
                                    b.column,
                                    b.row,
                                    newCols,
                                    newRows,
                                  );
                                  _updateBlock(
                                    selectedItem,
                                    nextBlock,
                                    layout,
                                    rotation: nextRotation,
                                  );
                                },
                              ),
                              TextButton.icon(
                                onPressed: () => _editRack(selectedItem),
                                icon: const Icon(Icons.edit_outlined, size: 16),
                                label: const Text('Kích thước và thông tin'),
                              ),
                              if (selectedItem.stockRack) ...[
                                TextButton.icon(
                                  onPressed: () => _showMobileInspectionSheet(
                                    selectedItem.rackCode,
                                    c,
                                  ),
                                  icon: const Icon(
                                    Icons.list_alt_outlined,
                                    size: 16,
                                  ),
                                  label: const Text('Chi tiết kệ'),
                                ),
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                  ),
                                  onPressed: () => widget.onAssignRack(
                                    selectedItem.rackCode,
                                    null,
                                    null,
                                  ),
                                  icon: const Icon(
                                    Icons.add_location_alt_outlined,
                                    size: 16,
                                  ),
                                  label: const Text('Gắn sản phẩm'),
                                ),
                              ],
                              if (!widget.racks.containsKey(
                                selectedItem.rackCode,
                              ))
                                IconButton(
                                  tooltip: 'Bỏ khối khỏi mặt bằng',
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: Colors.red,
                                  ),
                                  onPressed: () {
                                    final next = Map<String, _FloorObject>.from(
                                      _objects,
                                    )..remove(selectedItem.id);
                                    _save(next, null);
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Edit Mode Bottom Fixtures Bar
                  if (_editing)
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: c.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: c.divider),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              if (_undo != null) ...[
                                IconButton(
                                  tooltip: 'Hoàn tác',
                                  icon: const Icon(Icons.undo, size: 20),
                                  onPressed: () => _save(
                                    _undo!.objects,
                                    null,
                                    undo: true,
                                    extraColumns: _undo!.columns,
                                    extraRows: _undo!.rows,
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              TextButton.icon(
                                label: const Text('+5 cột'),
                                icon: const Icon(Icons.view_column_outlined),
                                onPressed: _columns >= _maxGridSize
                                    ? null
                                    : () => _save(
                                        _objects,
                                        _selection,
                                        extraColumns: math.min(
                                          _extraColumns + 5,
                                          _maxGridSize - _baseColumns,
                                        ),
                                      ),
                              ),
                              TextButton.icon(
                                label: const Text('+5 hàng'),
                                icon: const Icon(Icons.table_rows_outlined),
                                onPressed: _rows >= _maxGridSize
                                    ? null
                                    : () => _save(
                                        _objects,
                                        _selection,
                                        extraRows:
                                            math.min(_rows + 5, _maxGridSize) -
                                            _baseRows,
                                      ),
                              ),
                              for (final kind in _FixtureKind.values)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: _buildFixtureToolButton(kind, c),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            if (directory)
              Container(
                width: 280,
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: c.divider)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
                      child: Text(
                        'Tra cứu theo kệ',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        children: [
                          for (final entry in widget.racks.entries)
                            if (widget.searchQuery.isEmpty ||
                                widget.matchingRacks.contains(entry.key))
                              ListTile(
                                leading: Icon(Icons.shelves, color: c.primary),
                                title: Text(
                                  layout['stock:${entry.key}']
                                              ?.name
                                              .isNotEmpty ==
                                          true
                                      ? layout['stock:${entry.key}']!.rackTitle
                                      : entry.key,
                                ),
                                subtitle: Text(
                                  entry.value.first['productName']
                                          ?.toString() ??
                                      '',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right,
                                  size: 18,
                                ),
                                onTap: () {
                                  setState(() {
                                    _selection = 'stock:${entry.key}';
                                    _inspectionLevel = null;
                                    _inspectionBin = null;
                                  });
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    if (mounted) _revealRack(entry.key);
                                  });
                                },
                              ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            // Desktop Docked Inspection Panel (Only when not in edit mode)
            if (isDesktop &&
                !_editing &&
                _selection != null &&
                selectedItem != null &&
                selectedItem.stockRack)
              Container(
                width: 360,
                decoration: BoxDecoration(
                  color: c.surface,
                  border: Border(left: BorderSide(color: c.divider)),
                ),
                child: _buildInspectionContent(selectedItem.rackCode, c),
              ),
          ],
        );
      },
    );
    final warning = _readWarning;
    if (warning == null) return floor;
    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_outlined, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('$warning Bố trí đang ở chế độ chỉ xem.')),
                if (_damagedSource == null)
                  TextButton(onPressed: _load, child: const Text('Thử lại'))
                else if (widget.canEdit)
                  TextButton(
                    onPressed: _saving ? null : _recoverFloor,
                    child: const Text('Khôi phục'),
                  ),
              ],
            ),
          ),
        ),
        Expanded(child: floor),
      ],
    );
  }

  Future<void> _editRack(_FloorObject rack) async {
    final form = GlobalKey<FormState>();
    var name = rack.name;
    var note = rack.note;
    var block = _blockFor(rack);
    if (block.row + block.rows > _maxSavedRows) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đưa kệ lên gần đầu mặt bằng để chỉnh sửa.'),
        ),
      );
      return;
    }
    final layout = _effectiveLayout();
    String? dimensionError(String? value, bool horizontal) {
      final size = int.tryParse(value?.trim() ?? '');
      final max = horizontal
          ? _columns - block.column
          : math.min(_rows, _maxSavedRows) - block.row;
      if (size == null || size < 1 || size > max) return 'Nhập từ 1 đến $max ô';
      return null;
    }

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          rack.stockRack
              ? 'Thông tin và kích thước'
              : 'Kích thước ${rack.kind.label.toLowerCase()}',
        ),
        scrollable: true,
        content: Form(
          key: form,
          child: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (rack.stockRack)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.shelves),
                    title: Text(rack.rackTitle),
                    trailing: Text(rack.rackCode),
                    subtitle: const Text('Mã kệ dùng để gắn vị trí hàng'),
                  ),
                Row(
                  children: [
                    for (final horizontal in [true, false]) ...[
                      if (!horizontal) const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          initialValue:
                              '${horizontal ? block.columns : block.rows}',
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: horizontal ? 'Chiều rộng' : 'Chiều sâu',
                            suffixText: 'ô',
                          ),
                          validator: (value) =>
                              dimensionError(value, horizontal),
                          onSaved: (value) {
                            final size = int.parse(value!.trim());
                            block = (
                              column: block.column,
                              row: block.row,
                              columns: horizontal ? size : block.columns,
                              rows: horizontal ? block.rows : size,
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
                if (rack.stockRack) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: name,
                    maxLength: 48,
                    decoration: const InputDecoration(
                      labelText: 'Tên hiển thị',
                    ),
                    onSaved: (value) => name = value?.trim() ?? '',
                  ),
                  TextFormField(
                    initialValue: note,
                    maxLength: 160,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Ghi chú kệ'),
                    onSaved: (value) => note = value?.trim() ?? '',
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              if (!form.currentState!.validate()) return;
              form.currentState!.save();
              Navigator.pop(dialogContext, true);
            },
            child: const Text('Lưu thông tin kệ'),
          ),
        ],
      ),
    );
    if (!mounted || save != true) return;
    if (_overlaps(block, rack.id, layout)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kích thước mới chồng lên khối khác.')),
      );
      return;
    }
    await _save({
      ..._objects,
      rack.id: rack.copyWith(name: name, note: note, block: block),
    }, rack.id);
  }

  Widget _buildFixtureToolButton(_FixtureKind kind, AppThemeColors c) {
    final active = _placement == kind;
    void onTap() {
      setState(() {
        _placement = active ? null : kind;
        _selection = null;
      });
    }

    final buttonWidget = OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: active ? c.primary : c.textPrimary,
        backgroundColor: active ? c.primarySubtle : c.card,
        side: BorderSide(
          color: active ? c.primary : c.divider,
          width: active ? 1.5 : 1.0,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: onTap,
      icon: _fixtureThumbnail(kind),
      label: Text(
        kind.label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );

    final chipWrapped = ActionChip(
      padding: EdgeInsets.zero,
      labelPadding: EdgeInsets.zero,
      backgroundColor: Colors.transparent,
      elevation: 0,
      pressElevation: 0,
      side: BorderSide.none,
      onPressed: onTap,
      label: buttonWidget,
    );

    return Draggable<_SceneDrag>(
      data: (id: null, kind: kind),
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.85,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: c.primary, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _fixtureThumbnail(kind),
                const SizedBox(width: 8),
                Text(
                  kind.label,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      child: chipWrapped,
    );
  }

  Widget _fixtureThumbnail(_FixtureKind kind) {
    return Image.asset(
      kind.assetPath(),
      width: 30,
      height: 22,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
    );
  }

  Widget _buildFloorSurface(
    Map<String, _FloorObject> layout,
    AppThemeColors c,
    bool isDesktop,
  ) {
    return CustomPaint(
      painter: _WarehouseFloorPainter(
        columns: _columns,
        rows: _rows,
        cellSize: _cellSize,
        themeColors: c,
        showCoordinates: _editing,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final item in layout.values)
            _buildTile(item, layout, c, isDesktop),
        ],
      ),
    );
  }

  Widget _buildTile(
    _FloorObject item,
    Map<String, _FloorObject> layout,
    AppThemeColors c,
    bool isDesktop,
  ) {
    final block = _blockFor(item);
    final isSelected = _selection == item.id;
    final isRack = item.stockRack;
    final rackCode = item.rackCode;
    final positions = isRack
        ? (widget.racks[rackCode] ?? [])
        : const <Map<String, dynamic>>[];
    final isSearchMatch = isRack && widget.matchingRacks.contains(rackCode);

    final asset = item.kind.assetPath(occupied: positions.isNotEmpty);
    final vertical = block.rows == block.columns
        ? item.rotation.isOdd
        : block.rows > block.columns;
    final highlighted = isSelected || isSearchMatch;
    final label = isRack ? item.rackTitle : item.kind.label;
    final content = Tooltip(
      message: _editing
          ? '$label · Kéo để di chuyển'
          : isRack
          ? '$label · ${positions.length} mặt hàng · Mở chi tiết'
          : label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: highlighted ? Border.all(color: c.primary, width: 2) : null,
          color: highlighted ? c.primarySubtle : null,
        ),
        child: LayoutBuilder(
          builder: (context, size) {
            final compact = size.maxHeight < 50 || size.maxWidth < 68;
            final inset = highlighted ? 4.0 : 2.0;
            return Stack(
              fit: StackFit.expand,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    inset,
                    inset,
                    inset,
                    compact ? inset : 18,
                  ),
                  child: RotatedBox(
                    quarterTurns:
                        (vertical ? 1 : 0) + (item.rotation >= 2 ? 2 : 0),
                    child: Image.asset(
                      asset,
                      fit:
                          item.kind == _FixtureKind.wall ||
                              item.kind == _FixtureKind.aisle
                          ? BoxFit.fill
                          : BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                      excludeFromSemantics: true,
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    constraints: BoxConstraints(maxWidth: size.maxWidth - 4),
                    margin: const EdgeInsets.only(bottom: 2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: highlighted ? c.primary : c.card,
                    ),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 9 : 11,
                        fontWeight: FontWeight.w700,
                        color: highlighted
                            ? Theme.of(context).colorScheme.onPrimary
                            : c.textPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );

    Widget interactive = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() {
          _selection = item.id;
          _inspectionLevel = null;
          _inspectionBin = null;
        });
        if (isRack) {
          if (!isDesktop && !_editing) {
            _showMobileInspectionSheet(rackCode, c);
          }
        }
      },
      child: content,
    );

    if (_editing) {
      interactive = Draggable<_SceneDrag>(
        data: (id: item.id, kind: null),
        maxSimultaneousDrags: _saving || _loading || _moving != null ? 0 : 1,
        dragAnchorStrategy: (_, _, global) {
          final origin = Offset(
            block.column * _cellSize,
            block.row * _cellSize,
          );
          _moving = (
            id: item.id,
            grab: (_floorPoint(global) ?? origin) - origin,
          );
          return Offset.zero;
        },
        feedback: const SizedBox.shrink(),
        onDragStarted: () {
          setState(() {
            _selection = item.id;
            _inspectionLevel = null;
            _inspectionBin = null;
          });
          _edgePanTimer = Timer.periodic(
            const Duration(milliseconds: 16),
            (_) => _panWhileDragging(item, layout),
          );
        },
        onDragUpdate: (details) => _dragPointer = details.globalPosition,
        onDragEnd: (_) {
          _edgePanTimer?.cancel();
          _dragPointer = null;
          setState(() {
            _moving = null;
            _preview = null;
          });
        },
        childWhenDragging: Opacity(opacity: 0.25, child: content),
        child: MouseRegion(cursor: SystemMouseCursors.grab, child: interactive),
      );
    }

    return Positioned(
      key: ValueKey(item.id),
      left: block.column * _cellSize,
      top: block.row * _cellSize,
      width: block.columns * _cellSize,
      height: block.rows * _cellSize,
      child: Opacity(
        opacity: widget.searchQuery.isNotEmpty && !isSearchMatch ? .28 : 1,
        child: interactive,
      ),
    );
  }

  void _showMobileInspectionSheet(String rackCode, AppThemeColors c) {
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: .82,
        child: StatefulBuilder(
          builder: (_, refresh) => _buildInspectionContent(
            rackCode,
            c,
            refresh: refresh,
            close: () => Navigator.pop(sheetContext),
          ),
        ),
      ),
    );
  }

  int? _inspectionLevel;
  int? _inspectionBin;
  Widget _buildInspectionContent(
    String rackCode,
    AppThemeColors c, {
    StateSetter? refresh,
    VoidCallback? close,
  }) {
    final positions = widget.racks[rackCode] ?? [];
    final rack = _effectiveLayout()['stock:$rackCode'];

    final levels = positions.map((row) => row['level'] as int).toSet().toList()
      ..sort();
    final level = levels.contains(_inspectionLevel)
        ? _inspectionLevel
        : levels.firstOrNull;
    void assign() {
      close?.call();
      widget.onAssignRack(rackCode, level, _inspectionBin);
    }

    final onLevel = positions.where((row) => row['level'] == level).toList();
    final lastBin = onLevel.fold<int>(
      4,
      (max, row) => math.max(max, row['bin'] as int),
    );
    final visible =
        positions
            .where(
              (row) =>
                  (level == null || row['level'] == level) &&
                  (_inspectionBin == null || row['bin'] == _inspectionBin),
            )
            .toList()
          ..sort((a, b) {
            final byLevel = (a['level'] as int).compareTo(b['level'] as int);
            return byLevel != 0
                ? byLevel
                : (a['bin'] as int).compareTo(b['bin'] as int);
          });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rack?.rackTitle ?? 'Kệ $rackCode',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: c.textPrimary,
                      ),
                    ),
                    Text(
                      rack?.rackTitle == 'Kệ $rackCode'
                          ? warehouseDisplayName(widget.warehouseName)
                          : '$rackCode · ${warehouseDisplayName(widget.warehouseName)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              if (widget.canEdit && _readWarning == null && rack != null)
                IconButton(
                  tooltip: 'Sửa thông tin kệ',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () {
                    close?.call();
                    _editRack(rack);
                  },
                ),
              IconButton(
                tooltip: 'Đóng chi tiết kệ',
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() => _selection = null);
                  close?.call();
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        if (rack != null && rack.note.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              rack.note,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            '${positions.length} mặt hàng · ${levels.length} tầng có hàng',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: c.textSecondary,
            ),
          ),
        ),

        if (levels.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final value in levels)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text('Tầng $value'),
                        selected: level == value,
                        onSelected: (_) => (refresh ?? setState)(() {
                          _inspectionLevel = value;
                          _inspectionBin = null;
                        }),
                      ),
                    ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        if (level != null)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: c.cardAlt,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vị trí trên tầng $level',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var bin = 1; bin <= lastBin; bin++)
                        _buildBinPreview(
                          c,
                          bin,
                          onLevel.where((row) => row['bin'] == bin).toList(),
                          () => (refresh ?? setState)(() {
                            _inspectionBin = _inspectionBin == bin ? null : bin;
                          }),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        // Products List
        Expanded(
          child: visible.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inbox_outlined, size: 40, color: c.textMuted),
                      const SizedBox(height: 8),
                      Text(
                        positions.isEmpty
                            ? 'Vị trí này chưa có hàng.'
                            : 'Ô này chưa có hàng.',
                        style: TextStyle(color: c.textMuted, fontSize: 14),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  key: ValueKey((rackCode, level, _inspectionBin)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: visible.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = visible[index];
                    final id = (item['productId'] as num?)?.toInt();
                    final openProduct = widget.onOpenProduct;
                    return Material(
                      color: c.card,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: c.divider),
                      ),
                      child: ListTile(
                        leading: _productImage(item, 44),
                        title: Text(
                          item['productName'] as String? ?? 'Sản phẩm',
                        ),
                        subtitle: Text(
                          "${item['sku'] ?? '—'} · Tầng ${item['level']} · Ô ${item['bin']}",
                        ),
                        onTap: () {
                          showDialog<void>(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: Text(
                                item['productName'] as String? ?? 'Sản phẩm',
                              ),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _productImage(item, 92),
                                  const SizedBox(height: 12),
                                  Text(
                                    "Mã sản phẩm: ${item['sku'] ?? '—'}\n"
                                    "Kho: ${warehouseDisplayName(widget.warehouseName)}\n"
                                    "Vị trí: Kệ $rackCode · Tầng ${item['level']} · Ô ${item['bin']}",
                                  ),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogContext),
                                  child: const Text('Đóng'),
                                ),
                                if (openProduct != null && id != null)
                                  FilledButton(
                                    onPressed: () {
                                      Navigator.pop(dialogContext);
                                      close?.call();
                                      openProduct(id);
                                    },
                                    child: const Text('Mở hồ sơ sản phẩm'),
                                  ),
                              ],
                            ),
                          );
                        },
                        trailing: widget.canEdit
                            ? IconButton(
                                tooltip: 'Sửa vị trí sản phẩm',
                                icon: const Icon(
                                  Icons.edit_location_alt_outlined,
                                ),
                                onPressed: () {
                                  close?.call();
                                  widget.onEditPosition(item);
                                },
                              )
                            : const Icon(Icons.chevron_right),
                      ),
                    );
                  },
                ),
        ),

        // Bottom Action Button
        if (widget.canEdit)
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: c.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: assign,
              icon: const Icon(Icons.add, size: 18),
              label: Text(
                _inspectionBin == null
                    ? 'Gắn sản phẩm'
                    : 'Gắn sản phẩm vào ô $_inspectionBin',
              ),
            ),
          ),
      ],
    );
  }

  Widget _productImage(
    Map<String, dynamic> item,
    double size,
  ) => ProductThumbnail(
    // Recreate the web image view when a tier or bin displays a different item.
    key: ValueKey((item['productId'] as int?, item['imageUrl'] as String?)),
    imageUrl: item['imageUrl'] as String?,
    name: item['productName'] as String?,
    size: size,
  );

  Widget _buildBinPreview(
    AppThemeColors colors,
    int bin,
    List<Map<String, dynamic>> items,
    VoidCallback onTap,
  ) {
    final selected = _inspectionBin == bin;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: selected ? colors.primarySubtle : colors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: selected ? colors.primary : colors.divider),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 72,
            height: 94,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Ô $bin',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (items.isNotEmpty)
                  _productImage(items.first, 40)
                else
                  Icon(Icons.inbox_outlined, color: colors.textMuted, size: 26),
                Text(
                  items.isEmpty ? 'Trống' : '${items.length} mặt hàng',
                  style: TextStyle(color: colors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WarehouseFloorPainter extends CustomPainter {
  const _WarehouseFloorPainter({
    required this.columns,
    required this.rows,
    required this.cellSize,
    required this.themeColors,
    required this.showCoordinates,
  });

  final int columns;
  final int rows;
  final double cellSize;
  final AppThemeColors themeColors;
  final bool showCoordinates;

  @override
  void paint(Canvas canvas, Size size) {
    final floorRect = Offset.zero & size;

    // Floor concrete/surface background
    final floorPaint = Paint()
      ..color = Color.alphaBlend(const Color(0x105c7766), themeColors.surface);
    canvas.drawRRect(
      RRect.fromRectAndRadius(floorRect, const Radius.circular(12)),
      floorPaint,
    );

    final edge = Paint()
      ..color = Color.alphaBlend(const Color(0x30426468), themeColors.surface);
    canvas.drawRRect(
      RRect.fromRectAndRadius(floorRect.deflate(3), const Radius.circular(9)),
      edge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6,
    );
    // Outer warehouse perimeter wall (Technical double border)
    final wallPaint = Paint()
      ..color = themeColors.divider
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawRRect(
      RRect.fromRectAndRadius(floorRect, const Radius.circular(12)),
      wallPaint,
    );

    // Subtle CAD Blueprint Grid Lines
    final gridPaint = Paint()
      ..color = themeColors.divider.withValues(alpha: 0.35)
      ..strokeWidth = 0.8;

    for (var col = 1; col < columns; col++) {
      final x = col * cellSize;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var row = 1; row < rows; row++) {
      final y = row * cellSize;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (!showCoordinates) return;

    // Grid coordinates guides (1, 2, 3...)
    final textStyle = TextStyle(
      color: themeColors.textMuted.withValues(alpha: 0.5),
      fontSize: 9,
      fontWeight: FontWeight.w600,
    );

    for (var col = 0; col < columns; col += 2) {
      final textPainter = TextPainter(
        text: TextSpan(text: '${col + 1}', style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(col * cellSize + 4, 3));
    }
  }

  @override
  bool shouldRepaint(covariant _WarehouseFloorPainter oldDelegate) {
    return oldDelegate.columns != columns ||
        oldDelegate.rows != rows ||
        oldDelegate.cellSize != cellSize ||
        oldDelegate.themeColors != themeColors ||
        oldDelegate.showCoordinates != showCoordinates;
  }
}

class _PositionDialog extends StatefulWidget {
  const _PositionDialog({
    required this.choices,
    required this.positions,
    required this.racksByWarehouse,
    this.rackCode,
    this.initialLevel,
    this.initialBin,
  });
  final int? initialLevel;
  final int? initialBin;
  final String? rackCode;
  final List<Map<String, dynamic>> choices;
  final List<Map<String, dynamic>> positions;
  final Map<int, Map<String, _FloorObject?>> racksByWarehouse;

  @override
  State<_PositionDialog> createState() => _PositionDialogState();
}

class _PositionDialogState extends State<_PositionDialog> {
  late int? _selected = widget.choices.first.containsKey('rack') ? 0 : null;
  late int _warehouseId = widget.choices.first['warehouseId'] as int;
  String _query = '';
  bool _showAllSlots = false;
  final _queryController = TextEditingController();
  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  late String? _rack =
      widget.rackCode ?? widget.choices.first['rack'] as String?;
  late int _level =
      (widget.choices.first['level'] as int?) ?? widget.initialLevel ?? 1;
  late int? _bin = (widget.choices.first['bin'] as int?) ?? widget.initialBin;

  Map<String, dynamic>? _currentPosition(Map<String, dynamic>? product) {
    if (product == null) return null;
    return widget.positions
        .where(
          (row) =>
              row['warehouseId'] == _warehouseId &&
              row['productId'] == product['productId'],
        )
        .firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final c = _appColors(context);

    final warehouses = {
      for (final row in widget.choices)
        row['warehouseId'] as int: warehouseDisplayName(row['warehouseName']),
    };
    final editing = widget.choices.first.containsKey('rack');
    final selected = _selected == null ? null : widget.choices[_selected!];
    final current = _currentPosition(selected);
    final racks = widget.racksByWarehouse[_warehouseId] ?? {};
    final rackCode = _rack;
    final rackSelected = rackCode != null && racks.containsKey(rackCode);
    final rackItems = widget.positions
        .where(
          (row) =>
              row['warehouseId'] == _warehouseId && row['rack'] == rackCode,
        )
        .toList();
    final usedLevels = rackItems.map((row) => row['level'] as int).toSet();
    final nextLevel = List.generate(
      12,
      (i) => i + 1,
    ).where((level) => !usedLevels.contains(level)).firstOrNull;
    final levels = _showAllSlots
        ? List.generate(12, (i) => i + 1)
        : ({...usedLevels, _level, ?nextLevel}.toList()..sort());
    final onLevel = rackItems.where((row) => row['level'] == _level).toList();
    final lastUsedBin = onLevel.fold<int>(
      0,
      (max, item) => math.max(max, item['bin'] as int),
    );
    final binCount = _showAllSlots
        ? 16
        : math.min(16, math.max(4, math.max(_bin ?? 1, lastUsedBin + 1)));
    final destination = onLevel.where((row) => row['bin'] == _bin).toList();
    final rackTitle = racks[rackCode]?.rackTitle ?? 'Kệ $rackCode';
    final query = foldSearchText(_query);
    final matches = widget.choices.indexed.where((entry) {
      final product = entry.$2;
      return product['warehouseId'] == _warehouseId &&
          (foldSearchText(product['productName']).contains(query) ||
              foldSearchText(product['sku']).contains(query));
    }).toList();

    return AlertDialog(
      constraints: const BoxConstraints(maxWidth: 560),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      title: Text(editing ? 'Sửa vị trí sản phẩm' : 'Gắn sản phẩm vào kệ'),
      scrollable: true,
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (warehouses.length == 1)
              Row(
                children: [
                  Icon(Icons.warehouse_outlined, color: c.primary, size: 19),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      warehouses[_warehouseId]!,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ],
              )
            else
              DropdownButtonFormField<int>(
                initialValue: _warehouseId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Kho'),
                items: [
                  for (final w in warehouses.entries)
                    DropdownMenuItem(
                      value: w.key,
                      child: Text(
                        warehouses.values
                                    .where((name) => name == w.value)
                                    .length >
                                1
                            ? '${w.value} (#${w.key})'
                            : w.value,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (id) {
                  if (id != null) {
                    setState(() {
                      _warehouseId = id;
                      _selected = null;
                      _rack = null;
                      _level = 1;
                      _bin = null;
                      _query = '';
                      _queryController.clear();
                    });
                  }
                },
              ),
            const SizedBox(height: 14),
            if (selected == null) ...[
              TextField(
                controller: _queryController,
                decoration: const InputDecoration(
                  labelText: 'Tìm sản phẩm',
                  hintText: 'Nhập tên hoặc mã SKU',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: math.min(190.0, math.max(56.0, matches.length * 60.0)),
                child: matches.isEmpty
                    ? const Center(
                        child: Text('Không tìm thấy sản phẩm trong kho này.'),
                      )
                    : ListView.separated(
                        primary: false,
                        itemCount: matches.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (_, index) {
                          final (i, row) = matches[index];
                          return ListTile(
                            dense: true,
                            title: Text(
                              row['productName'].toString(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(row['sku'].toString()),
                            trailing: const Icon(
                              Icons.add_circle_outline,
                              size: 18,
                            ),
                            onTap: () => setState(() {
                              _selected = i;
                              final existing = _currentPosition(row);
                              if (widget.rackCode == null) {
                                _rack = existing?['rack'] as String?;
                                _level = existing?['level'] as int? ?? 1;
                                _bin = existing?['bin'] as int?;
                              }
                            }),
                          );
                        },
                      ),
              ),
            ] else
              DecoratedBox(
                decoration: BoxDecoration(
                  color: c.primarySubtle,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListTile(
                  leading: Icon(Icons.inventory_2_outlined, color: c.primary),
                  title: Text(selected['productName'].toString()),
                  subtitle: Text(selected['sku'].toString()),
                  trailing: editing
                      ? null
                      : TextButton(
                          onPressed: () => setState(() => _selected = null),
                          child: const Text('Đổi'),
                        ),
                ),
              ),
            if (selected != null) ...[
              const SizedBox(height: 14),
              if (current != null) ...[
                Text(
                  "Đang lưu tại kệ ${current['rack']} · Tầng ${current['level']} · Ô ${current['bin']}",
                  style: TextStyle(color: c.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 10),
              ],
              DropdownButtonFormField<String>(
                key: ValueKey((_warehouseId, rackCode)),
                initialValue: rackSelected ? rackCode : null,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Kệ hoặc thiết bị lưu trữ',
                  prefixIcon: Icon(Icons.shelves),
                ),
                hint: Text(
                  racks.isEmpty
                      ? 'Kho chưa có kệ trên mặt bằng'
                      : 'Chọn kệ trên mặt bằng',
                ),
                items: [
                  for (final entry in racks.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(
                        entry.value?.name.isNotEmpty == true
                            ? '${entry.value!.rackTitle} · ${entry.key}'
                            : entry.value?.rackTitle ?? 'Kệ ${entry.key}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: racks.isEmpty
                    ? null
                    : (value) {
                        if (value == rackCode) return;
                        setState(() {
                          _rack = value;
                          final existing =
                              current != null && current['rack'] == value
                              ? current
                              : null;
                          _level = existing?['level'] as int? ?? 1;
                          _bin = existing?['bin'] as int?;
                        });
                      },
              ),
              if (racks.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Dùng Bố trí kho để đặt kệ trước khi gắn sản phẩm.',
                  ),
                ),
              if (rackSelected) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: c.cardAlt,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: c.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Image.asset(
                            (racks[rackCode]?.kind ?? _FixtureKind.rack)
                                .assetPath(occupied: rackItems.isNotEmpty),
                            width: 66,
                            height: 34,
                            fit: BoxFit.contain,
                            excludeFromSemantics: true,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _bin == null
                                  ? '$rackTitle · Tầng $_level'
                                  : '$rackTitle · Tầng $_level · Ô $_bin',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (final tier in levels)
                            ChoiceChip(
                              label: Text('Tầng $tier'),
                              selected: _level == tier,
                              onSelected: (_) {
                                if (tier == _level) return;
                                setState(() {
                                  _level = tier;
                                  _bin =
                                      current?['rack'] == rackCode &&
                                          current?['level'] == tier
                                      ? (current?['bin'] as int?)
                                      : null;
                                });
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _bin == null
                            ? 'Chọn một ô để xem vị trí sẽ lưu'
                            : destination.isEmpty
                            ? 'Ô trống'
                            : destination
                                  .map((row) => row['productName'])
                                  .join(', '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: c.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (var bin = 1; bin <= binCount; bin++)
                            _PlacementBin(
                              bin: bin,
                              selected: _bin == bin,
                              current:
                                  current?['rack'] == rackCode &&
                                  current?['level'] == _level &&
                                  current?['bin'] == bin,
                              items: onLevel
                                  .where((row) => row['bin'] == bin)
                                  .toList(),
                              onTap: () => setState(() => _bin = bin),
                            ),
                        ],
                      ),
                      TextButton(
                        onPressed: () =>
                            setState(() => _showAllSlots = !_showAllSlots),
                        child: Text(
                          _showAllSlots
                              ? 'Thu gọn tầng và ô'
                              : 'Hiện thêm tầng và ô',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: c.primary,
            foregroundColor: Colors.white,
          ),
          onPressed: selected == null || !rackSelected || _bin == null
              ? null
              : () {
                  final choice = selected;
                  Navigator.pop(context, {
                    'warehouseId': choice['warehouseId'],
                    'productId': choice['productId'],
                    'rack': _rack,
                    'level': _level,
                    'bin': _bin,
                  });
                },
          child: const Text('Lưu vị trí'),
        ),
      ],
    );
  }
}

class _PlacementBin extends StatelessWidget {
  const _PlacementBin({
    required this.bin,
    required this.selected,
    required this.current,
    required this.items,
    required this.onTap,
  });

  final int bin;
  final bool selected;
  final bool current;
  final List<Map<String, dynamic>> items;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = _appColors(context);
    final item = items.firstOrNull;
    return Material(
      color: selected ? c.primarySubtle : c.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: selected ? c.primary : c.divider),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 74,
          constraints: const BoxConstraints(minHeight: 83),
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Ô $bin',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: selected ? c.primary : c.textPrimary,
                ),
              ),
              if (item == null)
                Icon(Icons.inbox_outlined, color: c.textMuted, size: 28)
              else
                ProductThumbnail(
                  key: ValueKey((item['productId'], item['imageUrl'])),
                  imageUrl: item['imageUrl'] as String?,
                  name: item['productName'] as String?,
                  size: 32,
                ),
              Text(
                current
                    ? 'Hiện tại'
                    : selected
                    ? 'Đã chọn'
                    : items.isEmpty
                    ? 'Trống'
                    : '${items.length} mặt hàng',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? c.primary : c.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
