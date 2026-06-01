import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/tag_provider.dart';

class TagManagementScreen extends ConsumerStatefulWidget {
  final String type;
  const TagManagementScreen({super.key, this.type = 'product'});

  @override
  ConsumerState<TagManagementScreen> createState() => _TagManagementScreenState();
}

class _TagManagementScreenState extends ConsumerState<TagManagementScreen> {
  final List<String> _predefinedColors = [
    '#EF4444', '#F97316', '#F59E0B', '#10B981', '#3B82F6', '#6366F1', '#8B5CF6', '#EC4899', '#64748B', '#000000'
  ];

  Future<void> _showTagDialog({TagModel? tag}) async {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);
    
    final nameCtrl = TextEditingController(text: tag?.name);
    String selectedColor = tag?.color ?? _predefinedColors[4];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 20, right: 20, top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tag == null ? 'Tạo Nhãn (Tag) Mới' : 'Chỉnh sửa Nhãn',
                    style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: c.textPrimary),
                  ),
                  const SizedBox(height: 20),
                  Text('Tên nhãn', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: c.textSecondary)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: nameCtrl,
                    style: GoogleFonts.inter(color: c.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Nhập tên nhãn...',
                      filled: true,
                      fillColor: c.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Màu sắc', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: c.textSecondary)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _predefinedColors.map((hex) {
                      final isSelected = selectedColor == hex;
                      final colorVal = Color(int.parse('FF${hex.substring(1)}', radix: 16));
                      return GestureDetector(
                        onTap: () => setModalState(() => selectedColor = hex),
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: colorVal,
                            shape: BoxShape.circle,
                            border: isSelected ? Border.all(color: theme.colorScheme.primary, width: 3) : null,
                            boxShadow: isSelected ? [BoxShadow(color: colorVal.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 4))] : null,
                          ),
                          child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) return;
                        
                        try {
                          if (tag == null) {
                            await ref.read(tagRepoProvider).create(name, selectedColor, type: widget.type);
                          } else {
                            await ref.read(tagRepoProvider).update(tag.id, name, selectedColor, type: widget.type);
                          }
                          ref.invalidate(tagListProvider(widget.type));
                          if (context.mounted) Navigator.pop(ctx);
                        } catch (e) {
                          // error
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Lưu thay đổi', style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteTag(TagModel tag) async {
    final c = AppThemeColors.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.bg,
        title: Text('Xóa nhãn?', style: GoogleFonts.outfit(color: c.textPrimary)),
        content: Text('Bạn có chắc muốn xóa nhãn "${tag.name}"? Các sản phẩm đang gắn nhãn này sẽ không bị ảnh hưởng.', style: GoogleFonts.inter(color: c.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xóa', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(tagRepoProvider).delete(tag.id);
        ref.invalidate(tagListProvider(widget.type));
      } catch (e) {
        // error
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);
    final tagsAsync = ref.watch(tagListProvider(widget.type));
    final isOwner = ref.watch(authProvider).isShopOwner;

    if (!isOwner) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quản lý nhãn')),
        body: Center(
          child: Text('Bạn không có quyền truy cập tính năng này', style: GoogleFonts.inter(fontSize: 16)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Quản lý Nhãn (Tags)',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20, color: c.textPrimary),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showTagDialog(),
        icon: const HugeIcon(icon: HugeIcons.strokeRoundedTag01, color: Colors.white, size: 24),
        label: Text('Tạo nhãn', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: theme.colorScheme.primary,
      ),
      body: tagsAsync.when(
        data: (tags) {
          if (tags.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.local_offer_outlined, size: 64, color: c.divider),
                  const SizedBox(height: 16),
                  Text('Chưa có nhãn nào', style: GoogleFonts.outfit(fontSize: 20, color: c.textSecondary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Bấm "Tạo nhãn" để phân loại sản phẩm của bạn.', style: GoogleFonts.inter(color: c.textSecondary)),
                ],
              ),
            );
          }
          
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tags.length,
            itemBuilder: (ctx, i) {
              final tag = tags[i];
              return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: c.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: c.divider.withValues(alpha: 0.3)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: tag.uiColor.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.sell_rounded, color: tag.uiColor, size: 20),
                    ),
                    title: Text(tag.name, style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: c.textPrimary)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: HugeIcon(icon: HugeIcons.strokeRoundedEdit02, color: c.textSecondary, size: 20),
                          onPressed: () => _showTagDialog(tag: tag),
                        ),
                        IconButton(
                          icon: HugeIcon(icon: HugeIcons.strokeRoundedDelete02, color: Colors.red.withValues(alpha: 0.7), size: 20),
                          onPressed: () => _deleteTag(tag),
                        ),
                      ],
                    ),
                  ),
                );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Đã có lỗi xảy ra', style: TextStyle(color: c.textPrimary))),
      ),
    );
  }
}
