import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/toast_service.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../providers/operations_provider.dart';

class ProductCategoryManagementScreen extends ConsumerStatefulWidget {
  const ProductCategoryManagementScreen({super.key});
  @override
  ConsumerState<ProductCategoryManagementScreen> createState() =>
      _ProductCategoryManagementScreenState();
}

class _ProductCategoryManagementScreenState
    extends ConsumerState<ProductCategoryManagementScreen> {
  final _search = TextEditingController();
  Future<List<dynamic>>? _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => setState(() {
    _future = ref
        .read(settingsOperationsRepositoryProvider)
        .categories(search: _search.text);
  });

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeColors.of(context).bg,
      body: AppResponsiveContent(
        maxWidth: 1100,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppPageHeader(
              title: 'Danh mục sản phẩm',
              subtitle:
                  'Chuẩn hóa nhóm hàng và theo dõi số sản phẩm đang sử dụng.',
              showBackButton: true,
              action: FilledButton.icon(
                onPressed: () => _edit(),
                icon: const Icon(Icons.add),
                label: const Text('Thêm danh mục'),
              ),
              compactAction: IconButton.filled(
                onPressed: () => _edit(),
                icon: const Icon(Icons.add),
                tooltip: 'Thêm danh mục',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _reload(),
              decoration: InputDecoration(
                hintText: 'Tìm theo tên danh mục',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  onPressed: _reload,
                  icon: const Icon(Icons.arrow_forward),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: FutureBuilder<List<dynamic>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return _StateMessage(
                      icon: Icons.cloud_off_outlined,
                      title: 'Chưa tải được danh mục',
                      message: snapshot.error.toString(),
                      onRetry: _reload,
                    );
                  }
                  final items = snapshot.data ?? const [];
                  if (items.isEmpty) {
                    return _StateMessage(
                      icon: Icons.category_outlined,
                      title: 'Chưa có danh mục phù hợp',
                      message: 'Tạo danh mục đầu tiên để phân nhóm sản phẩm.',
                      onRetry: () => _edit(),
                      retryLabel: 'Tạo danh mục',
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                    itemCount: items.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final item = Map<String, dynamic>.from(items[index]);
                      final active = item['isActive'] != false;
                      final count = NumberFormatHelper.integer(
                        item['productCount'],
                      );
                      return AppCardContainer(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.xxs,
                          ),
                          leading: CircleAvatar(
                            child: Icon(
                              active
                                  ? Icons.category_outlined
                                  : Icons.pause_circle_outline,
                            ),
                          ),
                          title: Text(
                            item['name']?.toString() ?? 'Danh mục',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${item['description']?.toString().trim().isNotEmpty == true ? '${item['description']} · ' : ''}$count sản phẩm đang dùng${active ? '' : ' · Đã ngừng sử dụng'}',
                          ),
                          trailing: active
                              ? PopupMenuButton<String>(
                                  onSelected: (value) => value == 'edit'
                                      ? _edit(item)
                                      : _deactivate(item, items),
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Chỉnh sửa'),
                                    ),
                                    PopupMenuItem(
                                      value: 'deactivate',
                                      child: Text('Ngừng sử dụng'),
                                    ),
                                  ],
                                )
                              : const Chip(label: Text('Ngừng dùng')),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit([Map<String, dynamic>? item]) async {
    var name = item?['name']?.toString() ?? '';
    var description = item?['description']?.toString() ?? '';
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(item == null ? 'Thêm danh mục' : 'Sửa danh mục'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: name,
                onChanged: (value) => name = value,
                autofocus: true,
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'Tên danh mục *'),
              ),
              TextFormField(
                initialValue: description,
                onChanged: (value) => description = value,
                maxLength: 500,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Mô tả'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () async {
              if (name.trim().isEmpty) return;
              try {
                final repo = ref.read(settingsOperationsRepositoryProvider);
                final data = {
                  'name': name.trim(),
                  'description': description.trim(),
                };
                if (item == null) {
                  await repo.createCategory(data);
                } else {
                  await repo.updateCategory(item['id'] as int, data);
                }
                if (dialogContext.mounted) Navigator.pop(dialogContext, true);
              } catch (error) {
                ToastService.showError(error.toString());
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    if (saved == true) _reload();
  }

  Future<void> _deactivate(Map<String, dynamic> item, List<dynamic> all) async {
    int? replacement;
    final count = int.tryParse(item['productCount']?.toString() ?? '') ?? 0;
    final activeOptions = all
        .map((e) => Map<String, dynamic>.from(e))
        .where((e) => e['isActive'] != false && e['id'] != item['id'])
        .toList();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Ngừng sử dụng danh mục?'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count > 0
                      ? 'Danh mục đang có $count sản phẩm. Bạn có thể chuyển sang danh mục khác hoặc giữ nguyên trên sản phẩm cũ.'
                      : 'Danh mục sẽ không còn xuất hiện khi tạo sản phẩm mới.',
                ),
                if (count > 0 && activeOptions.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<int?>(
                    initialValue: replacement,
                    decoration: const InputDecoration(
                      labelText: 'Danh mục thay thế (không bắt buộc)',
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Giữ nguyên sản phẩm cũ'),
                      ),
                      ...activeOptions.map(
                        (e) => DropdownMenuItem<int?>(
                          value: e['id'] as int,
                          child: Text(e['name'].toString()),
                        ),
                      ),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => replacement = value),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Ngừng sử dụng'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(settingsOperationsRepositoryProvider)
          .deactivateCategory(
            item['id'] as int,
            replacementCategoryId: replacement,
          );
      _reload();
    } catch (error) {
      ToastService.showError(error.toString());
    }
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.onRetry,
    this.retryLabel = 'Thử lại',
  });
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onRetry;
  final String retryLabel;
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52),
          const SizedBox(height: AppSpacing.sm),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xxs),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(onPressed: onRetry, child: Text(retryLabel)),
        ],
      ),
    ),
  );
}

class NumberFormatHelper {
  static String integer(dynamic value) =>
      (int.tryParse(value?.toString() ?? '') ?? 0).toString();
}
