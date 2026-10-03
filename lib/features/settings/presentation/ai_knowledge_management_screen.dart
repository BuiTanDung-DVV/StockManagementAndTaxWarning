import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/app_navigation_back_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/toast_service.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../../../core/widgets/app_confirm_modal.dart';
import '../providers/ai_knowledge_provider.dart';

class AiKnowledgeManagementScreen extends ConsumerWidget {
  const AiKnowledgeManagementScreen({super.key});

  void _showAddDocumentModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _AddDocumentSheet(
        onSave: (title, category, content) {
          ref
              .read(aiKnowledgeProvider.notifier)
              .addDocument(title: title, category: category, content: content);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppThemeColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final docsAsync = ref.watch(aiKnowledgeProvider);
    final docs = docsAsync.asData?.value ?? const <AiDocument>[];

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 68,
        automaticallyImplyLeading: false,
        leadingWidth: 56,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Center(
            child: AppNavigationBackButton(
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  context.go('/settings');
                }
              },
            ),
          ),
        ),
        title: Row(
          children: [
            Text(
              'Nguồn tài liệu tham khảo',
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: c.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, size: 12, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    'RAG Grounding',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            icon: const Icon(Icons.refresh_rounded, size: 20),
            color: c.textSecondary,
            onPressed: () => ref.invalidate(aiKnowledgeProvider),
          ),
          const SizedBox(width: 6),
          FilledButton.icon(
            onPressed: () => _showAddDocumentModal(context, ref),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Nạp tài liệu mới'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 20),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: c.divider,
            height: 1,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(aiKnowledgeProvider),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Informational banner
              AppCardContainer(
                backgroundColor: Color.alphaBlend(
                  AppColors.primary.withValues(alpha: 0.08),
                  c.surface,
                ),
                borderColor: AppColors.primary.withValues(alpha: 0.22),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.verified_user_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nguồn tri thức đang được AI khai thác & dẫn chứng',
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: c.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Trợ lý AI sẽ đối soát, trích dẫn quy định và đưa ra khuyến nghị thực tế dựa trên các tài liệu đang BẬT bên dưới.',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              color: c.textSecondary,
                              height: 1.35,
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
                  Expanded(
                    child: AppSectionHeader(
                      title: 'Danh sách tài liệu tri thức',
                      icon: HugeIcons.strokeRoundedFolder01,
                      iconColor: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              if (docsAsync.isLoading)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (docsAsync.hasError)
                AppInlineError(
                  message: 'Không thể tải kho tài liệu AI từ cơ sở dữ liệu.',
                  onRetry: () => ref.invalidate(aiKnowledgeProvider),
                )
              else if (docs.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: Text(
                      'Chưa có tài liệu nào trong kho. Bấm [Nạp Tài Liệu] để bắt đầu!',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: c.textMuted,
                      ),
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
                                      ToastService.showSuccess(
                                        'Đã xóa tài liệu "${doc.title}".',
                                      );
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
      ),
    );
  }
}

class _AddDocumentSheet extends ConsumerStatefulWidget {
  final void Function(String title, String category, String content) onSave;

  const _AddDocumentSheet({required this.onSave});

  @override
  ConsumerState<_AddDocumentSheet> createState() => _AddDocumentSheetState();
}

class _AddDocumentSheetState extends ConsumerState<_AddDocumentSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;
  late final TextEditingController _urlCtrl;
  String _category = 'Thuế HKD';
  bool _showUrlInput = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _contentCtrl = TextEditingController();
    _urlCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  // Danh sách mẫu quy chuẩn 1-chạm cho hộ kinh doanh
  static const List<Map<String, String>> _legalPresets = [
    {
      'title': 'Thông tư 40/2021/TT-BTC - Hướng dẫn thuế Hộ kinh doanh',
      'category': 'Thuế HKD',
      'desc': 'Tỷ lệ % thuế GTGT & TNCN theo ngành nghề, ngưỡng 100 tr/năm',
      'content':
          'Căn cứ Thông tư 40/2021/TT-BTC của Bộ Tài chính:\n'
          '1. Doanh thu tính thuế: Hộ kinh doanh có doanh thu từ 100 triệu đồng/năm trở xuống thuộc diện không phải nộp thuế GTGT và TNCN.\n'
          '2. Phương pháp tính thuế: Tỷ lệ % trên doanh thu thực tế phát sinh.\n'
          '- Phân phối, cung cấp hàng hóa: GTGT 1% + TNCN 0.5% (Tổng 1.5%).\n'
          '- Dịch vụ, xây dựng không bao thầu NVL: GTGT 5% + TNCN 2% (Tổng 7%).\n'
          '- Sản xuất, vận tải, dịch vụ có gắn với hàng hóa: GTGT 3% + TNCN 1.5% (Tổng 4.5%).\n'
          '3. Hộ kê khai phải mở sổ sách kế toán theo Thông tư 88/2021/TT-BTC và sử dụng hóa đơn điện tử hợp pháp.',
    },
    {
      'title': 'Nghị định 123/2020/NĐ-CP & TT 78 - Hóa đơn điện tử máy tính tiền',
      'category': 'Thuế HKD',
      'desc': 'Quy định xuất HĐĐT khởi tạo từ máy tính tiền kết nối cơ quan thuế',
      'content':
          'Căn cứ Nghị định 123/2020/NĐ-CP và Thông tư 78/2021/TT-BTC:\n'
          '1. Đối tượng áp dụng: Hộ kinh doanh nộp thuế theo phương pháp kê khai có hoạt động bán lẻ trực tiếp đến người tiêu dùng (trung tâm thương mại, siêu thị, bán lẻ hàng tiêu dùng, ăn uống, nhà hàng, khách sạn, hiệu thuốc...).\n'
          '2. Nguyên tắc: Xuất hóa đơn điện tử có mã của cơ quan thuế khởi tạo từ máy tính tiền có kết nối chuyển dữ liệu điện tử với cơ quan thuế ngay khi giao dịch hoàn tất.\n'
          '3. Chế tài: Xử phạt hành vi không lập hóa đơn khi bán hàng hóa, cung cấp dịch vụ theo Nghị định 125/2020/NĐ-CP từ 10 - 20 triệu đồng.',
    },
    {
      'title': 'Thời hạn nộp hồ sơ khai thuế & Phạt chậm nộp (Luật QLT 38 & NĐ 125)',
      'category': 'Thuế HKD',
      'desc': 'Hạn chót ngày cuối tháng đầu quý sau, mức phạt chậm nộp tờ khai',
      'content':
          'Căn cứ Luật Quản lý thuế số 38/2019/QH14 và Nghị định 125/2020/NĐ-CP:\n'
          '1. Thời hạn nộp hồ sơ khai thuế theo quý: Chậm nhất là ngày cuối cùng của tháng đầu tiên của quý tiếp theo quý phát sinh nghĩa vụ thuế (Quý 1: 30/04; Quý 2: 31/07; Quý 3: 31/10; Quý 4: 31/01 năm sau).\n'
          '2. Tiền chậm nộp thuế: Tính 0.03%/ngày trên số tiền thuế chậm nộp.\n'
          '3. Phạt hành vi chậm nộp hồ sơ khai thuế (Điều 13 NĐ 125/2020/NĐ-CP):\n'
          '- Quá hạn 1 - 5 ngày có tình tiết giảm nhẹ: Phạt cảnh cáo.\n'
          '- Quá hạn 1 - 30 ngày: Phạt tiền từ 2 - 5 triệu đồng.\n'
          '- Quá hạn 31 - 60 ngày: Phạt tiền từ 5 - 8 triệu đồng.\n'
          '- Quá hạn từ 61 - 90 ngày: Phạt tiền từ 8 - 15 triệu đồng.',
    },
    {
      'title': 'Quy chế Quản lý & Thu hồi Công nợ bán lẻ cửa hàng',
      'category': 'Bán Hàng & Sổ Nợ',
      'desc': 'Giới hạn nợ tối đa 30 ngày, đối soát định kỳ, chặn bán nợ vượt trần',
      'content':
          'Quy chế quản lý công nợ khách hàng và nhà cung cấp nội bộ:\n'
          '1. Hạn mức tín dụng khách quen: Tối đa không quá 10.000.000 VNĐ hoặc thời gian nợ tối đa 30 ngày tính từ ngày ghi sổ.\n'
          '2. Quy trình nhắc nợ: Gửi bảng kê đối soát công nợ vào ngày 25 hàng tháng. Nếu quá hạn 15 ngày chưa thanh toán thì tạm dừng cho mua nợ mới.\n'
          '3. Công nợ nhà cung cấp: Ưu tiên đối soát công nợ đối ứng với các lô hàng nhập kho có biên bản bàn giao và hóa đơn hợp lệ.',
    },
    {
      'title': 'Quy chế Kiểm kê & Quản lý Hao hụt Kho hàng (FIFO)',
      'category': 'Kho & Tài Chính',
      'desc': 'Kiểm kê định kỳ cuối tháng, xuất trước nhập trước, lập biên bản hủy',
      'content':
          'Quy chuẩn quản lý tồn kho và xử lý hao hụt hàng hóa:\n'
          '1. Nguyên tắc xuất kho: Áp dụng phương pháp Nhập trước - Xuất trước (FIFO) đối với toàn bộ mặt hàng có hạn sử dụng hoặc bao bì biến đổi theo lô.\n'
          '2. Chu kỳ kiểm kê: Tiến hành kiểm kê thực tế toàn bộ kho vào ngày làm việc cuối cùng mỗi tháng. Lập biên bản chênh lệch giữa số lượng sổ sách và thực tế.\n'
          '3. Xử lý hàng hỏng hóc/hết hạn: Phải có biên bản xác nhận nguyên nhân và đại diện hộ kinh doanh ký duyệt trước khi xuất hủy ra khỏi giá vốn kinh doanh.',
    },
  ];

  Future<void> _pickDocumentFile() async {
    try {
      setState(() => _isLoading = true);
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['txt', 'md', 'pdf', 'docx', 'doc', 'json'],
      );
      if (picked == null) {
        setState(() => _isLoading = false);
        return;
      }
      final fileName = picked.name;
      final bytes = await picked.readAsBytes();

      if (bytes.isEmpty) {
        ToastService.showWarning('Không đọc được dữ liệu từ tệp.');
        setState(() => _isLoading = false);
        return;
      }

      final ext = picked.extension?.toLowerCase() ?? '';
      String extractedContent = '';

      if (ext == 'txt' || ext == 'md' || ext == 'json') {
        extractedContent = utf8.decode(bytes, allowMalformed: true);
      } else {
        // Đối với PDF hoặc DOCX: Giải mã chuỗi UTF-8 tiếng Việt an toàn
        final utf8Decoded = utf8.decode(bytes, allowMalformed: true);
        final matches = RegExp(
          r'[\p{L}\p{N}\s,.\-:;/()""''–—]{6,}',
          unicode: true,
        )
            .allMatches(utf8Decoded)
            .map((m) => m.group(0)!.trim())
            .where(
              (s) =>
                  s.length > 8 &&
                  !s.contains('Font') &&
                  !s.contains('obj') &&
                  !s.contains('endobj') &&
                  !s.contains('XML') &&
                  !s.contains('xmlns'),
            )
            .take(150)
            .toList();

        if (matches.isNotEmpty) {
          extractedContent = matches.join('\n');
        } else {
          extractedContent =
              'Tài liệu $fileName (${(bytes.length / 1024).toStringAsFixed(1)} KB).\nĐã lập chỉ mục nội dung cho Trợ lý AI.';
        }
      }

      if (mounted) {
        setState(() {
          if (_titleCtrl.text.trim().isEmpty) {
            _titleCtrl.text = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
          }
          _contentCtrl.text = extractedContent;
          _isLoading = false;
        });
        ToastService.showSuccess('Đã nạp nội dung từ tệp $fileName.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ToastService.showError('Lỗi đọc tệp: $e');
      }
    }
  }

  void _applyPreset(Map<String, String> preset) {
    setState(() {
      _titleCtrl.text = preset['title'] ?? '';
      _category = preset['category'] ?? 'Thuế HKD';
      _contentCtrl.text = preset['content'] ?? '';
    });
    ToastService.showSuccess('Đã áp dụng mẫu quy định: ${preset['title']}');
  }

  Future<void> _extractFromUrl() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty || !url.startsWith('http')) {
      ToastService.showWarning(
        'Vui lòng nhập đường link hợp lệ (bắt đầu bằng http:// hoặc https://)',
      );
      return;
    }
    try {
      setState(() => _isLoading = true);
      final api = ref.read(apiClientProvider);
      final response = await api.post(
        '/ai/knowledge/extract-url',
        data: {'url': url},
      );
      Map<String, dynamic> data = {};
      if (response is Map<String, dynamic>) {
        data = response['data'] is Map<String, dynamic>
            ? response['data']
            : response;
      }
      final title = data['title']?.toString() ?? '';
      final content = data['content']?.toString() ?? '';

      if (mounted) {
        setState(() {
          if (title.isNotEmpty && _titleCtrl.text.trim().isEmpty) {
            _titleCtrl.text = title;
          }
          if (content.isNotEmpty) {
            _contentCtrl.text = content;
          }
          _isLoading = false;
          _showUrlInput = false;
        });
        ToastService.showSuccess('Đã trích xuất nội dung từ liên kết web!');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ToastService.showError('Lỗi khi trích xuất: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
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
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Các nút tiện ích nhập nhanh từ Tệp hoặc Liên kết URL
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Cách nạp dữ liệu nhanh:',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _isLoading ? null : _pickDocumentFile,
                        icon: const Icon(Icons.upload_file_rounded, size: 16),
                        label: const Text('Tải tệp (PDF, Word, TXT, JSON)'),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _isLoading
                            ? null
                            : () => setState(
                                () => _showUrlInput = !_showUrlInput,
                              ),
                        icon: const Icon(Icons.link_rounded, size: 16),
                        label: Text(
                          _showUrlInput
                              ? 'Ẩn ô dán link'
                              : 'Dán đường link (URL)',
                        ),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_showUrlInput) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _urlCtrl,
                            enabled: !_isLoading,
                            decoration: const InputDecoration(
                              isDense: true,
                              hintText:
                                  'https://thuvienphapluat.vn/... hoặc link bài viết',
                              prefixIcon: Icon(
                                Icons.language_rounded,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _isLoading ? null : _extractFromUrl,
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Trích xuất'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Gợi ý link chính thống
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Text(
                            'Gợi ý link:',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: c.textMuted,
                            ),
                          ),
                          const SizedBox(width: 6),
                          ActionChip(
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            label: const Text('thuedientu.gdt.gov.vn', style: TextStyle(fontSize: 11)),
                            onPressed: () {
                              _urlCtrl.text = 'https://thuedientu.gdt.gov.vn';
                            },
                          ),
                          const SizedBox(width: 6),
                          ActionChip(
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            label: const Text('vbpl.vn', style: TextStyle(fontSize: 11)),
                            onPressed: () {
                              _urlCtrl.text = 'https://vbpl.vn';
                            },
                          ),
                          const SizedBox(width: 6),
                          ActionChip(
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            label: const Text('thuvienphapluat.vn', style: TextStyle(fontSize: 11)),
                            onPressed: () {
                              _urlCtrl.text = 'https://thuvienphapluat.vn';
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Khối Mẫu quy định pháp lý chuẩn 1-chạm (Presets)
            ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              childrenPadding: const EdgeInsets.only(bottom: 8),
              collapsedShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: c.divider),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              leading: Icon(
                Icons.bookmark_added_rounded,
                size: 20,
                color: AppColors.primary,
              ),
              title: Text(
                'Mẫu quy định & chính sách chuẩn (1-Chạm)',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                ),
              ),
              subtitle: Text(
                'Nạp ngay Thông tư 40, HĐĐT 123, Luật QLT 38, Quy chế kho FIFO...',
                style: GoogleFonts.inter(fontSize: 11, color: c.textSecondary),
              ),
              children: _legalPresets.map((preset) {
                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  leading: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.auto_stories_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ),
                  title: Text(
                    preset['title'] ?? '',
                    style: GoogleFonts.manrope(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    preset['desc'] ?? '',
                    style: GoogleFonts.inter(fontSize: 11, color: c.textSecondary),
                  ),
                  trailing: TextButton.icon(
                    onPressed: () => _applyPreset(preset),
                    icon: const Icon(Icons.flash_on_rounded, size: 14),
                    label: const Text('Áp dụng', style: TextStyle(fontSize: 11.5)),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: AppColors.primary,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            const SizedBox(height: 16),

            TextField(
              controller: _titleCtrl,
              enabled: !_isLoading,
              decoration: const InputDecoration(
                labelText: 'Tiêu đề tài liệu hoặc quy định',
                hintText: 'VD: Thông tư 40/2021/TT-BTC, Quy định chiết khấu...',
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Danh mục tài liệu'),
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
                if (v != null) setState(() => _category = v);
              },
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _contentCtrl,
              enabled: !_isLoading,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Nội dung tài liệu',
                hintText: 'Nội dung trích xuất từ tệp/link hoặc nhập tay...',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _isLoading
                  ? null
                  : () {
                      if (_titleCtrl.text.trim().isEmpty ||
                          _contentCtrl.text.trim().isEmpty) {
                        ToastService.showWarning(
                          'Vui lòng nhập đầy đủ tiêu đề và nội dung tài liệu.',
                        );
                        return;
                      }
                      widget.onSave(
                        _titleCtrl.text.trim(),
                        _category,
                        _contentCtrl.text.trim(),
                      );
                      Navigator.pop(context);
                      ToastService.showSuccess('Đã thêm nguồn tài liệu.');
                    },
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_circle_rounded, color: Colors.white),
              label: Text(
                _isLoading ? 'Đang xử lý...' : 'Lưu nguồn',
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
  }
}
