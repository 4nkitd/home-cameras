import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_cameras/main.dart';
import 'package:home_cameras/model.dart';
import 'package:home_cameras/platform_bridge.dart';
import 'package:home_cameras/live_feed.dart';
import 'package:home_cameras/setup_sheet.dart';
import 'package:home_cameras/store.dart';
import 'package:home_cameras/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'store_test.dart' show MemoryRepository;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppStore store;
  late MemoryRepository repository;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = MemoryRepository();
    store = AppStore(repository, await SharedPreferences.getInstance());
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          TvPlatform.channel,
          (call) async => call.method == 'requestNetwork' ? true : null,
        );
  });
  tearDown(() {
    store.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(TvPlatform.channel, null);
  });

  testWidgets(
    'Approved compact home fits TV logical sizes with all camera tiles visible',
    (tester) async {
      repository.value = List.generate(
        4,
        (i) => CameraConfig(
          id: '$i',
          name: 'Camera ${i + 1}',
          mainUrl: 'rtsp://host/$i',
          room: 'Outdoors',
        ),
      );
      for (final size in [
        const Size(960, 540),
        const Size(1280, 720),
        const Size(1920, 1080),
      ]) {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(
          HomeCamerasApp(store: store, renderVideo: false),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(CameraTile), findsNWidgets(4));
        final first = tester.getRect(find.byType(CameraTile).first);
        final last = tester.getRect(find.byType(CameraTile).last);
        expect(first.top, lessThan(100));
        expect(last.bottom, lessThan(size.height));
      }
      await tester.pumpWidget(const SizedBox());
      await tester.binding.setSurfaceSize(null);
    },
  );

  testWidgets(
    'Empty home opens real setup, manual URL form and preserves back navigation',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(960, 540));
      await tester.pumpWidget(HomeCamerasApp(store: store, renderVideo: false));
      await tester.pumpAndSettle();
      expect(find.text('A home for your cameras.'), findsOneWidget);
      await tester.tap(find.text('Add your first camera'));
      await tester.pumpAndSettle();
      expect(find.text('Bring your cameras home.'), findsOneWidget);
      await tester.tap(find.text('Add with an RTSP address'));
      await tester.pumpAndSettle();
      expect(find.text('Main RTSP address'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('A home for your cameras.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.binding.setSurfaceSize(null);
    },
  );

  testWidgets('Remote Select opens a camera and Escape returns to grid', (
    tester,
  ) async {
    repository.value = [
      const CameraConfig(
        id: 'a',
        name: 'Entrance',
        mainUrl: 'rtsp://host/live',
      ),
    ];
    await tester.binding.setSurfaceSize(const Size(960, 540));
    await tester.pumpWidget(HomeCamerasApp(store: store, renderVideo: false));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.text('Audio off'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(CameraTile), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
    'Remote arrows traverse the grid and Enter activates the selected camera',
    (tester) async {
      repository.value = List.generate(
        4,
        (i) => CameraConfig(
          id: 'remote-$i',
          name: 'Remote camera $i',
          mainUrl: 'rtsp://host/$i',
        ),
      );
      await tester.binding.setSurfaceSize(const Size(960, 540));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(HomeCamerasApp(store: store, renderVideo: false));
      await tester.pumpAndSettle();

      bool focused(int index) => tester
          .widget<CameraTile>(find.byType(CameraTile).at(index))
          .focusNode
          .hasFocus;
      expect(focused(0), isTrue);
      for (final step in [
        (LogicalKeyboardKey.arrowRight, 1),
        (LogicalKeyboardKey.arrowDown, 3),
        (LogicalKeyboardKey.arrowLeft, 2),
        (LogicalKeyboardKey.arrowUp, 0),
        (LogicalKeyboardKey.arrowRight, 1),
      ]) {
        await tester.sendKeyEvent(step.$1);
        await tester.pumpAndSettle();
        expect(
          focused(step.$2),
          isTrue,
          reason: '${step.$1.keyLabel} must move to tile ${step.$2}',
        );
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Audio off'), findsOneWidget);
      expect(find.text('Remote camera 1'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(focused(1), isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Enter and numpad Enter can open first-camera setup without touch',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(960, 540));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(HomeCamerasApp(store: store, renderVideo: false));
      await tester.pumpAndSettle();
      for (final key in [
        LogicalKeyboardKey.enter,
        LogicalKeyboardKey.numpadEnter,
      ]) {
        await tester.sendKeyEvent(key);
        await tester.pumpAndSettle();
        expect(
          find.text('Bring your cameras home.'),
          findsOneWidget,
          reason: '${key.keyLabel} must activate the focused button',
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Remote Down moves username to password without stealing caret keys',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(960, 540));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(HomeCamerasApp(store: store, renderVideo: false));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add your first camera'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add with an RTSP address'));
      await tester.pumpAndSettle();
      final username = find.widgetWithText(
        TextFormField,
        'Username · optional',
      );
      final password = find.widgetWithText(
        TextFormField,
        'Password · optional',
      );
      EditableText editable(Finder field) => tester.widget<EditableText>(
        find.descendant(of: field, matching: find.byType(EditableText)),
      );
      await tester.ensureVisible(username);
      await tester.tap(username);
      await tester.enterText(username, 'viewer');
      await tester.pumpAndSettle();
      expect(editable(username).focusNode.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(editable(username).focusNode.hasFocus, isTrue);
      expect(editable(username).controller.selection.baseOffset, 5);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(editable(password).focusNode.hasFocus, isTrue);
      final fieldRect = tester.getRect(password);
      expect(fieldRect.top, greaterThanOrEqualTo(0));
      expect(fieldRect.bottom, lessThan(540));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(editable(username).focusNode.hasFocus, isTrue);
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      expect(editable(password).focusNode.hasFocus, isTrue);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(editable(password).focusNode.hasFocus, isFalse);
      expect(find.text('Making the connection.'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'White primary buttons have a clearly contrasting focused border',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: homeTheme(),
          home: Scaffold(
            body: TvButton(
              'Continue',
              primary: true,
              autofocus: true,
              onPressed: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final style = tester.widget<TextButton>(find.byType(TextButton)).style!;
      final states = {WidgetState.focused};
      final border = style.side!.resolve(states)!;
      final fill = style.backgroundColor!.resolve(states)!;
      expect(border.color, isNot(fill));
      final contrast =
          (fill.computeLuminance() + .05) /
          (border.color.computeLuminance() + .05);
      expect(contrast, greaterThanOrEqualTo(3));
      expect(border.width, greaterThanOrEqualTo(3));
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Late preview unlocks onboarding and a later interruption cannot hide Save',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(960, 540));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await store.load();
      late VoidCallback ready;
      late ValueChanged<FeedStatus> status;
      await tester.pumpWidget(
        MaterialApp(
          theme: homeTheme(),
          home: SetupSheet(
            store: store,
            previewBuilder: (camera, onReady, onStatus) {
              ready = onReady;
              status = onStatus;
              return const ColoredBox(
                color: Colors.black,
                child: Text('Injected preview'),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add with an RTSP address'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Main RTSP address'),
        'rtsp://192.168.1.21:554/main',
      );
      await tester.ensureVisible(find.text('Test connection'));
      await tester.tap(find.text('Test connection'));
      await tester.pumpAndSettle();
      status(FeedStatus.unavailable);
      await tester.pumpAndSettle();
      expect(find.text('Add to home'), findsNothing);
      ready();
      await tester.pumpAndSettle();
      expect(find.text('There you are.'), findsOneWidget);
      expect(find.text('Add to home'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Camera name'),
        'Delayed front door',
      );
      status(FeedStatus.unavailable);
      await tester.pumpAndSettle();
      expect(find.text('Add to home'), findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, 'Delayed front door'),
        findsOneWidget,
      );
      ready();
      await tester.pumpAndSettle();
      expect(find.textContaining('preview was interrupted'), findsNothing);
      await tester.ensureVisible(find.text('Add to home'));
      await tester.tap(find.text('Add to home'));
      await tester.pumpAndSettle();
      expect(find.text('Right where it belongs.'), findsOneWidget);
      expect(repository.value.single.name, 'Delayed front door');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
