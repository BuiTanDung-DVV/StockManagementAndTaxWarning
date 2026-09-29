import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/parse_utils.dart';
import '../../../core/utils/toast_service.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/widgets/app_navigation_back_button.dart';
import 'package:printing/printing.dart';
import '../../settings/providers/system_provider.dart';
import '../../settings/providers/tax_config_provider.dart';
import '../services/tax_declaration_pdf_service.dart';
import '../services/tax_service.dart';
import '../widgets/tax_export_format_dialog.dart';
import '../widgets/tax_warning_widget.dart';

class TaxEstimateScreen extends ConsumerStatefulWidget {
  const TaxEstimateScreen({super.key});

  @override
  ConsumerState<TaxEstimateScreen> createState() => _TaxEstimateScreenState();
}

class _TaxEstimateScreenState extends ConsumerState<TaxEstimateScreen> {
  String _selectedPeriod = DateTime.now().month.toString().padLeft(2, '0');
  String _selectedYear = DateTime.now().year.toString();

  bool _isLoading = false;
  bool _didStart = false;
  bool _isExporting = false;
  Map<String, dynamic>? _reportData;
  String? _errorMessage;

  Future<void> _fetchEstimate() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final taxService = ref.read(taxServiceProvider);
      final data = await taxService.getTaxEstimate(
        _selectedPeriod,
        _selectedYear,
      );
      if (!mounted) return;
      setState(() => _reportData = data);
    } catch (e) {
      if (mounted) {
        setState(() {
          _reportData = null;
          _errorMessage =
              'Không thể tải báo cáo của kỳ đã chọn. Kiểm tra cấu hình thuế từ DB rồi thử lại.';
        });
        ToastService.showError('Không thể tải báo cáo thuế kỳ đã chọn.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _exportDeclaration() async {
    final format = await showTaxExportFormatDialog(
      context: context,
      period: _selectedPeriod,
      year: _selectedYear,
      formCode: '01/CNKD',
    );
    if (format == null || !mounted) return;

    if (format == TaxExportFormat.pdf) {
      try {
        final profile = ref.read(shopProfileProvider).value ?? {};
        final config = ref.read(taxConfigProvider);
        final shopName =
            _reportData?['shopName']?.toString() ??
            profile['shopName']?.toString() ??
            'Hộ kinh doanh SmartStock';
        final taxCode =
            _reportData?['taxCode']?.toString() ??
            profile['taxCode']?.toString() ??
            'Chưa cập nhật';
        final totalRevenue = asDouble(_reportData?['totalRevenue']);
        final vatOwed = asDouble(_reportData?['vatOwed']);
        final pitOwed = asDouble(_reportData?['pitOwed']);
        final isExempt = _reportData?['taxExempt'] == true;

        final pdfBytes = await TaxDeclarationPdfService.build(
          shopName: shopName,
          taxCode: taxCode,
          businessSector: config.businessType.label,
          period: _selectedPeriod,
          year: _selectedYear,
          revenue: totalRevenue,
          vatRate: config.effectiveVatRate,
          pitRate: config.effectivePitRate,
          vatAmount: vatOwed,
          pitAmount: pitOwed,
          policySourceCode: config.policySourceCode ?? 'TT 40/2021/TT-BTC',
          isExempt: isExempt,
        );

        await Printing.layoutPdf(
          onLayout: (_) async => pdfBytes,
          name: 'To_khai_01_CNKD_${_selectedPeriod}_$_selectedYear.pdf',
        );
      } catch (e) {
        if (mounted) {
          ToastService.showError('Không thể tạo bản in PDF: $e');
        }
      }
      return;
    }

    if (_isExporting) return;
    setState(() => _isExporting = true);
    final taxService = ref.read(taxServiceProvider);
    try {
      await taxService.exportHTKK(_selectedPeriod, _selectedYear);
      if (mounted) {
        ToastService.showSuccess('Đang mở liên kết tải xuống XML...');
      }
    } catch (e) {
      if (mounted) {
        final message = e.toString().replaceFirst('Exception: ', '').trim();
        ToastService.showError(
          message.isNotEmpty
              ? message
              : 'Không thể xuất file XML HTKK. Vui lòng thử lại sau.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(taxConfigProvider);
    if (!config.isLoaded) {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leadingWidth: Navigator.of(context).canPop() ? 60 : null,
          leading: Navigator.of(context).canPop()
              ? AppNavigationBackLeading(
                  onPressed: () => Navigator.of(context).pop(),
                )
              : null,
          title: const Text('Ước tính & xuất thuế (HTKK)'),
        ),
        body: Center(
          child: config.isLoading
              ? const CircularProgressIndicator()
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: AppInlineError(
                    message:
                        config.errorMessage ??
                        'Không thể tải cấu hình thuế từ DB.',
                    onRetry: () =>
                        ref.read(taxConfigProvider.notifier).refresh(),
                  ),
                ),
        ),
      );
    }
    final fiscalYear = config.fiscalYear.toString();
    if (!_didStart) {
      _didStart = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _selectedYear = fiscalYear);
          _fetchEstimate();
        }
      });
    }
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: Navigator.of(context).canPop() ? 60 : null,
        leading: Navigator.of(context).canPop()
            ? AppNavigationBackLeading(
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: const Text('Ước Tính & Xuất Thuế (HTKK)'),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchEstimate,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedPeriod,
                      decoration: const InputDecoration(
                        labelText: 'Kỳ (Tháng/Quý)',
                      ),
                      items: [
                        for (int i = 1; i <= 12; i++)
                          DropdownMenuItem(
                            value: i.toString().padLeft(2, '0'),
                            child: Text('Tháng $i'),
                          ),
                        const DropdownMenuItem(
                          value: 'Q1',
                          child: Text('Quý 1'),
                        ),
                        const DropdownMenuItem(
                          value: 'Q2',
                          child: Text('Quý 2'),
                        ),
                        const DropdownMenuItem(
                          value: 'Q3',
                          child: Text('Quý 3'),
                        ),
                        const DropdownMenuItem(
                          value: 'Q4',
                          child: Text('Quý 4'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedPeriod = val;
                          });
                          _fetchEstimate();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedYear,
                      decoration: const InputDecoration(labelText: 'Năm'),
                      items: [
                        DropdownMenuItem(
                          value: fiscalYear,
                          child: Text(fiscalYear),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedYear = val;
                          });
                          _fetchEstimate();
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : _errorMessage != null
                  ? AppInlineError(
                      message: _errorMessage!,
                      onRetry: _fetchEstimate,
                    )
                  : _reportData != null
                  ? Column(
                      children: [
                        TaxWarningWidget(
                          totalRevenue: asDouble(_reportData!['totalRevenue']),
                          vatOwed: asDouble(_reportData!['vatOwed']),
                          pitOwed: asDouble(_reportData!['pitOwed']),
                          exemptionThreshold: config.thresholds?.tier4 ?? 0.0,
                          policySourceCode:
                              config.policySourceCode ??
                              'văn bản đang hiệu lực',
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _isExporting ? null : _exportDeclaration,
                          icon: _isExporting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.download),
                          label: Text(
                            _isExporting
                                ? 'Đang xuất XML...'
                                : 'Kết xuất tờ khai (XML / PDF)',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    )
                  : const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: AppEmpty(
                        message: 'Chưa có dữ liệu cho kỳ đã chọn.',
                        subtitle:
                            'Hãy chọn kỳ báo cáo khác hoặc kiểm tra lại doanh thu phát sinh.',
                        visual: AppEmptyVisual.tax,
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
