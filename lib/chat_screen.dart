import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_classic_bluetooth/flutter_classic_bluetooth.dart';

// Calling is disabled for now — see the commented-out "Calling" section
// below for the mic-capture/playback implementation, kept intact to
// re-enable later.
// import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
// import 'package:record/record.dart';

// const int _sampleRate = 16000;

// Every write is wrapped in a small frame so multiple message types can
// share the one RFCOMM connection:
//   [1 byte type][4 byte big-endian length][payload]
const int _frameText = 0x01;
// const int _frameAudio = 0x02;
// const int _frameCallStart = 0x03;
// const int _frameCallEnd = 0x04;

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final FlutterClassicBluetooth bluetooth = FlutterClassicBluetooth();

  final TextEditingController messageController =
  TextEditingController();

  BtcServerSocket? server;
  StreamSubscription<BtcConnection>? serverSub;

  BtcConnection? connection;
  StreamSubscription<Uint8List>? rawSub;
  StreamSubscription<BtcConnectionState>? connStateSub;

  StreamSubscription<BtcDevice>? discoverySub;

  bool isWaiting = false;
  bool isDiscovering = false;
  bool isConnecting = false;

  List<BtcDevice> pairedDevices = [];
  List<BtcDevice> discoveredDevices = [];

  final List<String> messages = [];

  // ── Calling (disabled) ──────────────────────────────────────────────
  //
  // final AudioRecorder recorder = AudioRecorder();
  // StreamSubscription<Uint8List>? micSub;
  //
  // bool inCall = false;
  // bool _pcmReady = false;
  //
  // // Jitter buffer of decoded Int16 samples waiting to be played.
  // final List<int> _playbackBuffer = [];
  //
  // // Leftover odd byte within an audio frame's payload (samples are 2 bytes
  // // each; defensive in case a mic chunk is ever an odd length).
  // List<int> _pendingAudioBytes = [];

  // Incoming byte accumulator used to reassemble frames split across reads.
  final List<int> _rxBuffer = [];

  @override
  void dispose() {
    serverSub?.cancel();
    server?.close();
    rawSub?.cancel();
    connStateSub?.cancel();
    discoverySub?.cancel();
    connection?.dispose();
    messageController.dispose();

    // micSub?.cancel();
    // recorder.dispose();
    // if (_pcmReady) {
    //   FlutterPcmSound.release();
    // }

    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _ensureBluetoothOn() async {
    if (!await bluetooth.isEnabled()) {
      await bluetooth.enableBluetooth();
    }
  }

  Future<void> startWaiting() async {
    if (isWaiting) return;

    setState(() {
      isWaiting = true;
    });

    try {
      await _ensureBluetoothOn();
      await bluetooth.setDiscoverable(120);

      final newServer = await bluetooth.startServer(
        serviceName: 'BLE LED Controller Chat',
      );

      server = newServer;

      serverSub = newServer.connections.listen((incoming) {
        _attachConnection(incoming);
      });
    } catch (e) {
      _showError('Failed to start waiting: $e');

      if (mounted) {
        setState(() {
          isWaiting = false;
        });
      }
    }
  }

  Future<void> stopWaiting() async {
    await serverSub?.cancel();
    await server?.close();

    serverSub = null;
    server = null;

    if (mounted) {
      setState(() {
        isWaiting = false;
      });
    }
  }

  Future<void> scanForDevices() async {
    if (isDiscovering) return;

    setState(() {
      isDiscovering = true;
      discoveredDevices = [];
    });

    try {
      await _ensureBluetoothOn();

      pairedDevices = await bluetooth.getPairedDevices();

      await discoverySub?.cancel();

      discoverySub = bluetooth.discoveryResults.listen((device) {
        if (!mounted) return;

        setState(() {
          final index = discoveredDevices.indexWhere(
                (d) => d.address == device.address,
          );

          if (index >= 0) {
            discoveredDevices[index] = device;
          } else {
            discoveredDevices.add(device);
          }
        });
      });

      await bluetooth.startDiscovery();

      await Future.delayed(const Duration(seconds: 12));

      await bluetooth.stopDiscovery();
    } catch (e) {
      _showError('Scan failed: $e');
    }

    await discoverySub?.cancel();
    discoverySub = null;

    if (mounted) {
      setState(() {
        isDiscovering = false;
      });
    }
  }

  Future<void> connectToDevice(BtcDevice device) async {
    if (isConnecting) return;

    setState(() {
      isConnecting = true;
    });

    try {
      await bluetooth.stopDiscovery();

      final newConnection = await bluetooth.connect(
        address: device.address,
        timeout: const Duration(seconds: 15),
      );

      _attachConnection(newConnection);
    } catch (e) {
      _showError('Connection failed: $e');
    }

    if (mounted) {
      setState(() {
        isConnecting = false;
      });
    }
  }

  void _attachConnection(BtcConnection newConnection) {
    connection = newConnection;
    _rxBuffer.clear();

    rawSub = newConnection.input.listen(_onRawData);

    connStateSub = newConnection.stateStream.listen((state) {
      if (state == BtcConnectionState.disconnected) {
        _resetConnection();
      }
    });

    if (mounted) {
      setState(() {});
    }
  }

  void _resetConnection() {
    rawSub?.cancel();
    connStateSub?.cancel();
    connection?.dispose();

    rawSub = null;
    connStateSub = null;
    connection = null;
    _rxBuffer.clear();

    // endCall(notifyRemote: false);

    if (mounted) {
      setState(() {});
    }
  }

  // ── Framing ──────────────────────────────────────────────────────────

  Future<void> _sendFrame(int type, Uint8List payload) async {
    final activeConnection = connection;
    if (activeConnection == null) return;

    final frame = Uint8List(5 + payload.length);
    frame[0] = type;
    frame[1] = (payload.length >> 24) & 0xFF;
    frame[2] = (payload.length >> 16) & 0xFF;
    frame[3] = (payload.length >> 8) & 0xFF;
    frame[4] = payload.length & 0xFF;
    frame.setRange(5, 5 + payload.length, payload);

    await activeConnection.output.add(frame);
  }

  void _onRawData(Uint8List chunk) {
    _rxBuffer.addAll(chunk);

    while (_rxBuffer.length >= 5) {
      final len = (_rxBuffer[1] << 24) |
          (_rxBuffer[2] << 16) |
          (_rxBuffer[3] << 8) |
          _rxBuffer[4];

      if (_rxBuffer.length < 5 + len) break;

      final type = _rxBuffer[0];
      final payload = Uint8List.fromList(_rxBuffer.sublist(5, 5 + len));

      _rxBuffer.removeRange(0, 5 + len);

      _onIncomingFrame(type, payload);
    }
  }

  void _onIncomingFrame(int type, Uint8List payload) {
    switch (type) {
      case _frameText:
        if (!mounted) return;
        setState(() {
          messages.add('Them: ${utf8.decode(payload)}');
        });
        break;
      // case _frameAudio:
      //   if (inCall) _onAudioReceived(payload);
      //   break;
      // case _frameCallStart:
      //   if (!inCall) {
      //     _showError('Incoming call');
      //     _beginCall();
      //   }
      //   break;
      // case _frameCallEnd:
      //   if (inCall) endCall(notifyRemote: false);
      //   break;
    }
  }

  Future<void> sendMessage() async {
    final activeConnection = connection;

    if (activeConnection == null) return;

    final text = messageController.text.trim();

    if (text.isEmpty) return;

    messageController.clear();

    setState(() {
      messages.add('Me: $text');
    });

    try {
      await _sendFrame(_frameText, Uint8List.fromList(utf8.encode(text)));
    } catch (e) {
      _showError('Send failed: $e');
    }
  }

  Future<void> disconnect() async {
    await connection?.finish();
    _resetConnection();
  }

  // ── Calling (disabled) ──────────────────────────────────────────────
  //
  // Future<void> startCall() async {
  //   if (connection == null || inCall) return;
  //
  //   await _beginCall();
  //   await _sendFrame(_frameCallStart, Uint8List(0));
  // }
  //
  // Future<void> _beginCall() async {
  //   if (inCall) return;
  //
  //   // Set before setup so the very first native feed callback (which can
  //   // fire immediately) doesn't get dropped by the `!inCall` guard.
  //   inCall = true;
  //
  //   await _setupPlayback();
  //   FlutterPcmSound.start();
  //
  //   await _startMic();
  //
  //   if (mounted) {
  //     setState(() {});
  //   }
  // }
  //
  // Future<void> _setupPlayback() async {
  //   if (_pcmReady) return;
  //
  //   await FlutterPcmSound.setup(
  //     sampleRate: _sampleRate,
  //     channelCount: 1,
  //   );
  //
  //   await FlutterPcmSound.setFeedThreshold(_sampleRate ~/ 10);
  //   FlutterPcmSound.setFeedCallback(_onFeed);
  //
  //   _pcmReady = true;
  // }
  //
  // void _onFeed(int remainingFrames) {
  //   if (!inCall) return;
  //
  //   const wantFrames = _sampleRate ~/ 10;
  //
  //   final take = _playbackBuffer.length < wantFrames
  //       ? _playbackBuffer.length
  //       : wantFrames;
  //
  //   final samples = List<int>.filled(wantFrames, 0);
  //
  //   for (var i = 0; i < take; i++) {
  //     samples[i] = _playbackBuffer[i];
  //   }
  //
  //   if (take > 0) {
  //     _playbackBuffer.removeRange(0, take);
  //   }
  //
  //   FlutterPcmSound.feed(PcmArrayInt16.fromList(samples));
  // }
  //
  // void _onAudioReceived(Uint8List chunk) {
  //   if (!inCall) return;
  //
  //   final combined = [..._pendingAudioBytes, ...chunk];
  //   final sampleCount = combined.length ~/ 2;
  //
  //   for (var i = 0; i < sampleCount; i++) {
  //     final lo = combined[i * 2];
  //     final hi = combined[i * 2 + 1];
  //     final value = (hi << 8) | lo;
  //
  //     _playbackBuffer.add(value >= 0x8000 ? value - 0x10000 : value);
  //   }
  //
  //   _pendingAudioBytes = combined.length.isOdd ? [combined.last] : [];
  //
  //   // Cap the jitter buffer so a slow network doesn't build up latency.
  //   final maxBufferedSamples = _sampleRate * 2;
  //
  //   if (_playbackBuffer.length > maxBufferedSamples) {
  //     _playbackBuffer.removeRange(
  //       0,
  //       _playbackBuffer.length - maxBufferedSamples,
  //     );
  //   }
  // }
  //
  // Future<void> _startMic() async {
  //   if (!await recorder.hasPermission()) {
  //     _showError('Microphone permission denied');
  //     await endCall();
  //     return;
  //   }
  //
  //   final stream = await recorder.startStream(
  //     const RecordConfig(
  //       encoder: AudioEncoder.pcm16bits,
  //       sampleRate: _sampleRate,
  //       numChannels: 1,
  //       autoGain: true,
  //       echoCancel: true,
  //       noiseSuppress: true,
  //     ),
  //   );
  //
  //   micSub = stream.listen((chunk) {
  //     _sendFrame(_frameAudio, chunk);
  //   });
  // }
  //
  // Future<void> endCall({bool notifyRemote = true}) async {
  //   if (!inCall) return;
  //
  //   await micSub?.cancel();
  //   micSub = null;
  //   await recorder.stop();
  //
  //   _playbackBuffer.clear();
  //   _pendingAudioBytes = [];
  //
  //   inCall = false;
  //
  //   if (notifyRemote) {
  //     try {
  //       await _sendFrame(_frameCallEnd, Uint8List(0));
  //     } catch (_) {
  //       // Connection may already be gone; nothing left to notify.
  //     }
  //   }
  //
  //   if (mounted) {
  //     setState(() {});
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    final connected = connection != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Phone Connection'),
        actions: [
          // if (connected && !inCall)
          //   IconButton(
          //     onPressed: startCall,
          //     icon: const Icon(Icons.call),
          //   ),
          // if (inCall)
          //   IconButton(
          //     onPressed: () => endCall(),
          //     icon: const Icon(Icons.call_end),
          //     color: Colors.red,
          //   ),
          if (connected)
            IconButton(
              onPressed: disconnect,
              icon: const Icon(Icons.link_off),
              tooltip: 'Disconnect',
            ),
        ],
      ),
      body: connected ? _buildChat() : _buildSetup(),
    );
  }

  Widget _buildSetup() {
    final knownAddresses = pairedDevices.map((d) => d.address).toSet();

    final nearbyOnly = discoveredDevices
        .where((d) => !knownAddresses.contains(d.address))
        .toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                        child: Icon(
                          Icons.podcasts,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Host',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isWaiting
                        ? 'Waiting for the other phone to connect...'
                        : 'Make this phone discoverable and wait for the other phone to connect to it.',
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed:
                      isWaiting ? stopWaiting : startWaiting,
                      icon: Icon(
                        isWaiting ? Icons.stop_circle_outlined : Icons.wifi_tethering,
                      ),
                      label: Text(
                        isWaiting
                            ? 'Stop Waiting'
                            : 'Wait for Connection',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Nearby Devices',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              isDiscovering
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
                  : IconButton(
                onPressed: scanForDevices,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: (pairedDevices.isEmpty && nearbyOnly.isEmpty)
                ? Center(
              child: Text(
                isDiscovering
                    ? 'Scanning...'
                    : 'No devices found. Tap refresh to scan, and make sure the other phone is also waiting/discoverable.',
                textAlign: TextAlign.center,
              ),
            )
                : ListView(
              children: [
                ...pairedDevices.map(_deviceTile),
                ...nearbyOnly.map(_deviceTile),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _deviceTile(BtcDevice device) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
          child: Icon(
            Icons.phone_android,
            color: Theme.of(context).colorScheme.onSecondaryContainer,
          ),
        ),
        title: Text(device.name ?? device.address),
        subtitle: Text(device.address),
        trailing: FilledButton(
          onPressed: isConnecting
              ? null
              : () => connectToDevice(device),
          child: const Text('Connect'),
        ),
      ),
    );
  }

  Widget _buildChat() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final message = messages[index];
              final mine = message.startsWith('Me: ');
              final text = message.substring(
                message.indexOf(': ') + 2,
              );
              final colors = Theme.of(context).colorScheme;

              return Align(
                alignment: mine
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    vertical: 4,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  constraints: const BoxConstraints(maxWidth: 280),
                  decoration: BoxDecoration(
                    color: mine
                        ? colors.primaryContainer
                        : colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(mine ? 16 : 4),
                      bottomRight: Radius.circular(mine ? 4 : 16),
                    ),
                  ),
                  child: Text(
                    text,
                    style: TextStyle(
                      color: mine
                          ? colors.onPrimaryContainer
                          : colors.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: messageController,
                    decoration: const InputDecoration(
                      hintText: 'Message',
                    ),
                    onSubmitted: (_) => sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: sendMessage,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
