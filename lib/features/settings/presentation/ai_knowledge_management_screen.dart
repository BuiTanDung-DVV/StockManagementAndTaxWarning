import '../../../core/assets/app_icon.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
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
import '../../../core/utils/search_text.dart';
import '../../../core/widgets/app_pagination_bar.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../../../core/widgets/app_confirm_modal.dart';
import '../models/knowledge_html.dart';
import '../providers/ai_knowledge_provider.dart';

class AiKnowledgeManagementScreen extends ConsumerStatefulWidget {
  const AiKnowledgeManagementScreen({super.key});

  @override
  ConsumerState<AiKnowledgeManagementScreen> createState() =>
      _AiKnowledgeManagementScreenState();
}

enum _DocumentStatus { all, active, inactive }

class _AiKnowledgeManagementScreenState
    extends ConsumerState<AiKnowledgeManagementScreen> {
  static const _pageSize = 10;
  final _search = TextEditingController();
  final _scroll = ScrollController();
  String? _categoryFilter;
  _DocumentStatus _status = _DocumentStatus.all;
  int _page = 1;

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _clearFilters() => setState(() {
    _search.clear();
    _categoryFilter = null;
    _status = _DocumentStatus.all;
    _page = 1;
  });

  void _showAddDocumentModal(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        constraints: const BoxConstraints(maxWidth: 660),
        child: _AddDocumentSheet(
          onSave: (title, category, content) => ref
              .read(aiKnowledgeProvider.notifier)
              .addDocument(title: title, category: category, content: content),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final docsAsync = ref.watch(aiKnowledgeProvider);
    final docs = docsAsync.asData?.value ?? const <AiDocument>[];
    final categories = docs.map((doc) => doc.category).toSet().toList()..sort();
    final category = categories.contains(_categoryFilter)
        ? _categoryFilter
        : null;
    final query = foldSearchText(_search.text);
    final filtered = docs.where((doc) {
      if (category != null && doc.category != category) return false;
      if (_status != _DocumentStatus.all &&
          doc.isActive != (_status == _DocumentStatus.active)) {
        return false;
      }
      return query.isEmpty ||
          foldSearchText(doc.title).contains(query) ||
          foldSearchText(doc.content).contains(query);
    }).toList();
    final totalPages = (filtered.length / _pageSize).ceil().clamp(
      1,
      filtered.length + 1,
    );
    final currentPage = _page.clamp(1, totalPages);
    final visibleDocs = filtered
        .skip((currentPage - 1) * _pageSize)
        .take(_pageSize)
        .toList();
    final hasFilters =
        _search.text.isNotEmpty ||
        category != null ||
        _status != _DocumentStatus.all;

    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final compactLayout =
        MediaQuery.sizeOf(context).width < 900 || textScale > 1.15;
    final double calculatedHeight = 18 * 2 * textScale * 1.2 + 24;
    final double toolbarHeight = compactLayout && calculatedHeight > 68.0
        ? calculatedHeight
        : 68.0;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: toolbarHeight,
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
            Flexible(
              child: Text(
                'Nguồn tài liệu tham khảo',
                style: GoogleFonts.manrope(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                  letterSpacing: -0.3,
                ),
                maxLines: compactLayout ? 2 : 1,
                softWrap: compactLayout,
                overflow: compactLayout
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
              ),
            ),
            if (!compactLayout) ...[
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
                    AppIcon(
                      Icons.auto_awesome,
                      size: 12,
                      color: AppColors.primary,
                    ),
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
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            icon: const AppIcon(Icons.refresh_rounded, size: 20),
            color: c.textSecondary,
            onPressed: () => ref.invalidate(aiKnowledgeProvider),
          ),
          const SizedBox(width: 6),
          if (compactLayout)
            IconButton(
              tooltip: 'Nạp tài liệu mới',
              icon: const AppIcon(Icons.add_rounded, size: 24),
              color: AppColors.primary,
              onPressed: () => _showAddDocumentModal(context, ref),
            )
          else
            FilledButton.icon(
              onPressed: () => _showAddDocumentModal(context, ref),
              icon: const AppIcon(Icons.add_rounded, size: 18),
              label: const Text('Nạp tài liệu mới'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
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
          child: Container(color: c.divider, height: 1),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(aiKnowledgeProvider),
        child: SingleChildScrollView(
          controller: _scroll,
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
                      child: AppIcon(
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

              if (docsAsync.hasValue) ...[
                TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    labelText: 'Tìm theo tiêu đề hoặc nội dung',
                    prefixIcon: const AppIcon(Icons.search),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Xóa từ khóa',
                            onPressed: () => setState(() {
                              _search.clear();
                              _page = 1;
                            }),
                            icon: const AppIcon(Icons.close),
                          ),
                  ),
                  onChanged: (_) => setState(() => _page = 1),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 230,
                      child: DropdownButtonFormField<String>(
                        key: ValueKey(('category', category)),
                        initialValue: category,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Danh mục',
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Tất cả danh mục'),
                          ),
                          for (final item in categories)
                            DropdownMenuItem(
                              value: item,
                              child: Text(
                                item,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (value) => setState(() {
                          _categoryFilter = value;
                          _page = 1;
                        }),
                      ),
                    ),
                    SizedBox(
                      width: 210,
                      child: DropdownButtonFormField<_DocumentStatus>(
                        key: ValueKey(_status),
                        initialValue: _status,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Trạng thái',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: _DocumentStatus.all,
                            child: Text('Tất cả trạng thái'),
                          ),
                          DropdownMenuItem(
                            value: _DocumentStatus.active,
                            child: Text('Đang sử dụng'),
                          ),
                          DropdownMenuItem(
                            value: _DocumentStatus.inactive,
                            child: Text('Đã tắt'),
                          ),
                        ],
                        onChanged: (value) => setState(() {
                          _status = value ?? _DocumentStatus.all;
                          _page = 1;
                        }),
                      ),
                    ),
                    if (hasFilters)
                      TextButton(
                        onPressed: _clearFilters,
                        child: const Text('Bỏ lọc'),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
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
              else if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: Text(
                      docs.isEmpty
                          ? 'Chưa có nguồn tài liệu.'
                          : 'Không tìm thấy tài liệu phù hợp.',
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
                  itemCount: visibleDocs.length,
                  itemBuilder: (context, index) {
                    final doc = visibleDocs[index];
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
                                  icon: const AppIcon(
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
              if (filtered.isNotEmpty)
                AppPaginationBar(
                  currentPage: currentPage,
                  totalPages: totalPages,
                  totalItems: filtered.length,
                  itemLabel: 'tài liệu',
                  compactNavigation: true,
                  onPageChanged: (page) {
                    setState(() => _page = page);
                    if (_scroll.hasClients) _scroll.jumpTo(0);
                  },
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddDocumentSheet extends ConsumerStatefulWidget {
  final Future<void> Function(String title, String category, String content)
  onSave;

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
  bool _isSaving = false;
  String? _importError;
  String? _importStatus;
  String? _saveError;
  final _formKey = GlobalKey<FormState>();

  bool get _busy => _isLoading || _isSaving;

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
      'title':
          'Nghị định 123/2020/NĐ-CP & TT 78 - Hóa đơn điện tử máy tính tiền',
      'category': 'Thuế HKD',
      'desc':
          'Quy định xuất HĐĐT khởi tạo từ máy tính tiền kết nối cơ quan thuế',
      'content':
          'Căn cứ Nghị định 123/2020/NĐ-CP và Thông tư 78/2021/TT-BTC:\n'
          '1. Đối tượng áp dụng: Hộ kinh doanh nộp thuế theo phương pháp kê khai có hoạt động bán lẻ trực tiếp đến người tiêu dùng (trung tâm thương mại, siêu thị, bán lẻ hàng tiêu dùng, ăn uống, nhà hàng, khách sạn, hiệu thuốc...).\n'
          '2. Nguyên tắc: Xuất hóa đơn điện tử có mã của cơ quan thuế khởi tạo từ máy tính tiền có kết nối chuyển dữ liệu điện tử với cơ quan thuế ngay khi giao dịch hoàn tất.\n'
          '3. Chế tài: Xử phạt hành vi không lập hóa đơn khi bán hàng hóa, cung cấp dịch vụ theo Nghị định 125/2020/NĐ-CP từ 10 - 20 triệu đồng.',
    },
    {
      'title':
          'Thời hạn nộp hồ sơ khai thuế & Phạt chậm nộp (Luật QLT 38 & NĐ 125)',
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
      'desc':
          'Giới hạn nợ tối đa 30 ngày, đối soát định kỳ, chặn bán nợ vượt trần',
      'content':
          'Quy chế quản lý công nợ khách hàng và nhà cung cấp nội bộ:\n'
          '1. Hạn mức tín dụng khách quen: Tối đa không quá 10.000.000 VNĐ hoặc thời gian nợ tối đa 30 ngày tính từ ngày ghi sổ.\n'
          '2. Quy trình nhắc nợ: Gửi bảng kê đối soát công nợ vào ngày 25 hàng tháng. Nếu quá hạn 15 ngày chưa thanh toán thì tạm dừng cho mua nợ mới.\n'
          '3. Công nợ nhà cung cấp: Ưu tiên đối soát công nợ đối ứng với các lô hàng nhập kho có biên bản bàn giao và hóa đơn hợp lệ.',
    },
    {
      'title': 'Quy chế Kiểm kê & Quản lý Hao hụt Kho hàng (FIFO)',
      'category': 'Kho & Tài Chính',
      'desc':
          'Kiểm kê định kỳ cuối tháng, xuất trước nhập trước, lập biên bản hủy',
      'content':
          'Quy chuẩn quản lý tồn kho và xử lý hao hụt hàng hóa:\n'
          '1. Nguyên tắc xuất kho: Áp dụng phương pháp Nhập trước - Xuất trước (FIFO) đối với toàn bộ mặt hàng có hạn sử dụng hoặc bao bì biến đổi theo lô.\n'
          '2. Chu kỳ kiểm kê: Tiến hành kiểm kê thực tế toàn bộ kho vào ngày làm việc cuối cùng mỗi tháng. Lập biên bản chênh lệch giữa số lượng sổ sách và thực tế.\n'
          '3. Xử lý hàng hỏng hóc/hết hạn: Phải có biên bản xác nhận nguyên nhân và đại diện hộ kinh doanh ký duyệt trước khi xuất hủy ra khỏi giá vốn kinh doanh.',
    },
  ];

  Future<void> _pickDocumentFile({bool htmlOnly = false}) async {
    setState(() {
      _isLoading = true;
      _importError = null;
      _importStatus = null;
    });
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: htmlOnly
            ? const ['html', 'htm']
            : const ['docx', 'txt', 'md', 'json', 'html', 'htm'],
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final fileTitle = file.name.replaceFirst(RegExp(r'\.[^.]+$'), '');
      final (title, text) = switch (file.extension?.toLowerCase()) {
        'docx' => (fileTitle, _readWordText(bytes)),
        'html' || 'htm' => readKnowledgeHtml(bytes, fileTitle),
        _ => (fileTitle, utf8.decode(bytes)),
      };
      final content = text.trim();
      if (!mounted) return;
      if (content.isEmpty) {
        setState(() => _importError = 'Tệp không có nội dung.');
        return;
      }
      _applyContent(
        title,
        content,
        'Đã đọc ${file.name}. Kiểm tra nội dung trước khi lưu.',
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _importError =
              'Không đọc được tệp. Hãy kiểm tra định dạng và thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _readWordText(Uint8List bytes) {
    const limit = 8 * 1024 * 1024;
    if (bytes.length > limit) throw const FormatException('Tệp quá lớn.');
    final directory = ZipDirectory()..read(InputMemoryStream(bytes));
    var expandedSize = 0;
    for (final entry in directory.fileHeaders) {
      expandedSize += entry.uncompressedSize;
      if (expandedSize > limit || entry.generalPurposeBitFlag & 1 != 0) {
        throw const FormatException('Không đọc được nội dung tệp.');
      }
    }
    final document = ZipDecoder()
        .decodeBytes(bytes)
        .findFile('word/document.xml');
    if (document == null) throw const FormatException('Tệp DOCX không hợp lệ.');
    const wordNamespace =
        'http://schemas.openxmlformats.org/wordprocessingml/2006/main';
    return XmlDocument.parse(utf8.decode(document.content))
        .findAllElements('p', namespace: wordNamespace)
        .map(
          (paragraph) => paragraph
              .findAllElements('t', namespace: wordNamespace)
              .map((text) => text.innerText)
              .join(),
        )
        .where((paragraph) => paragraph.trim().isNotEmpty)
        .join('\n');
  }

  void _applyContent(String title, String content, String status) {
    setState(() {
      if (_titleCtrl.text.trim().isEmpty) _titleCtrl.text = title;
      _contentCtrl.text = content;
      _importStatus = status;
      _saveError = null;
    });
  }

  Future<void> _extractFromUrl() async {
    final url = _urlCtrl.text.trim();
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !const {'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      setState(() {
        _importStatus = null;
        _importError = 'Nhập địa chỉ trang bắt đầu bằng https:// hoặc http://.';
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _importError = null;
      _importStatus = null;
    });
    try {
      final response = await ref
          .read(apiClientProvider)
          .post('/ai/knowledge/extract-url', data: {'url': url});
      if (!mounted) return;
      final data = response is Map ? response['data'] ?? response : null;
      final content = data is Map
          ? (data['content']?.toString() ?? '').trim()
          : '';
      if (content.isEmpty) {
        setState(
          () => _importError =
              'Trang không có văn bản để nhập. Hãy thử nguồn khác hoặc dán nội dung vào biểu mẫu.',
        );
        return;
      }
      _applyContent(
        data['title']?.toString() ?? '',
        content,
        'Đã đọc nội dung từ liên kết. Kiểm tra lại trước khi lưu.',
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      final blocked = error.message.contains('HTTP 403');
      setState(
        () => _importError = blocked
            ? 'Trang nguồn từ chối yêu cầu tải (HTTP 403). Mở trang trong trình duyệt, lưu dưới dạng HTML rồi chọn tệp bên dưới. Bạn cũng có thể dán văn bản.'
            : error.statusCode == 403
            ? 'Tài khoản cần quyền chỉnh sửa cài đặt để trích xuất từ đường dẫn.'
            : 'Không đọc được nội dung từ liên kết. Kiểm tra địa chỉ, thử lại hoặc dán nội dung vào biểu mẫu.',
      );
    } catch (_) {
      if (mounted) {
        setState(() => _importError = 'Không thể tải liên kết. Hãy thử lại.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _saveError = null;
    });
    try {
      await widget.onSave(
        _titleCtrl.text.trim(),
        _category,
        _contentCtrl.text.trim(),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _saveError =
              'Chưa lưu được nguồn. Nội dung đã nhập vẫn còn trong biểu mẫu.';
        });
      }
      return;
    }
    if (!mounted) return;
    Navigator.pop(context);
    ToastService.showSuccess('Đã thêm nguồn tài liệu.');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return PopScope(
      canPop: !_isSaving,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
            child: Row(
              children: [
                AppIcon(
                  Icons.note_add_outlined,
                  color: colors.primary,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Thêm nguồn tham khảo',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Đóng',
                  onPressed: _isSaving ? null : () => Navigator.pop(context),
                  icon: const AppIcon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _pickDocumentFile,
                          icon: const AppIcon(
                            Icons.upload_file_rounded,
                            size: 18,
                          ),
                          label: const Text('Tải tệp văn bản'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () => setState(
                                  () => _showUrlInput = !_showUrlInput,
                                ),
                          icon: const AppIcon(Icons.link_rounded, size: 18),
                          label: Text(
                            _showUrlInput
                                ? 'Ẩn đường dẫn'
                                : 'Nhập từ đường dẫn',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Hỗ trợ DOCX, TXT, Markdown, JSON và HTML. Với PDF hoặc DOC, hãy dán phần văn bản cần lưu.',
                      style: theme.textTheme.bodySmall,
                    ),
                    if (_showUrlInput) ...[
                      const SizedBox(height: 14),
                      TextField(
                        controller: _urlCtrl,
                        enabled: !_busy,
                        keyboardType: TextInputType.url,
                        onChanged: (_) {
                          if (_importError != null || _importStatus != null) {
                            setState(() {
                              _importError = null;
                              _importStatus = null;
                            });
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: 'Đường dẫn tài liệu',
                          hintText: 'https://...',
                          prefixIcon: AppIcon(Icons.link_rounded, size: 18),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton(
                          onPressed: _busy ? null : _extractFromUrl,
                          child: const Text('Trích xuất'),
                        ),
                      ),
                    ],
                    if (_isLoading) const LinearProgressIndicator(),
                    if (_importError case final error?)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            error,
                            style: TextStyle(color: colors.error),
                          ),
                        ),
                      ),
                    if (_showUrlInput && _importError != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _pickDocumentFile(htmlOnly: true),
                          icon: const AppIcon(
                            Icons.upload_file_rounded,
                            size: 18,
                          ),
                          label: const Text('Chọn tệp HTML đã lưu'),
                        ),
                      ),
                    if (_importStatus case final status?)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(status, style: theme.textTheme.bodySmall),
                      ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _titleCtrl,
                      enabled: !_busy,
                      decoration: const InputDecoration(
                        labelText: 'Tiêu đề tài liệu',
                      ),
                      validator: (value) => (value ?? '').trim().isEmpty
                          ? 'Nhập tiêu đề tài liệu.'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      key: ValueKey(_category),
                      initialValue: _category,
                      isExpanded: true,
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
                      onChanged: _busy
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() => _category = value);
                              }
                            },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _contentCtrl,
                      enabled: !_busy,
                      minLines: 4,
                      maxLines: 7,
                      decoration: const InputDecoration(
                        labelText: 'Nội dung tài liệu',
                        alignLabelWithHint: true,
                      ),
                      validator: (value) => (value ?? '').trim().isEmpty
                          ? 'Nhập nội dung tài liệu.'
                          : null,
                    ),
                    const SizedBox(height: 8),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('Mẫu nội dung tham khảo'),
                      subtitle: const Text(
                        'Đối chiếu nội dung với tài liệu gốc trước khi lưu.',
                      ),
                      children: [
                        for (final preset in _legalPresets)
                          ListTile(
                            title: Text(preset['title']!),
                            subtitle: Text(preset['desc']!),
                            contentPadding: EdgeInsets.zero,
                            trailing: TextButton(
                              onPressed: _busy
                                  ? null
                                  : () {
                                      setState(() {
                                        _titleCtrl.text = preset['title']!;
                                        _category = preset['category']!;
                                        _contentCtrl.text = preset['content']!;
                                        _importError = null;
                                        _importStatus = null;
                                        _saveError = null;
                                      });
                                    },
                              child: const Text('Áp dụng'),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_saveError case final error?)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(error, style: TextStyle(color: colors.error)),
                    ),
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      TextButton(
                        onPressed: _isSaving
                            ? null
                            : () => Navigator.pop(context),
                        child: const Text('Hủy'),
                      ),
                      FilledButton(
                        onPressed: _busy ? null : _save,
                        child: Text(_isSaving ? 'Đang lưu…' : 'Lưu nguồn'),
                      ),
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
}
