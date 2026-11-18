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

/// Stateful model of the sign: stores one text per slot, shows the slot last
/// written, and ignores any message frame that arrives while it is still busy
/// applying a speed change (the behaviour that matches the client's "old
/// message stays on screen" report). Time is virtual, in milliseconds.
class SignDevice {
  static const busyAfterSpeedMs = 300;

  final Map<String, String> slots = {};
  String displayed = '';
  int speed = 0;
  int _busyUntil = 0;
  final dropped = <String>[];

  void receive(Uint8List frame, int atMs) {
    final type = frame[5];
    if (type == 0x03) {
      speed = frame[10] - 0x30;
      _busyUntil = atMs + busyAfterSpeedMs;
      return;
    }
    if (type != 0x01) return;
    final shown = simulateSign(frame);
    if (atMs < _busyUntil) {
      dropped.add(shown);
      return;
    }
    final slot = String.fromCharCode(frame[9]);
    slots[slot] = shown;
    displayed = shown;
  }
}

/// What the OLD app did on every tap: speed frame, then message frame, no gap.
void oldTap(SignDevice d, LedFrameVariant v, String text, int clock) {
  d.receive(LedProtocol.sendSpeed(5), clock);
  d.receive(build(v, text), clock + 20);
}

/// What the app does now: replays LedProtocol.messageSequence with the real
/// inter-frame delay.
void newTap(SignDevice d, LedFrameVariant v, String text, int clock) {
  final frames = LedProtocol.messageSequence(
    messageSlot: 'A',
    movingMode: LedMovingMode.left,
    text: text,
    speed: 5,
    variant: v,
  );
  d.receive(frames[0], clock);
  d.receive(frames[1], clock + LedProtocol.interFrameDelay.inMilliseconds);
}

void main() {
  test('old speed-first order leaves the previous message on screen', () {
    final d = SignDevice();
    d.receive(build(LedFrameVariant.a, 'UBER AND LYFT'), 0); // earlier send
    d.receive(LedProtocol.sendSpeed(5), 1000); // speed slider released
    oldTap(d, LedFrameVariant.a, 'UBER FOR MARK', 1100); // tap lands in busy window
    expect(d.displayed, 'UBER AND LYFT'); // the client's exact symptom
    expect(d.dropped, ['UBER FOR MARK']);
  });

  group('device simulation, new order: every option shows what was typed', () {
    const sends = [
      'UBER FOR MARK',
      'UBER AND LYFT',
      'LYFT FOR MARK',
      'HELLO WORLD',
      'NOW OPEN 24 HOURS',
      'A',
    ];

    for (final v in LedFrameVariant.values) {
      test(v.label, () {
        final d = SignDevice();
        final log = StringBuffer('\n${v.label}\n');
        var clock = 0;
        for (final t in sends) {
          // Tap again the instant the app re-enables Send (worst case): the
          // app holds Send disabled for message + pause + speed + pause.
          newTap(d, v, t, clock);
          clock += 2 * LedProtocol.interFrameDelay.inMilliseconds;
          log.writeln('  typed "$t"  ->  sign shows "${d.displayed}"'
              '${d.displayed == t ? '' : '   <-- MISMATCH'}');
          expect(d.displayed, t, reason: '${v.label} after "$t"');
        }
        expect(d.dropped, isEmpty);
        expect(d.speed, 5);
        // ignore: avoid_print
        print(log);
      });
    }
  });

  test('Stop Message blanks the sign on every option, and a new message follows', () {
    for (final v in LedFrameVariant.values) {
      final d = SignDevice();
      newTap(d, v, 'UBER FOR MARK', 0);
      expect(d.displayed, 'UBER FOR MARK', reason: v.label);

      d.receive(
        LedProtocol.sendMessage(
          messageSlot: 'A',
          movingMode: LedMovingMode.left,
          text: LedProtocol.blankMessage,
          variant: v,
        ),
        1000,
      );
      expect(d.displayed.trim(), isEmpty, reason: '${v.label} after Stop');

      newTap(d, v, 'LYFT FOR MARK', 2000);
      expect(d.displayed, 'LYFT FOR MARK', reason: '${v.label} after Stop + new send');
    }
  });

  test('full app flow per option: multi-word send, change, stop, send again', () {
    const flow = <String>[
      'UBER FOR MARK',
      'UBER AND LYFT',
      '<STOP>',
      'LYFT FOR MARK',
      'GRAND OPENING SALE TODAY ONLY',
      '<STOP>',
      'HI',
    ];
    final out = StringBuffer();
    for (final v in LedFrameVariant.values) {
      final d = SignDevice();
      var clock = 0;
      out.writeln('\n${v.label}');
      for (final step in flow) {
        if (step == '<STOP>') {
          d.receive(
            LedProtocol.sendMessage(
              messageSlot: 'A',
              movingMode: LedMovingMode.left,
              text: LedProtocol.blankMessage,
              variant: v,
            ),
            clock,
          );
          clock += LedProtocol.interFrameDelay.inMilliseconds;
          out.writeln('  Stop Message          -> screen: "${d.displayed}" (blank)');
          expect(d.displayed.trim(), isEmpty, reason: v.label);
        } else {
          newTap(d, v, step, clock);
          clock += 2 * LedProtocol.interFrameDelay.inMilliseconds;
          final ok = d.displayed == step;
          out.writeln('  Send "$step" -> screen: "${d.displayed}" ${ok ? 'OK' : 'MISMATCH'}');
          expect(d.displayed, step, reason: '${v.label} "$step"');
        }
      }
      expect(d.dropped, isEmpty, reason: v.label);
    }
    // ignore: avoid_print
    print(out);
  });

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
