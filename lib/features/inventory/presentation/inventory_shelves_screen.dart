import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../settings/providers/shop_provider.dart';

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
  // Deprecated kinds for legacy compatibility:
  coldStorage('Tủ mát', Icons.ac_unit_outlined),
  display('Bàn trưng bày', Icons.table_restaurant_outlined),
  counter('Quầy', Icons.storefront_outlined);

  const _FixtureKind(this.label, this.icon);
  final String label;
  final IconData icon;

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
    this.block,
  });

  factory _FloorObject.fromJson(Map<String, dynamic> json) {
    _FixtureKind kind;
    try {
      kind = _FixtureKind.values.byName(json['kind'] as String);
    } catch (_) {
      kind = _FixtureKind.rack;
    }
    return _FloorObject(
      id: json['id'] as String,
      kind: kind,
      x: (json['x'] as num?)?.toDouble().clamp(0.0, 1.0) ?? 0.0,
      y: (json['y'] as num?)?.toDouble().clamp(0.0, 1.0) ?? 0.0,
      width: (json['width'] as num?)?.toDouble().clamp(0.5, 3.0) ?? 1.0,
      height: (json['height'] as num?)?.toDouble().clamp(0.5, 3.0) ?? 1.0,
      rotation: ((json['rotation'] as int?) ?? 0) % 4,
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
  String get rackCode => stockRack ? id.substring(6) : '';

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'rotation': rotation,
    if (manualRack) 'manualRack': true,
    if (block case final b?) 'block': [b.column, b.row, b.columns, b.rows],
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
  bool _assigning = false;
  int? _activeWarehouseId;

  Future<void> _assign(
    int shopId, {
    Map<String, dynamic>? position,
    int? warehouseId,
    String? rackCode,
  }) async {
    if (_assigning) return;
    setState(() => _assigning = true);
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
        choices.add({
          'warehouseId': position['warehouseId'],
          'productId': position['productId'],
          'warehouseName': position['warehouseName'],
          'productName': position['productName'],
          'sku': position['sku'],
          'rack': position['rack'],
          'level': position['level'],
          'bin': position['bin'],
        });
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
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => _PositionDialog(choices: choices, rackCode: rackCode),
      );
      if (result == null || !current()) return;
      await api.putInShop(
        _path,
        '$shopId',
        data: result,
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
      if (mounted) setState(() => _assigning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _appColors(context);
    final shop = ref.watch(shopProvider);
    final shopId = shop.currentShopId;
    final canEdit = shop.hasPermission('inventory', 'edit');

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: const Text('Sơ đồ kệ'),
        backgroundColor: c.surface,
        foregroundColor: c.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        actions: [
          if (shopId != null && shopId > 0 && canEdit)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: OutlinedButton.icon(
                onPressed: _assigning ? null : () => _assign(shopId),
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
          : ref
                .watch(_shelvesProvider(shopId))
                .when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: c.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          'Không tải được sơ đồ.',
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.tonal(
                          onPressed: () =>
                              ref.invalidate(_shelvesProvider(shopId)),
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                  data: (data) {
                    final positions = data.positions;
                    final warehouses = data.warehouses;

                    if (warehouses.isEmpty) {
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

                    final selectedWarehouseId =
                        _activeWarehouseId ?? warehouses.first['id'] as int;
                    final currentWarehouse = warehouses.firstWhere(
                      (w) => w['id'] == selectedWarehouseId,
                      orElse: () => warehouses.first,
                    );

                    final warehousePositions = positions
                        .where((p) => p['warehouseId'] == selectedWarehouseId)
                        .toList();

                    final racks = <String, List<Map<String, dynamic>>>{};
                    for (final p in warehousePositions) {
                      final code = (p['rack'] as String?)?.trim() ?? '';
                      if (code.isNotEmpty) {
                        (racks[code] ??= []).add(p);
                      }
                    }

                    bool matchesSearch(Map<String, dynamic> p) {
                      if (_search.isEmpty) return false;
                      final query = _search.toLowerCase();
                      final name = (p['productName'] as String? ?? '')
                          .toLowerCase();
                      final sku = (p['sku'] as String? ?? '').toLowerCase();
                      final rack = (p['rack'] as String? ?? '').toLowerCase();
                      return name.contains(query) ||
                          sku.contains(query) ||
                          rack.contains(query);
                    }

                    final matchingPositions = warehousePositions
                        .where(matchesSearch)
                        .toList();
                    final matchingRacks = <String>{};
                    for (final p in matchingPositions) {
                      final code = (p['rack'] as String?)?.trim() ?? '';
                      if (code.isNotEmpty) matchingRacks.add(code);
                    }

                    return Column(
                      children: [
                        // Top Search & Filter Bar
                        Container(
                          color: c.surface,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  // Warehouse Selector
                                  if (warehouses.length > 1) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: c.cardAlt,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: c.divider),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<int>(
                                          value: selectedWarehouseId,
                                          isDense: true,
                                          style: TextStyle(
                                            color: c.textPrimary,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                          items: warehouses.map((w) {
                                            return DropdownMenuItem<int>(
                                              value: w['id'] as int,
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.store_outlined,
                                                    size: 16,
                                                    color: c.primary,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    w['name'] as String? ??
                                                        'Kho',
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: (val) {
                                            if (val != null) {
                                              setState(() {
                                                _activeWarehouseId = val;
                                                _selectedRack = null;
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                  ],
                                  // Search input
                                  Expanded(
                                    child: SizedBox(
                                      height: 42,
                                      child: TextField(
                                        textInputAction: TextInputAction.search,
                                        style: TextStyle(
                                          color: c.textPrimary,
                                          fontSize: 14,
                                        ),
                                        onChanged: (value) => setState(() {
                                          _search = value.trim().toLowerCase();
                                          _selectedRack = null;
                                        }),
                                        decoration: InputDecoration(
                                          isDense: true,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                vertical: 10,
                                                horizontal: 12,
                                              ),
                                          prefixIcon: Icon(
                                            Icons.search,
                                            size: 20,
                                            color: c.textMuted,
                                          ),
                                          suffixIcon: _search.isNotEmpty
                                              ? IconButton(
                                                  icon: const Icon(
                                                    Icons.clear,
                                                    size: 18,
                                                  ),
                                                  onPressed: () => setState(
                                                    () => _search = '',
                                                  ),
                                                )
                                              : null,
                                          hintText:
                                              'Tìm theo tên mặt hàng hoặc SKU',
                                          hintStyle: TextStyle(
                                            color: c.textMuted,
                                            fontSize: 14,
                                          ),
                                          filled: true,
                                          fillColor: c.inputFill,
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            borderSide: BorderSide(
                                              color: c.divider,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            borderSide: BorderSide(
                                              color: c.primary,
                                              width: 1.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (_search.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                if (matchingPositions.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: 4,
                                      left: 4,
                                    ),
                                    child: Text(
                                      'Không tìm thấy mặt hàng trên sơ đồ.',
                                      style: TextStyle(
                                        color: Colors.amber.shade800,
                                        fontSize: 13,
                                      ),
                                    ),
                                  )
                                else ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.amber.shade300,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Tìm thấy ${matchingPositions.length} sản phẩm trên ${matchingRacks.length} kệ:',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.amber.shade900,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 6,
                                          children: [
                                            for (final p
                                                in matchingPositions.take(10))
                                              ActionChip(
                                                label: Text(
                                                  '${p['productName']} (Kệ ${p['rack']})',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        Colors.amber.shade900,
                                                  ),
                                                ),
                                                backgroundColor: Colors.white,
                                                side: BorderSide(
                                                  color: Colors.amber.shade400,
                                                ),
                                                visualDensity:
                                                    VisualDensity.compact,
                                                onPressed: () {
                                                  setState(() {
                                                    _selectedRack = (
                                                      selectedWarehouseId,
                                                      currentWarehouse['name']
                                                              as String? ??
                                                          'Kho',
                                                      p['rack'] as String,
                                                    );
                                                  });
                                                },
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ],
                          ),
                        ),
                        const Divider(height: 1, thickness: 1),
                        // Canvas & Inspection Panel Area
                        Expanded(
                          child: _RackFloor(
                            key: ValueKey((shopId, selectedWarehouseId)),
                            storageKey:
                                'inventory.shelf.scene.$shopId.$selectedWarehouseId',
                            warehouseId: selectedWarehouseId,
                            warehouseName:
                                currentWarehouse['name'] as String? ?? 'Kho',
                            canEdit: canEdit,
                            racks: racks,
                            searchQuery: _search,
                            matchingRacks: matchingRacks,
                            selectedRackCode:
                                _selectedRack?.$1 == selectedWarehouseId
                                ? _selectedRack?.$3
                                : null,
                            onSelectRack: (rackCode) {
                              setState(() {
                                _selectedRack = rackCode == null
                                    ? null
                                    : (
                                        selectedWarehouseId,
                                        currentWarehouse['name'] as String? ??
                                            'Kho',
                                        rackCode,
                                      );
                              });
                            },
                            onAssignRack: (rack) => _assign(
                              shopId,
                              warehouseId: selectedWarehouseId,
                              rackCode: rack,
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
    this.selectedRackCode,
    required this.onSelectRack,
    required this.onAssignRack,
  });

  final String storageKey;
  final int warehouseId;
  final String warehouseName;
  final bool canEdit;
  final Map<String, List<Map<String, dynamic>>> racks;
  final String searchQuery;
  final Set<String> matchingRacks;
  final String? selectedRackCode;
  final ValueChanged<String?> onSelectRack;
  final ValueChanged<String> onAssignRack;

  @override
  State<_RackFloor> createState() => _RackFloorState();
}

class _RackFloorState extends State<_RackFloor> {
  static const double _cellSize = 44.0;
  static const int _baseColumns = 24;
  static const int _baseRows = 16;
  static const int _maxGridSize = 60;

  final _floorKey = GlobalKey();
  final _viewport = TransformationController();

  Map<String, _FloorObject> _objects = {};
  _FloorSnapshot? _undo;
  int _extraColumns = 0;
  int _extraRows = 0;
  String? _selection;
  bool _editing = false;
  bool _saving = false;
  bool _loading = true;
  bool _is3dView = false;
  _FixtureKind? _placement;

  int get _columns =>
      (_baseColumns + _extraColumns).clamp(_baseColumns, _maxGridSize);
  int get _rows => math
      .max(
        _baseRows + _extraRows,
        _objects.values.fold(_baseRows, (maxRow, item) {
          final b = item.block;
          return b == null ? maxRow : math.max(maxRow, b.row + b.rows + 1);
        }),
      )
      .clamp(_baseRows, _maxGridSize);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _RackFloor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedRackCode != null &&
        widget.selectedRackCode != oldWidget.selectedRackCode) {
      _selection = 'stock:${widget.selectedRackCode}';
    }
  }

  @override
  void dispose() {
    _viewport.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(widget.storageKey);
      if (json != null) {
        final decoded = jsonDecode(json);
        final saved = decoded is Map<String, dynamic> ? decoded : null;
        final rawList = ((saved?['objects'] ?? decoded) as List);
        final list = rawList.map(
          (val) => _FloorObject.fromJson(Map<String, dynamic>.from(val as Map)),
        );
        if (mounted) {
          setState(() {
            _objects = {for (final item in list) item.id: item};
            _extraColumns = (saved?['extraColumns'] as int? ?? 0).clamp(
              0,
              _maxGridSize - _baseColumns,
            );
            _extraRows = (saved?['extraRows'] as int? ?? 0).clamp(
              0,
              _maxGridSize - _baseRows,
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

  Future<void> _save(
    Map<String, _FloorObject> next,
    String? selection, {
    bool undo = false,
    int? extraColumns,
    int? extraRows,
  }) async {
    if (_saving || _loading || !widget.canEdit) return;
    final previous = (
      objects: Map<String, _FloorObject>.from(_objects),
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
      final jsonString = (next.isEmpty && _extraColumns == 0 && _extraRows == 0)
          ? '[]'
          : jsonEncode(next.values.toList());

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
      (item.y * _rows - rows / 2).round(),
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

  _GridBlock _findFreeBlock(
    _GridBlock requested,
    String id,
    Map<String, _FloorObject> layout,
  ) {
    if (!_overlaps(requested, id, layout)) return requested;
    for (var d = 1; d <= 8; d++) {
      for (var dy = -d; dy <= d; dy++) {
        for (var dx = -d; dx <= d; dx++) {
          final candidate = _snap(
            requested.column + dx,
            requested.row + dy,
            requested.columns,
            requested.rows,
          );
          if (!_overlaps(candidate, id, layout)) return candidate;
        }
      }
    }
    return requested;
  }

  void _updateBlock(
    _FloorObject item,
    _GridBlock block,
    Map<String, _FloorObject> layout, {
    int? rotation,
    double? width,
    double? height,
  }) {
    final effectiveBlock = _findFreeBlock(block, item.id, layout);
    _save({
      ..._objects,
      item.id: item.copyWith(
        block: effectiveBlock,
        rotation: rotation,
        width: width,
        height: height,
      ),
    }, item.id);
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
    final targetCol = (position.dx * _columns - current.columns / 2).floor();
    final targetRow = (position.dy * _rows - current.rows / 2).floor();
    final block = _snap(targetCol, targetRow, current.columns, current.rows);

    _updateBlock(item, block, layout);
  }

  void _zoomBy(double factor) {
    final matrix = _viewport.value;
    final scale = matrix.getMaxScaleOnAxis();
    final adjustment = (scale * factor).clamp(0.5, 2.5) / scale;
    _viewport.value = Matrix4.copy(matrix)
      ..scaleByDouble(adjustment, adjustment, 1, 1);
  }

  void _resetZoom() {
    _viewport.value = Matrix4.identity();
  }

  Map<String, _FloorObject> _effectiveLayout() {
    final layout = Map<String, _FloorObject>.from(_objects);
    layout.removeWhere(
      (key, value) =>
          value.stockRack &&
          !value.manualRack &&
          !widget.racks.containsKey(key.substring(6)),
    );

    var nextCol = 1;
    var nextRow = 2;
    for (final name in widget.racks.keys) {
      final id = 'stock:$name';
      layout.putIfAbsent(id, () {
        final block = _snap(nextCol, nextRow, 3, 2);
        nextCol += 4;
        if (nextCol + 3 >= _columns) {
          nextCol = 1;
          nextRow += 3;
        }
        return _FloorObject(
          id: id,
          kind: _FixtureKind.rack,
          x: block.column / _columns,
          y: block.row / _rows,
          block: block,
        );
      });
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;

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
                      transformationController: _viewport,
                      minScale: 0.5,
                      maxScale: 2.5,
                      boundaryMargin: const EdgeInsets.all(250),
                      constrained: false,
                      child: Container(
                        key: _floorKey,
                        width: width,
                        height: height,
                        margin: const EdgeInsets.all(40),
                        child: DragTarget<_SceneDrag>(
                          onWillAcceptWithDetails: (_) => widget.canEdit,
                          onAcceptWithDetails: (details) {
                            final box =
                                _floorKey.currentContext?.findRenderObject()
                                    as RenderBox?;
                            if (box == null) return;
                            final point = box.globalToLocal(details.offset);
                            setState(() => _placement = null);
                            _place(
                              details.data,
                              Offset(
                                (point.dx / width).clamp(0.0, 1.0),
                                (point.dy / height).clamp(0.0, 1.0),
                              ),
                              layout,
                            );
                          },
                          builder: (context, candidateData, rejectedData) {
                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTapDown: (details) {
                                if (_placement != null) {
                                  final normX =
                                      (details.localPosition.dx / width).clamp(
                                        0.0,
                                        1.0,
                                      );
                                  final normY =
                                      (details.localPosition.dy / height).clamp(
                                        0.0,
                                        1.0,
                                      );
                                  _place(
                                    (id: null, kind: _placement),
                                    Offset(normX, normY),
                                    layout,
                                  );
                                  setState(() => _placement = null);
                                } else {
                                  setState(() => _selection = null);
                                  widget.onSelectRack(null);
                                }
                              },
                              child: _buildFloorSurface(layout, c, isDesktop),
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
                          const Divider(height: 1, indent: 4, endIndent: 4),
                          // 2D / 3D Toggle
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                onTap: () => setState(() => _is3dView = false),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 6,
                                  ),
                                  child: Text(
                                    '2D',
                                    style: TextStyle(
                                      color: !_is3dView
                                          ? c.primary
                                          : c.textMuted,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const Text('/', style: TextStyle(fontSize: 10)),
                              InkWell(
                                onTap: () => setState(() => _is3dView = true),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 6,
                                  ),
                                  child: Text(
                                    '3D',
                                    style: TextStyle(
                                      color: _is3dView
                                          ? c.primary
                                          : c.textMuted,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Edit Mode Toggle Button (Top Right)
                  if (widget.canEdit)
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
                            if (_editing) _is3dView = false;
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
                      top: 16,
                      left: 16,
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
                            Text(
                              'Đang đặt: ${_placement!.label} (Chạm sàn để đặt)',
                              style: TextStyle(
                                color: c.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
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

                  // Selected Fixture Action Bar in Edit Mode
                  if (_editing && selectedItem != null)
                    Positioned(
                      top: 16,
                      left: _placement != null ? 360 : 16,
                      child: Container(
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
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              selectedItem.stockRack
                                  ? 'Kệ ${selectedItem.rackCode}'
                                  : selectedItem.kind.label,
                              style: TextStyle(
                                color: c.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              tooltip: 'Xoay khối 90°',
                              icon: const Icon(
                                Icons.rotate_90_degrees_ccw_outlined,
                                size: 18,
                              ),
                              onPressed: () {
                                final nextRotation =
                                    (selectedItem.rotation + 1) % 4;
                                final b = _blockFor(selectedItem);
                                final newCols = selectedItem.rotation.isEven
                                    ? b.rows
                                    : b.columns;
                                final newRows = selectedItem.rotation.isEven
                                    ? b.columns
                                    : b.rows;
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
                            IconButton(
                              tooltip: 'Tăng chiều ngang',
                              icon: const Icon(Icons.swap_horiz, size: 18),
                              onPressed: () {
                                final b = _blockFor(selectedItem);
                                final nextWidth = (selectedItem.width >= 1.2
                                    ? 1.0
                                    : 1.2);
                                final nextCols =
                                    (b.columns *
                                            (nextWidth / selectedItem.width))
                                        .round();
                                final nextBlock = _snap(
                                  b.column,
                                  b.row,
                                  nextCols,
                                  b.rows,
                                );
                                _updateBlock(
                                  selectedItem,
                                  nextBlock,
                                  layout,
                                  width: nextWidth,
                                );
                              },
                            ),
                            if (selectedItem.stockRack)
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                ),
                                onPressed: () =>
                                    widget.onAssignRack(selectedItem.rackCode),
                                icon: const Icon(
                                  Icons.add_location_alt_outlined,
                                  size: 16,
                                ),
                                label: const Text('Gắn sản phẩm'),
                              ),
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
                                  onPressed: () =>
                                      _save(_undo!.objects, null, undo: true),
                                ),
                                const SizedBox(width: 8),
                              ],
                              for (final kind in const [
                                _FixtureKind.rack,
                                _FixtureKind.door,
                                _FixtureKind.aisle,
                                _FixtureKind.receiving,
                                _FixtureKind.dispatch,
                                _FixtureKind.wall,
                                _FixtureKind.pallet,
                                _FixtureKind.bulk,
                              ])
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
  }

  Widget _buildFixtureToolButton(_FixtureKind kind, AppThemeColors c) {
    final active = _placement == kind;
    void onTap() {
      setState(() => _placement = active ? null : kind);
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
      icon: Icon(kind.icon, size: 16),
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
                Icon(kind.icon, size: 16, color: c.primary),
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

  Widget _buildFloorSurface(
    Map<String, _FloorObject> layout,
    AppThemeColors c,
    bool isDesktop,
  ) {
    Widget floorCanvas = CustomPaint(
      painter: _WarehouseFloorPainter(
        columns: _columns,
        rows: _rows,
        cellSize: _cellSize,
        themeColors: c,
        is3d: _is3dView,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final item in layout.values)
            _buildTile(item, layout, c, isDesktop),
          if (_is3dView) _buildForkliftVisual(c),
        ],
      ),
    );

    if (_is3dView) {
      floorCanvas = AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        transformAlignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0006)
          ..rotateX(46 * math.pi / 180)
          ..rotateZ(-36 * math.pi / 180),
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 40,
              offset: const Offset(-20, 30),
            ),
          ],
        ),
        child: floorCanvas,
      );
    }

    return floorCanvas;
  }

  Widget _buildForkliftVisual(AppThemeColors c) {
    double x = 2 * _cellSize;
    double y = (_rows - 3).clamp(1, _rows - 2) * _cellSize;

    final aisle = _objects.values
        .where(
          (o) =>
              o.kind == _FixtureKind.aisle || o.kind == _FixtureKind.receiving,
        )
        .firstOrNull;
    if (aisle != null && aisle.block != null) {
      x = aisle.block!.column * _cellSize + 4;
      y = aisle.block!.row * _cellSize - 8;
    }

    return Positioned(
      left: x,
      top: y,
      child: IgnorePointer(
        ignoring: true,
        child: SizedBox(
          width: _cellSize * 2.2,
          height: _cellSize * 1.4,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Shadow
              Positioned(
                left: 6,
                bottom: 2,
                width: 50,
                height: 10,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              // Body
              Positioned(
                left: 6,
                bottom: 6,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Cab & Engine
                    Container(
                      width: 32,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAB308), // OSHA yellow
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: const Color(0xFFCA8A04),
                          width: 1.2,
                        ),
                      ),
                      child: Stack(
                        children: [
                          // ROPS cage
                          Positioned(
                            top: 2,
                            left: 3,
                            right: 6,
                            height: 12,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: Center(
                                child: Container(
                                  width: 10,
                                  height: 6,
                                  color: Colors.lightBlueAccent.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Amber beacon
                          Positioned(
                            top: -2,
                            left: 6,
                            child: Container(
                              width: 4,
                              height: 4,
                              decoration: const BoxDecoration(
                                color: Color(0xFFF97316),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          // Wheels
                          Positioned(
                            bottom: -3,
                            left: 3,
                            child: Container(
                              width: 8,
                              height: 6,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: -3,
                            right: 3,
                            child: Container(
                              width: 7,
                              height: 5,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 2),
                    // Mast beam
                    Container(
                      width: 4,
                      height: 30,
                      color: const Color(0xFF334155),
                    ),
                    // Pallet & Cargo box
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 16,
                          height: 14,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD97706),
                            borderRadius: BorderRadius.circular(2),
                            border: Border.all(
                              color: const Color(0xFF92400E),
                              width: 0.8,
                            ),
                          ),
                          child: Center(
                            child: Container(
                              width: 4,
                              height: 3,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Container(
                          width: 18,
                          height: 3,
                          color: const Color(0xFFB45309), // Pallet
                        ),
                        Container(
                          width: 16,
                          height: 2,
                          color: const Color(0xFF64748B), // Forks
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

    Widget content;
    if (isRack) {
      content = _buildRackVisual(
        rackCode,
        positions,
        isSelected,
        isSearchMatch,
        c,
      );
    } else {
      content = _buildFixtureVisual(item.kind, isSelected, c, rows: block.rows);
    }

    Widget interactive = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() => _selection = item.id);
        if (isRack) {
          widget.onSelectRack(rackCode);
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
        dragAnchorStrategy: pointerDragAnchorStrategy,
        feedback: Material(
          color: Colors.transparent,
          child: Opacity(
            opacity: 0.8,
            child: SizedBox(
              width: block.columns * _cellSize,
              height: block.rows * _cellSize,
              child: content,
            ),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.25, child: content),
        child: interactive,
      );
    }

    return Positioned(
      left: block.column * _cellSize,
      top: block.row * _cellSize,
      width: block.columns * _cellSize,
      height: block.rows * _cellSize,
      child: interactive,
    );
  }

  Widget _buildRackVisual(
    String rackCode,
    List<Map<String, dynamic>> positions,
    bool isSelected,
    bool isSearchMatch,
    AppThemeColors c,
  ) {
    final hasStock = positions.isNotEmpty;
    final steelColor = isSelected
        ? c.primary
        : (hasStock ? const Color(0xFF2563EB) : const Color(0xFF64748B));
    final beamColor = isSelected ? c.primary : const Color(0xFFEA580C);

    final borderColor = isSelected
        ? c.primary
        : isSearchMatch
        ? Colors.amber.shade700
        : hasStock
        ? c.primary.withValues(alpha: 0.6)
        : c.divider;

    final bgColor = isSelected
        ? c.primarySubtle
        : isSearchMatch
        ? Colors.amber.shade50
        : hasStock
        ? c.card
        : c.cardAlt;

    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: borderColor,
          width: isSelected || isSearchMatch ? 2.2 : 1.2,
        ),
        boxShadow: [
          if (isSelected || isSearchMatch)
            BoxShadow(
              color: (isSelected ? c.primary : Colors.amber).withValues(
                alpha: 0.25,
              ),
              blurRadius: 8,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Stack(
        children: [
          // Left upright steel frame
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 4,
            child: Container(
              decoration: BoxDecoration(
                color: steelColor.withValues(alpha: 0.8),
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(5),
                ),
              ),
            ),
          ),
          // Right upright steel frame
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: 4,
            child: Container(
              decoration: BoxDecoration(
                color: steelColor.withValues(alpha: 0.8),
                borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(5),
                ),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Header: Rack Name & Count Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Kệ $rackCode',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? c.primary : c.textPrimary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: hasStock
                            ? Colors.teal.shade700
                            : c.textMuted.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        hasStock ? '${positions.length} SP' : 'Trống',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: hasStock ? Colors.white : c.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),

                // Industrial Shelf Bays with Cargo Boxes / Pallets
                Container(
                  height: 14,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: beamColor.withValues(alpha: 0.7),
                        width: 1.5,
                      ),
                    ),
                  ),
                  child: Row(
                    children: List.generate(4, (index) {
                      final isSlotOccupied = index < positions.length;
                      final isMatch =
                          isSlotOccupied &&
                          widget.searchQuery.isNotEmpty &&
                          ('${positions[index]['productName']} ${positions[index]['sku']}')
                              .toLowerCase()
                              .contains(widget.searchQuery);

                      return Expanded(
                        child: Container(
                          margin: EdgeInsets.only(right: index < 3 ? 2 : 0),
                          alignment: Alignment.bottomCenter,
                          child: isSlotOccupied
                              ? Container(
                                  height: 11,
                                  decoration: BoxDecoration(
                                    color: isMatch
                                        ? Colors.amber.shade400
                                        : const Color(0xFFD97706),
                                    borderRadius: BorderRadius.circular(1.5),
                                    border: Border.all(
                                      color: isMatch
                                          ? Colors.amber.shade800
                                          : const Color(0xFF92400E),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Center(
                                    child: Container(
                                      width: 3,
                                      height: 2,
                                      color: Colors.white.withValues(
                                        alpha: 0.8,
                                      ),
                                    ),
                                  ),
                                )
                              : Container(
                                  height: 8,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: c.divider.withValues(alpha: 0.5),
                                      width: 0.8,
                                    ),
                                    borderRadius: BorderRadius.circular(1),
                                  ),
                                ),
                        ),
                      );
                    }),
                  ),
                ),

                // Footer Summary
                Text(
                  hasStock ? '${positions.length} mặt hàng' : 'Chưa có hàng',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: hasStock ? c.textSecondary : c.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFixtureVisual(
    _FixtureKind kind,
    bool isSelected,
    AppThemeColors c, {
    int rows = 1,
  }) {
    Color accentColor;
    Color fillColor;

    switch (kind) {
      case _FixtureKind.door:
        accentColor = Colors.purple.shade600;
        fillColor = Colors.purple.shade50;
      case _FixtureKind.receiving:
        accentColor = Colors.blue.shade600;
        fillColor = Colors.blue.shade50;
      case _FixtureKind.dispatch:
        accentColor = Colors.orange.shade600;
        fillColor = Colors.orange.shade50;
      case _FixtureKind.wall:
        accentColor = Colors.blueGrey.shade700;
        fillColor = Colors.blueGrey.shade100;
      case _FixtureKind.aisle:
        accentColor = Colors.grey.shade600;
        fillColor = Colors.grey.shade100;
      case _FixtureKind.pallet || _FixtureKind.bulk:
        accentColor = Colors.amber.shade700;
        fillColor = Colors.amber.shade50;
      default:
        accentColor = c.textMuted;
        fillColor = c.cardAlt;
    }

    final isHorizontal = rows <= 1;

    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isSelected ? c.primary : accentColor.withValues(alpha: 0.6),
          width: isSelected ? 2.0 : 1.0,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Center(
        child: isHorizontal
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(kind.icon, size: 14, color: accentColor),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      kind.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: accentColor,
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(kind.icon, size: 18, color: accentColor),
                  const SizedBox(height: 2),
                  Flexible(
                    child: Text(
                      kind.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: accentColor,
                      ),
                    ),
                  ),
                ],
              ),
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
      builder: (_) =>
          SizedBox(height: 480, child: _buildInspectionContent(rackCode, c)),
    );
  }

  Widget _buildRackElevationDiagram(
    String rackCode,
    List<Map<String, dynamic>> positions,
    AppThemeColors c,
  ) {
    const totalLevels = 3;
    const totalBins = 3;
    const slotTotal = totalLevels * totalBins;

    final slotMap = <String, Map<String, dynamic>>{};
    for (final p in positions) {
      final lvl = (p['level'] as num?)?.toInt() ?? 1;
      final bin = (p['bin'] as num?)?.toInt() ?? 1;
      slotMap['$lvl-$bin'] = p;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.view_in_ar_outlined,
                      size: 15,
                      color: Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'MẶT DỰNG KỆ 3D (RACK ELEVATION)',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: c.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: positions.isEmpty
                      ? c.divider.withValues(alpha: 0.3)
                      : Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: positions.isEmpty ? c.divider : Colors.teal.shade300,
                  ),
                ),
                child: Text(
                  'Lấp đầy: ${positions.length}/$slotTotal ô (${(positions.length / slotTotal * 100).toStringAsFixed(0)}%)',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: positions.isEmpty
                        ? c.textMuted
                        : Colors.teal.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Khung thép Pallet Rack 3 tầng
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF1E40AF), width: 1.5),
            ),
            child: Stack(
              children: [
                // Cột thép trái
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 6,
                  child: Container(color: const Color(0xFF1E40AF)),
                ),
                // Cột thép phải
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: 6,
                  child: Container(color: const Color(0xFF1E40AF)),
                ),
                // 3 tầng T3 -> T1
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Column(
                    children: [
                      for (int lvl = totalLevels; lvl >= 1; lvl--) ...[
                        Expanded(
                          child: Row(
                            children: [
                              SizedBox(
                                width: 22,
                                child: Text(
                                  'T$lvl',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E40AF),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Row(
                                  children: [
                                    for (
                                      int bin = 1;
                                      bin <= totalBins;
                                      bin++
                                    ) ...[
                                      if (bin > 1) const SizedBox(width: 4),
                                      Expanded(
                                        child: _buildBaySlot(
                                          slotMap['$lvl-$bin'],
                                          lvl,
                                          bin,
                                          rackCode,
                                          c,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Thanh dầm cam OSHA
                        Container(
                          margin: const EdgeInsets.only(
                            left: 22,
                            top: 1,
                            bottom: 2,
                          ),
                          height: 3,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEA580C),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBaySlot(
    Map<String, dynamic>? slotItem,
    int level,
    int bin,
    String rackCode,
    AppThemeColors c,
  ) {
    final hasItem = slotItem != null;

    if (hasItem) {
      return Tooltip(
        message:
            'Tầng $level · Ô $bin: ${slotItem['productName']} (SKU: ${slotItem['sku']})',
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: const Color(0xFFD97706), width: 0.8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 14,
                    height: 10,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706),
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                    child: Center(
                      child: Container(
                        width: 4,
                        height: 2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                slotItem['sku']?.toString() ?? 'SP',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF92400E),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      onTap: widget.canEdit ? () => widget.onAssignRack(rackCode) : null,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: c.divider.withValues(alpha: 0.6),
            width: 0.6,
          ),
        ),
        child: Center(
          child: Text(
            'Ô $bin',
            style: TextStyle(
              fontSize: 8,
              color: c.textMuted.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInspectionContent(String rackCode, AppThemeColors c) {
    final positions = widget.racks[rackCode] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kệ $rackCode',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: c.textPrimary,
                    ),
                  ),
                  Text(
                    'Kho: ${widget.warehouseName}',
                    style: TextStyle(fontSize: 13, color: c.textSecondary),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() => _selection = null);
                  widget.onSelectRack(null);
                  if (Navigator.canPop(context)) Navigator.maybePop(context);
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Quick Stats
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: c.cardAlt,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${positions.length}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: c.primary,
                        ),
                      ),
                      Text(
                        'Mặt hàng',
                        style: TextStyle(fontSize: 12, color: c.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: c.cardAlt,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        positions.isEmpty
                            ? '0'
                            : '${positions.map((p) => p['level']).toSet().length}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: c.textPrimary,
                        ),
                      ),
                      Text(
                        'Số tầng dùng',
                        style: TextStyle(fontSize: 12, color: c.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // 3D Multi-tier Rack Elevation Diagram
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _buildRackElevationDiagram(rackCode, positions, c),
        ),
        const SizedBox(height: 8),

        // Products List
        Expanded(
          child: positions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inbox_outlined, size: 40, color: c.textMuted),
                      const SizedBox(height: 8),
                      Text(
                        'Kệ này chưa có hàng.',
                        style: TextStyle(color: c.textMuted, fontSize: 14),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: positions.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = positions[index];
                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: c.card,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: c.divider),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['productName'] as String? ?? 'Sản phẩm',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: c.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: c.cardAlt,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'SKU: ${item['sku'] ?? 'N/A'}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: c.textSecondary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Tầng ${item['level'] ?? 1} · Ô ${item['bin'] ?? 1}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: c.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (widget.canEdit)
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () => widget.onAssignRack(rackCode),
                            ),
                        ],
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
              onPressed: () => widget.onAssignRack(rackCode),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Gắn sản phẩm'),
            ),
          ),
      ],
    );
  }
}

class _WarehouseFloorPainter extends CustomPainter {
  const _WarehouseFloorPainter({
    required this.columns,
    required this.rows,
    required this.cellSize,
    required this.themeColors,
    required this.is3d,
  });

  final int columns;
  final int rows;
  final double cellSize;
  final AppThemeColors themeColors;
  final bool is3d;

  @override
  void paint(Canvas canvas, Size size) {
    final floorRect = Offset.zero & size;

    // Floor concrete/surface background
    final floorPaint = Paint()..color = themeColors.surface;
    canvas.drawRRect(
      RRect.fromRectAndRadius(floorRect, const Radius.circular(12)),
      floorPaint,
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
        oldDelegate.is3d != is3d;
  }
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
    final c = _appColors(context);

    return AlertDialog(
      title: const Text('Vị trí trên kệ'),
      scrollable: true,
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
              ],
              onChanged: (value) => setState(() => _selected = value!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _rack,
              readOnly: widget.rackCode != null,
              maxLength: 24,
              decoration: const InputDecoration(labelText: 'Mã kệ'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Nhập mã kệ' : null,
              onSaved: (value) => _rack = value!.trim(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _numberField('Tầng', _level, 12, (v) => _level = v),
                ),
                const SizedBox(width: 12),
                Expanded(child: _numberField('Ô', _bin, 16, (v) => _bin = v)),
              ],
            ),
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
        final parsed = int.tryParse(value ?? '');
        return parsed == null || parsed < 1 || parsed > max ? '1-$max' : null;
      },
      onSaved: (value) => save(int.parse(value!)),
    );
  }
}
