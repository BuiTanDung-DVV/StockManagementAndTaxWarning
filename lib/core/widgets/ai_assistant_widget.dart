import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../../features/settings/providers/ai_knowledge_provider.dart';

class AiAssistantWidget extends ConsumerStatefulWidget {
  const AiAssistantWidget({super.key});

  @override
  ConsumerState<AiAssistantWidget> createState() => _AiAssistantWidgetState();
}

class _AiAssistantWidgetState extends ConsumerState<AiAssistantWidget> {
  bool _isOpen = false;
  final TextEditingController _queryController = TextEditingController();
  final List<Map<String, String>> _messages = [
    {
      'sender': 'ai',
      'text':
          'Xin chào! Tôi là Trợ Lý AI SmartStock. Mọi thông tin của tôi được kiểm soát 100% từ Kho Tài Liệu của cửa hàng. Bạn cần tra cứu quy định hay tài liệu nào?',
    },
  ];

  final List<String> _quickQuestions = [
    'Doanh thu bao nhiêu thì phải nộp thuế?',
    'Hộ kinh doanh bán lẻ nộp thuế bao nhiêu %?',
    'Quy định quản lý nợ mua thiếu?',
    'Nội quy chốt két tiền mặt cuối ngày?',
  ];

  void _handleSend(String question) {
    final query = question.trim();
    if (query.isEmpty) return;

    setState(() {
      _messages.add({'sender': 'user', 'text': query});
      _queryController.clear();
    });

    final activeDocs = ref
        .read(aiKnowledgeProvider)
        .where((d) => d.isActive)
        .toList();

    // Strict Grounding RAG Engine
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      String answer = '';
      String citation = '';

      final qLower = query.toLowerCase();

      // Search matching active documents strictly
      AiDocument? matchedDoc;
      for (final doc in activeDocs) {
        final titleLower = doc.title.toLowerCase();
        final contentLower = doc.content.toLowerCase();

        // Check keyword matches
        if (qLower
            .split(' ')
            .any(
              (word) =>
                  word.length > 3 &&
                  (titleLower.contains(word) || contentLower.contains(word)),
            )) {
          matchedDoc = doc;
          break;
        }
      }

      if (matchedDoc != null) {
        answer = matchedDoc.content.trim();
        citation = matchedDoc.title;
      }

      if (matchedDoc == null) {
        setState(() {
          _messages.add({
            'sender': 'ai',
            'text':
                '⚠️ Rất tiếc, câu hỏi của bạn chưa có dữ liệu trong Kho Tài Liệu AI đã nạp của cửa hàng.\n\nĐể AI trả lời chính xác và không bịa đặt, vui lòng nhấn icon ⚙️ [Quản lý tài liệu] ở góc trên để nạp thêm văn bản hướng dẫn vào hệ thống.',
          });
        });
      } else {
        setState(() {
          _messages.add({
            'sender': 'ai',
            'text': '$answer\n\n📌 [Trích dẫn nguồn: $citation]',
          });
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final media = MediaQuery.of(context);
    final isMobile = media.size.width < 700;
    final mobileBottomOffset = 84.0 + media.padding.bottom;
    final panelBottom = isMobile ? mobileBottomOffset + 68 : 80.0;
    final panelHeight = (media.size.height - panelBottom - 24)
        .clamp(320.0, 490.0)
        .toDouble();

    return Stack(
      fit: StackFit.expand,
      children: [
        if (_isOpen)
          Positioned(
            bottom: panelBottom,
            right: 16,
            left: isMobile ? 16 : null,
            child: Material(
              elevation: 16,
              borderRadius: BorderRadius.circular(24),
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              child: Container(
                width: isMobile ? null : 360,
                height: panelHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    // AI Header
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(22),
                        ),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: Colors.white,
                            radius: 15,
                            child: Text('🤖', style: TextStyle(fontSize: 15)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Trợ Lý AI Tri Thức (RAG)',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  'Chỉ trả lời từ kho tài liệu đã nạp',
                                  style: GoogleFonts.inter(
                                    color: Colors.white70,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Manage documents button
                          IconButton(
                            icon: const Icon(
                              Icons.settings_suggest_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            tooltip: 'Quản lý kho tài liệu AI',
                            onPressed: () {
                              setState(() => _isOpen = false);
                              context.push('/settings/ai-knowledge');
                            },
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: () => setState(() => _isOpen = false),
                          ),
                        ],
                      ),
                    ),

                    // Chat messages list
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isAi = msg['sender'] == 'ai';
                          return Align(
                            alignment: isAi
                                ? Alignment.centerLeft
                                : Alignment.centerRight,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              constraints: const BoxConstraints(maxWidth: 290),
                              decoration: BoxDecoration(
                                color: isAi
                                    ? (isDark
                                          ? const Color(0xFF334155)
                                          : const Color(0xFFF1F5F9))
                                    : AppColors.primary,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                msg['text']!,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: isAi
                                      ? (isDark ? Colors.white : Colors.black87)
                                      : Colors.white,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Quick suggestion chips
                    SizedBox(
                      height: 38,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        itemCount: _quickQuestions.length,
                        itemBuilder: (context, i) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ActionChip(
                              label: Text(
                                _quickQuestions[i],
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black87,
                                ),
                              ),
                              backgroundColor: isDark
                                  ? const Color(0xFF0F172A)
                                  : const Color(0xFFE2E8F0),
                              onPressed: () => _handleSend(_quickQuestions[i]),
                            ),
                          );
                        },
                      ),
                    ),

                    const Divider(height: 1),

                    // Input Bar
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _queryController,
                              style: const TextStyle(fontSize: 12),
                              decoration: InputDecoration(
                                hintText: 'Tra cứu theo kho tài liệu AI...',
                                hintStyle: TextStyle(
                                  fontSize: 12,
                                  color: c.textMuted,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: isDark
                                    ? const Color(0xFF0F172A)
                                    : const Color(0xFFF8FAFC),
                              ),
                              onSubmitted: _handleSend,
                            ),
                          ),
                          const SizedBox(width: 6),
                          CircleAvatar(
                            backgroundColor: AppColors.primary,
                            radius: 18,
                            child: IconButton(
                              icon: const Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                              onPressed: () =>
                                  _handleSend(_queryController.text),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Floating Trigger Button
        Positioned(
          bottom: isMobile ? mobileBottomOffset : 20,
          right: 16,
          child: isMobile
              ? FloatingActionButton(
                  onPressed: () => setState(() => _isOpen = !_isOpen),
                  backgroundColor: AppColors.primary,
                  tooltip: 'Hỏi AI Tri Thức',
                  child: const Icon(
                    Icons.smart_toy_rounded,
                    color: Colors.white,
                  ),
                )
              : FloatingActionButton.extended(
                  onPressed: () => setState(() => _isOpen = !_isOpen),
                  backgroundColor: AppColors.primary,
                  icon: const Icon(
                    Icons.smart_toy_rounded,
                    color: Colors.white,
                  ),
                  label: Text(
                    'Hỏi AI Tri Thức',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
