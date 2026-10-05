import 'package:flutter/material.dart';

import '../../../constants/color_constants.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.message, this.onRefresh});

  final IconData icon;
  final String message;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                color: blePink,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: bleMaroon),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black.withValues(alpha: 0.55)),
            ),
            if (onRefresh != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: onRefresh,
                style: FilledButton.styleFrom(
                  backgroundColor: blePinkChip,
                  foregroundColor: bleMaroon,
                ),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Scan now'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
