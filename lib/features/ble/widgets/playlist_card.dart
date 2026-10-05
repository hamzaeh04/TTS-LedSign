import 'package:flutter/material.dart';

import '../../../constants/color_constants.dart';
import '../models/message_slots.dart';
import 'card_title.dart';

class PlaylistCard extends StatelessWidget {
  const PlaylistCard({
    super.key,
    required this.previewMode,
    required this.sending,
    required this.messageListOrder,
    required this.onToggleSlot,
    required this.onSend,
  });

  final bool previewMode;
  final bool sending;
  final List<String> messageListOrder;
  final ValueChanged<String> onToggleSlot;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final canSend = !previewMode && !sending && messageListOrder.isNotEmpty;

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
          const CardTitle(icon: Icons.playlist_play, title: 'Message Playlist'),
          const SizedBox(height: 4),
          const Text(
            'Tap slots in the order they should cycle. Tap a slot again '
                'to remove it.',
            style: TextStyle(color: bleTextMuted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final letter in kMessageSlots)
                _SlotChip(
                  label: letter,
                  selected: messageListOrder.contains(letter),
                  onTap: previewMode ? null : () => onToggleSlot(letter),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            messageListOrder.isEmpty
                ? 'No slots selected'
                : 'Order: ${messageListOrder.join(' → ')}',
            style: const TextStyle(color: bleTextMuted),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: canSend ? onSend : null,
              style: FilledButton.styleFrom(
                backgroundColor: canSend ? bleMaroon : blePinkChip,
                foregroundColor: canSend ? Colors.white : bleMaroon.withValues(alpha: 0.5),
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
                sending ? 'Sending…' : 'Send Playlist',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? bleMaroon : blePink,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: selected ? Colors.white : bleTextDark,
            ),
          ),
        ),
      ),
    );
  }
}
