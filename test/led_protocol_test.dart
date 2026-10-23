import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:iphone_bluetooth/led_protocol.dart';

/// Model of the sign's parser inferred from the client's four reports:
/// 0x00 bytes in the text area are ignored, the first remaining character is
/// swallowed, and (length - 4) / 2 characters are shown, reading past the end
/// of the frame (checksum, then stale buffer bytes) if the text is shorter.
String simulateSign(Uint8List frame, {int stale = 0x42}) {
  expect(frame.sublist(0, 5), [0x42, 0x54, 0x30, 0x31, 0x35]);
  final len = (frame[7] << 8) | frame[8];
  final textArea = [...frame.sublist(9 + 4), stale, stale, stale, stale, stale];
  final chars = textArea.where((b) => b != 0).skip(1).toList();
  final count = (len - 4) ~/ 2;
  return String.fromCharCodes(chars.take(count));
}

/// The pre-fix encoder, kept only to prove the model reproduces the bug.
Uint8List oldFrame(LedFrameVariant v, String text) {
  final padded = v == LedFrameVariant.b || v == LedFrameVariant.c;
  final tb = v == LedFrameVariant.d
      ? text.codeUnits
      : [for (final c in text.codeUnits) ...[c >> 8, c & 0xFF]];
  final payload = [0x41, 0x41, 0x31, 0x00, if (padded) ...[0, 0], ...tb];
  final len = v == LedFrameVariant.b ? payload.length - 2 : payload.length;
  var ck = 0;
  for (final b in payload) {
    ck ^= b;
  }
  return Uint8List.fromList(
      [0x42, 0x54, 0x30, 0x31, 0x35, 0x01, 0, len >> 8, len & 0xFF, ...payload, ck]);
}

Uint8List build(LedFrameVariant v, String t) => LedProtocol.sendMessage(
    messageSlot: 'A', movingMode: LedMovingMode.left, text: t, variant: v);

void main() {
  test('sign model reproduces the reported bugs with the old frames', () {
    // The checksum character depends on slot/mode (unknown on the client's
    // device), so only its position/count is compared, not its value.
    final a = simulateSign(oldFrame(LedFrameVariant.a, 'UBER FOR MARK'));
    final b = simulateSign(oldFrame(LedFrameVariant.b, 'UBER FOR MARK'));
    final c = simulateSign(oldFrame(LedFrameVariant.c, 'LYFT FOR MARK'));
    expect(a.length, 13);
    expect(a.startsWith('BER FOR MARK'), isTrue);
    expect(b, a);
    expect(c.length, 14);
    expect(c.startsWith('YFT FOR MARK'), isTrue);
    expect(c.endsWith('B'), isTrue);
    expect(simulateSign(oldFrame(LedFrameVariant.d, 'LYFT FOR MARK')), 'YFT FO');
  });

  const cases = [
    'UBER FOR MARK',
    'LYFT FOR MARK',
    'ABC',
    'A',
    'HELLO WORLD',
    'THIS IS A LONG MESSAGE FOR THE SIGN BOARD 0123456789 ABCDEFGHIJKLMNOPQRSTUVWXYZ',
  ];

  for (final v in LedFrameVariant.values) {
    for (final t in cases) {
      test('${v.name}: "$t"', () {
        final f = build(v, t);

        expect(simulateSign(f), t);

        // Structure: checksum is XOR of payload, frame is header(9)+payload+1.
        final payload = f.sublist(9, f.length - 1);
        var ck = 0;
        for (final b in payload) {
          ck ^= b;
        }
        expect(f.last, ck);

        // Real text is present, in order, after the lead char.
        final nonZero = payload.skip(4).where((b) => b != 0).toList();
        expect(String.fromCharCodes(nonZero), ' $t');

        // Building twice gives identical bytes (no state carried over).
        expect(build(v, t), f);
      });
    }
  }
}
