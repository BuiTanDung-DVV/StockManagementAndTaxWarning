import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/assets/app_icon.dart';
import '../../../core/offline/offline_store.dart';
import '../../../core/offline/offline_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/finance_display.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../settings/providers/shop_provider.dart';
import '../../auth/providers/auth_provider.dart';
import 'offline_duplicate_review_dialog.dart';
import '../../../core/offline/offline_catalog.dart';

class OfflineWorkspaceScreen extends ConsumerStatefulWidget {
  const OfflineWorkspaceScreen({super.key});
  @override
  ConsumerState<OfflineWorkspaceScreen> createState() =>
      _OfflineWorkspaceScreenState();
}

class _OfflineWorkspaceScreenState
    extends ConsumerState<OfflineWorkspaceScreen> {
  bool _syncing = false;
  String? _message;

  Future<void> _review(
    OfflineStore store,
    OfflineScope scope,
    OfflineOperation item,
  ) async {
    final decision = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => OfflineDuplicateReviewDialog(operation: item),
    );
    if (decision == null ||
        !mounted ||
        ref.read(offlineScopeProvider)?.key != scope.key) {
      return;
    }
    try {
      await store.approveReview(scope, item.id, decision);
      if (mounted && ref.read(offlineScopeProvider)?.key == scope.key) {
        await _sync(scope);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'Chưa xác nhận được. Mở lại ghi chép để kiểm tra; nội dung vẫn được giữ.',
        );
      }
    }
  }

  Future<void> _prepare() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cho phép mở dữ liệu trên thiết bị này?'),
        content: const Text(
          'Chỉ bật trên thiết bị cá nhân. App sẽ tải tài nguyên mở lại và danh mục hàng, khách hàng, nhà cung cấp theo quyền của bạn. Người sử dụng thiết bị có thể xem dữ liệu đã lưu mà không đăng nhập lại. Không lưu mật khẩu. Đăng xuất sẽ tắt quyền mở cục bộ. Ảnh và chứng từ chưa tải có thể vẫn cần mạng.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Để sau'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cho phép trên thiết bị này'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    final scopeKey = ref.read(offlineScopeProvider)?.key;
    var resourcesReady = false;
    setState(() => _syncing = true);
    try {
      await ref.read(authProvider.notifier).prepareOfflineWorkspace();
      resourcesReady = true;
      await prepareOfflineCatalog(
        ref,
        onProgress: (resource, done, total) {
          if (mounted && ref.read(offlineScopeProvider)?.key == scopeKey) {
            setState(
              () => _message =
                  'Đang tải ${offlineCatalogLabels[resource]}: $done/$total…',
            );
          }
        },
      );
      if (mounted && ref.read(offlineScopeProvider)?.key == scopeKey) {
        setState(
          () => _message =
              'Đã chuẩn bị danh mục để tìm và chọn khi mất mạng. Giá và tồn là số liệu lúc tải; máy chủ kiểm tra lại khi đồng bộ. Ảnh/chứng từ chưa tải có thể vẫn cần mạng.',
        );
      }
    } catch (_) {
      if (mounted && ref.read(offlineScopeProvider)?.key == scopeKey) {
        setState(
          () => _message = resourcesReady
              ? 'Đã chuẩn bị mở app nhưng chưa tải đủ danh mục. Thử lại khi có mạng; bạn chỉ xem được dữ liệu đã tải trước đó.'
              : 'Chưa chuẩn bị đủ dữ liệu cục bộ. Kiểm tra kết nối và quyền cửa hàng; nếu vừa cập nhật app, đóng các tab SmartStock rồi mở lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _reconnect() async {
    setState(() => _syncing = true);
    try {
      await ref.read(authProvider.notifier).reconnectOfflineSession();
      if (mounted) {
        setState(
          () => _message =
              'Đã xác thực lại phiên trực tuyến. Có thể đồng bộ dữ liệu.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'Chưa kết nối lại được. Ghi chép trên thiết bị được giữ nguyên.',
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _sync(OfflineScope scope) async {
    setState(() {
      _syncing = true;
      _message = null;
    });
    try {
      final engine = await ref.read(offlineSyncEngineProvider.future);
      await engine.sync(scope, manual: true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'Chưa thể đồng bộ. Nội dung đã lưu trên thiết bị được giữ nguyên.',
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _recordCash(OfflineStore store, OfflineScope scope) async {
    try {
      final draft = await store.draft(scope, 'cash');
      if (!mounted || ref.read(offlineScopeProvider)?.key != scope.key) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _LocalCashDialog(
          store: store,
          scope: scope,
          initial: draft == null
              ? const {}
              : Map<String, dynamic>.from(draft['payload'] as Map),
          isCurrent: () => ref.read(offlineScopeProvider)?.key == scope.key,
        ),
      );
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'Không mở được dữ liệu trên thiết bị. Chưa có nội dung nào được gửi.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = ref.watch(offlineScopeProvider);
    final storeAsync = ref.watch(offlineStoreProvider);
    final c = AppThemeColors.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: AppResponsiveContent(
        maxWidth: 1200,
        child: ListView(
          children: [
            const AppPageHeader(
              title: 'Dữ liệu trên thiết bị',
              showBackButton: true,
              subtitle:
                  'Giữ ghi chép khi mất mạng và gửi lên cửa hàng khi cần.',
            ),
            const SizedBox(height: 16),
            if (scope == null)
              const Text(
                'Đăng nhập và chọn một cửa hàng để xem dữ liệu đã lưu trên thiết bị.',
              )
            else
              storeAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => const Text(
                  'Không mở được bộ nhớ thiết bị. Không thể xác nhận đã lưu offline.',
                ),
                data: (store) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ref.watch(shopProvider).currentShopName ??
                                  'Cửa hàng',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Chờ đồng bộ là dữ liệu mới lưu ở thiết bị, chưa được ghi vào số tiền, công nợ hoặc tồn kho trên cloud. Máy chủ kiểm tra lại trước khi ghi.',
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _syncing
                                      ? null
                                      : ref.watch(authProvider).isOfflineSession
                                      ? _reconnect
                                      : _prepare,
                                  icon: const AppIcon(Icons.cloud_off_outlined),
                                  label: Text(
                                    ref.watch(authProvider).isOfflineSession
                                        ? 'Kết nối lại'
                                        : 'Chuẩn bị dữ liệu offline',
                                  ),
                                ),
                                if (ref
                                    .watch(shopProvider)
                                    .hasPermission('finance', 'edit'))
                                  FilledButton.icon(
                                    onPressed: () => _recordCash(store, scope),
                                    icon: const AppIcon(Icons.add),
                                    label: const Text('Ghi khoản thu / chi'),
                                  ),
                                OutlinedButton.icon(
                                  onPressed: _syncing
                                      ? null
                                      : () => _sync(scope),
                                  icon: const AppIcon(Icons.sync),
                                  label: Text(
                                    _syncing ? 'Đang đồng bộ…' : 'Đồng bộ ngay',
                                  ),
                                ),
                              ],
                            ),
                            FutureBuilder<bool>(
                              future: store.autoSync(scope),
                              builder: (context, setting) =>
                                  SwitchListTile.adaptive(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text(
                                      'Tự đồng bộ khi kết nối được máy chủ',
                                    ),
                                    subtitle: const Text(
                                      'Áp dụng cho cửa hàng này khi app đang mở. Tắt để chủ động gửi bằng Đồng bộ ngay.',
                                    ),
                                    value: setting.data ?? false,
                                    onChanged: setting.hasData
                                        ? (value) async {
                                            await store.setAutoSync(
                                              scope,
                                              value,
                                            );
                                            if (mounted) setState(() {});
                                            if (value) await _sync(scope);
                                          }
                                        : null,
                                  ),
                            ),
                            const Text(
                              'Dữ liệu lưu trong trình duyệt/thiết bị hiện tại. Không xóa dữ liệu trình duyệt khi còn bản ghi chưa đồng bộ.',
                            ),
                          ],
                        ),
                      ),
                    ),
                    FutureBuilder<Map<String, Object?>?>(
                      key: ValueKey('catalog-${scope.key}'),
                      future: ref
                          .watch(offlineCatalogProvider.future)
                          .then((catalog) => catalog.summary(scope)),
                      builder: (context, snapshot) {
                        final summary = snapshot.data;
                        final counts = summary?['counts'] as Map?;
                        final time = DateTime.tryParse(
                          '${summary?['downloadedAt']}',
                        )?.toLocal();
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 12,
                          ),
                          child: Text(
                            snapshot.hasError
                                ? 'Chưa đọc được bản danh mục trên thiết bị.'
                                : counts == null
                                ? 'Chưa có bản danh mục tải đầy đủ cho cửa hàng này.'
                                : 'Danh mục đã tải${time == null ? '' : ' lúc ${DateFormat('HH:mm dd/MM/yyyy').format(time)}'}: ${counts.entries.map((e) => '${e.value} ${offlineCatalogLabels[e.key]}').join(' · ')}. Đây là dữ liệu đã lưu, không phải tồn hiện tại.',
                          ),
                        );
                      },
                    ),
                    if (_message != null)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(_message!),
                      ),
                    const SizedBox(height: 12),
                    StreamBuilder<List<OfflineOperation>>(
                      stream: store.watch(scope),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return const Text(
                            'Không đọc được danh sách ghi chép. Hãy mở lại trang; không xóa dữ liệu thiết bị.',
                          );
                        }
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final items = snapshot.data!;
                        if (items.isEmpty) {
                          return const Card(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'Chưa có ghi chép chờ đồng bộ. Bạn có thể ghi một khoản thu hoặc chi ngay cả khi mất mạng.',
                              ),
                            ),
                          );
                        }
                        final pending = items
                            .where((i) => i.status != 'confirmed')
                            .length;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '$pending bản ghi chưa xác nhận · ${items.length - pending} đã đồng bộ',
                            ),
                            const SizedBox(height: 8),
                            for (final item in items)
                              Card(
                                child: ListTile(
                                  title: Text(_title(item)),
                                  subtitle: Text(
                                    '${_status(item.status)}${item.message == null ? '' : '\n${item.message}'}',
                                  ),
                                  isThreeLine: item.message != null,
                                  onTap: () => showDialog<void>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text(_title(item)),
                                      content: SingleChildScrollView(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Trạng thái: ${_status(item.status)}',
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              'Ngày: ${item.payload['transactionDate'] ?? item.payload['orderDate'] ?? ''}',
                                            ),
                                            if (item.payload['category'] !=
                                                null)
                                              Text(
                                                'Phân loại: ${financeCategoryLabel(item.payload['category'].toString())}',
                                              ),
                                            if (item.payload['paymentMethod'] !=
                                                null)
                                              Text(
                                                'Phương thức: ${financePaymentMethodLabel(item.payload['paymentMethod'].toString())}',
                                              ),
                                            if (item.payload['counterparty']
                                                    ?.toString()
                                                    .isNotEmpty ==
                                                true)
                                              Text(
                                                'Người nhận / nộp: ${item.payload['counterparty']}',
                                              ),
                                            if (item.payload['notes']
                                                    ?.toString()
                                                    .isNotEmpty ==
                                                true)
                                              Text(
                                                'Nội dung: ${item.payload['notes']}',
                                              ),
                                            if (item.message != null) ...[
                                              const SizedBox(height: 12),
                                              Text(item.message!),
                                            ],
                                          ],
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: const Text('Đóng'),
                                        ),
                                      ],
                                    ),
                                  ),
                                  trailing: item.status == 'reviewRequired'
                                      ? TextButton(
                                          onPressed: _syncing
                                              ? null
                                              : () =>
                                                    _review(store, scope, item),
                                          child: const Text('Kiểm tra trùng'),
                                        )
                                      : [
                                          'rejected',
                                          'authRequired',
                                          'pending',
                                        ].contains(item.status)
                                      ? TextButton(
                                          onPressed: _syncing
                                              ? null
                                              : () async {
                                                  await store.retry(
                                                    scope,
                                                    item.id,
                                                  );
                                                  await _sync(scope);
                                                },
                                          child: Text(
                                            item.value['attempts'] == 0
                                                ? 'Gửi'
                                                : 'Thử lại',
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _title(OfflineOperation item) {
    if (item.kind == 'CASH_TRANSACTION_CREATE') {
      final amount = num.tryParse(item.payload['amount'].toString()) ?? 0;
      return '${item.payload['type'] == 'INCOME' ? 'Thu' : 'Chi'} ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0).format(amount)} · ${item.payload['notes'] ?? item.payload['counterparty'] ?? ''}';
    }
    return item.kind == 'SALES_ORDER_CREATE'
        ? 'Ghi nhận bán hàng'
        : 'Phiếu nhập hàng';
  }

  String _status(String value) => switch (value) {
    'confirmed' => 'Đã được cloud xác nhận',
    'sending' => 'Đang gửi',
    'authRequired' => 'Cần đăng nhập hoặc kiểm tra quyền',
    'rejected' => 'Cần kiểm tra nội dung',
    'reviewRequired' => 'Cần đối chiếu giao dịch tương tự',
    _ => 'Đã lưu trên thiết bị · Chờ đồng bộ',
  };
}

class _LocalCashDialog extends StatefulWidget {
  final OfflineStore store;
  final OfflineScope scope;
  final Map<String, dynamic> initial;
  final bool Function() isCurrent;
  const _LocalCashDialog({
    required this.store,
    required this.scope,
    required this.initial,
    required this.isCurrent,
  });
  @override
  State<_LocalCashDialog> createState() => _LocalCashDialogState();
}

class _LocalCashDialogState extends State<_LocalCashDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _amount, _notes, _party;
  late String _type, _method, _date, _category;
  bool _busy = false;
  String? _error;
  final _operationId = newOperationId();
  Future<void> _draftWrite = Future.value();

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _amount = TextEditingController(text: p['amount']?.toString() ?? '');
    _notes = TextEditingController(text: p['notes']?.toString() ?? '');
    _party = TextEditingController(text: p['counterparty']?.toString() ?? '');
    _type = p['type'] == 'INCOME' ? 'INCOME' : 'EXPENSE';
    _method = p['paymentMethod'] == 'TRANSFER' ? 'TRANSFER' : 'CASH';
    _category = p['category']?.toString() ?? 'OTHER';
    _date =
        p['transactionDate']?.toString() ??
        DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  Map<String, dynamic> _payload() => {
    'type': _type,
    'amount': _amount.text.trim(),
    'notes': _notes.text.trim(),
    'counterparty': _party.text.trim(),
    'category': _category,
    'paymentMethod': _method,
    'transactionDate': _date,
  };
  void _saveDraft() {
    if (!widget.isCurrent()) return;
    final payload = _payload();
    _draftWrite = _draftWrite
        .catchError((_) {})
        .then(
          (_) => widget.store.saveDraft(
            widget.scope,
            'cash',
            'CASH_TRANSACTION_CREATE',
            payload,
          ),
        );
    unawaited(
      _draftWrite.catchError((_) {
        if (mounted) {
          setState(
            () => _error =
                'Chưa lưu được bản nháp. Giữ cửa sổ này và thử lưu lại.',
          );
        }
      }),
    );
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _busy) return;
    if (!widget.isCurrent()) {
      setState(() => _error = 'Cửa hàng đã thay đổi. Chưa gửi nội dung này.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _draftWrite;
      await widget.store.enqueue(
        widget.scope,
        'CASH_TRANSACTION_CREATE',
        {..._payload(), 'amount': num.parse(_amount.text.trim())},
        operationId: _operationId,
        draftId: 'cash',
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Chưa lưu được. Nội dung vẫn ở đây để bạn thử lại.';
        });
      }
    }
  }

  Future<void> _close() async {
    _saveDraft();
    try {
      await _draftWrite;
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Chưa giữ được nháp. Hãy sao chép nội dung trước khi rời trang.',
        );
      }
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _notes.dispose();
    _party.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('Ghi khoản thu / chi'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            onChanged: _saveDraft,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Lưu trên thiết bị trước. Số tiền chỉ cập nhật trên cloud sau khi đồng bộ thành công.',
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Loại ghi chép'),
                  items: const [
                    DropdownMenuItem(
                      value: 'EXPENSE',
                      child: Text('Khoản chi'),
                    ),
                    DropdownMenuItem(value: 'INCOME', child: Text('Khoản thu')),
                  ],
                  onChanged: _busy
                      ? null
                      : (value) {
                          setState(() {
                            _type = value!;
                            _category = 'OTHER';
                          });
                          _saveDraft();
                        },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amount,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Số tiền (đồng)',
                  ),
                  validator: (value) {
                    final n = num.tryParse(value?.trim() ?? '');
                    return n == null || !n.isFinite || n <= 0
                        ? 'Nhập số tiền lớn hơn 0, không dùng dấu phân cách.'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey('category-$_type'),
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'Phân loại'),
                  items:
                      (_type == 'INCOME'
                              ? const ['OTHER', 'CAPITAL', 'LOAN', 'SALES']
                              : const [
                                  'OTHER',
                                  'RENT',
                                  'UTILITIES',
                                  'SALARY',
                                  'TRANSPORT',
                                ])
                          .map(
                            (code) => DropdownMenuItem(
                              value: code,
                              child: Text(financeCategoryLabel(code)),
                            ),
                          )
                          .toList(),
                  onChanged: _busy
                      ? null
                      : (value) {
                          setState(() => _category = value!);
                          _saveDraft();
                        },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notes,
                  enabled: !_busy,
                  maxLength: 500,
                  decoration: const InputDecoration(labelText: 'Nội dung'),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Nhập nội dung để dễ tìm lại.'
                      : null,
                ),
                TextFormField(
                  controller: _party,
                  enabled: !_busy,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    labelText: 'Người nhận / người nộp (nếu có)',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _method,
                  decoration: const InputDecoration(labelText: 'Phương thức'),
                  items: const [
                    DropdownMenuItem(value: 'CASH', child: Text('Tiền mặt')),
                    DropdownMenuItem(
                      value: 'TRANSFER',
                      child: Text('Chuyển khoản'),
                    ),
                  ],
                  onChanged: _busy
                      ? null
                      : (v) {
                          setState(() => _method = v!);
                          _saveDraft();
                        },
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _busy
                      ? null
                      : () async {
                          final today = DateUtils.dateOnly(DateTime.now());
                          final selected = await showDatePicker(
                            context: context,
                            initialDate: DateTime.tryParse(_date) ?? today,
                            firstDate: DateTime(2000),
                            lastDate: today,
                          );
                          if (selected != null && mounted) {
                            setState(
                              () => _date = DateFormat(
                                'yyyy-MM-dd',
                              ).format(selected),
                            );
                            _saveDraft();
                          }
                        },
                  icon: const AppIcon(Icons.calendar_today),
                  label: Text('Ngày: $_date'),
                ),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : _close,
          child: const Text('Đóng và giữ nháp'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Đang lưu…' : 'Lưu trên thiết bị'),
        ),
      ],
    ),
  );
}
