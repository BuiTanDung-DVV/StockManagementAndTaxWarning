import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/toast_service.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../providers/operations_provider.dart';

class BackupRestoreScreen extends ConsumerStatefulWidget {
  const BackupRestoreScreen({super.key});
  @override
  ConsumerState<BackupRestoreScreen> createState() =>
      _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends ConsumerState<BackupRestoreScreen> {
  bool _busy = false;
  Map<String, dynamic>? _preview;
  String? _rollbackId;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppThemeColors.of(context).bg,
    body: AppResponsiveContent(
      maxWidth: 1000,
      child: ListView(
        children: [
          const AppPageHeader(
            title: 'Sao lưu và khôi phục',
            subtitle:
                'Tạo bản sao riêng cho cửa hàng, kiểm tra chênh lệch trước khi thay thế dữ liệu.',
            showBackButton: true,
          ),
          const SizedBox(height: AppSpacing.md),
          AppCardContainer(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tạo bản sao',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  const Text(
                    'Gói dữ liệu có checksum, không chứa tài khoản, mật khẩu, token hay file ảnh gốc.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton.icon(
                    onPressed: _busy ? null : _export,
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Tải bản sao .smartstock-backup.gz'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCardContainer(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Khôi phục dữ liệu',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  const Text(
                    'Tệp tối đa 25 MB. Hệ thống sẽ kiểm tra phiên bản, cửa hàng và checksum trước khi cho phép khôi phục.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _pickAndValidate,
                    icon: const Icon(Icons.upload_file_outlined),
                    label: const Text('Chọn và kiểm tra bản sao'),
                  ),
                  if (_preview != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    _DifferenceTable(preview: _preview!),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton.icon(
                      onPressed: _busy ? null : _restore,
                      icon: const Icon(Icons.restore),
                      label: const Text('Xác nhận thay thế dữ liệu'),
                    ),
                  ],
                  if (_rollbackId != null) ...[
                    const Divider(height: AppSpacing.xl),
                    const Text('Đã tạo điểm hoàn tác trước khi khôi phục.'),
                    TextButton.icon(
                      onPressed: _busy ? null : _rollback,
                      icon: const Icon(Icons.undo),
                      label: const Text('Hoàn tác lần khôi phục vừa rồi'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_busy) ...[
            const SizedBox(height: AppSpacing.md),
            const LinearProgressIndicator(),
          ],
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    ),
  );

  Future<String?> _password(String title) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Mật khẩu hiện tại'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value?.trim().isNotEmpty == true ? value : null;
  }

  Future<void> _export() async {
    final password = await _password('Xác nhận tạo bản sao');
    if (password == null) return;
    setState(() => _busy = true);
    try {
      final bytes = await ref
          .read(settingsOperationsRepositoryProvider)
          .exportBackup(password);
      await FileSaver.instance.saveFile(
        name:
            'smartstock-backup-${DateTime.now().toIso8601String().substring(0, 10)}',
        bytes: bytes,
        fileExtension: 'smartstock-backup.gz',
        mimeType: MimeType.other,
        customMimeType: 'application/gzip',
      );
      ToastService.showSuccess('Đã tạo và tải bản sao dữ liệu');
    } catch (error) {
      ToastService.showError(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickAndValidate() async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['gz'],
    );
    if (picked == null) return;
    final Uint8List bytes = await picked.readAsBytes();
    final password = await _password('Xác nhận kiểm tra bản sao');
    if (password == null) return;
    setState(() => _busy = true);
    try {
      final data = await ref
          .read(settingsOperationsRepositoryProvider)
          .validateBackup(bytes, password);
      if (mounted) setState(() => _preview = data);
    } catch (error) {
      ToastService.showError(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final password = await _password('Xác nhận thay thế dữ liệu');
    if (password == null) return;
    setState(() => _busy = true);
    try {
      final data = await ref
          .read(settingsOperationsRepositoryProvider)
          .restoreBackup(_preview!['backupId'].toString(), password);
      if (mounted) {
        setState(() {
          _rollbackId = data['rollbackId']?.toString();
          _preview = null;
        });
      }
      ToastService.showSuccess('Khôi phục hoàn tất');
    } catch (error) {
      ToastService.showError(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rollback() async {
    final password = await _password('Xác nhận hoàn tác');
    if (password == null) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(settingsOperationsRepositoryProvider)
          .rollback(_rollbackId!, password);
      if (mounted) setState(() => _rollbackId = null);
      ToastService.showSuccess('Đã hoàn tác dữ liệu');
    } catch (error) {
      ToastService.showError(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _DifferenceTable extends StatelessWidget {
  const _DifferenceTable({required this.preview});
  final Map<String, dynamic> preview;
  @override
  Widget build(BuildContext context) {
    final current = Map<String, dynamic>.from(
      preview['currentCounts'] as Map? ?? const {},
    );
    final incoming = Map<String, dynamic>.from(
      preview['incomingCounts'] as Map? ?? const {},
    );
    final keys = {...current.keys, ...incoming.keys}
        .where((key) => (current[key] ?? 0) != (incoming[key] ?? 0))
        .take(12)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Chênh lệch chính',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.xs),
        if (keys.isEmpty)
          const Text('Số lượng bản ghi không thay đổi.')
        else
          ...keys.map(
            (key) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(child: Text(key)),
                  Text('${current[key] ?? 0}  →  ${incoming[key] ?? 0}'),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
