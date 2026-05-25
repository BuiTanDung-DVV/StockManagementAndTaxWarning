import 'package:flutter/material.dart';
import '../../../core/utils/toast_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/tax_service.dart';
import '../widgets/tax_warning_widget.dart';

class TaxEstimateScreen extends ConsumerStatefulWidget {
  const TaxEstimateScreen({super.key});

  @override
  ConsumerState<TaxEstimateScreen> createState() => _TaxEstimateScreenState();
}

class _TaxEstimateScreenState extends ConsumerState<TaxEstimateScreen> {
  String _selectedPeriod = '01'; // Default month 01
  String _selectedYear = DateTime.now().year.toString();
  
  bool _isLoading = false;
  Map<String, dynamic>? _reportData;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchEstimate();
    });
  }

  Future<void> _fetchEstimate() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final taxService = ref.read(taxServiceProvider);
      final data = await taxService.getTaxEstimate(_selectedPeriod, _selectedYear);
      setState(() {
        _reportData = data;
      });
    } catch (e) {
      if (mounted) {
        ToastService.showError('Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _exportHTKK() {
    final taxService = ref.read(taxServiceProvider);
    taxService.exportHTKK(_selectedPeriod, _selectedYear);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
                    decoration: const InputDecoration(labelText: 'Kỳ (Tháng/Quý)'),
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
                      for (int i = DateTime.now().year - 2; i <= DateTime.now().year; i++)
                        DropdownMenuItem(
                          value: i.toString(),
                          child: Text(i.toString()),
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
                : _reportData != null
                    ? Column(
                        children: [
                          TaxWarningWidget(
                            totalRevenue: double.tryParse(_reportData!['totalRevenue'].toString()) ?? 0,
                            vatOwed: double.tryParse(_reportData!['vatOwed'].toString()) ?? 0,
                            pitOwed: double.tryParse(_reportData!['pitOwed'].toString()) ?? 0,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _exportHTKK,
                            icon: const Icon(Icons.download),
                            label: const Text('Xuất XML HTKK (Mẫu 01/CNKD)'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                          ),
                        ],
                      )
                    : const Text('Chưa có dữ liệu'),
          ],
        ),
      ),
    );
  }
}

