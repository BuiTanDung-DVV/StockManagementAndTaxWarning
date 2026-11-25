part of 'inventory_shelves_screen.dart';

class _ShelfLookupBar extends StatelessWidget {
  const _ShelfLookupBar({
    required this.warehouses,
    required this.warehouseId,
    required this.rackCount,
    required this.controller,
    required this.query,
    required this.matches,
    required this.onWarehouseChanged,
    required this.onSearchChanged,
    required this.onOpenPosition,
  });

  final List<Map<String, dynamic>> warehouses;
  final int warehouseId;
  final int rackCount;
  final TextEditingController controller;
  final String query;
  final List<Map<String, dynamic>> matches;
  final ValueChanged<int> onWarehouseChanged;
  final VoidCallback onSearchChanged;
  final ValueChanged<Map<String, dynamic>> onOpenPosition;

  @override
  Widget build(BuildContext context) {
    final c = _appColors(context);
    final names = {
      for (final w in warehouses)
        w['id'] as int: warehouseDisplayName(w['name']),
    };
    String label(int id) {
      final name = names[id]!;
      return names.values.where((v) => v == name).length > 1
          ? '$name (#$id)'
          : name;
    }

    final selector = Row(
      children: [
        Icon(Icons.warehouse_outlined, size: 20, color: c.primary),
        const SizedBox(width: 8),
        Expanded(
          child: warehouses.length == 1
              ? Text(
                  label(warehouseId),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                )
              : DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: warehouseId,
                    isExpanded: true,
                    items: [
                      for (final id in names.keys)
                        DropdownMenuItem(
                          value: id,
                          child: Text(
                            label(id),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (id) {
                      if (id != null && id != warehouseId) {
                        onWarehouseChanged(id);
                      }
                    },
                  ),
                ),
        ),
        const SizedBox(width: 8),
        Text(
          '$rackCount kệ có hàng',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );

    final search = TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      onChanged: (_) => onSearchChanged(),
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Tìm tên hàng, SKU hoặc mã kệ',
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Xóa tìm kiếm',
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  controller.clear();
                  onSearchChanged();
                },
              ),
        border: const OutlineInputBorder(),
      ),
    );
    return Material(
      color: c.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 650;
            final availableHeight =
                MediaQuery.sizeOf(context).height -
                MediaQuery.viewInsetsOf(context).bottom;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (narrow) ...[
                  selector,
                  const SizedBox(height: 4),
                  search,
                ] else
                  Row(
                    children: [
                      Expanded(child: selector),
                      const SizedBox(width: 24),
                      Expanded(child: search),
                    ],
                  ),
                if (query.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    matches.isEmpty
                        ? 'Không tìm thấy mặt hàng trong kho này.'
                        : '${matches.length} kết quả',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  if (matches.isNotEmpty)
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: math.min(170, availableHeight * .23),
                      ),
                      child: ListView.builder(
                        key: ValueKey((warehouseId, query)),
                        primary: false,
                        shrinkWrap: true,
                        itemCount: matches.length,
                        itemBuilder: (context, index) {
                          final row = matches[index];
                          final address =
                              'Kệ ${row['rack']} · Tầng ${row['level']} · Ô ${row['bin']}';
                          final sku = row['sku']?.toString() ?? '';
                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                            ),
                            title: Text(
                              '${row['productName']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              sku.isEmpty ? address : '$sku · $address',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(Icons.chevron_right, size: 18),
                            onTap: () {
                              FocusScope.of(context).unfocus();
                              onOpenPosition(row);
                            },
                          );
                        },
                      ),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
