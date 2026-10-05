import 'package:flutter/material.dart';

import '../../../constants/color_constants.dart';

class CardTitle extends StatelessWidget {
  const CardTitle({super.key, required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: bleTextDark),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: bleTextDark),
        ),
      ],
    );
  }
}
