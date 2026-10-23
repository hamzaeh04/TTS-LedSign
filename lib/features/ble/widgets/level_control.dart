import 'package:flutter/material.dart';

import '../../../constants/color_constants.dart';

/// Compact card showing an icon, a title, the current value (which also
/// doubles as the "send" button — tap it to push the value to the sign),
/// and a slider to adjust the value locally before sending.
class LevelControl extends StatelessWidget {
  const LevelControl({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    required this.onSend,
  });

  final IconData icon;
  final String title;
  final int value;
  final ValueChanged<int> onChanged;
  final VoidCallback? onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      decoration: BoxDecoration(
        color: bleCardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: bleTextDark),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: bleTextDark),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Tooltip(
                message: 'Tap to send $title',
                child: Material(
                  color: bleTagBg,
                  borderRadius: BorderRadius.circular(999),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: onSend,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      child: Text(
                        '$value',
                        style: const TextStyle(color: bleMaroon, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              activeTrackColor: bleMaroon,
              inactiveTrackColor: blePink,
              thumbColor: bleMaroon,
              overlayColor: bleMaroon.withValues(alpha: 0.12),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: value.toDouble(),
              min: 1,
              max: 8,
              divisions: 7,
              label: '$value',
              onChanged: onSend == null ? null : (v) => onChanged(v.round()),
              // Push the level to the sign when the user releases the slider.
              onChangeEnd: onSend == null ? null : (_) => onSend!(),
            ),
          ),
        ],
      ),
    );
  }
}
