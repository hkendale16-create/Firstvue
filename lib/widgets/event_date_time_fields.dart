import 'package:flutter/material.dart';

import '../theme/firstvue_theme.dart';

/// Reusable date + time picker row for event create/edit flows.
class EventDateTimeFields extends StatelessWidget {
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final String sectionLabel;
  final bool allowClear;

  const EventDateTimeFields({
    super.key,
    required this.value,
    required this.onChanged,
    this.sectionLabel = 'DATE & TIME',
    this.allowClear = false,
  });

  static String formatLabel(DateTime? dateTime) {
    if (dateTime == null) return 'Not set';
    final local = dateTime.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.month}/${local.day}/${local.year} · $hour:$minute $ampm';
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final initial = value ?? now.add(const Duration(days: 7));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365 * 3)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: FirstVueColors.gold,
              onPrimary: FirstVueColors.background,
              surface: FirstVueColors.surface,
              onSurface: FirstVueColors.ivory,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    final base = value ?? picked;
    onChanged(
      DateTime(
        picked.year,
        picked.month,
        picked.day,
        base.hour,
        base.minute,
      ),
    );
  }

  Future<void> _pickTime(BuildContext context) async {
    final base = value ?? DateTime.now().add(const Duration(days: 7));
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: FirstVueColors.gold,
              onPrimary: FirstVueColors.background,
              surface: FirstVueColors.surface,
              onSurface: FirstVueColors.ivory,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    onChanged(
      DateTime(
        base.year,
        base.month,
        base.day,
        picked.hour,
        picked.minute,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          sectionLabel,
          style: TextStyle(
            color: fv.tertiaryText,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickDate(context),
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                label: Text(
                  value == null
                      ? 'Pick date'
                      : '${value!.toLocal().month}/${value!.toLocal().day}/${value!.toLocal().year}',
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: value == null
                    ? () => _pickDate(context)
                    : () => _pickTime(context),
                icon: const Icon(Icons.schedule_outlined, size: 18),
                label: Text(
                  value == null
                      ? 'Pick time'
                      : () {
                          final local = value!.toLocal();
                          final hour =
                              local.hour % 12 == 0 ? 12 : local.hour % 12;
                          final ampm = local.hour >= 12 ? 'PM' : 'AM';
                          final minute =
                              local.minute.toString().padLeft(2, '0');
                          return '$hour:$minute $ampm';
                        }(),
                ),
              ),
            ),
          ],
        ),
        if (value != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  formatLabel(value),
                  style: TextStyle(color: fv.secondaryText, fontSize: 12),
                ),
              ),
              if (allowClear)
                TextButton(
                  onPressed: () => onChanged(null),
                  child: const Text('Clear'),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
