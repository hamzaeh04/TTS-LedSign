import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_classic_bluetooth/flutter_classic_bluetooth.dart';

import 'led_protocol.dart';

enum LedTransport { ble, classic }

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

  int brightness = 8;
  int speed = 5;
  List<String> messageListOrder = [];

  static const List<String> _messageSlots = [
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K',
  ];

  int get _address => int.tryParse(addressHex, radix: 16)?.clamp(0, 0xFF) ?? 0x00;

  // Lets the control panel be viewed without a real device connected —
  // tap "Preview screen (no device)" on the scan chooser.
  bool debugPreview = false;

  // Debug log of the last Send Message / Send Raw Text attempt — shown on
  // screen (instead of only a transient snackbar) so it can be screenshotted
  // and sent back for debugging without needing the physical hardware.
  String? sendLog;

  List<ScanResult> get _sortedByRssi {
    final sorted = [...scanResults];
    sorted.sort((a, b) => b.rssi.compareTo(a.rssi));
    return sorted;
  }

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
  Future<void> _sendAndLog(String action, List<int> bytes) async {
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
  }

  Future<void> sendMessage() async {
    final text = messageController.text.trim();

    if (text.isEmpty) return;

    await _sendAndLog(
      'Send Message',
      LedProtocol.sendMessage(
        messageSlot: messageSlot,
        movingMode: movingMode,
        text: text,
        address: _address,
      ),
    );
  }


  Future<void> sendBrightness() async {
    await _sendAndLog(
      'Send Brightness',
      LedProtocol.sendBrightness(brightness, address: _address),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LED Sign'),
        actions: [
          if (connected)
            IconButton(
              onPressed: disconnect,
              icon: const Icon(Icons.link_off),
              tooltip: 'Disconnect',
            ),
        ],
      ),
      body: (connected || debugPreview) ? _buildConnected() : _buildScanChooser(),
    );
  }

  Widget _buildScanChooser() {
    final colors = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.tv_outlined, color: colors.onPrimaryContainer),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Connect to your sign',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Choose BLE or Classic Bluetooth, then scan for the LED sign.',
                      style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => setState(() => debugPreview = true),
              icon: const Icon(Icons.visibility_outlined, size: 18),
              label: const Text('Preview screen (no device)'),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SegmentedButton<LedTransport>(
            segments: const [
              ButtonSegment(
                value: LedTransport.ble,
                label: Text('BLE'),
                icon: Icon(Icons.bluetooth),
              ),
              ButtonSegment(
                value: LedTransport.classic,
                label: Text('Classic'),
                icon: Icon(Icons.bluetooth_audio),
              ),
            ],
            selected: {transport},
            onSelectionChanged: (selection) {
              setState(() {
                transport = selection.first;
              });
            },
          ),
        ),
        Expanded(
          child: transport == LedTransport.ble
              ? _buildBleScan()
              : _buildClassicScan(),
        ),
      ],
    );
  }

  Widget _buildBleScan() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeader(
            title: 'Nearby BLE Devices',
            count: scanResults.length,
            loading: scanning,
            onRefresh: startBleScan,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: scanResults.isEmpty
                ? _EmptyState(
              icon: Icons.bluetooth_searching,
              message: scanning
                  ? 'Scanning...'
                  : 'No devices found. Tap refresh to scan for the LED sign.',
              onRefresh: scanning ? null : startBleScan,
            )
                : ListView.builder(
              itemCount: _sortedByRssi.length,
              itemBuilder: (context, index) {
                final result = _sortedByRssi[index];
                final name = result.device.platformName.isNotEmpty
                    ? result.device.platformName
                    : 'Unknown Device';

                return _DeviceTile(
                  name: name,
                  subtitle: result.device.remoteId.toString(),
                  rssi: result.rssi,
                  connecting: bleConnecting,
                  onConnect: () => connectBle(result.device),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassicScan() {
    final knownAddresses = pairedDevices.map((d) => d.address).toSet();

    final nearbyOnly = discoveredDevices
        .where((d) => !knownAddresses.contains(d.address))
        .toList();

    final total = pairedDevices.length + nearbyOnly.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeader(
            title: 'Classic Bluetooth Devices',
            count: total,
            loading: discovering,
            onRefresh: startClassicScan,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: total == 0
                ? _EmptyState(
              icon: Icons.bluetooth_searching,
              message: discovering
                  ? 'Scanning...'
                  : 'No devices found. Tap refresh to scan for the LED sign.',
              onRefresh: discovering ? null : startClassicScan,
            )
                : ListView(
              children: [
                ...pairedDevices.map(_classicDeviceTile),
                ...nearbyOnly.map(_classicDeviceTile),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _classicDeviceTile(BtcDevice found) {
    return _DeviceTile(
      name: found.name ?? found.address,
      subtitle: found.address,
      connecting: classicConnecting,
      onConnect: () => connectClassic(found),
    );
  }

  Widget _buildConnected() {
    if (transport == LedTransport.ble &&
        targetCharacteristic == null &&
        !debugPreview) {
      return _buildServiceList();
    }

    return _buildControlPanel();
  }

  Widget _buildServiceList() {
    final colors = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Select the characteristic the LED sign writes to '
              '(look for Write or Write-without-response).',
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        if (services.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
        ...services.map((service) {
          return Card(
            clipBehavior: Clip.antiAlias,
            child: ExpansionTile(
              title: Text(
                'Service ${service.uuid}',
                style: const TextStyle(fontSize: 13),
              ),
              children: service.characteristics.map((characteristic) {
                final props = characteristic.properties;
                final tags = [
                  if (props.write) 'Write',
                  if (props.writeWithoutResponse) 'Write-no-response',
                  if (props.notify) 'Notify',
                  if (props.read) 'Read',
                ];

                return ListTile(
                  title: Text(
                    characteristic.uuid.toString(),
                    style: const TextStyle(fontSize: 13),
                  ),
                  subtitle: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: tags.isEmpty
                        ? [const Text('No properties')]
                        : tags
                        .map((t) => Chip(
                      label: Text(t),
                      labelStyle: const TextStyle(fontSize: 11),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize:
                      MaterialTapTargetSize.shrinkWrap,
                    ))
                        .toList(),
                  ),
                  trailing: (props.write || props.writeWithoutResponse)
                      ? FilledButton(
                    onPressed: () {
                      setState(() {
                        targetCharacteristic = characteristic;
                      });
                    },
                    child: const Text('Select'),
                  )
                      : null,
                );
              }).toList(),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildControlPanel() {
    final colors = Theme.of(context).colorScheme;

    final previewMode = debugPreview && !connected;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _statusBanner(colors, previewMode),
        const SizedBox(height: 16),
        _LedPreview(controller: messageController),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CardTitle(icon: Icons.message_outlined, title: 'Message'),
                const SizedBox(height: 12),
                TextField(
                  controller: messageController,
                  enabled: !previewMode,
                  minLines: 1,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'Message',
                    hintText: 'Tap to type on the keyboard',
                    suffixIcon: IconButton(
                      onPressed: previewMode ? null : _clearMessage,
                      icon: const Icon(Icons.close),
                      tooltip: 'Clear',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Text color',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<LedColor>(
                        initialValue: colorFont,
                        decoration: const InputDecoration(labelText: 'Font'),
                        items: LedColor.values.map((c) {
                          return DropdownMenuItem(value: c, child: Text(c.name));
                        }).toList(),
                        onChanged: previewMode
                            ? null
                            : (value) {
                                if (value == null) return;
                                setState(() => colorFont = value);
                              },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<LedColor>(
                        initialValue: colorBackground,
                        decoration: const InputDecoration(labelText: 'Background'),
                        items: LedColor.values.map((c) {
                          return DropdownMenuItem(value: c, child: Text(c.name));
                        }).toList(),
                        onChanged: previewMode
                            ? null
                            : (value) {
                                if (value == null) return;
                                setState(() => colorBackground = value);
                              },
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton.filledTonal(
                      onPressed: previewMode ? null : _insertColorTag,
                      icon: const Icon(Icons.add),
                      tooltip: 'Insert color tag',
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: previewMode ? null : sendMessage,
                    icon: const Icon(Icons.send_rounded),
                    label: Text(
                      previewMode ? 'Connect a device to send' : 'Send Message',
                    ),
                  ),
                ),
                if (sendLog != null) ...[
                  const SizedBox(height: 14),
                  _SendLogPanel(
                    log: sendLog!,
                    onClear: () => setState(() => sendLog = null),
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CardTitle(icon: Icons.settings_outlined, title: 'Sign Settings'),
                const SizedBox(height: 14),
                TextFormField(
                  initialValue: addressHex,
                  enabled: !previewMode,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Screen address (hex, 00 = all screens)',
                  ),
                  onChanged: (value) => addressHex = value,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: messageSlot,
                        decoration: const InputDecoration(labelText: 'Slot'),
                        items: [
                          for (final letter in _messageSlots)
                            DropdownMenuItem(value: letter, child: Text(letter)),
                        ],
                        onChanged: previewMode
                            ? null
                            : (value) {
                                if (value == null) return;
                                setState(() => messageSlot = value);
                              },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<LedMovingMode>(
                        initialValue: movingMode,
                        decoration: const InputDecoration(labelText: 'Moving mode'),
                        items: LedMovingMode.values.map((mode) {
                          return DropdownMenuItem(value: mode, child: Text(mode.name));
                        }).toList(),
                        onChanged: previewMode
                            ? null
                            : (value) {
                                if (value == null) return;
                                setState(() => movingMode = value);
                              },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _LevelControl(
              icon: Icons.brightness_6_outlined,
              title: 'Brightness',
              value: brightness,
              onChanged: (v) => setState(() => brightness = v),
              onSend: previewMode ? null : sendBrightness,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _LevelControl(
              icon: Icons.speed_outlined,
              title: 'Speed',
              value: speed,
              onChanged: (v) => setState(() => speed = v),
              onSend: previewMode ? null : sendSpeed,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CardTitle(icon: Icons.playlist_play, title: 'Message Playlist'),
                const SizedBox(height: 4),
                Text(
                  'Tap slots in the order they should cycle. Tap a slot again '
                      'to remove it.',
                  style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final letter in _messageSlots)
                      FilterChip(
                        label: Text(letter),
                        selected: messageListOrder.contains(letter),
                        onSelected: previewMode ? null : (_) => _toggleListSlot(letter),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  messageListOrder.isEmpty
                      ? 'No slots selected'
                      : 'Order: ${messageListOrder.join(' → ')}',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: (previewMode || messageListOrder.isEmpty)
                        ? null
                        : sendMessageList,
                    icon: const Icon(Icons.send),
                    label: const Text('Send Playlist'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _statusBanner(ColorScheme colors, bool previewMode) {
    final label = previewMode
        ? 'Preview mode — no device connected'
        : (transport == LedTransport.ble
            ? 'Connected via BLE characteristic'
            : 'Connected via Classic Bluetooth');

    final icon = previewMode ? Icons.visibility_outlined : Icons.bluetooth_connected;
    final bg = previewMode ? colors.tertiaryContainer : colors.primaryContainer;
    final fg = previewMode ? colors.onTertiaryContainer : colors.onPrimaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: fg, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: fg, fontWeight: FontWeight.w600),
            ),
          ),
          if (previewMode)
            TextButton(
              onPressed: () => setState(() => debugPreview = false),
              child: const Text('Exit'),
            )
          else if (transport == LedTransport.ble)
            TextButton(
              onPressed: () {
                setState(() {
                  targetCharacteristic = null;
                });
              },
              child: const Text('Change'),
            ),
        ],
      ),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.count,
    required this.loading,
    required this.onRefresh,
  });

  final String title;
  final int count;
  final bool loading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                loading
                    ? 'Scanning…'
                    : (count == 0 ? 'No devices yet' : '$count found'),
                style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
        loading
            ? const Padding(
          padding: EdgeInsets.all(12),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        )
            : IconButton.filledTonal(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message, this.onRefresh});

  final IconData icon;
  final String message;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: colors.outline),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            if (onRefresh != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Scan now'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.name,
    required this.subtitle,
    required this.connecting,
    required this.onConnect,
    this.rssi,
  });

  final String name;
  final String subtitle;
  final bool connecting;
  final VoidCallback onConnect;
  final int? rssi;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: colors.secondaryContainer,
          child: Icon(Icons.bluetooth, color: colors.onSecondaryContainer),
        ),
        title: Text(name),
        subtitle: rssi == null
            ? Text(subtitle)
            : Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(subtitle, overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 8),
                    _SignalBars(rssi: rssi!),
                    const SizedBox(width: 4),
                    Text(
                      '$rssi dBm',
                      style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
        trailing: FilledButton(
          onPressed: connecting ? null : onConnect,
          child: const Text('Connect'),
        ),
      ),
    );
  }
}

class _SignalBars extends StatelessWidget {
  const _SignalBars({required this.rssi});

  final int rssi;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final strength = rssi >= -60 ? 3 : (rssi >= -80 ? 2 : 1);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final active = i < strength;
        return Container(
          margin: const EdgeInsets.only(right: 2),
          width: 4,
          height: 6.0 + i * 4,
          decoration: BoxDecoration(
            color: active ? colors.primary : colors.outlineVariant,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(icon, size: 20, color: colors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _SendLogPanel extends StatelessWidget {
  const _SendLogPanel({required this.log, required this.onClear});

  final String log;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.terminal, size: 16, color: colors.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Send log',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: log));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Log copied')),
                  );
                },
                icon: const Icon(Icons.copy, size: 16),
                tooltip: 'Copy log',
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.close, size: 16),
                tooltip: 'Clear log',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          Text(
            'Screenshot this for debugging',
            style: TextStyle(fontSize: 10, color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          SelectableText(
            log,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelControl extends StatelessWidget {
  const _LevelControl({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    required this.onSend,
  });

  final IconData icon;
  final String title;
  final int value;
  final ValueChanged<int> onChanged;
  final VoidCallback? onSend;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _CardTitle(icon: icon, title: title),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$value',
                style: TextStyle(
                  color: colors.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: value.toDouble(),
                min: 1,
                max: 8,
                divisions: 7,
                label: '$value',
                onChanged: onSend == null ? null : (v) => onChanged(v.round()),
              ),
            ),
            FilledButton.tonal(
              onPressed: onSend,
              child: const Text('Send'),
            ),
          ],
        ),
      ],
    );
  }
}

class _LedPreview extends StatelessWidget {
  const _LedPreview({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Icon(Icons.tv_outlined, size: 14, color: Theme.of(context).colorScheme.outline),
              const SizedBox(width: 6),
              Text(
                'LIVE PREVIEW',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF141414), Color(0xFF060606)],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.red.withValues(alpha: 0.25),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withValues(alpha: 0.08),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              final hasText = controller.text.isNotEmpty;
              final text = hasText ? controller.text.toUpperCase() : 'HELLO WORLD';

              return Text(
                text,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                  color: hasText
                      ? Colors.redAccent
                      : Colors.red.withValues(alpha: 0.25),
                  shadows: hasText
                      ? [
                    Shadow(
                      color: Colors.red.withValues(alpha: 0.9),
                      blurRadius: 14,
                    ),
                    Shadow(
                      color: Colors.redAccent.withValues(alpha: 0.6),
                      blurRadius: 28,
                    ),
                  ]
                      : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
