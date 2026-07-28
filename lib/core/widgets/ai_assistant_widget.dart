import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

  const AiAssistantWidget({super.key, this.showLauncher = true});

  @override
  ConsumerState<AiAssistantWidget> createState() => _AiAssistantWidgetState();
}

class _AiAssistantWidgetState extends ConsumerState<AiAssistantWidget> {
  final TextEditingController _queryController = TextEditingController();
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
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _close() => ref.read(aiAssistantOpenProvider.notifier).close();

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
    final launcherBottom = isMobile ? 76.0 + media.padding.bottom : 16.0;

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
                top: 80,
                right: 16,
                bottom: widget.showLauncher ? 76 : 16,
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
              right: 16,
              bottom: launcherBottom,
              child: _AssistantLauncher(
                compact: isMobile,
                onPressed: () =>
                    ref.read(aiAssistantOpenProvider.notifier).open(),
              ),
            ),
        ],
      ),
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
                    assetPath: AppAssets.appIcon,
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
  final VoidCallback onPressed;

  const _AssistantLauncher({required this.compact, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Material(
      color: colors.surface,
      elevation: 4,
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: Container(
          constraints: const BoxConstraints(minHeight: 46),
          padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14),
          decoration: BoxDecoration(
            border: Border.all(color: colors.divider),
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppAssetIcon(
                assetPath: AppAssets.appIcon,
                size: 24,
                semanticLabel: 'Hỏi AI',
              ),
              if (!compact) ...[const SizedBox(width: 8), const Text('Hỏi AI')],
            ],
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
