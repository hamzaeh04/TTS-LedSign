import 'package:flutter/material.dart';

import '../../../constants/color_constants.dart';
import '../models/led_transport.dart';

class StatusBanner extends StatelessWidget {
  const StatusBanner({
    super.key,
    required this.transport,
    required this.previewMode,
    required this.onExitPreview,
    required this.onChangeCharacteristic,
  });

  final LedTransport transport;
  final bool previewMode;
  final VoidCallback onExitPreview;
  final VoidCallback onChangeCharacteristic;

  @override
  Widget build(BuildContext context) {
    final title = previewMode
        ? 'Preview mode'
        : (transport == LedTransport.ble
            ? 'Connected via BLE'
            : 'Connected via Classic Bluetooth');

    final subtitle = previewMode ? 'No device connected' : 'LED sign is ready';
    final icon = previewMode ? Icons.visibility_outlined : Icons.bluetooth;
    final iconBg = previewMode ? const Color(0xFFF59E0B) : bleBlue;

    String? trailingLabel;
    VoidCallback? onTrailing;
    if (previewMode) {
      trailingLabel = 'Exit';
      onTrailing = onExitPreview;
    } else if (transport == LedTransport.ble) {
      trailingLabel = 'Change';
      onTrailing = onChangeCharacteristic;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: blePink,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: bleTextDark),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: bleTextMuted),
                ),
              ],
            ),
          ),
          if (trailingLabel != null)
            TextButton(
              onPressed: onTrailing,
              style: TextButton.styleFrom(
                backgroundColor: blePinkChip,
                foregroundColor: bleMaroon,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              child: Text(
                trailingLabel,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}
