import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../constants/color_constants.dart';

class BleHeader extends StatelessWidget {
  const BleHeader({
    super.key,
    required this.showDisconnect,
    required this.onDisconnect,
    this.description,
  });

  final bool showDisconnect;
  final VoidCallback onDisconnect;

  /// When set, the header switches to a left-aligned "page title" layout
  /// (bigger title + this instructional copy) instead of the plain
  /// centered logo caption used on the scan-chooser screen.
  final String? description;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final hasDescription = description != null;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.only(
            top: topPadding + 18,
            bottom: hasDescription ? 22 : 26,
            left: 20,
            right: 20,
          ),
          decoration: const BoxDecoration(
            color: bleMaroon,
            image: DecorationImage(
              image: AssetImage('assets/png/background-image.jpg'),
              fit: BoxFit.cover,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/png/logo.png', height: hasDescription ? 34 : 42),
                  SizedBox(height: hasDescription ? 18 : 10),
                  if (hasDescription)
                    SizedBox(
                      width: double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'LED Sign',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            description!,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    const Text(
                      'LED Sign',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                    ),
                ],
              ),
              if (showDisconnect)
                Positioned(
                  right: 0,
                  top: 0,
                  child: _DisconnectButton(onPressed: onDisconnect),
                ),
            ],
          ),
        ),
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
      color: Colors.white.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: const Padding(
          padding: EdgeInsets.all(10),
          child: Icon(Icons.link_off, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}
