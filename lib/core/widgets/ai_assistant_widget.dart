import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../assets/app_assets.dart';
import '../theme/app_theme.dart';
import '../network/api_client.dart';
import '../../features/settings/providers/ai_knowledge_provider.dart';

class AiAssistantOpenNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void open() => state = true;
  void close() => state = false;
  void toggle() => state = !state;
}

final aiAssistantOpenProvider = NotifierProvider<AiAssistantOpenNotifier, bool>(
  AiAssistantOpenNotifier.new,
);

class AiAssistantLauncherVisibilityNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void show() => state = true;
  void hide() => state = false;
}

final aiAssistantLauncherVisibleProvider =
    NotifierProvider<AiAssistantLauncherVisibilityNotifier, bool>(
      AiAssistantLauncherVisibilityNotifier.new,
    );

class AiAssistantWidget extends ConsumerStatefulWidget {
  final bool showLauncher;
  final double topSafeInset;

  const AiAssistantWidget({
    super.key,
    this.showLauncher = true,
    this.topSafeInset = 0,
  });

  @override
  ConsumerState<AiAssistantWidget> createState() => _AiAssistantWidgetState();
}

class _AiAssistantWidgetState extends ConsumerState<AiAssistantWidget> {
  static const _launcherXKey = 'ai_assistant_launcher_x_v2';
  static const _launcherYKey = 'ai_assistant_launcher_y_v2';

  final TextEditingController _queryController = TextEditingController();
  Offset? _normalizedLauncherPosition;
  bool _isDraggingLauncher = false;
  final List<_AssistantMessage> _messages = const [
    _AssistantMessage(
      fromUser: false,
      text: '''### 👋 Chào bạn!

Tôi là **Trợ lý AI chuyên nghiệp** tư vấn về Quản lý Bán hàng, Tồn kho và Nghĩa vụ Thuế cho Hộ kinh doanh.

Bạn có thể đặt bất kỳ câu hỏi nào cho tôi về:
- 📊 **Doanh thu & Nghĩa vụ Thuế**: Ngưỡng chịu thuế mới (1 tỷ VNĐ/năm từ 2026), thuế VAT & TNCN.
- 📦 **Tồn kho & Định mức**: Danh sách hàng sắp hết, quy trình kiểm kê và nhập kho bổ sung.
- 💳 **Công nợ khách hàng**: Hạn mức nợ, đối soát và thu hồi công nợ.

Tôi có thể hỗ trợ thông tin gì cho cửa hàng của bạn ngay bây giờ?''',
    ),
  ].toList();

  final List<String> _quickQuestions = const [
    'Ngưỡng doanh thu và nghĩa vụ thuế',
    'Cách xử lý hàng dưới định mức',
    'Quy trình thu công nợ khách hàng',
  ];

  @override
  void initState() {
    super.initState();
    _restoreLauncherPosition();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _close() => ref.read(aiAssistantOpenProvider.notifier).close();

  Future<void> _restoreLauncherPosition() async {
    final preferences = await SharedPreferences.getInstance();
    final x = preferences.getDouble(_launcherXKey);
    final y = preferences.getDouble(_launcherYKey);
    if (!mounted || x == null || y == null) return;

    setState(() {
      _normalizedLauncherPosition = Offset(x.clamp(0, 1), y.clamp(0, 1));
    });
  }

  Future<void> _saveLauncherPosition() async {
    final position = _normalizedLauncherPosition;
    if (position == null) return;

    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      preferences.setDouble(_launcherXKey, position.dx),
      preferences.setDouble(_launcherYKey, position.dy),
    ]);
  }

  Offset _resolveLauncherPosition(Rect bounds) {
    final normalized = _normalizedLauncherPosition ?? const Offset(0, 0.5);
    return Offset(
      bounds.left + (bounds.width * normalized.dx),
      bounds.top + (bounds.height * normalized.dy),
    );
  }

  Offset _normalizeLauncherPosition(Offset position, Rect bounds) {
    final x = bounds.width == 0
        ? 0.0
        : (position.dx - bounds.left) / bounds.width;
    final y = bounds.height == 0
        ? 0.0
        : (position.dy - bounds.top) / bounds.height;
    return Offset(x.clamp(0, 1), y.clamp(0, 1));
  }

  void _moveLauncher(DragUpdateDetails details, Rect bounds) {
    final current = _resolveLauncherPosition(bounds);
    final next = Offset(
      (current.dx + details.delta.dx).clamp(bounds.left, bounds.right),
      (current.dy + details.delta.dy).clamp(bounds.top, bounds.bottom),
    );
    setState(() {
      _normalizedLauncherPosition = _normalizeLauncherPosition(next, bounds);
    });
  }

  Future<void> _handleSend(String question) async {
    final query = question.trim();
    if (query.isEmpty) return;

    setState(() {
      _messages.add(_AssistantMessage(fromUser: true, text: query));
      _queryController.clear();
      _messages.add(
        const _AssistantMessage(
          fromUser: false,
          text: 'Đang kết nối với Trợ lý AI...',
        ),
      );
    });

    try {
      final api = ref.read(apiClientProvider);
      final response = await api.post('/ai/chat', data: {'question': query});

      if (!mounted) return;

      Map<String, dynamic> data = {};
      if (response is Map<String, dynamic>) {
        data = response;
      }

      final answer =
          data['answer']?.toString() ??
          data['data']?['answer']?.toString() ??
          'Trợ lý AI đã ghi nhận thông tin.';
      final provider =
          data['provider']?.toString() ??
          data['data']?['provider']?.toString() ??
          'AI Assistant';

      setState(() {
        if (_messages.isNotEmpty &&
            _messages.last.text == 'Đang kết nối với Trợ lý AI...') {
          _messages.removeLast();
        }
        _messages.add(
          _AssistantMessage(fromUser: false, text: answer, source: provider),
        );
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        if (_messages.isNotEmpty &&
            _messages.last.text == 'Đang kết nối với Trợ lý AI...') {
          _messages.removeLast();
        }
        _messages.add(
          _AssistantMessage(
            fromUser: false,
            text: 'Lỗi kết nối với Trợ lý AI: ${error.toString()}',
            source: 'Lỗi hệ thống',
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOpen = ref.watch(aiAssistantOpenProvider);
    final launcherVisible = ref.watch(aiAssistantLauncherVisibleProvider);
    final media = MediaQuery.of(context);
    final isMobile = media.size.width < 700;

    return LayoutBuilder(
      builder: (context, constraints) {
        const launcherSize = Size(72, 80);
        const margin = 12.0;
        final minimumTop = math.min(
          widget.topSafeInset + margin,
          math.max(
            margin,
            constraints.maxHeight - launcherSize.height - margin,
          ),
        );
        final maximumLeft = math.max(
          margin,
          constraints.maxWidth - launcherSize.width - margin,
        );
        final maximumTop = math.max(
          minimumTop,
          constraints.maxHeight - launcherSize.height - margin,
        );
        final launcherBounds = Rect.fromLTRB(
          margin,
          minimumTop,
          maximumLeft,
          maximumTop,
        );
        final launcherPosition = _resolveLauncherPosition(launcherBounds);
        final desktopPanelTop = math.max(
          80.0,
          widget.topSafeInset + AppSpacing.md,
        );
        final desktopPanelHeight = math.min(
          680.0,
          math.max(0.0, constraints.maxHeight - desktopPanelTop - 16),
        );

        return IgnorePointer(
          ignoring: !isOpen && !widget.showLauncher,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (isOpen)
                if (isMobile)
                  Positioned.fill(
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.22),
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          child: _AssistantPanel(
                            messages: _messages,
                            quickQuestions: _quickQuestions,
                            queryController: _queryController,
                            onClose: _close,
                            onManageSources: () {
                              _close();
                              context.push('/settings/ai-knowledge');
                            },
                            onSend: _handleSend,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  Positioned(
                    right: 16,
                    bottom: 16,
                    width: 408,
                    height: desktopPanelHeight,
                    child: _AssistantPanel(
                      messages: _messages,
                      quickQuestions: _quickQuestions,
                      queryController: _queryController,
                      onClose: _close,
                      onManageSources: () {
                        _close();
                        context.push('/settings/ai-knowledge');
                      },
                      onSend: _handleSend,
                    ),
                  ),
              if (!isOpen && widget.showLauncher && launcherVisible)
                Positioned(
                  left: launcherPosition.dx,
                  top: launcherPosition.dy,
                  width: launcherSize.width,
                  height: launcherSize.height,
                  child: GestureDetector(
                    key: const ValueKey('ai-assistant-launcher'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () =>
                        ref.read(aiAssistantOpenProvider.notifier).open(),
                    onPanStart: (_) =>
                        setState(() => _isDraggingLauncher = true),
                    onPanUpdate: (details) =>
                        _moveLauncher(details, launcherBounds),
                    onPanEnd: (_) {
                      setState(() => _isDraggingLauncher = false);
                      _saveLauncherPosition();
                    },
                    child: _AssistantLauncher(
                      compact: true,
                      dragging: _isDraggingLauncher,
                      onHide: () => ref
                          .read(aiAssistantLauncherVisibleProvider.notifier)
                          .hide(),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _AssistantPanel extends StatelessWidget {
  final List<_AssistantMessage> messages;
  final List<String> quickQuestions;
  final TextEditingController queryController;
  final VoidCallback onClose;
  final VoidCallback onManageSources;
  final ValueChanged<String> onSend;

  const _AssistantPanel({
    required this.messages,
    required this.quickQuestions,
    required this.queryController,
    required this.onClose,
    required this.onManageSources,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Material(
      color: colors.surface,
      elevation: 10,
      borderRadius: BorderRadius.circular(AppRadius.dialog),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: colors.divider),
          borderRadius: BorderRadius.circular(AppRadius.dialog),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(
                children: [
                  const AppAssetIcon(
                    assetPath: AppAssets.aiMascot,
                    size: 30,
                    semanticLabel: 'Trợ giúp nghiệp vụ',
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Trợ giúp nghiệp vụ',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          'Ưu tiên nguồn tài liệu đang bật',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: onManageSources,
                    child: const Text('Nguồn'),
                  ),
                  TextButton(onPressed: onClose, child: const Text('Đóng')),
                ],
              ),
            ),
            Divider(height: 1, color: colors.divider),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) =>
                    _MessageBlock(message: messages[index]),
              ),
            ),
            if (messages.length == 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Câu hỏi thường dùng',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final question in quickQuestions)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: OutlinedButton(
                          onPressed: () => onSend(question),
                          style: OutlinedButton.styleFrom(
                            alignment: Alignment.centerLeft,
                          ),
                          child: Text(
                            question,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            Divider(height: 1, color: colors.divider),
            Padding(
              padding: EdgeInsets.fromLTRB(
                12,
                12,
                12,
                12 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: queryController,
                      minLines: 1,
                      maxLines: 3,
                      textInputAction: TextInputAction.send,
                      onSubmitted: onSend,
                      decoration: const InputDecoration(
                        hintText: 'Nhập nội dung cần tra cứu',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => onSend(queryController.text),
                    child: const Text('Gửi'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBlock extends ConsumerWidget {
  final _AssistantMessage message;

  const _MessageBlock({required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppThemeColors.of(context);
    final primary = Theme.of(context).colorScheme.primary;

    return Align(
      alignment: message.fromUser
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: message.fromUser
              ? primary.withValues(alpha: 0.08)
              : colors.cardAlt,
          borderRadius: BorderRadius.circular(AppRadius.control),
          border: Border.all(
            color: message.fromUser
                ? primary.withValues(alpha: 0.2)
                : colors.divider,
          ),
        ),
        child: SelectionArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.fromUser)
                Text(
                  message.text,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.textPrimary,
                    height: 1.5,
                  ),
                )
              else
                MarkdownBody(
                  data: message.text,
                  onTapLink: (text, href, title) async {
                    if (href != null && href.isNotEmpty) {
                      final uri = Uri.parse(href);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    }
                  },
                  styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                      .copyWith(
                        p: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.textPrimary,
                          height: 1.5,
                        ),
                        a: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: primary,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                        h3: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: primary,
                        ),
                        blockquoteDecoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(4),
                          border: Border(
                            left: BorderSide(color: primary, width: 3),
                          ),
                        ),
                      ),
                ),
              if (!message.fromUser) ...[
                const SizedBox(height: 8),
                _buildLegalDocumentCitations(
                  context,
                  ref,
                  message.text,
                  primary,
                  colors,
                ),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: message.text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Đã sao chép nội dung câu trả lời!'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppAssetIcon(
                            assetPath: AppAssets.copy,
                            size: 14,
                            color: colors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Sao chép',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: colors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegalDocumentCitations(
    BuildContext context,
    WidgetRef ref,
    String text,
    Color primary,
    AppThemeColors colors,
  ) {
    final regExp = RegExp(r'\[([^\]]+)\]\((https?:\/\/[^\)]+)\)');
    final matches = regExp.allMatches(text);
    if (matches.isEmpty) return const SizedBox.shrink();

    final citations = <Map<String, String>>[];
    for (final m in matches) {
      final rawTitle = m.group(1) ?? '';
      final url = m.group(2) ?? '';
      final title = rawTitle.replaceAll('📄', '').trim();
      if (title.isNotEmpty &&
          url.isNotEmpty &&
          !citations.any((c) => c['url'] == url)) {
        citations.add({'title': title, 'url': url});
      }
    }

    if (citations.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 12),
        Text(
          'Văn bản trích dẫn (${citations.length}):',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        ...citations.map(
          (doc) => Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: primary.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                AppAssetIcon(
                  assetPath: AppAssets.emptyDocument,
                  size: 16,
                  color: primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final url = doc['url'];
                      if (url != null && url.isNotEmpty) {
                        final uri = Uri.parse(url);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      }
                    },
                    child: Text(
                      doc['title'] ?? '',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: primary,
                        decoration: TextDecoration.underline,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () async {
                    try {
                      final title = doc['title'] ?? 'Văn bản tra cứu';
                      final url = doc['url'] ?? '';
                      await ref
                          .read(aiKnowledgeProvider.notifier)
                          .addDocument(
                            title: title,
                            category: 'TAX',
                            content: 'Văn bản tra cứu Thư Viện Pháp Luật: $url',
                          );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '✅ Đã thêm "$title" vào Thư viện Cửa hàng!',
                            ),
                            backgroundColor: AppColors.success,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    } catch (err) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Văn bản này đã có sẵn trong Thư viện Cửa hàng.',
                            ),
                            backgroundColor: AppColors.warning,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    }
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppAssetIcon(
                          assetPath: AppAssets.add,
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Thêm vào Thư viện',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AssistantLauncher extends StatelessWidget {
  final bool compact;
  final bool dragging;
  final VoidCallback onHide;

  const _AssistantLauncher({
    required this.compact,
    required this.dragging,
    required this.onHide,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final primary = Theme.of(context).colorScheme.primary;

    return Semantics(
      container: true,
      explicitChildNodes: true,
      button: true,
      label: 'Hỏi AI. Có thể kéo để đổi vị trí.',
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 12,
            bottom: 0,
            child: Tooltip(
              message: 'Kéo để đổi vị trí • Nhấn để hỏi AI',
              child: MouseRegion(
                cursor: SystemMouseCursors.move,
                child: AnimatedScale(
                  scale: dragging ? 1.04 : 1,
                  duration: const Duration(milliseconds: 140),
                  child: Material(
                    color: colors.surface,
                    elevation: dragging ? 12 : 8,
                    shadowColor: primary.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(22),
                    clipBehavior: Clip.antiAlias,
                    child: Container(
                      padding: EdgeInsets.fromLTRB(
                        compact ? 8 : 7,
                        7,
                        compact ? 8 : 12,
                        7,
                      ),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.04),
                        border: Border.all(
                          color: primary.withValues(
                            alpha: dragging ? 0.5 : 0.28,
                          ),
                        ),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AppAssetIcon(
                            assetPath: AppAssets.aiMascot,
                            size: compact ? 48 : 52,
                            semanticLabel: 'Stocky, trợ lý SmartStock',
                          ),
                          if (!compact) ...[
                            const SizedBox(width: 7),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Hỏi AI',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(
                                          color: colors.textPrimary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  Text(
                                    'Kéo để đặt vị trí',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(color: colors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Tooltip(
              message: 'Ẩn nút AI',
              child: Material(
                color: colors.surface,
                elevation: 4,
                shape: CircleBorder(side: BorderSide(color: colors.divider)),
                child: InkWell(
                  onTap: onHide,
                  customBorder: const CircleBorder(),
                  child: SizedBox.square(
                    dimension: 26,
                    child: Center(
                      child: Text(
                        '×',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 18,
                          height: 1,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssistantMessage {
  final bool fromUser;
  final String text;
  final String? source;

  const _AssistantMessage({
    required this.fromUser,
    required this.text,
    this.source,
  });
}
