import 'package:flutter/material.dart';

import '../../../constants/color_constants.dart';
import '../../../led_protocol.dart';
import 'card_title.dart';
import 'send_log_panel.dart';

Color _swatchFor(LedColor color) {
  switch (color) {
    case LedColor.red:
      return Colors.red;
    case LedColor.yellow:
      return Colors.yellow.shade700;
    case LedColor.green:
      return Colors.green;
    case LedColor.cyan:
      return Colors.cyan;
    case LedColor.blue:
      return Colors.blue;
    case LedColor.purple:
      return Colors.purple;
    case LedColor.white:
      return Colors.white;
    case LedColor.black:
      return Colors.black;
  }
}

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

class MessageCard extends StatelessWidget {
  const MessageCard({
    super.key,
    required this.controller,
    required this.previewMode,
    required this.sending,
    required this.colorFont,
    required this.colorBackground,
    required this.onColorFontChanged,
    required this.onColorBackgroundChanged,
    required this.onInsertColorTag,
    required this.onClearMessage,
    required this.onSend,
    required this.sendLog,
    required this.onClearLog,
  });

  final TextEditingController controller;
  final bool previewMode;
  final bool sending;
  final LedColor colorFont;
  final LedColor colorBackground;
  final ValueChanged<LedColor> onColorFontChanged;
  final ValueChanged<LedColor> onColorBackgroundChanged;
  final VoidCallback onInsertColorTag;
  final VoidCallback onClearMessage;
  final VoidCallback onSend;
  final String? sendLog;
  final VoidCallback onClearLog;

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
          const CardTitle(icon: Icons.message_outlined, title: 'Message'),
          const SizedBox(height: 14),
          const Text(
            'Enter text to display',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: bleTextMuted),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            enabled: !previewMode,
            minLines: 1,
            maxLines: 3,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(color: bleTextDark, fontWeight: FontWeight.w600),
            decoration: _pillDecoration().copyWith(
              hintText: 'Tap to type on the keyboard',
              suffixIcon: IconButton(
                onPressed: previewMode ? null : onClearMessage,
                icon: const Icon(Icons.close, color: bleTextMuted),
                tooltip: 'Clear',
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _ColorField(
                  label: 'Text Color',
                  value: colorFont,
                  enabled: !previewMode,
                  onChanged: onColorFontChanged,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ColorField(
                  label: 'Background',
                  value: colorBackground,
                  enabled: !previewMode,
                  onChanged: onColorBackgroundChanged,
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: bleTagBg,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: previewMode ? null : onInsertColorTag,
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(Icons.add, color: bleMaroon, size: 18),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: (previewMode || sending) ? null : onSend,
              style: FilledButton.styleFrom(
                backgroundColor: bleMaroon,
                foregroundColor: Colors.white,
                disabledBackgroundColor: blePinkChip,
                disabledForegroundColor: bleMaroon.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
              icon: sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: bleMaroon),
                    )
                  : const Icon(Icons.play_arrow_rounded),
              label: Text(
                sending
                    ? 'Sending…'
                    : (previewMode ? 'Connect a device to send' : 'Send Message'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          if (sendLog != null) ...[
            const SizedBox(height: 14),
            SendLogPanel(log: sendLog!, onClear: onClearLog),
          ],
        ],
      ),
    );
  }
}

class _ColorField extends StatelessWidget {
  const _ColorField({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final LedColor value;
  final bool enabled;
  final ValueChanged<LedColor> onChanged;

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
        DropdownButtonFormField<LedColor>(
          initialValue: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: bleTextDark),
          style: const TextStyle(color: bleTextDark, fontWeight: FontWeight.w600, fontSize: 14),
          decoration: _pillDecoration(),
          items: LedColor.values.map((c) {
            return DropdownMenuItem(
              value: c,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _swatchFor(c),
                      shape: BoxShape.circle,
                      border: Border.all(color: bleTextMuted.withValues(alpha: 0.3)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(c.name[0].toUpperCase() + c.name.substring(1)),
                ],
              ),
            );
          }).toList(),
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
