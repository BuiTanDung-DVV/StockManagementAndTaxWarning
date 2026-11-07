import '../utils/search_text.dart';
import 'package:flutter/material.dart';
import '../assets/app_icon.dart';

/// A page-local filter. Server totals and pagination remain unchanged.
class LoadedRecordsFilter extends StatefulWidget {
  final List<dynamic> items;
  final Widget Function(List<dynamic>) builder;
  const LoadedRecordsFilter({
    super.key,
    required this.items,
    required this.builder,
  });
  @override
  State<LoadedRecordsFilter> createState() => _LoadedRecordsFilterState();
}

class _LoadedRecordsFilterState extends State<LoadedRecordsFilter> {
  final _search = TextEditingController();
  String? _status;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _recordText(dynamic item) => recordSearchText(item);
  String? _recordStatus(dynamic item) =>
      item is Map ? item['status']?.toString() : null;
  String _statusLabel(String status) =>
      const {
        'DRAFT': 'Nháp',
        'COMPLETED': 'Hoàn tất',
        'CANCELLED': 'Đã hủy',
        'PENDING': 'Chờ xử lý',
        'CONFIRMED': 'Đã xác nhận',
        'APPROVED': 'Đã duyệt',
        'REJECTED': 'Đã từ chối',
      }[status] ??
      status;
  @override
  Widget build(BuildContext context) {
    final query = foldSearchText(_search.text);
    final statuses =
        widget.items.map(_recordStatus).whereType<String>().toSet().toList()
          ..sort();
    // Keep a selected condition visible after a refresh removes its last row.
    if (_status != null && !statuses.contains(_status)) statuses.add(_status!);
    final filtered = widget.items
        .where(
          (item) =>
              (query.isEmpty || _recordText(item).contains(query)) &&
              (_status == null || _recordStatus(item) == _status),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText:
                      'Tìm trong ${widget.items.length} bản ghi trên trang này',
                  hintText: 'Tên, mã hoặc nội dung',
                  prefixIcon: const AppIcon(Icons.search, size: 18),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (statuses.isNotEmpty)
                    DropdownButton<String>(
                      hint: const Text('Tất cả trạng thái'),
                      value: statuses.contains(_status) ? _status : null,
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Tất cả trạng thái'),
                        ),
                        for (final status in statuses)
                          DropdownMenuItem(
                            value: status,
                            child: Text(_statusLabel(status)),
                          ),
                      ],
                      onChanged: (v) => setState(() => _status = v),
                    ),
                  Text(
                    '${filtered.length} / ${widget.items.length} bản ghi trên trang',
                  ),
                  if (query.isNotEmpty || _status != null)
                    TextButton.icon(
                      onPressed: () => setState(() {
                        _search.clear();
                        _status = null;
                      }),
                      icon: const AppIcon(Icons.close, size: 18),
                      label: const Text('Bỏ lọc'),
                    ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: (query.isNotEmpty || _status != null) && filtered.isEmpty
              ? const Center(
                  child: Text(
                    'Không có bản ghi phù hợp. Hãy đổi điều kiện hoặc bỏ lọc.',
                  ),
                )
              : widget.builder(filtered),
        ),
      ],
    );
  }
}
