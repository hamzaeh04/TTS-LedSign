import 'package:flutter/material.dart';

import '../../../constants/color_constants.dart';
import '../../../led_protocol.dart';
import '../models/message_slots.dart';
import 'card_title.dart';

InputDecoration _pillDecoration() {
  return InputDecoration(
    filled: true,
    fillColor: blePink,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
  );
}

class SignSettingsCard extends StatelessWidget {
  const SignSettingsCard({
    super.key,
    required this.addressHex,
    required this.onAddressChanged,
    required this.previewMode,
    required this.messageSlot,
    required this.onMessageSlotChanged,
    required this.movingMode,
    required this.onMovingModeChanged,
    required this.frameVariant,
    required this.onFrameVariantChanged,
  });

  final String addressHex;
  final ValueChanged<String> onAddressChanged;
  final bool previewMode;
  final String messageSlot;
  final ValueChanged<String> onMessageSlotChanged;
  final LedMovingMode movingMode;
  final ValueChanged<LedMovingMode> onMovingModeChanged;
  final LedFrameVariant frameVariant;
  final ValueChanged<LedFrameVariant> onFrameVariantChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bleCardBg,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CardTitle(icon: Icons.tune_outlined, title: 'Sign Settings'),
          const SizedBox(height: 14),
          const Text(
            'Screen Address (hex, 00 all screens)',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: bleTextMuted),
          ),
          const SizedBox(height: 6),
          TextFormField(
            initialValue: addressHex,
            enabled: !previewMode,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(color: bleTextDark, fontWeight: FontWeight.w600),
            decoration: _pillDecoration(),
            onChanged: onAddressChanged,
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _LabeledDropdown<String>(
                  label: 'Slot',
                  value: messageSlot,
                  enabled: !previewMode,
                  items: [
                    for (final letter in kMessageSlots)
                      DropdownMenuItem(value: letter, child: Text(letter)),
                  ],
                  onChanged: onMessageSlotChanged,
                ),
              ),
              // const SizedBox(width: 12),
              // Expanded(
              //   flex: 2,
              //   child: _LabeledDropdown<LedMovingMode>(
              //     label: 'Moving Mode',
              //     value: movingMode,
              //     enabled: !previewMode,
              //     items: LedMovingMode.values.map((mode) {
              //       return DropdownMenuItem(
              //         value: mode,
              //         child: Text(mode.name[0].toUpperCase() + mode.name.substring(1)),
              //       );
              //     }).toList(),
              //     onChanged: onMovingModeChanged,
              //   ),
              // ),
            ],
          ),
          const SizedBox(height: 14),
          // Temporary: lets the client try each candidate message layout on
          // the real sign, since we don't have the hardware. Remove once the
          // working one is confirmed.
          _LabeledDropdown<LedFrameVariant>(
            label: 'Frame Format (test)',
            value: frameVariant,
            enabled: !previewMode,
            items: [
              for (final variant in LedFrameVariant.values)
                DropdownMenuItem(value: variant, child: Text(variant.label)),
            ],
            onChanged: onFrameVariantChanged,
          ),
        ],
      ),
    );
  }
}

class _LabeledDropdown<T> extends StatelessWidget {
  const _LabeledDropdown({
    required this.label,
    required this.value,
    required this.enabled,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final bool enabled;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: bleTextMuted),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<T>(
          initialValue: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: bleTextDark),
          style: const TextStyle(color: bleTextDark, fontWeight: FontWeight.w600, fontSize: 14),
          decoration: _pillDecoration(),
          items: items,
          onChanged: enabled
              ? (value) {
                  if (value == null) return;
                  onChanged(value);
                }
              : null,
        ),
      ],
    );
  }
}
