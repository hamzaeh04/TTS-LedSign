import 'package:flutter/material.dart';

import '../../../constants/color_constants.dart';

class DeviceTile extends StatelessWidget {
  const DeviceTile({
    super.key,
    required this.name,
    required this.subtitle,
    required this.connecting,
    required this.onConnect,
    this.rssi,
    this.recommended = false,
  });

  final String name;
  final String subtitle;
  final bool connecting;
  final VoidCallback onConnect;
  final int? rssi;
  final bool recommended;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bleCardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: blePink,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.bluetooth, color: bleMaroon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.black.withValues(alpha: 0.45)),
                ),
                if (recommended) ...[
                  const SizedBox(height: 6),
                  const _RecommendedBadge(),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (rssi != null) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _SignalBars(rssi: rssi!),
                    const SizedBox(width: 4),
                    Text(
                      '$rssi dBm',
                      style: TextStyle(fontSize: 11, color: Colors.black.withValues(alpha: 0.45)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              _ConnectButton(
                connecting: connecting,
                highlighted: recommended,
                onPressed: onConnect,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecommendedBadge extends StatelessWidget {
  const _RecommendedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: lightGreenColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(color: neonGreenColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          const Text(
            'Recommended',
            style: TextStyle(fontSize: 10, color: neonGreenColor, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _ConnectButton extends StatelessWidget {
  const _ConnectButton({
    required this.connecting,
    required this.highlighted,
    required this.onPressed,
  });

  final bool connecting;
  final bool highlighted;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: connecting ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: highlighted ? bleMaroon : blePinkChip,
        foregroundColor: highlighted ? Colors.white : bleMaroon,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
      child: const Text('Connect'),
    );
  }
}

class _SignalBars extends StatelessWidget {
  const _SignalBars({required this.rssi});

  final int rssi;

  @override
  Widget build(BuildContext context) {
    final strength = rssi >= -60 ? 3 : (rssi >= -80 ? 2 : 1);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final active = i < strength;
        return Container(
          margin: const EdgeInsets.only(right: 2),
          width: 4,
          height: 6.0 + i * 4,
          decoration: BoxDecoration(
            color: active ? bleMaroon : blePink,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}
