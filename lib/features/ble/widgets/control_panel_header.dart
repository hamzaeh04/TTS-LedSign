import 'package:flutter/material.dart';

import '../../../constants/color_constants.dart';

class ControlPanelHeader extends StatelessWidget {
  const ControlPanelHeader({
    super.key,
    required this.showDisconnect,
    required this.onDisconnect,
  });

  final bool showDisconnect;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, topPadding + 12, 20, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expanded(
            child: Text(
              'LED Sign',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: bleTextDark),
            ),
          ),
          if (showDisconnect) _DisconnectButton(onPressed: onDisconnect),
        ],
      ),
    );
  }
}

class _DisconnectButton extends StatelessWidget {
  const _DisconnectButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bleBlueBg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: const Padding(
          padding: EdgeInsets.all(10),
          child: Icon(Icons.visibility_off_outlined, color: bleTextDark, size: 20),
        ),
      ),
    );
  }
}
