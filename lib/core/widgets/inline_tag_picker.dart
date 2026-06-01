import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';

import '../theme/app_theme.dart';
import '../utils/toast_service.dart';
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
  final _nameCtrl = TextEditingController();
  final List<String> _predefinedColors = ['#EF4444', '#F97316', '#F59E0B', '#10B981', '#3B82F6', '#6366F1', '#8B5CF6', '#EC4899', '#64748B', '#000000'];
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

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_isCreating ? 'Tạo nhãn mới' : 'Chọn nhãn', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: c.textPrimary)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 16),
          if (!_isCreating) ...[
            tagsAsync.when(
              data: (tags) {
                if (tags.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Chưa có nhãn nào. Hãy tạo mới.', style: GoogleFonts.inter(color: c.textSecondary)),
                  );
                }
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: tags.map((t) {
                    final isSelected = widget.selectedTags.contains(t.name);
                    return FilterChip(
                      label: Text(t.name, style: TextStyle(color: isSelected ? Colors.white : t.uiColor, fontWeight: FontWeight.w500)),
                      selected: isSelected,
                      onSelected: (selected) {
                        final newTags = List<String>.from(widget.selectedTags);
                        if (selected) {
                          newTags.add(t.name);
                        } else {
                          newTags.remove(t.name);
                        }
                        widget.onTagsChanged(newTags);
                      },
                      selectedColor: t.uiColor,
                      backgroundColor: t.uiColor.withValues(alpha: 0.1),
                      side: BorderSide(color: t.uiColor.withValues(alpha: 0.3)),
                      checkmarkColor: Colors.white,
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Text('Lỗi tải danh sách nhãn'),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _isCreating = true),
                    icon: const Icon(Icons.add, color: Colors.blue, size: 20),
                    label: const Text('Tạo nhãn mới'),
                  ),
                ),
                if (ref.watch(authProvider).isShopOwner) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        context.push('/products/tags', extra: {'type': widget.type});
                      },
                      icon: const HugeIcon(icon: HugeIcons.strokeRoundedSettings01, color: Colors.blue, size: 20),
                      label: const Text('Quản lý nâng cao'),
                    ),
                  ),
                ]
              ],
            ),
          ] else ...[
            Text('Tên nhãn', style: GoogleFonts.inter(fontSize: 13, color: c.textSecondary)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameCtrl,
              style: GoogleFonts.inter(color: c.textPrimary),
              decoration: InputDecoration(
                hintText: 'Nhập tên...',
                filled: true,
                fillColor: c.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            Text('Màu sắc', style: GoogleFonts.inter(fontSize: 13, color: c.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _predefinedColors.map((hex) {
                final isSelected = _selectedColor == hex;
                final colorVal = Color(int.parse('FF${hex.substring(1)}', radix: 16));
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = hex),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: colorVal,
                      shape: BoxShape.circle,
                      border: isSelected ? Border.all(color: theme.colorScheme.primary, width: 2) : null,
                    ),
                    child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => setState(() => _isCreating = false),
                    child: const Text('Hủy'),
                  ),
                ),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final name = _nameCtrl.text.trim();
                      if (name.isEmpty) return;
                      try {
                        final tag = await ref.read(tagRepoProvider).create(name, _selectedColor, type: widget.type);
                        if (!mounted) return;
                        
                        final newTags = List<String>.from(widget.selectedTags)..add(tag.name);
                        widget.onTagsChanged(newTags);
                        
                        ref.invalidate(tagListProvider(widget.type));
                        setState(() => _isCreating = false);
                      } catch (e) {
                        ToastService.showError('Tên nhãn đã tồn tại hoặc có lỗi');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Lưu & Chọn', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
