import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

Object? readableAuditValue(Object? value) {
  if (value is String) {
    try {
      return readableAuditValue(jsonDecode(value));
    } catch (_) {
      return value;
    }
  }
  if (value is Map) {
    return {
      for (final entry in value.entries)
        entry.key.toString():
            RegExp(
              r'password|secret|token|credential|otp|authorization|cookie',
              caseSensitive: false,
            ).hasMatch(entry.key.toString())
            ? '[Đã ẩn]'
            : readableAuditValue(entry.value),
    };
  }
  if (value is List) return value.map(readableAuditValue).toList();
  return value;
}

class ActivityLogDetailDialog extends StatelessWidget {
  final Map log;
  final String actor;
  final String action;
  const ActivityLogDetailDialog({
    super.key,
    required this.log,
    required this.actor,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    final rawDate = '${log['createdAt'] ?? log['created_at'] ?? ''}';
    final date = DateTime.tryParse(rawDate);
    final fields = <String, Object?>{
      'Thao tác': action,
      'Người thực hiện': actor,
      if (log['userId'] != null) 'Mã người dùng': log['userId'],
      'Thời gian': date == null
          ? rawDate
          : DateFormat('dd/MM/yyyy HH:mm:ss').format(date.toLocal()),
      'Đối tượng': log['entityName'] ?? log['entityType'],
      'Mã đối tượng': log['entityId'],
      'Mô tả': log['description'] ?? log['message'],
      'Dữ liệu trước thay đổi': log['oldValue'],
      'Dữ liệu sau thay đổi': log['newValue'],
      'Thông tin bổ sung': log['details'] ?? log['metadata'],
    }..removeWhere((_, value) => value == null || value.toString().isEmpty);
    return AlertDialog(
      title: const Text('Chi tiết hoạt động'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: fields.entries.map((entry) {
              final value = readableAuditValue(entry.value);
              final text = value is Map || value is List
                  ? const JsonEncoder.withIndent('  ').convert(value)
                  : '$value';
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.key,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 4),
                    SelectableText(text),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Đóng'),
        ),
      ],
    );
  }
}
