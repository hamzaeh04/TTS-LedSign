import 'package:flutter/material.dart';

import '../../../constants/color_constants.dart';

class LedPreview extends StatelessWidget {
  const LedPreview({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              const Icon(Icons.tv_outlined, size: 18, color: bleTextDark),
              const SizedBox(width: 8),
              const Text(
                'Live Preview',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: bleTextDark),
              ),
              const Spacer(),
              Icon(Icons.crop_free, size: 18, color: bleTextMuted),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF141414), Color(0xFF060606)],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.red.withValues(alpha: 0.25),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withValues(alpha: 0.08),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              final hasText = controller.text.isNotEmpty;
              final text = hasText ? controller.text.toUpperCase() : 'HELLO WORLD';

              return Text(
                text,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                  color: hasText
                      ? Colors.redAccent
                      : Colors.red.withValues(alpha: 0.25),
                  shadows: hasText
                      ? [
                    Shadow(
                      color: Colors.red.withValues(alpha: 0.9),
                      blurRadius: 14,
                    ),
                    Shadow(
                      color: Colors.redAccent.withValues(alpha: 0.6),
                      blurRadius: 28,
                    ),
                  ]
                      : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
