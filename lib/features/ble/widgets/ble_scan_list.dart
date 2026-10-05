import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'device_tile.dart';
import 'empty_state.dart';
import 'section_header.dart';

class BleScanList extends StatelessWidget {
  const BleScanList({
    super.key,
    required this.results,
    required this.scanning,
    required this.connecting,
    required this.onRefresh,
    required this.onConnect,
  });

  final List<ScanResult> results;
  final bool scanning;
  final bool connecting;
  final VoidCallback onRefresh;
  final ValueChanged<BluetoothDevice> onConnect;

  List<ScanResult> get _sortedByRssi {
    final sorted = [...results];
    sorted.sort((a, b) => b.rssi.compareTo(a.rssi));
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: 'Nearby BLE Devices',
            count: results.length,
            loading: scanning,
            onRefresh: onRefresh,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: results.isEmpty
                ? EmptyState(
              icon: Icons.bluetooth_searching,
              message: scanning
                  ? 'Scanning...'
                  : 'No devices found. Tap refresh to scan for the LED sign.',
              onRefresh: scanning ? null : onRefresh,
            )

                : ListView.builder(
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: _sortedByRssi.length,
              itemBuilder: (context, index) {
                final result = _sortedByRssi[index];
                final name = result.device.platformName.isNotEmpty
                    ? result.device.platformName
                    : 'Unknown Device';

                return DeviceTile(
                  name: name,
                  subtitle: result.device.remoteId.toString(),
                  rssi: result.rssi,
                  connecting: connecting,
                  recommended: index == 0,
                  onConnect: () => onConnect(result.device),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
