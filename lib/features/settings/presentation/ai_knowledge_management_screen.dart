import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../../../core/widgets/app_confirm_modal.dart';
import '../providers/ai_knowledge_provider.dart';

class AiKnowledgeManagementScreen extends ConsumerWidget {
  const AiKnowledgeManagementScreen({super.key});

  void _showAddDocumentModal(BuildContext context, WidgetRef ref) {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    String category = 'Thuế HKD';

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppColors.primary,
                              radius: 16,
                              child: const Icon(
                                Icons.note_add_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Thêm nguồn tham khảo',
                              style: GoogleFonts.manrope(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Tiêu đề tài liệu hoặc quy định',
                        hintText:
                            'VD: Thông tư 40/2021/TT-BTC, Quy định chiết khấu...',
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: const InputDecoration(
                        labelText: 'Danh mục tài liệu',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Thuế HKD',
                          child: Text('Thuế hộ kinh doanh'),
                        ),
                        DropdownMenuItem(
                          value: 'Bán Hàng & Sổ Nợ',
                          child: Text('Bán hàng và sổ nợ'),
                        ),
                        DropdownMenuItem(
                          value: 'Kho & Tài Chính',
                          child: Text('Kho và quản lý tiền mặt'),
                        ),
                        DropdownMenuItem(
                          value: 'Cửa Hàng',
                          child: Text('Quy định cửa hàng'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) setModalState(() => category = v);
                      },
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: contentCtrl,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Nội dung tài liệu',
                        hintText:
                            'Nhập nội dung cần dùng làm nguồn tham khảo...',
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () {
                        if (titleCtrl.text.trim().isEmpty ||
                            contentCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Vui lòng nhập đầy đủ tiêu đề và nội dung tài liệu.',
                              ),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }
                        ref
                            .read(aiKnowledgeProvider.notifier)
                            .addDocument(
                              title: titleCtrl.text,
                              category: category,
                              content: contentCtrl.text,
                            );
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã thêm nguồn tài liệu.'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.white,
                      ),
                      label: Text(
                        'Lưu nguồn',
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppThemeColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final docs = ref.watch(aiKnowledgeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Nguồn tài liệu tham khảo',
          style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Nạp tài liệu mới',
            onPressed: () => _showAddDocumentModal(context, ref),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Informational banner
            AppCardContainer(
              backgroundColor: AppColors.primary.withValues(alpha: 0.08),
              borderColor: AppColors.primary.withValues(alpha: 0.3),
              child: Row(
                children: [
                  Icon(
                    Icons.verified_user_rounded,
                    color: AppColors.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nguồn đang được sử dụng',
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: c.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tính năng tra cứu chỉ tìm trong các tài liệu đang bật bên dưới. Hãy kiểm tra nội dung và ngày hiệu lực trước khi sử dụng.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: c.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                AppSectionHeader(
                  title: 'Danh sách tài liệu',
                  icon: HugeIcons.strokeRoundedFolder01,
                  iconColor: AppColors.primary,
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddDocumentModal(context, ref),
                  icon: const Icon(Icons.note_add_rounded, size: 16),
                  label: const Text('Thêm tài liệu'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            if (docs.isEmpty)
              Padding(
                padding: const EdgeInsets.all(40),
                child: Center(
                  child: Text(
                    'Chưa có tài liệu nào trong kho. Bấm [Nạp Tài Liệu] để bắt đầu!',
                    style: GoogleFonts.inter(fontSize: 13, color: c.textMuted),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    child: AppCardContainer(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: doc.isActive
                                      ? AppColors.success.withValues(
                                          alpha: 0.15,
                                        )
                                      : c.textMuted.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  doc.category,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: doc.isActive
                                        ? AppColors.success
                                        : c.textMuted,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                doc.isActive ? 'ĐANG DÙNG' : 'ĐÃ TẮT',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: doc.isActive
                                      ? AppColors.success
                                      : c.textMuted,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Switch(
                                value: doc.isActive,
                                activeThumbColor: AppColors.success,
                                onChanged: (_) {
                                  ref
                                      .read(aiKnowledgeProvider.notifier)
                                      .toggleDocument(doc.id);
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            doc.title,
                            style: GoogleFonts.manrope(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: c.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF0F172A)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              doc.content,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: c.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Nạp ngày: ${DateFormat('dd/MM/yyyy HH:mm').format(doc.createdAt)}',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: c.textMuted,
                                ),
                              ),
                              // REMOVE / DELETE DOCUMENT BUTTON
                              TextButton.icon(
                                onPressed: () async {
                                  final confirm = await AppConfirmModal.show(
                                    context,
                                    title: 'Xóa tài liệu?',
                                    message:
                                        'Bạn có chắc chắn muốn xóa "${doc.title}" khỏi nguồn tham khảo?',
                                    confirmText: 'Xóa tài liệu',
                                    isDestructive: true,
                                  );
                                  if (confirm == true) {
                                    ref
                                        .read(aiKnowledgeProvider.notifier)
                                        .removeDocument(doc.id);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Đã xóa tài liệu "${doc.title}".',
                                          ),
                                          backgroundColor: AppColors.danger,
                                        ),
                                      );
                                    }
                                  }
                                },
                                icon: const Icon(
                                  Icons.delete_forever_rounded,
                                  size: 16,
                                  color: AppColors.danger,
                                ),
                                label: const Text(
                                  'Xóa',
                                  style: TextStyle(
                                    color: AppColors.danger,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 88), // UI Breathing Room Padding
          ],
        ),
      ),
    );
  }
}
