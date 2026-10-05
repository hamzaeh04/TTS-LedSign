import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SendLogPanel extends StatelessWidget {
  const SendLogPanel({super.key, required this.log, required this.onClear});

  final String log;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.terminal, size: 16, color: colors.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Send log',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: log));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Log copied')),
                  );
                },
                icon: const Icon(Icons.copy, size: 16),
                tooltip: 'Copy log',
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.close, size: 16),
                tooltip: 'Clear log',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          Text(
            'Screenshot this for debugging',
            style: TextStyle(fontSize: 10, color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          SelectableText(
            log,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
