import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_classic_bluetooth/flutter_classic_bluetooth.dart';

import '../../../constants/color_constants.dart';
import '../../../led_protocol.dart';
import '../models/led_transport.dart';
import '../widgets/ble_header.dart';
import '../widgets/ble_scan_list.dart';
// Classic Bluetooth is disabled for now — only BLE devices are supported.
// import '../widgets/classic_scan_list.dart';
import '../widgets/control_panel.dart';
import '../widgets/control_panel_header.dart';
import '../widgets/scan_chooser.dart';
import '../widgets/service_list.dart';

class BleScreen extends StatefulWidget {
  const BleScreen({super.key});

  @override
  State<BleScreen> createState() => _BleScreenState();
}

class _BleScreenState extends State<BleScreen> {
  final TextEditingController messageController = TextEditingController();

  LedTransport transport = LedTransport.ble;

  // ── BLE ──────────────────────────────────────────────────────────────

  StreamSubscription<List<ScanResult>>? scanSub;
  List<ScanResult> scanResults = [];
  bool scanning = false;

  BluetoothDevice? device;
  bool bleConnecting = false;
  StreamSubscription<BluetoothConnectionState>? connStateSub;

  List<BluetoothService> services = [];
  BluetoothCharacteristic? targetCharacteristic;

  // ── Classic Bluetooth ────────────────────────────────────────────────

  final FlutterClassicBluetooth classicBt = FlutterClassicBluetooth();

  StreamSubscription<BtcDevice>? discoverySub;
  List<BtcDevice> pairedDevices = [];
  List<BtcDevice> discoveredDevices = [];
  bool discovering = false;

  BtcConnection? classicConnection;
  StreamSubscription<BtcConnectionState>? classicStateSub;
  bool classicConnecting = false;

  // ── LED control state ───────────────────────────────────────────────

  LedMovingMode movingMode = LedMovingMode.left;
  String messageSlot = 'A';
  String addressHex = '00';
  LedColor colorFont = LedColor.red;
  LedColor colorBackground = LedColor.black;
  LedFrameVariant frameVariant = LedFrameVariant.b;

  int speed = 5;
  List<String> messageListOrder = [];

  int get _address => int.tryParse(addressHex, radix: 16)?.clamp(0, 0xFF) ?? 0x00;

  // Lets the control panel be viewed without a real device connected —
  // tap "Preview screen (no device)" on the scan chooser.
  bool debugPreview = false;

  // Debug log of the last Send Message / Send Raw Text attempt — shown on
  // screen (instead of only a transient snackbar) so it can be screenshotted
  // and sent back for debugging without needing the physical hardware.
  String? sendLog;

  // True while a write to the sign is in flight. Blocks overlapping sends
  // (see _sendAndLog) and lets the UI show a busy state instead of looking
  // like the tap did nothing.
  bool sending = false;

  bool get connected => transport == LedTransport.ble
      ? device != null
      : classicConnection != null;

  @override
  void dispose() {
    scanSub?.cancel();
    connStateSub?.cancel();
    discoverySub?.cancel();
    classicStateSub?.cancel();
    classicConnection?.dispose();
    messageController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // ── BLE actions ──────────────────────────────────────────────────────

  Future<void> startBleScan() async {
    if (scanning) return;

    setState(() {
      scanning = true;
      scanResults = [];
    });

    try {
      await FlutterBluePlus.stopScan();

      await scanSub?.cancel();

      scanSub = FlutterBluePlus.scanResults.listen((results) {
        if (!mounted) return;
        setState(() {
          scanResults = results;
        });
      });

      // startScan() returns almost immediately and only schedules an
      // internal auto-stop timer; it does NOT block for `timeout`. We have
      // to wait out the duration ourselves before stopping, or the scan
      // gets cut short after a few milliseconds every time.
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 8),
      );

      await Future.delayed(const Duration(seconds: 8));

      await FlutterBluePlus.stopScan();
    } catch (e) {
      _showError('Scan failed: $e');
    }

    await scanSub?.cancel();
    scanSub = null;

    if (mounted) {
      setState(() {
        scanning = false;
      });
    }
  }

  Future<void> connectBle(BluetoothDevice target) async {
    if (bleConnecting) return;

    setState(() {
      bleConnecting = true;
    });

    try {
      await FlutterBluePlus.stopScan();

      await target.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );

      device = target;

      connStateSub = target.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _resetBle();
        }
      });

      final discovered = await target.discoverServices();

      if (mounted) {
        setState(() {
          services = discovered;
        });
      }
    } catch (e) {
      _showError('Connection failed: $e');
    }

    if (mounted) {
      setState(() {
        bleConnecting = false;
      });
    }
  }

  void _resetBle() {
    connStateSub?.cancel();
    connStateSub = null;
    device = null;
    services = [];
    targetCharacteristic = null;

    if (mounted) {
      setState(() {});
    }
  }

  // ── Classic Bluetooth actions ───────────────────────────────────────

  Future<void> _ensureClassicOn() async {
    if (!await classicBt.isEnabled()) {
      await classicBt.enableBluetooth();
    }
  }

  Future<void> startClassicScan() async {
    if (discovering) return;

    setState(() {
      discovering = true;
      discoveredDevices = [];
    });

    try {
      await _ensureClassicOn();

      pairedDevices = await classicBt.getPairedDevices();

      await discoverySub?.cancel();

      discoverySub = classicBt.discoveryResults.listen((found) {
        if (!mounted) return;

        setState(() {
          final index = discoveredDevices.indexWhere(
                (d) => d.address == found.address,
          );

          if (index >= 0) {
            discoveredDevices[index] = found;
          } else {
            discoveredDevices.add(found);
          }
        });
      });

      await classicBt.startDiscovery();

      await Future.delayed(const Duration(seconds: 12));

      await classicBt.stopDiscovery();
    } catch (e) {
      _showError('Scan failed: $e');
    }

    await discoverySub?.cancel();
    discoverySub = null;

    if (mounted) {
      setState(() {
        discovering = false;
      });
    }
  }

  Future<void> connectClassic(BtcDevice target) async {
    if (classicConnecting) return;

    setState(() {
      classicConnecting = true;
    });

    try {
      await classicBt.stopDiscovery();

      final conn = await classicBt.connect(
        address: target.address,
        timeout: const Duration(seconds: 15),
      );

      classicConnection = conn;

      classicStateSub = conn.stateStream.listen((state) {
        if (state == BtcConnectionState.disconnected) {
          _resetClassic();
        }
      });

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      _showError('Connection failed: $e');
    }

    if (mounted) {
      setState(() {
        classicConnecting = false;
      });
    }
  }

  void _resetClassic() {
    classicStateSub?.cancel();
    classicStateSub = null;
    classicConnection?.dispose();
    classicConnection = null;

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> disconnect() async {
    if (transport == LedTransport.ble) {
      await device?.disconnect();
      _resetBle();
    } else {
      await classicConnection?.finish();
      _resetClassic();
    }
  }

  // ── LED protocol write ──────────────────────────────────────────────

  // Returns null on success, or a description of what went wrong — used to
  // build the on-screen debug log in _sendAndLog. The original snackbar
  // behavior on failure is unchanged.
  Future<String?> _writeToTarget(List<int> bytes) async {
    try {
      if (transport == LedTransport.ble) {
        final characteristic = targetCharacteristic;

        if (characteristic == null) {
          _showError('Select a characteristic first');
          return 'No characteristic selected';
        }

        await characteristic.write(
          bytes,
          withoutResponse: characteristic.properties.writeWithoutResponse &&
              !characteristic.properties.write,
        );
      } else {
        final conn = classicConnection;
        if (conn == null) return 'No classic connection';

        await conn.output.add(Uint8List.fromList(bytes));
      }

      return null;
    } catch (e) {
      _showError('Write failed: $e');
      return e.toString();
    }
  }

  // Builds an on-screen log of exactly what was sent and what happened, so
  // it can be screenshotted from the client's phone for debugging without
  // access to the physical LED sign.
  //
  // Guarded by `sending` so a second tap (e.g. an impatient user re-tapping
  // "Send" because the first tap hadn't visibly done anything yet) can't
  // start a second write while one is still in flight — two overlapping
  // writes to the same BLE characteristic can interleave/corrupt what the
  // sign actually receives, which showed up as the sign displaying a
  // truncated/shifted version of the message.
  Future<void> _sendAndLog(String action, List<int> bytes) async {
    if (sending) return;

    setState(() {
      sending = true;
    });

    try {
      final hex = bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join(' ');

      String asText;
      try {
        asText = utf8.decode(bytes, allowMalformed: true);
      } catch (e) {
        asText = '(could not decode as text: $e)';
      }

      final target = transport == LedTransport.ble
          ? 'BLE characteristic ${targetCharacteristic?.uuid ?? '(none)'}'
          : 'Classic Bluetooth ${classicConnection?.address ?? '(none)'}';

      final error = await _writeToTarget(bytes);

      final log = StringBuffer()
        ..writeln('$action — ${DateTime.now().toIso8601String()}')
        ..writeln('Target: $target')
        ..writeln('Result: ${error == null ? 'sent OK, no error thrown' : 'FAILED — $error'}')
        ..writeln('Bytes (${bytes.length}): $hex')
        ..write('As text: $asText');

      if (mounted) {
        setState(() {
          sendLog = log.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          sending = false;
        });
      } else {
        sending = false;
      }
    }
  }

  Future<void> sendMessage() async {
    final text = messageController.text.trim();

    if (text.isEmpty) return;

    await _sendAndLog(
      'Send Message (frame ${frameVariant.label})',
      LedProtocol.sendMessage(
        messageSlot: messageSlot,
        movingMode: movingMode,
        text: text,
        address: _address,
        variant: frameVariant,
      ),
    );
  }

  Future<void> sendSpeed() async {
    await _sendAndLog(
      'Send Speed',
      LedProtocol.sendSpeed(speed, address: _address),
    );
  }

  Future<void> sendMessageList() async {
    if (messageListOrder.isEmpty) return;

    await _sendAndLog(
      'Send Playlist',
      LedProtocol.sendMessageList(messageListOrder, address: _address),
    );
  }

  void _toggleListSlot(String slot) {
    setState(() {
      if (messageListOrder.contains(slot)) {
        messageListOrder.remove(slot);
      } else {
        messageListOrder.add(slot);
      }
    });
  }

  bool get _showingServiceList =>
      transport == LedTransport.ble &&
      targetCharacteristic == null &&
      !debugPreview &&
      connected;

  bool get _showingControlPanel => (connected || debugPreview) && !_showingServiceList;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: blePageBg,
      body: Column(
        children: [
          _showingControlPanel
              ? ControlPanelHeader(showDisconnect: connected, onDisconnect: disconnect)
              : BleHeader(
                  showDisconnect: connected,
                  onDisconnect: disconnect,
                  description: _showingServiceList
                      ? 'Select the characteristic the LED sign writes to '
                          '(look for Write or Write-without-response).'
                      : null,
                ),
          Expanded(
            child: SafeArea(
              top: false,
              child: (connected || debugPreview) ? _buildConnected() : _buildScanChooser(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanChooser() {
    return ScanChooser(
      transport: transport,
      onTransportChanged: (value) => setState(() => transport = value),
      onPreview: () => setState(() => debugPreview = true),
      // Classic Bluetooth is disabled for now — only BLE devices are supported.
      // child: transport == LedTransport.ble
      //     ? BleScanList(
      //         results: scanResults,
      //         scanning: scanning,
      //         connecting: bleConnecting,
      //         onRefresh: startBleScan,
      //         onConnect: connectBle,
      //       )
      //     : ClassicScanList(
      //         pairedDevices: pairedDevices,
      //         discoveredDevices: discoveredDevices,
      //         discovering: discovering,
      //         connecting: classicConnecting,
      //         onRefresh: startClassicScan,
      //         onConnect: connectClassic,
      //       ),
      child: BleScanList(
        results: scanResults,
        scanning: scanning,
        connecting: bleConnecting,
        onRefresh: startBleScan,
        onConnect: connectBle,
      ),
    );
  }

  Widget _buildConnected() {
    if (_showingServiceList) {
      return BleServiceList(
        services: services,
        onSelect: (characteristic) {
          setState(() {
            targetCharacteristic = characteristic;
          });
        },
      );
    }

    return _buildControlPanel();
  }

  Widget _buildControlPanel() {
    final previewMode = debugPreview && !connected;

    return ControlPanel(
      transport: transport,
      previewMode: previewMode,
      sending: sending,
      onExitPreview: () => setState(() => debugPreview = false),
      onChangeCharacteristic: () {
        setState(() {
          targetCharacteristic = null;
        });
      },
      messageController: messageController,
      colorFont: colorFont,
      colorBackground: colorBackground,
      onColorFontChanged: (value) => setState(() => colorFont = value),
      onColorBackgroundChanged: (value) => setState(() => colorBackground = value),
      onInsertColorTag: _insertColorTag,
      onClearMessage: _clearMessage,
      onSendMessage: sendMessage,
      sendLog: sendLog,
      onClearLog: () => setState(() => sendLog = null),
      addressHex: addressHex,
      onAddressChanged: (value) => addressHex = value,
      messageSlot: messageSlot,
      onMessageSlotChanged: (value) => setState(() => messageSlot = value),
      movingMode: movingMode,
      onMovingModeChanged: (value) => setState(() => movingMode = value),
      frameVariant: frameVariant,
      onFrameVariantChanged: (value) => setState(() => frameVariant = value),
      speed: speed,
      onSpeedChanged: (v) => setState(() => speed = v),
      onSendSpeed: (previewMode || sending) ? null : sendSpeed,
      messageListOrder: messageListOrder,
      onToggleListSlot: _toggleListSlot,
      onSendPlaylist: sendMessageList,
    );
  }

  void _insertColorTag() {
    setState(() {
      messageController.text += LedProtocol.colorTag(colorFont, colorBackground);
    });
  }

  void _clearMessage() {
    setState(() {
      messageController.clear();
    });
  }
}
