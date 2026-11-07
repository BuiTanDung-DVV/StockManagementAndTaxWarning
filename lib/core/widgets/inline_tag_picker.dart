import 'package:flutter/foundation.dart';
import '../network/api_client.dart';
import '../../core/assets/app_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';

import '../theme/app_theme.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/products/providers/tag_provider.dart';

class InlineTagPicker extends ConsumerStatefulWidget {
  final String type;
  final List<String> selectedTags;
  final ValueChanged<List<String>> onTagsChanged;

  const InlineTagPicker({
    super.key,
    required this.type,
    required this.selectedTags,
    required this.onTagsChanged,
  });

  @override
  ConsumerState<InlineTagPicker> createState() => _InlineTagPickerState();
}

class _InlineTagPickerState extends ConsumerState<InlineTagPicker> {
  bool _isCreating = false;
  bool _isSaving = false;
  String? _saveError;
  late List<String> _selectedTags;
  final Map<String, TagModel> _createdTags = {};

  @override
  void initState() {
    super.initState();
    _selectedTags = widget.selectedTags.toSet().toList();
  }

  @override
  void didUpdateWidget(covariant InlineTagPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.selectedTags, widget.selectedTags)) {
      _selectedTags = widget.selectedTags.toSet().toList();
    }
  }

  void _select(String name, bool selected) {
    setState(() {
      if (selected && !_selectedTags.contains(name)) _selectedTags.add(name);
      if (!selected) _selectedTags.remove(name);
    });
    widget.onTagsChanged(List.of(_selectedTags));
  }

  Future<void> _save() async {
    if (_isSaving) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _saveError = 'Vui lòng nhập tên nhãn.');
      return;
    }
    setState(() {
      _isSaving = true;
      _saveError = null;
    });
    try {
      final tag = await ref
          .read(tagRepoProvider)
          .create(name, _selectedColor, type: widget.type);
      if (!mounted) return;
      setState(() {
        _createdTags[tag.name] = tag;
        if (!_selectedTags.contains(tag.name)) _selectedTags.add(tag.name);
        _isCreating = false;
        _nameCtrl.clear();
      });
      widget.onTagsChanged(List.of(_selectedTags));
      // Reload in the background. The returned, persisted tag is already visible.
      ref.invalidate(tagListProvider(widget.type));
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _saveError =
            error is ApiException && error.message.contains('đã tồn tại')
            ? 'Tên nhãn đã tồn tại. Hãy chọn nhãn có sẵn hoặc nhập tên khác.'
            : 'Không thể lưu nhãn. Nội dung đang nhập được giữ lại để thử lại.',
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  final _nameCtrl = TextEditingController();
  final List<String> _predefinedColors = [
    '#EF4444',
    '#F97316',
    '#F59E0B',
    '#10B981',
    '#3B82F6',
    '#6366F1',
    '#8B5CF6',
    '#EC4899',
    '#64748B',
    '#000000',
  ];
  String _selectedColor = '#3B82F6';

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);
    final tagsAsync = ref.watch(tagListProvider(widget.type));

    return PopScope(
      canPop: !_isSaving,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isCreating ? 'Tạo nhãn mới' : 'Chọn nhãn',
                  style: GoogleFonts.manrope(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: c.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const AppIcon(Icons.close),
                  onPressed: _isSaving ? null : () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (!_isCreating) ...[
              _buildTagChoices(tagsAsync),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => setState(() {
                        _isCreating = true;
                        _saveError = null;
                      }),
                      icon: const AppIcon(
                        Icons.add,
                        color: Colors.blue,
                        size: 20,
                      ),
                      label: const Text('Tạo nhãn mới'),
                    ),
                  ),
                  if (ref.watch(authProvider).isShopOwner) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          context.push(
                            '/products/tags',
                            extra: {'type': widget.type},
                          );
                        },
                        icon: const AppHugeIcon(
                          icon: HugeIcons.strokeRoundedSettings01,
                          color: Colors.blue,
                          size: 20,
                        ),
                        label: const Text('Quản lý nâng cao'),
                      ),
                    ),
                  ],
                ],
              ),
            ] else ...[
              Text(
                'Tên nhãn',
                style: GoogleFonts.inter(fontSize: 13, color: c.textSecondary),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameCtrl,
                enabled: !_isSaving,
                style: GoogleFonts.inter(color: c.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Nhập tên...',
                  filled: true,
                  fillColor: c.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Màu sắc',
                style: GoogleFonts.inter(fontSize: 13, color: c.textSecondary),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _predefinedColors.map((hex) {
                  final isSelected = _selectedColor == hex;
                  final colorVal = Color(
                    int.parse('FF${hex.substring(1)}', radix: 16),
                  );
                  return GestureDetector(
                    onTap: _isSaving
                        ? null
                        : () => setState(() => _selectedColor = hex),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: colorVal,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(
                                color: theme.colorScheme.primary,
                                width: 2,
                              )
                            : null,
                      ),
                      child: isSelected
                          ? const AppIcon(
                              Icons.check,
                              color: Colors.white,
                              size: 16,
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isSaving
                          ? null
                          : () => setState(() => _isCreating = false),
                      child: const Text('Hủy'),
                    ),
                  ),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _isSaving ? 'Đang lưu…' : 'Lưu & Chọn',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (_saveError != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _saveError!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildTagChoices(AsyncValue<List<TagModel>> source) {
    final tags = <String, TagModel>{
      for (final tag in source.value ?? <TagModel>[]) tag.name: tag,
      ..._createdTags,
    };
    for (final selected in _selectedTags) {
      tags.putIfAbsent(
        selected,
        () => TagModel(
          id: -1,
          name: selected,
          color: '#64748B',
          type: widget.type,
        ),
      );
    }
    if (tags.isEmpty && source.isLoading)
      return const Center(child: CircularProgressIndicator());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (source.hasError)
          TextButton.icon(
            onPressed: () => ref.invalidate(tagListProvider(widget.type)),
            icon: const AppIcon(Icons.refresh, size: 18),
            label: const Text('Không tải được danh sách nhãn · Thử lại'),
          ),
        if (tags.isEmpty && !source.hasError)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Chưa có nhãn nào. Hãy tạo mới.'),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tags.values.map((tag) {
            final selected = _selectedTags.contains(tag.name);
            return FilterChip(
              label: Text(
                tag.name,
                style: TextStyle(
                  color: selected ? Colors.white : tag.uiColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              selected: selected,
              onSelected: (value) => _select(tag.name, value),
              selectedColor: tag.uiColor,
              backgroundColor: tag.uiColor.withValues(alpha: .1),
              side: BorderSide(color: tag.uiColor.withValues(alpha: .3)),
              checkmarkColor: Colors.white,
            );
          }).toList(),
        ),
      ],
    );
  }
}
