import 'package:flutter/material.dart';

import '../assets/app_assets.dart';
import '../theme/app_theme.dart';
import '../theme/tag_colors.dart';
import '../utils/search_text.dart';

/// A short strip of frequent choices; the complete searchable picker stays first.
class QuickTagFilterBar extends StatefulWidget {
  final List<String> tags;
  final String value;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final bool hasFilters;
  final int visibleLimit;
  final Map<String, Color> tagColors;

  const QuickTagFilterBar({
    super.key,
    required this.tags,
    required this.value,
    required this.onChanged,
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

  Future<void> _showAll() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (_) => _AllTagsDialog(
        tags: widget.tags,
        value: widget.value,
        tagColors: widget.tagColors,
      ),
    );
    if (choice != null && mounted) widget.onChanged(choice);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final all = widget.tags.toSet().toList();
    final quick = all.take(widget.visibleLimit).toList();
    if (widget.value.isNotEmpty && !quick.contains(widget.value)) {
      if (quick.length == widget.visibleLimit) quick.removeLast();
      quick.add(widget.value);
    }
    Widget chip(String label, bool selected, VoidCallback onTap, {Key? key}) {
      final accent = label == 'Tất cả'
          ? colors.primary
          : TagColors.resolve(label, configured: widget.tagColors[label]);
      final background = TagColors.surface(
        accent,
        colors.card,
        selected: selected,
      );
      return ChoiceChip(
        key: key,
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        selectedColor: background,
        backgroundColor: background,
        side: BorderSide(
          color: accent.withValues(alpha: selected ? 1 : 0.45),
          width: selected ? 2 : 1,
        ),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: TagColors.foreground(accent, background),
        ),
        onSelected: (_) => onTap(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              key: const Key('quick-tag-options'),
              tooltip: 'Bộ lọc · tìm trong tất cả ${all.length} nhãn',
              onPressed: _showAll,
              icon: AppAssetIcon(
                assetPath: AppAssets.filter,
                size: 20,
                color: colors.textSecondary,
              ),
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            ),
            const SizedBox(width: 4),
            chip(
              'Tất cả',
              widget.value.isEmpty && !widget.hasFilters,
              widget.onClear,
              key: const Key('product-all-filter'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Scrollbar(
                controller: _scroll,
                child: SingleChildScrollView(
                  controller: _scroll,
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final name in quick)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Semantics(
                            button: true,
                            selected: widget.value == name,
                            label: widget.value == name
                                ? 'Bỏ lọc nhãn $name'
                                : 'Lọc theo nhãn $name',
                            child: chip(
                              name,
                              widget.value == name,
                              () => widget.onChanged(
                                widget.value == name ? '' : name,
                              ),
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
          TextButton(
            key: const Key('product-reset-filters'),
            onPressed: widget.onClear,
            child: const Text('Bỏ lọc'),
          ),
      ],
    );
  }
}

class _AllTagsDialog extends StatefulWidget {
  final List<String> tags;
  final String value;
  final Map<String, Color> tagColors;
  const _AllTagsDialog({
    required this.tags,
    required this.value,
    required this.tagColors,
  });
  @override
  State<_AllTagsDialog> createState() => _AllTagsDialogState();
}

class _AllTagsDialogState extends State<_AllTagsDialog> {
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
