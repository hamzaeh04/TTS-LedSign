import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../../constants/color_constants.dart';

class BleServiceList extends StatelessWidget {
  const BleServiceList({
    super.key,
    required this.services,
    required this.onSelect,
  });

  final List<BluetoothService> services;
  final ValueChanged<BluetoothCharacteristic> onSelect;

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: bleMaroon),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      children: [
        for (final service in services) ...[
          _ServiceCard(service: service, onSelect: onSelect),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.service, required this.onSelect});

  final BluetoothService service;
  final ValueChanged<BluetoothCharacteristic> onSelect;

  @override
  Widget build(BuildContext context) {
    final count = service.characteristics.length;

    return Container(
      decoration: BoxDecoration(
        color: bleCardBg,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          childrenPadding: EdgeInsets.zero,
          backgroundColor: bleCardBg,
          collapsedBackgroundColor: bleCardBg,
          iconColor: bleTextDark,
          collapsedIconColor: bleTextDark,
          leading: Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: blePink,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.category_outlined, color: bleMaroon, size: 22),
          ),
          title: Text(
            'Service ${service.uuid}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: bleTextDark),
          ),
          subtitle: Text(
            '$count characteristic${count == 1 ? '' : 's'}',
            style: const TextStyle(fontSize: 13, color: bleTextMuted),
          ),
          children: [
            Container(
              width: double.infinity,
              color: blePink,
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(
                children: [
                  for (final characteristic in service.characteristics) ...[
                    _CharacteristicRow(characteristic: characteristic, onSelect: onSelect),
                    if (characteristic != service.characteristics.last) const SizedBox(height: 14),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CharacteristicRow extends StatelessWidget {
  const _CharacteristicRow({required this.characteristic, required this.onSelect});

  final BluetoothCharacteristic characteristic;
  final ValueChanged<BluetoothCharacteristic> onSelect;

  @override
  Widget build(BuildContext context) {
    final props = characteristic.properties;
    final tags = [
      if (props.write) 'Write',
      if (props.writeWithoutResponse) 'Write-no-response',
      if (props.notify) 'Notify',
      if (props.read) 'Read',
    ];
    final selectable = props.write || props.writeWithoutResponse;
    const iconIndent = 32.0; // icon width (22) + gap (10), for the wrapped tag row below

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.description_outlined, color: bleMaroon, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                characteristic.uuid.toString(),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: bleTextDark),
              ),
            ),
            const SizedBox(width: 8),
            if (selectable)
              FilledButton(
                onPressed: () => onSelect(characteristic),
                style: FilledButton.styleFrom(
                  backgroundColor: bleMaroon,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                child: const Text('Select'),
              )
            else if (tags.isEmpty)
              const Text(
                'No properties',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: bleTextDark),
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: tags.map((t) => _Tag(label: t)).toList(),
              ),
          ],
        ),
        if (selectable && tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: iconIndent),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: tags.map((t) => _Tag(label: t)).toList(),
            ),
          ),
        ],
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: bleTagBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: bleTextDark),
      ),
    );
  }
}
