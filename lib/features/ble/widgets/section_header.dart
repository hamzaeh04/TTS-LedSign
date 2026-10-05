import 'package:flutter/material.dart';

import '../../../constants/color_constants.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    required this.count,
    required this.loading,
    required this.onRefresh,
  });

  final String title;
  final int count;
  final bool loading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                loading
                    ? 'Scanning…'
                    : (count == 0 ? 'No devices yet' : '$count found'),
                style: TextStyle(fontSize: 12, color: Colors.black.withValues(alpha: 0.45)),
              ),
            ],
          ),
        ),
        loading
            ? const Padding(
          padding: EdgeInsets.all(12),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: bleMaroon),
          ),
        )
            : TextButton.icon(
          onPressed: onRefresh,
          style: TextButton.styleFrom(
            backgroundColor: blePinkChip,
            foregroundColor: bleMaroon,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text(
            'Scan Again',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
