import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iphone_bluetooth/features/ble/widgets/message_card.dart';
import 'package:iphone_bluetooth/led_protocol.dart';

Widget card({
  bool previewMode = false,
  bool sending = false,
  bool stopping = false,
  bool messageOnScreen = false,
  VoidCallback? onSend,
  VoidCallback? onStop,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: MessageCard(
          controller: TextEditingController(text: 'UBER FOR MARK'),
          previewMode: previewMode,
          sending: sending,
          stopping: stopping,
          messageOnScreen: messageOnScreen,
          colorFont: LedColor.red,
          colorBackground: LedColor.black,
          onColorFontChanged: (_) {},
          onColorBackgroundChanged: (_) {},
          onInsertColorTag: () {},
          onClearMessage: () {},
          onSend: onSend ?? () {},
          onStop: onStop ?? () {},
          sendLog: null,
          onClearLog: () {},
        ),
      ),
    ),
  );
}

OutlinedButton stopBtn(WidgetTester t) => t.widget<OutlinedButton>(find
    .ancestor(
      of: find.byWidgetPredicate((w) => w is Text && (w.data == 'Stop Message' || w.data == 'Stopping…')),
      matching: find.byWidgetPredicate((w) => w is OutlinedButton),
    )
    .first);
FilledButton sendBtn(WidgetTester t) => t.widget<FilledButton>(find.byWidgetPredicate((w) => w is FilledButton));

void main() {
  testWidgets('nothing on screen: Stop disabled, Send enabled', (t) async {
    await t.pumpWidget(card(messageOnScreen: false));
    expect(stopBtn(t).onPressed, isNull);
    expect(sendBtn(t).onPressed, isNotNull);
  });

  testWidgets('message on screen: Stop enabled', (t) async {
    await t.pumpWidget(card(messageOnScreen: true));
    expect(stopBtn(t).onPressed, isNotNull);
  });

  testWidgets('preview mode: Stop disabled even if a message is flagged', (t) async {
    await t.pumpWidget(card(previewMode: true, messageOnScreen: true));
    expect(stopBtn(t).onPressed, isNull);
  });

  testWidgets('tapping Stop calls only onStop, never onSend', (t) async {
    var sends = 0, stops = 0;
    await t.pumpWidget(card(
      messageOnScreen: true,
      onSend: () => sends++,
      onStop: () => stops++,
    ));
    await t.tap(find.text('Stop Message'));
    await t.pump();
    expect((sends, stops), (0, 1));
  });

  testWidgets('while Stop is in flight Send does NOT show "Sending…"', (t) async {
    await t.pumpWidget(card(sending: true, stopping: true, messageOnScreen: true));
    expect(find.text('Sending…'), findsNothing);
    expect(find.text('Send Message'), findsOneWidget);
    expect(find.text('Stopping…'), findsOneWidget);
    expect(sendBtn(t).onPressed, isNull); // still blocked, just not "busy"
    expect(stopBtn(t).onPressed, isNull);
  });

  testWidgets('while Send is in flight Send shows "Sending…", Stop disabled', (t) async {
    await t.pumpWidget(card(sending: true, messageOnScreen: true));
    expect(find.text('Sending…'), findsOneWidget);
    expect(find.text('Stop Message'), findsOneWidget);
    expect(stopBtn(t).onPressed, isNull);
  });
}
