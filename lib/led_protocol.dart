import 'dart:typed_data';

/// Text scroll direction for a message, per the BLUE Communication
/// Protocol V4 "Moving mode" field.
enum LedMovingMode {
  left(0x31),
  right(0x32),
  static_(0x33),
  snow(0x34),
  up(0x35),
  down(0x36),
  flash(0x37);

  final int code;

  const LedMovingMode(this.code);
}

/// Font/background color pair, inserted mid-message as `<C{font}{bg}>`.
enum LedColor {
  red(0x52),
  yellow(0x59),
  green(0x47),
  cyan(0x43),
  blue(0x42),
  purple(0x50),
  white(0x57),
  black(0x44);

  final int unicode;

  const LedColor(this.unicode);
}

/// Builds BT015 protocol frames for the Bluetooth LED sign board, per
/// "BLUE Communication Protocol V4 (Word stock version)".
///
/// Frame layout: "BT015" + type + address + length(2, big-endian) + payload
/// + checksum(XOR of payload). Length and checksum cover only the payload
/// (message number / fixed bytes / message text etc.), never the header,
/// type, address, or themselves. Verified against the doc's own worked
/// examples (e.g. brightness packet 42 54 30 31 35 02 00 00 02 55 31 64,
/// where checksum 0x64 = 0x55 XOR 0x31).
///
/// Address 0x00 is the documented "general address" that any screen
/// answers to regardless of its own configured address (0x01-0xFF), so
/// it's used as the default here since the target screen's configured
/// address is unknown.
class LedProtocol {
  static const List<int> _header = [0x42, 0x54, 0x30, 0x31, 0x35]; // "BT015"

  static const int _typeMessage = 0x01;
  static const int _typeBrightness = 0x02;
  static const int _typeSpeed = 0x03;
  static const int _typeMessageList = 0x04;

  static Uint8List _buildFrame(int type, int address, List<int> payload) {
    final frame = <int>[
      ..._header,
      type,
      address,
      (payload.length >> 8) & 0xFF,
      payload.length & 0xFF,
      ...payload,
    ];

    var checksum = 0;
    for (final b in payload) {
      checksum ^= b;
    }
    frame.add(checksum);

    return Uint8List.fromList(frame);
  }

  /// [messageSlot] selects which of the sign's message slots (A-K) this
  /// text is stored/shown in.
  static Uint8List sendMessage({
    required String messageSlot,
    required LedMovingMode movingMode,
    required String text,
    int address = 0x00,
  }) {
    final payload = <int>[
      messageSlot.codeUnitAt(0),
      0x41, // Fixed "GB code" byte, per protocol doc.
      movingMode.code,
      0x00, // Reserved bit per doc's packet table; value unspecified there.
      ..._encodeUtf16Be(text),
    ];

    return _buildFrame(_typeMessage, address, payload);
  }

  /// Wraps [text] with a `<C{font}{bg}>` color-change escape, matching the
  /// protocol's in-message color codes.
  static String colorTag(LedColor font, LedColor background) {
    return '<C${String.fromCharCode(font.unicode)}${String.fromCharCode(background.unicode)}>';
  }

  /// [level] is 1-8.
  static Uint8List sendBrightness(int level, {int address = 0x00}) {
    assert(level >= 1 && level <= 8, 'Brightness level must be 1-8');
    return _buildFrame(_typeBrightness, address, [0x55, 0x30 + level]);
  }

  /// [level] is 1-8.
  static Uint8List sendSpeed(int level, {int address = 0x00}) {
    assert(level >= 1 && level <= 8, 'Speed level must be 1-8');
    return _buildFrame(_typeSpeed, address, [0xAA, 0x30 + level]);
  }

  /// [messageSlots] is an ordered list of slot letters (e.g. ['A','B','C'])
  /// the sign should cycle through.
  static Uint8List sendMessageList(
      List<String> messageSlots, {
        int address = 0x00,
      }) {
    final payload = <int>[
      0x30,
      ...messageSlots.map((s) => s.codeUnitAt(0)),
    ];

    return _buildFrame(_typeMessageList, address, payload);
  }

  static List<int> _encodeUtf16Be(String text) {
    final bytes = <int>[];

    for (final codeUnit in text.codeUnits) {
      bytes.add((codeUnit >> 8) & 0xFF);
      bytes.add(codeUnit & 0xFF);
    }

    return bytes;
  }
}
