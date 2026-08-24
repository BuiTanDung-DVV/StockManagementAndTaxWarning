import 'package:flutter/material.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/features/settings/presentation/ai_knowledge_management_screen.dart';
import 'package:flutter_app/features/settings/providers/ai_knowledge_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FailedKnowledgeNotifier extends AiKnowledgeNotifier {
  @override
  Future<List<AiDocument>> build() async {
    throw Exception('database unavailable');
  }
}

class _EmptyKnowledgeNotifier extends AiKnowledgeNotifier {
  @override
  Future<List<AiDocument>> build() async => const [];
}

Widget _app(AiKnowledgeNotifier Function() createNotifier) {
  return ProviderScope(
    overrides: [aiKnowledgeProvider.overrideWith(createNotifier)],
    child: MaterialApp(
      theme: AppTheme.lightTheme(AppColors.primary),
      home: const AiKnowledgeManagementScreen(),
    ),
  );
}

void main() {
  testWidgets(
    'AI knowledge database failure is not shown as an empty library',
    (tester) async {
      await tester.pumpWidget(_app(_FailedKnowledgeNotifier.new));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('Không thể tải kho tài liệu AI từ cơ sở dữ liệu.'),
        findsOneWidget,
      );
      expect(find.textContaining('Chưa có tài liệu nào'), findsNothing);
      expect(find.text('Thử lại'), findsOneWidget);
    },
  );

  testWidgets(
    'AI knowledge empty state is only used for an empty DB response',
    (tester) async {
      await tester.pumpWidget(_app(_EmptyKnowledgeNotifier.new));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('Chưa có tài liệu nào'), findsOneWidget);
      expect(
        find.text('Không thể tải kho tài liệu AI từ cơ sở dữ liệu.'),
        findsNothing,
      );
    },
  );
}
