import 'package:flutter/material.dart';
import '../assets/app_icon.dart';
import 'package:intl/intl.dart';

class BusinessDateField extends StatelessWidget {
  final String label;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onChanged;
  final bool enabled;

  const BusinessDateField({
    super.key,
    required this.label,
    required this.selectedDate,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final formattedDate = dateFormat.format(selectedDate);

    return Semantics(
      button: true,
      enabled: enabled,
      child: InkWell(
        onTap: enabled
            ? () async {
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);
                final selectedOnly = DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                );
                final initial = selectedOnly.isAfter(today)
                    ? today
                    : selectedOnly;

                final picked = await showDatePicker(
                  context: context,
                  initialDate: initial,
                  firstDate: DateTime(1),
                  lastDate: today,
                );
                if (picked != null && context.mounted) {
                  onChanged(picked);
                }
              }
            : null,
        borderRadius: BorderRadius.circular(4),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              floatingLabelBehavior: FloatingLabelBehavior.always,
              suffixIcon: const AppIcon(Icons.calendar_today),
              enabled: enabled,
            ),
            child: Text(formattedDate),
          ),
        ),
      ),
    );
  }
}
