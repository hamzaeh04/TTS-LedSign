import 'package:flutter/material.dart';

import '../../../led_protocol.dart';
import '../models/led_transport.dart';
import 'led_preview.dart';
import 'level_control.dart';
import 'message_card.dart';
import 'playlist_card.dart';
import 'sign_settings_card.dart';
import 'status_banner.dart';

class ControlPanel extends StatelessWidget {
  const ControlPanel({
    super.key,
    required this.transport,
    required this.previewMode,
    required this.sending,
    required this.onExitPreview,
    required this.onChangeCharacteristic,
    required this.messageController,
    required this.colorFont,
    required this.colorBackground,
    required this.onColorFontChanged,
    required this.onColorBackgroundChanged,
    required this.onInsertColorTag,
    required this.onClearMessage,
    required this.onSendMessage,
    required this.sendLog,
    required this.onClearLog,
    required this.addressHex,
    required this.onAddressChanged,
    required this.messageSlot,
    required this.onMessageSlotChanged,
    required this.movingMode,
    required this.onMovingModeChanged,
    required this.frameVariant,
    required this.onFrameVariantChanged,
    required this.speed,
    required this.onSpeedChanged,
    required this.onSendSpeed,
    required this.messageListOrder,
    required this.onToggleListSlot,
    required this.onSendPlaylist,
  });

  final LedTransport transport;
  final bool previewMode;
  final bool sending;
  final VoidCallback onExitPreview;
  final VoidCallback onChangeCharacteristic;

  final TextEditingController messageController;
  final LedColor colorFont;
  final LedColor colorBackground;
  final ValueChanged<LedColor> onColorFontChanged;
  final ValueChanged<LedColor> onColorBackgroundChanged;
  final VoidCallback onInsertColorTag;
  final VoidCallback onClearMessage;
  final VoidCallback onSendMessage;
  final String? sendLog;
  final VoidCallback onClearLog;

  final String addressHex;
  final ValueChanged<String> onAddressChanged;
  final String messageSlot;
  final ValueChanged<String> onMessageSlotChanged;
  final LedMovingMode movingMode;
  final ValueChanged<LedMovingMode> onMovingModeChanged;
  final LedFrameVariant frameVariant;
  final ValueChanged<LedFrameVariant> onFrameVariantChanged;

  final int speed;
  final ValueChanged<int> onSpeedChanged;
  final VoidCallback? onSendSpeed;

  final List<String> messageListOrder;
  final ValueChanged<String> onToggleListSlot;
  final VoidCallback onSendPlaylist;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        StatusBanner(
          transport: transport,
          previewMode: previewMode,
          onExitPreview: onExitPreview,
          onChangeCharacteristic: onChangeCharacteristic,
        ),
        const SizedBox(height: 16),
        LedPreview(controller: messageController),
        const SizedBox(height: 20),
        MessageCard(
          controller: messageController,
          previewMode: previewMode,
          sending: sending,
          colorFont: colorFont,
          colorBackground: colorBackground,
          onColorFontChanged: onColorFontChanged,
          onColorBackgroundChanged: onColorBackgroundChanged,
          onInsertColorTag: onInsertColorTag,
          onClearMessage: onClearMessage,
          onSend: onSendMessage,
          sendLog: sendLog,
          onClearLog: onClearLog,
        ),
        const SizedBox(height: 16),
        SignSettingsCard(
          addressHex: addressHex,
          onAddressChanged: onAddressChanged,
          previewMode: previewMode,
          messageSlot: messageSlot,
          onMessageSlotChanged: onMessageSlotChanged,
          movingMode: movingMode,
          onMovingModeChanged: onMovingModeChanged,
          frameVariant: frameVariant,
          onFrameVariantChanged: onFrameVariantChanged,
        ),
        const SizedBox(height: 16),
        LevelControl(
          icon: Icons.speed_outlined,
          title: 'Speed',
          value: speed,
          onChanged: onSpeedChanged,
          onSend: onSendSpeed,
        ),
        const SizedBox(height: 16),
        PlaylistCard(
          previewMode: previewMode,
          sending: sending,
          messageListOrder: messageListOrder,
          onToggleSlot: onToggleListSlot,
          onSend: onSendPlaylist,
        ),
      ],
    );
  }
}
