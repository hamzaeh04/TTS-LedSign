import 'package:flutter/material.dart';

import '../../../constants/color_constants.dart';
import '../models/led_transport.dart';

class ScanChooser extends StatelessWidget {
  const ScanChooser({
    super.key,
    required this.transport,
    required this.onTransportChanged,
    required this.onPreview,
    required this.child,
  });

  final LedTransport transport;
  final ValueChanged<LedTransport> onTransportChanged;
  final VoidCallback onPreview;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: _ConnectCard(onPreview: onPreview),
        ),
        // BLE/Classic transport tab is removed — only BLE devices are supported.
        // Padding(
        //   padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        //   child: _TransportToggle(
        //     transport: transport,
        //     onChanged: onTransportChanged,
        //   ),
        // ),
        const SizedBox(height: 16),
        Expanded(child: child),
      ],
    );
  }
}

class _ConnectCard extends StatelessWidget {
  const _ConnectCard({required this.onPreview});

  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: blePink,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: bleMaroon,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.tv_outlined, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Connect to your sign',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  'Scan for nearby BLE devices to connect to the LED sign.',
                  style: TextStyle(fontSize: 12, color: Colors.black.withValues(alpha: 0.55)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onPreview,
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Icon(Icons.visibility_outlined, size: 16, color: bleMaroon),
                SizedBox(height: 4),
                Text(
                  'Preview screen\n(no device)',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 11,
                    color: bleMaroon,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// BLE/Classic transport tab is removed — only BLE devices are supported.
// Kept here (commented out) so the toggle can be restored easily if a second
// transport is ever re-enabled.
//
// class _TransportToggle extends StatelessWidget {
//   const _TransportToggle({required this.transport, required this.onChanged});
//
//   final LedTransport transport;
//   final ValueChanged<LedTransport> onChanged;
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(4),
//       decoration: BoxDecoration(
//         color: blePinkChip,
//         borderRadius: BorderRadius.circular(999),
//       ),
//       child: Row(
//         children: [
//           Expanded(
//             child: _ToggleSegment(
//               label: 'BLE',
//               icon: Icons.bluetooth,
//               selected: transport == LedTransport.ble,
//               onTap: () => onChanged(LedTransport.ble),
//             ),
//           ),
//           Expanded(
//             child: _ToggleSegment(
//               label: 'Classic',
//               icon: Icons.bluetooth_audio,
//               selected: transport == LedTransport.classic,
//               onTap: () => onChanged(LedTransport.classic),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// class _ToggleSegment extends StatelessWidget {
//   const _ToggleSegment({
//     required this.label,
//     required this.icon,
//     required this.selected,
//     required this.onTap,
//   });
//
//   final String label;
//   final IconData icon;
//   final bool selected;
//   final VoidCallback onTap;
//
//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: onTap,
//       child: AnimatedContainer(
//         duration: const Duration(milliseconds: 200),
//         padding: const EdgeInsets.symmetric(vertical: 10),
//         decoration: BoxDecoration(
//           color: selected ? bleMaroon : Colors.transparent,
//           borderRadius: BorderRadius.circular(999),
//         ),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(icon, size: 16, color: selected ? Colors.white : bleMaroon),
//             const SizedBox(width: 6),
//             Text(
//               label,
//               style: TextStyle(
//                 color: selected ? Colors.white : bleMaroon,
//                 fontWeight: FontWeight.w600,
//                 fontSize: 14,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
