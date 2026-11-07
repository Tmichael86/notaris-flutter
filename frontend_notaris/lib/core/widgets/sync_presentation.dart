import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

String syncLocalTime(Object? value, {bool precise = false}) {
  final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  if (date == null) return '—';
  if (precise) {
    return '${date.toIso8601String()} (lokal, UTC${date.timeZoneOffset.isNegative ? '-' : '+'}${date.timeZoneOffset.inMinutes.abs() ~/ 60}:${(date.timeZoneOffset.inMinutes.abs() % 60).toString().padLeft(2, '0')})';
  }
  String pad(int n) => n.toString().padLeft(2, '0');
  return '${pad(date.day)}/${pad(date.month)}/${date.year} ${pad(date.hour)}:${pad(date.minute)}:${pad(date.second)}';
}

class SyncDetailField extends StatelessWidget {
  const SyncDetailField(this.label, this.value, {super.key, this.copy = false});
  final String label, value;
  final bool copy;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: SelectableText(value)),
            if (copy)
              IconButton(
                tooltip: 'Salin $label',
                onPressed: () => Clipboard.setData(ClipboardData(text: value)),
                icon: const Icon(Icons.copy, size: 18),
              ),
          ],
        ),
      ],
    ),
  );
}
