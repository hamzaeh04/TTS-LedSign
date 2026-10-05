import 'package:flutter/material.dart';
import 'package:flutter_classic_bluetooth/flutter_classic_bluetooth.dart';

import 'device_tile.dart';
import 'empty_state.dart';
import 'section_header.dart';

class ClassicScanList extends StatelessWidget {
  const ClassicScanList({
    super.key,
    required this.pairedDevices,
    required this.discoveredDevices,
    required this.discovering,
    required this.connecting,
    required this.onRefresh,
    required this.onConnect,
  });

  final List<BtcDevice> pairedDevices;
  final List<BtcDevice> discoveredDevices;
  final bool discovering;
  final bool connecting;
  final VoidCallback onRefresh;
  final ValueChanged<BtcDevice> onConnect;

  Widget _deviceTile(BtcDevice found) {
    return DeviceTile(
      name: found.name ?? found.address,
      subtitle: found.address,
      connecting: connecting,
      onConnect: () => onConnect(found),
    );
  }

  @override
  Widget build(BuildContext context) {
    final knownAddresses = pairedDevices.map((d) => d.address).toSet();

    final nearbyOnly = discoveredDevices
        .where((d) => !knownAddresses.contains(d.address))
        .toList();

    final total = pairedDevices.length + nearbyOnly.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: 'Classic Bluetooth Devices',
            count: total,
            loading: discovering,
            onRefresh: onRefresh,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: total == 0
                ? EmptyState(
              icon: Icons.bluetooth_searching,
              message: discovering
                  ? 'Scanning...'
                  : 'No devices found. Tap refresh to scan for the LED sign.',
              onRefresh: discovering ? null : onRefresh,
            )
                : ListView(
              children: [
                ...pairedDevices.map(_deviceTile),
                ...nearbyOnly.map(_deviceTile),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
