import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/assets/app_icon.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/toast_service.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../sales/models/receipt_template_config.dart';
import '../../sales/services/receipt_pdf_service.dart';
import '../providers/operations_provider.dart';
import '../providers/shop_provider.dart';

class ReceiptTemplateScreen extends ConsumerStatefulWidget {
  const ReceiptTemplateScreen({super.key});
  @override
  ConsumerState<ReceiptTemplateScreen> createState() =>
      _ReceiptTemplateScreenState();
}

class _ReceiptTemplateScreenState extends ConsumerState<ReceiptTemplateScreen> {
  Map<String, dynamic>? _profile;
  Map<String, dynamic> _config = ReceiptTemplateConfig.normalize({});
  final _title = TextEditingController();
  final _footer = TextEditingController();
  final _imageCache = <String, Future<pw.ImageProvider>>{};
  Future<Uint8List>? _previewPdf;
  Timer? _debounce;
  Uint8List? _logoBytes;
  String? _uploadedLogoUrl;
  String? _error;
  bool _saving = false, _picking = false, _printing = false;
  bool _dirty = false, _allowExit = false, _mobilePreview = false;
  int _loadRevision = 0, _previewRevision = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final revision = ++_loadRevision;
    _debounce?.cancel();
    try {
      final profile = await ref
          .read(settingsOperationsRepositoryProvider)
          .shopProfile();
      if (!mounted || revision != _loadRevision) return;
      final config = ReceiptTemplateConfig.normalize(
        Map<String, dynamic>.from(
          profile['receiptTemplateConfig'] as Map? ?? const {},
        ),
      );
      if (!(profile['receiptTemplateConfig'] as Map? ?? const {}).containsKey(
        'footer',
      )) {
        config['footer'] = profile['receiptFooter']?.toString() ?? '';
      }
      setState(() {
        _profile = profile;
        _config = config;
        _title.text = config['title'] as String;
        _footer.text = config['footer'] as String;
        _logoBytes = null;
        _uploadedLogoUrl = null;
        _imageCache.clear();
        _dirty = false;
        _error = null;
      });
      _refreshPreview();
    } catch (_) {
      if (mounted && revision == _loadRevision) {
        setState(
          () => _error =
              'Không tải được mẫu phiếu. Vui lòng chọn một cửa hàng và thử lại.',
        );
      }
    }
  }

  void _change(String key, dynamic value) {
    setState(() {
      _config[key] = value;
      _dirty = true;
    });
    _schedulePreview();
  }

  void _schedulePreview() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _refreshPreview);
  }

  Future<pw.ImageProvider> _loadImage(String url) =>
      _imageCache.putIfAbsent(url, () => networkImage(url));

  Future<Uint8List> _buildPdf() => ReceiptPdfService.build(
    profile: Map<String, dynamic>.from(_profile!),
    config: Map<String, dynamic>.from(_config),
    logoBytes: _config['logoSource'] == 'custom' ? _logoBytes : null,
    imageLoader: _loadImage,
    order: receiptTemplateSampleOrder,
  );

  void _refreshPreview() {
    if (!mounted || _profile == null) return;
    final future = _buildPdf();
    // The settings tab can be visible while the preview tab is unmounted.
    unawaited(future.then<void>((_) {}, onError: (Object _, StackTrace _) {}));
    setState(() {
      _previewPdf = future;
      _previewRevision++;
    });
  }

  Future<void> _pickLogo() async {
    final revision = _loadRevision;
    setState(() => _picking = true);
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty || bytes.length > 4 * 1024 * 1024) {
        throw const FormatException('Logo phải có dung lượng không quá 4 MB.');
      }
      final name = file.name.toLowerCase();
      if (!['.png', '.jpg', '.jpeg', '.webp'].any(name.endsWith)) {
        throw const FormatException('Chọn ảnh PNG, JPG hoặc WEBP.');
      }
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      try {
        if (descriptor.width * descriptor.height > 20000000) {
          throw const FormatException(
            'Logo có độ phân giải quá lớn. Chọn ảnh nhỏ hơn 20 megapixel.',
          );
        }
        final codec = await descriptor.instantiateCodec(
          targetWidth: descriptor.width > 1200 ? 1200 : descriptor.width,
        );
        try {
          final frame = await codec.getNextFrame();
          try {
            final png = await frame.image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            if (png == null || png.lengthInBytes > 4 * 1024 * 1024) {
              throw const FormatException(
                'Logo sau xử lý vượt 4 MB. Chọn ảnh nhỏ hơn.',
              );
            }
            if (!mounted || revision != _loadRevision) return;
            setState(() {
              _logoBytes = png.buffer.asUint8List();
              _uploadedLogoUrl = null;
              _config['logoSource'] = 'custom';
              _config['showLogo'] = true;
              _config['logoUrl'] = '';
              _dirty = true;
            });
            _refreshPreview();
          } finally {
            frame.image.dispose();
          }
        } finally {
          codec.dispose();
        }
      } finally {
        descriptor.dispose();
        buffer.dispose();
      }
    } on FormatException catch (error) {
      if (mounted) ToastService.showError(error.message);
    } catch (_) {
      if (mounted) {
        ToastService.showError(
          'Không đọc được logo. Vui lòng chọn một ảnh khác.',
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _save() async {
    if (!ref.read(shopProvider).hasPermission('settings', 'edit')) {
      ToastService.showError(
        'Bạn chưa có quyền chỉnh mẫu phiếu của cửa hàng này.',
      );
      return;
    }
    if (_title.text.trim().isEmpty) {
      ToastService.showError('Vui lòng nhập tiêu đề phiếu.');
      return;
    }
    if (_config['logoSource'] == 'custom' &&
        _logoBytes == null &&
        '${_config['logoUrl']}'.isEmpty) {
      ToastService.showError('Vui lòng chọn ảnh logo riêng.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    final api = ref.read(apiClientProvider);
    final shopId = api.shopId;
    final session = api.sessionVersion;
    final revision = _loadRevision;
    final repository = ref.read(settingsOperationsRepositoryProvider);
    try {
      final pending = Map<String, dynamic>.from(_config);
      if (pending['logoSource'] == 'custom' && _logoBytes != null) {
        if (_uploadedLogoUrl == null) {
          final uploaded = await repository.uploadReceiptLogo(
            bytes: _logoBytes!,
            fileName: 'receipt-logo.png',
            contentType: 'image/png',
          );
          if (!mounted ||
              revision != _loadRevision ||
              api.shopId != shopId ||
              api.sessionVersion != session) {
            return;
          }
          _uploadedLogoUrl = uploaded['imageUrl']?.toString();
          if (_uploadedLogoUrl == null || _uploadedLogoUrl!.isEmpty) {
            throw ApiException(
              'Máy chủ chưa trả về địa chỉ logo. Vui lòng thử lại.',
            );
          }
        }
        pending['logoUrl'] = _uploadedLogoUrl;
      }
      if (!mounted ||
          revision != _loadRevision ||
          api.shopId != shopId ||
          api.sessionVersion != session) {
        return;
      }
      final profile = await repository.saveReceiptConfig(pending);
      if (!mounted ||
          revision != _loadRevision ||
          api.shopId != shopId ||
          api.sessionVersion != session) {
        return;
      }
      setState(() {
        _profile = profile;
        _config = ReceiptTemplateConfig.normalize(
          Map<String, dynamic>.from(profile['receiptTemplateConfig'] as Map),
        );
        _dirty = false;
      });
      ToastService.showSuccess('Đã lưu mẫu phiếu cho cửa hàng này.');
      _refreshPreview();
    } on ApiException catch (error) {
      if (mounted && revision == _loadRevision) {
        ToastService.showError(error.message);
      }
    } catch (_) {
      if (mounted && revision == _loadRevision) {
        ToastService.showError(
          'Chưa lưu được mẫu phiếu. Các chỉnh sửa vẫn được giữ để thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _print() async {
    setState(() => _printing = true);
    try {
      // Generate from the current draft, including changes made during debounce.
      final bytes = await _buildPdf();
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'mau-phieu-ban-hang.pdf',
      );
    } on ReceiptImageException catch (error) {
      if (mounted) ToastService.showError(error.message);
    } catch (_) {
      if (mounted) {
        ToastService.showError('Không mở được bản in. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _title.dispose();
    _footer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(shopProvider.select((s) => (s.currentShopId, s.isAllShops)), (
      previous,
      next,
    ) {
      if (previous != next) {
        setState(() {
          _profile = null;
          _error = null;
        });
        _load();
      }
    });
    final colors = AppThemeColors.of(context);
    final canEdit = ref.watch(shopProvider).hasPermission('settings', 'edit');
    return PopScope(
      canPop: (!_dirty && !_saving) || _allowExit,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _saving) return;
        final discard = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Bỏ các thay đổi chưa lưu?'),
            content: const Text(
              'Mẫu phiếu đang áp dụng của cửa hàng sẽ được giữ nguyên.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Tiếp tục chỉnh'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Bỏ thay đổi'),
              ),
            ],
          ),
        );
        if (discard == true && mounted) {
          setState(() => _allowExit = true);
          Navigator.of(this.context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: colors.bg,
        body: AppResponsiveContent(
          maxWidth: 1440,
          child: _profile == null
              ? Center(
                  child: _error == null
                      ? const CircularProgressIndicator()
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: () {
                                setState(() => _error = null);
                                _load();
                              },
                              child: const Text('Thử tải lại'),
                            ),
                          ],
                        ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppPageHeader(
                      title: 'Thiết kế mẫu phiếu',
                      subtitle:
                          'Chỉnh mẫu phiếu bán hàng của cửa hàng hiện tại.',
                      showBackButton: true,
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final wide = constraints.maxWidth >= 1000;
                          if (wide) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(width: 420, child: _editor()),
                                const SizedBox(width: 20),
                                Expanded(child: _preview()),
                              ],
                            );
                          }
                          return Column(
                            children: [
                              SegmentedButton<bool>(
                                segments: const [
                                  ButtonSegment(
                                    value: false,
                                    icon: AppIcon(Icons.tune_rounded, size: 18),
                                    label: Text('Thiết lập'),
                                  ),
                                  ButtonSegment(
                                    value: true,
                                    icon: AppIcon(
                                      Icons.visibility_outlined,
                                      size: 18,
                                    ),
                                    label: Text('Xem trước'),
                                  ),
                                ],
                                selected: {_mobilePreview},
                                onSelectionChanged: (v) =>
                                    setState(() => _mobilePreview = v.first),
                              ),
                              const SizedBox(height: 12),
                              Expanded(
                                child: _mobilePreview ? _preview() : _editor(),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        Text(
                          _dirty
                              ? 'Có thay đổi chưa lưu'
                              : 'Đang dùng mẫu đã lưu',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textSecondary,
                          ),
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _printing || _saving ? null : _print,
                              icon: const AppIcon(
                                Icons.print_outlined,
                                size: 18,
                              ),
                              label: Text(
                                _printing ? 'Đang mở…' : 'In thử / PDF',
                              ),
                            ),
                            FilledButton.icon(
                              onPressed:
                                  _saving || _picking || !_dirty || !canEdit
                                  ? null
                                  : _save,
                              icon: _saving
                                  ? const SizedBox.square(
                                      dimension: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const AppIcon(
                                      Icons.save_outlined,
                                      size: 18,
                                    ),
                              label: Text(
                                _saving ? 'Đang lưu…' : 'Lưu mẫu phiếu',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _editor() => AbsorbPointer(
    absorbing:
        _saving ||
        _picking ||
        !ref.read(shopProvider).hasPermission('settings', 'edit'),
    child: ListView(
      key: const PageStorageKey('receipt-editor'),
      children: [
        _section('Khổ giấy & bố cục', Icons.description_outlined, [
          _select(
            'paperSize',
            'Khổ giấy',
            {'80mm': 'Giấy cuộn 80mm', 'A4': 'Giấy A4'},
            onChanged: (v) {
              final a4 = v == 'A4';
              setState(() {
                _config['paperSize'] = v;
                _config['fontSize'] = a4 ? 10.0 : 8.5;
                _config['titleSize'] = a4 ? 18.0 : 12.0;
                _config['marginMm'] = a4 ? 10.0 : 3.5;
                _dirty = true;
              });
              _schedulePreview();
            },
          ),
          _select(
            'preset',
            'Mẫu bố cục',
            {'compact': 'Gọn', 'standard': 'Tiêu chuẩn', 'detailed': 'Đầy đủ'},
            onChanged: (v) {
              setState(() {
                _config = ReceiptTemplateConfig.applyPreset(_config, v);
                _dirty = true;
              });
              _schedulePreview();
            },
          ),
          const Text(
            'Chọn mẫu sẽ đặt lại cỡ chữ, khoảng cách và một số nội dung; giữ tiêu đề, lời nhắn và logo.',
            style: TextStyle(fontSize: 12),
          ),
        ]),
        _section('Logo trên phiếu', Icons.image_outlined, [
          _select('logoSource', 'Nguồn logo', {
            'shop': 'Logo cửa hàng',
            'custom': 'Logo riêng cho phiếu',
            'none': 'Không dùng logo',
          }),
          if (_config['logoSource'] != 'none') ...[
            _logoPreview(),
            if (_config['logoSource'] == 'custom')
              OutlinedButton.icon(
                onPressed: _picking ? null : _pickLogo,
                icon: const AppIcon(Icons.upload_file_outlined, size: 18),
                label: Text(_picking ? 'Đang đọc ảnh…' : 'Chọn ảnh logo'),
              ),
            if (_config['logoSource'] == 'custom')
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'PNG, JPG, WEBP · tối đa 4 MB. Ưu tiên PNG nền trong suốt. Chỉ tải lên khi lưu mẫu.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            _select('logoPosition', 'Vị trí logo', {
              'left': 'Bên trái',
              'center': 'Chính giữa',
              'right': 'Bên phải',
            }),
            _slider('logoWidthMm', 'Chiều rộng logo', 'mm'),
            _slider('logoHeightMm', 'Chiều cao logo', 'mm'),
            const Text(
              'Ảnh giữ nguyên tỷ lệ trong khung đã chọn, không bị kéo méo.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ]),
        _section('Tiêu đề & lời nhắn', Icons.notes_outlined, [
          TextField(
            controller: _title,
            maxLength: 100,
            decoration: const InputDecoration(labelText: 'Tiêu đề phiếu *'),
            onChanged: (v) => _change('title', v.trim()),
          ),
          _select('headerAlignment', 'Căn phần đầu phiếu', {
            'left': 'Căn trái',
            'center': 'Căn giữa',
            'right': 'Căn phải',
          }),
          TextField(
            controller: _footer,
            minLines: 2,
            maxLines: 4,
            maxLength: 500,
            decoration: const InputDecoration(labelText: 'Lời nhắn cuối phiếu'),
            onChanged: (v) => _change('footer', v.trim()),
          ),
          _select('footerAlignment', 'Căn lời nhắn', {
            'left': 'Căn trái',
            'center': 'Căn giữa',
            'right': 'Căn phải',
          }),
        ]),
        _section('Chữ, khoảng cách & lề', Icons.text_fields_rounded, [
          _select('fontFamily', 'Phông chữ', {
            'noto': 'Noto Sans',
            'inter': 'Inter',
          }),
          _slider('fontSize', 'Cỡ chữ nội dung', 'pt', step: .5),
          _slider('titleSize', 'Cỡ chữ tiêu đề', 'pt'),
          _slider('lineSpacing', 'Khoảng cách thêm giữa dòng', 'pt', step: .5),
          _slider('marginMm', 'Lề giấy', 'mm', step: .5),
          _slider('qrSizeMm', 'Kích thước QR', 'mm'),
        ], expanded: false),
        _section('Nội dung hiển thị', Icons.checklist_rounded, [
          for (final entry in ReceiptTemplateConfig.flags.entries)
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(entry.value),
              value: _config[entry.key] == true,
              onChanged: (value) => _change(entry.key, value),
            ),
          const Text(
            'Bật/tắt chỉ thay đổi nội dung in. Tổng tiền vẫn lấy từ đơn hàng và luôn hiển thị.',
            style: TextStyle(fontSize: 12),
          ),
        ], expanded: false),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Text(
            'Phiếu bán hàng nội bộ không thay thế hóa đơn điện tử.',
            style: TextStyle(fontSize: 12),
          ),
        ),
      ],
    ),
  );

  Widget _section(
    String title,
    IconData icon,
    List<Widget> children, {
    bool expanded = true,
  }) {
    final c = AppThemeColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: PageStorageKey(title),
        initiallyExpanded: expanded,
        leading: AppIcon(icon, size: 20, color: c.textSecondary),
        title: Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        shape: const Border(),
        collapsedShape: const Border(),
        childrenPadding: const EdgeInsets.all(16),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                children[i],
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _select(
    String key,
    String label,
    Map<String, String> options, {
    ValueChanged<String>? onChanged,
  }) => DropdownButtonFormField<String>(
    key: ValueKey('$key-${_config[key]}'),
    initialValue: _config[key] as String,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: options.entries
        .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
        .toList(),
    onChanged: (value) {
      if (value != null) (onChanged ?? (v) => _change(key, v))(value);
    },
  );

  Widget _slider(String key, String label, String unit, {double step = 1}) {
    final range = ReceiptTemplateConfig.ranges[key]!;
    final value = (_config[key] as num).toDouble();
    final formatted = value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
            Text(
              '$formatted $unit',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        Slider(
          semanticFormatterCallback: (v) =>
              '$label ${v.toStringAsFixed(1)} $unit',
          value: value,
          min: range[0],
          max: range[1],
          divisions: ((range[1] - range[0]) / step).round(),
          onChanged: (value) => _change(key, value),
        ),
      ],
    );
  }

  Widget _logoPreview() {
    final custom = _config['logoSource'] == 'custom';
    final bytes = custom ? _logoBytes : null;
    final url = custom
        ? _config['logoUrl']?.toString()
        : _profile?['logoUrl']?.toString();
    Widget empty(String text) => Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12),
      ),
    );
    return Container(
      height: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppThemeColors.of(context).divider),
        borderRadius: BorderRadius.circular(8),
      ),
      child: bytes != null
          ? Image.memory(bytes, fit: BoxFit.contain)
          : url?.isNotEmpty == true
          ? Image.network(
              url!,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => empty('Không tải được ảnh logo.'),
            )
          : empty(
              custom
                  ? 'Chưa chọn logo riêng'
                  : 'Cửa hàng chưa có logo. Bạn có thể chọn logo riêng cho phiếu.',
            ),
    );
  }

  Widget _preview() {
    final c = AppThemeColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.divider),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Xem trước · ${_config['paperSize']}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Dữ liệu minh họa · bản in dùng cùng mẫu này',
                  style: TextStyle(fontSize: 12, color: c.textSecondary),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: c.divider),
          Expanded(
            child: FutureBuilder<Uint8List>(
              future: _previewPdf,
              builder: (context, snapshot) {
                if (snapshot.hasError) return _previewError(snapshot.error);
                if (snapshot.connectionState != ConnectionState.done ||
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final bytes = snapshot.data!;
                return PdfPreview(
                  key: ValueKey(_previewRevision),
                  build: (_) async => bytes,
                  useActions: false,
                  canChangePageFormat: false,
                  canChangeOrientation: false,
                  canDebug: false,
                  allowPrinting: false,
                  allowSharing: false,
                  maxPageWidth: _config['paperSize'] == 'A4' ? 700 : 340,
                  padding: const EdgeInsets.all(16),
                  scrollViewDecoration: BoxDecoration(color: c.bg),
                  onError: (_, error) => _previewError(error),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewError(Object? error) => Center(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppIcon(Icons.info_outline_rounded, size: 24),
          const SizedBox(height: 10),
          Text(
            error is ReceiptImageException
                ? error.message
                : 'Không hiển thị được bản xem trước. Bạn có thể thử lại hoặc mở In thử / PDF.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              _imageCache.clear();
              _refreshPreview();
            },
            child: const Text('Thử lại xem trước'),
          ),
        ],
      ),
    ),
  );
}

final Map<String, dynamic> receiptTemplateSampleOrder = {
  'orderCode': 'MAU-001',
  'orderDate': '2026-11-06T03:30:00.000Z',
  'subtotal': 1250000,
  'discountAmount': 50000,
  'taxAmount': 0,
  'shippingFee': 30000,
  'totalAmount': 1230000,
  'paidAmount': 1000000,
  'remainingAmount': 230000,
  'customer': {'name': 'Nguyễn Minh Anh'},
  'notes': 'Kiểm tra số lượng và tình trạng hàng khi nhận.',
  'items': [
    {
      'quantity': 10,
      'unitPrice': 85000,
      'subtotal': 850000,
      'product': {
        'name': 'Xi măng PCB40 bao 50kg',
        'sku': 'XM-001',
        'unit': 'Bao',
      },
    },
    {
      'quantity': 2,
      'unitPrice': 200000,
      'subtotal': 400000,
      'product': {
        'name': 'Sơn lót nội thất kháng kiềm màu trắng',
        'sku': 'SON-002',
        'unit': 'Lon',
      },
    },
  ],
};
