import 'package:flutter/material.dart';
import '../../../core/widgets/app_navigation_back_button.dart';
import '../../../core/utils/toast_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/tax_service.dart';
import '../widgets/tax_warning_widget.dart';
import '../../settings/providers/tax_config_provider.dart';
import '../../../core/widgets/app_animations.dart';

class TaxEstimateScreen extends ConsumerStatefulWidget {
  const TaxEstimateScreen({super.key});

  @override
  ConsumerState<TaxEstimateScreen> createState() => _TaxEstimateScreenState();
}

class _TaxEstimateScreenState extends ConsumerState<TaxEstimateScreen> {
  String _selectedPeriod = '01'; // Default month 01
  String _selectedYear = DateTime.now().year.toString();

  bool _isLoading = false;
  bool _didStart = false;
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

  Future<void> _exportHTKK() async {
    final taxService = ref.read(taxServiceProvider);
    try {
      await taxService.exportHTKK(_selectedPeriod, _selectedYear);
      if (mounted) {
        ToastService.showSuccess('Đang mở liên kết tải xuống...');
      }
    } catch (e) {
      if (mounted) {
        ToastService.showError('Lỗi: $e');
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
                    onRetry: () => ref
                        .read(taxConfigProvider.notifier)
                        .refresh(),
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
      body: Padding(
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
                      const DropdownMenuItem(value: 'Q1', child: Text('Quý 1')),
                      const DropdownMenuItem(value: 'Q2', child: Text('Quý 2')),
                      const DropdownMenuItem(value: 'Q3', child: Text('Quý 3')),
                      const DropdownMenuItem(value: 'Q4', child: Text('Quý 4')),
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
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? AppInlineError(
                    message: _errorMessage!,
                    onRetry: _fetchEstimate,
                  )
                : _reportData != null
                ? Column(
                    children: [
                      TaxWarningWidget(
                        totalRevenue:
                            double.tryParse(
                              _reportData!['totalRevenue'].toString(),
                            ) ??
                            0,
                        vatOwed:
                            double.tryParse(
                              _reportData!['vatOwed'].toString(),
                            ) ??
                            0,
                        pitOwed:
                            double.tryParse(
                              _reportData!['pitOwed'].toString(),
                            ) ??
                            0,
                        exemptionThreshold: config.thresholds!.tier4,
                        policySourceCode:
                            config.policySourceCode ?? 'văn bản đang hiệu lực',
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _exportHTKK,
                        icon: const Icon(Icons.download),
                        label: const Text('Xuất XML HTKK (Mẫu 01/CNKD)'),
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
                : const Text('Chưa có dữ liệu cho kỳ đã chọn.'),
          ],
        ),
      ),
    );
  }
}
