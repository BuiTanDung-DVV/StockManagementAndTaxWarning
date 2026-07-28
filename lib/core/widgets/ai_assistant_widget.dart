import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/settings/providers/ai_knowledge_provider.dart';
import '../assets/app_assets.dart';
import '../theme/app_theme.dart';

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
  static const _launcherXKey = 'ai_assistant_launcher_x';
  static const _launcherYKey = 'ai_assistant_launcher_y';

  final TextEditingController _queryController = TextEditingController();
  Offset? _normalizedLauncherPosition;
  bool _isDraggingLauncher = false;
  final List<_AssistantMessage> _messages = const [
    _AssistantMessage(
      fromUser: false,
      text:
          'Bạn có thể tra cứu hướng dẫn bán hàng, tồn kho, công nợ và tài liệu thuế đang được bật trong hệ thống.',
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
    final normalized = _normalizedLauncherPosition ?? const Offset(1, 1);
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

  void _handleSend(String question) {
    final query = question.trim();
    if (query.isEmpty) return;

    setState(() {
      _messages.add(_AssistantMessage(fromUser: true, text: query));
      _queryController.clear();
    });

    final activeDocs = ref
        .read(aiKnowledgeProvider)
        .where((document) => document.isActive)
        .toList();

    Future<void>.delayed(const Duration(milliseconds: 350), () {
      if (!mounted) return;

      final normalizedQuery = query.toLowerCase();
      AiDocument? matchedDocument;
      for (final document in activeDocs) {
        final searchable = '${document.title} ${document.content}'
            .toLowerCase();
        final hasMatch = normalizedQuery
            .split(RegExp(r'\s+'))
            .where((word) => word.length > 3)
            .any(searchable.contains);
        if (hasMatch) {
          matchedDocument = document;
          break;
        }
      }

      setState(() {
        if (matchedDocument == null) {
          _messages.add(
            const _AssistantMessage(
              fromUser: false,
              text:
                  'Chưa có đủ nguồn đang bật để trả lời câu hỏi này. Hãy kiểm tra nguồn tài liệu hoặc bổ sung tài liệu phù hợp.',
            ),
          );
        } else {
          _messages.add(
            _AssistantMessage(
              fromUser: false,
              text: matchedDocument.content.trim(),
              source: matchedDocument.title,
            ),
          );
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isOpen = ref.watch(aiAssistantOpenProvider);
    final media = MediaQuery.of(context);
    final isMobile = media.size.width < 700;

    return LayoutBuilder(
      builder: (context, constraints) {
        final launcherSize = Size(isMobile ? 68 : 144, 68);
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
                    top: math.max(80, widget.topSafeInset + 16),
                    right: 16,
                    bottom: 16,
                    width: 408,
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
              if (widget.showLauncher && !isOpen)
                Positioned(
                  left: launcherPosition.dx,
                  top: launcherPosition.dy,
                  width: launcherSize.width,
                  height: launcherSize.height,
                  child: GestureDetector(
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
                      compact: isMobile,
                      dragging: _isDraggingLauncher,
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

class _MessageBlock extends StatelessWidget {
  final _AssistantMessage message;

  const _MessageBlock({required this.message});

  @override
  Widget build(BuildContext context) {
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.textPrimary,
                height: 1.5,
              ),
            ),
            if (message.source != null) ...[
              const SizedBox(height: 10),
              Text(
                'Nguồn: ${message.source}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AssistantLauncher extends StatelessWidget {
  final bool compact;
  final bool dragging;

  const _AssistantLauncher({required this.compact, required this.dragging});

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final primary = Theme.of(context).colorScheme.primary;

    return Semantics(
      button: true,
      label: 'Hỏi AI. Có thể kéo để đổi vị trí.',
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
                    color: primary.withValues(alpha: dragging ? 0.5 : 0.28),
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
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            Text(
                              'Kéo để đặt vị trí',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall
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
