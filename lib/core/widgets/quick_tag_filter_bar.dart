import 'package:flutter/material.dart';

import '../assets/app_assets.dart';
import '../assets/app_icon.dart';
import '../theme/app_theme.dart';
import '../theme/tag_colors.dart';
import '../utils/search_text.dart';

/// A colorful, highly-responsive tag filter bar supporting both multi-select and single-select modes.
class QuickTagFilterBar extends StatefulWidget {
  final List<String> tags;
  final String? value;
  final ValueChanged<String>? onChanged;
  final Set<String>? selectedTags;
  final ValueChanged<String>? onToggleTag;
  final bool inStockOnly;
  final VoidCallback? onToggleInStock;
  final VoidCallback onClear;
  final bool hasFilters;
  final int visibleLimit;
  final Map<String, Color> tagColors;

  const QuickTagFilterBar({
    super.key,
    required this.tags,
    this.value,
    this.onChanged,
    this.selectedTags,
    this.onToggleTag,
    this.inStockOnly = false,
    this.onToggleInStock,
    required this.onClear,
    this.hasFilters = false,
    this.visibleLimit = 12,
    this.tagColors = const {},
  });

  @override
  State<QuickTagFilterBar> createState() => _QuickTagFilterBarState();
}

class _QuickTagFilterBarState extends State<QuickTagFilterBar> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  bool get _isMultiSelect => widget.selectedTags != null;

  Future<void> _showAll(List<String> allTags) async {
    if (_isMultiSelect) {
      await showDialog<void>(
        context: context,
        builder: (dialogCtx) => StatefulBuilder(
          builder: (ctx, setDialogState) {
            return _MultiTagSelectDialog(
              tags: allTags,
              tagColors: widget.tagColors,
              selectedTags: widget.selectedTags!,
              inStockOnly: widget.inStockOnly,
              onToggleTag: (tag) {
                widget.onToggleTag?.call(tag);
                setDialogState(() {});
              },
              onToggleInStock: widget.onToggleInStock != null
                  ? () {
                      widget.onToggleInStock!();
                      setDialogState(() {});
                    }
                  : null,
              onClearAll: () {
                widget.onClear();
                setDialogState(() {});
              },
            );
          },
        ),
      );
    } else {
      final choice = await showDialog<String>(
        context: context,
        builder: (_) => _SingleTagDialog(
          tags: widget.tags,
          value: widget.value ?? '',
          tagColors: widget.tagColors,
        ),
      );
      if (choice != null && mounted) widget.onChanged?.call(choice);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final all = widget.tags.toSet().toList();
    final quick = all.take(widget.visibleLimit).toList();

    if (_isMultiSelect) {
      for (final sel in widget.selectedTags!) {
        if (!quick.contains(sel) && all.contains(sel)) {
          quick.add(sel);
        }
      }
    } else if (widget.value != null &&
        widget.value!.isNotEmpty &&
        !quick.contains(widget.value)) {
      if (quick.length == widget.visibleLimit) quick.removeLast();
      quick.add(widget.value!);
    }

    final isAllSelected = _isMultiSelect
        ? (widget.selectedTags!.isEmpty && !widget.inStockOnly)
        : ((widget.value == null || widget.value!.isEmpty) &&
              !widget.hasFilters);

    Widget buildChip({
      required String label,
      required bool selected,
      required VoidCallback onTap,
      IconData? icon,
      Color? customAccent,
      Key? key,
    }) {
      final accent =
          customAccent ??
          (label == 'Tất cả'
              ? colors.primary
              : TagColors.resolve(label, configured: widget.tagColors[label]));
      final background = TagColors.surface(
        accent,
        colors.card,
        selected: selected,
      );
      final foreground = TagColors.foreground(accent, background);

      return Material(
        color: Colors.transparent,
        child: InkWell(
          key: key,
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: accent.withValues(alpha: selected ? 1.0 : 0.45),
                width: selected ? 1.8 : 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14, color: foreground),
                  const SizedBox(width: 5),
                ] else if (selected && label != 'Tất cả') ...[
                  Icon(Icons.check_rounded, size: 13, color: foreground),
                  const SizedBox(width: 4),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                    color: foreground,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final selectedCount = _isMultiSelect ? widget.selectedTags!.length : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              key: const Key('quick-tag-options'),
              tooltip: _isMultiSelect
                  ? 'Tìm và chọn nhãn (${widget.selectedTags!.length}/${all.length})'
                  : 'Bộ lọc · tìm trong tất cả ${all.length} nhãn',
              onPressed: () => _showAll(all),
              icon: AppAssetIcon(
                assetPath: AppAssets.filter,
                size: 20,
                color: (_isMultiSelect && widget.selectedTags!.isNotEmpty)
                    ? colors.primary
                    : colors.textSecondary,
              ),
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            ),
            const SizedBox(width: 4),
            buildChip(
              label: 'Tất cả',
              selected: isAllSelected,
              onTap: widget.onClear,
              key: const Key('product-all-filter'),
            ),
            const SizedBox(width: 8),
            if (widget.onToggleInStock != null) ...[
              buildChip(
                label: 'Có tồn kho',
                selected: widget.inStockOnly,
                icon: Icons.inventory_2_outlined,
                customAccent: AppColors.success,
                onTap: widget.onToggleInStock!,
                key: const Key('product-in-stock-chip'),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Scrollbar(
                controller: _scroll,
                child: SingleChildScrollView(
                  controller: _scroll,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      for (final name in quick)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Semantics(
                            button: true,
                            selected: _isMultiSelect
                                ? widget.selectedTags!.contains(name)
                                : widget.value == name,
                            label:
                                (_isMultiSelect
                                    ? widget.selectedTags!.contains(name)
                                    : widget.value == name)
                                ? 'Bỏ lọc nhãn $name'
                                : 'Lọc theo nhãn $name',
                            child: buildChip(
                              label: name,
                              selected: _isMultiSelect
                                  ? widget.selectedTags!.contains(name)
                                  : widget.value == name,
                              onTap: () {
                                if (_isMultiSelect) {
                                  widget.onToggleTag?.call(name);
                                } else {
                                  widget.onChanged?.call(
                                    widget.value == name ? '' : name,
                                  );
                                }
                              },
                              key: ValueKey('quick-tag-$name'),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (widget.hasFilters)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Row(
              children: [
                TextButton.icon(
                  key: const Key('product-reset-filters'),
                  onPressed: widget.onClear,
                  icon: const AppIcon(Icons.filter_alt_off_rounded, size: 15),
                  label: const Text('Bỏ lọc', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                ),
                if (_isMultiSelect && selectedCount > 0) ...[
                  const SizedBox(width: 8),
                  Text(
                    'Đã chọn $selectedCount nhãn',
                    style: TextStyle(fontSize: 11, color: colors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _MultiTagSelectDialog extends StatefulWidget {
  final List<String> tags;
  final Map<String, Color> tagColors;
  final Set<String> selectedTags;
  final bool inStockOnly;
  final ValueChanged<String> onToggleTag;
  final VoidCallback? onToggleInStock;
  final VoidCallback onClearAll;

  const _MultiTagSelectDialog({
    required this.tags,
    required this.tagColors,
    required this.selectedTags,
    required this.inStockOnly,
    required this.onToggleTag,
    required this.onToggleInStock,
    required this.onClearAll,
  });

  @override
  State<_MultiTagSelectDialog> createState() => _MultiTagSelectDialogState();
}

class _MultiTagSelectDialogState extends State<_MultiTagSelectDialog> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final all = widget.tags.toSet().toList();
    final matches = all
        .where((name) => foldSearchText(name).contains(foldSearchText(_query)))
        .toList();

    final totalSelected =
        widget.selectedTags.length + (widget.inStockOnly ? 1 : 0);

    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Text(
              'Chọn nhãn lọc ($totalSelected đã chọn)',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          if (totalSelected > 0)
            TextButton(
              onPressed: widget.onClearAll,
              child: const Text(
                'Bỏ chọn tất cả',
                style: TextStyle(fontSize: 12),
              ),
            ),
        ],
      ),
      content: SizedBox(
        width: 440,
        height: 420,
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              autofocus: false,
              decoration: InputDecoration(
                hintText: 'Tìm nhãn sản phẩm...',
                prefixIcon: const AppAssetIcon(
                  assetPath: AppAssets.search,
                  size: 18,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 8),

            // Mục Có tồn kho ở đầu danh sách nếu có hỗ trợ
            if (widget.onToggleInStock != null &&
                (_query.isEmpty ||
                    foldSearchText(
                      'Có tồn kho',
                    ).contains(foldSearchText(_query)))) ...[
              CheckboxListTile(
                dense: true,
                value: widget.inStockOnly,
                onChanged: (_) => widget.onToggleInStock!(),
                title: const Text(
                  'Có tồn kho',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                secondary: const Icon(
                  Icons.inventory_2_outlined,
                  color: AppColors.success,
                  size: 20,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              ),
              const Divider(height: 1),
            ],

            Expanded(
              child: matches.isEmpty
                  ? const Center(child: Text('Không tìm thấy nhãn phù hợp'))
                  : ListView.builder(
                      itemCount: matches.length,
                      itemBuilder: (ctx, index) {
                        final tag = matches[index];
                        final isSelected = widget.selectedTags.contains(tag);
                        final tagColor = TagColors.resolve(
                          tag,
                          configured: widget.tagColors[tag],
                        );

                        return CheckboxListTile(
                          dense: true,
                          value: isSelected,
                          onChanged: (_) => widget.onToggleTag(tag),
                          title: Text(tag),
                          secondary: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: tagColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Áp dụng'),
        ),
      ],
    );
  }
}

class _SingleTagDialog extends StatefulWidget {
  final List<String> tags;
  final String value;
  final Map<String, Color> tagColors;
  const _SingleTagDialog({
    required this.tags,
    required this.value,
    required this.tagColors,
  });
  @override
  State<_SingleTagDialog> createState() => _SingleTagDialogState();
}

class _SingleTagDialogState extends State<_SingleTagDialog> {
  final _search = TextEditingController();
  String _query = '';
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matches = widget.tags
        .toSet()
        .where((name) => foldSearchText(name).contains(foldSearchText(_query)))
        .toList();
    return AlertDialog(
      title: Text('Chọn nhãn lọc (${widget.tags.toSet().length})'),
      content: SizedBox(
        width: 420,
        height: 400,
        child: Column(
          children: [
            TextField(
              key: const Key('quick-tag-search'),
              controller: _search,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Tìm nhãn...',
                prefixIcon: AppAssetIcon(assetPath: AppAssets.search, size: 18),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: matches.isEmpty
                  ? const Center(child: Text('Không tìm thấy nhãn phù hợp'))
                  : ListView.builder(
                      itemCount: matches.length,
                      itemBuilder: (_, index) => ListTile(
                        leading: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: TagColors.resolve(
                              matches[index],
                              configured: widget.tagColors[matches[index]],
                            ),
                            shape: BoxShape.circle,
                          ),
                        ),
                        title: Text(matches[index]),
                        selected: matches[index] == widget.value,
                        trailing: matches[index] == widget.value
                            ? const AppAssetIcon(
                                assetPath: AppAssets.check,
                                size: 18,
                              )
                            : null,
                        onTap: () => Navigator.of(context).pop(matches[index]),
                      ),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Đóng'),
        ),
      ],
    );
  }
}
