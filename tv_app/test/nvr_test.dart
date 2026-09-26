import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_cameras/main.dart';
import 'package:home_cameras/model.dart';
import 'package:home_cameras/nvr_controller.dart';
import 'package:home_cameras/nvr_model.dart';
import 'package:home_cameras/nvr_ui.dart';
import 'package:home_cameras/platform_bridge.dart';
import 'package:home_cameras/recording_library.dart';
import 'package:home_cameras/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'store_test.dart' show MemoryRepository;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('NVR, recording and detectors default to off; settings roundtrip', () {
    const settings = NvrSettings();
    expect(settings.enabled, isFalse);
    expect(settings.quotaGb, 2);
    expect(settings.rule('camera').active, isFalse);
    final next = settings.copyWith(
      enabled: true,
      rules: {
        'camera': const CameraRule(
          mode: RecordingMode.detection,
          animals: true,
        ),
      },
    );
    final restored = NvrSettings.fromJson(
      jsonDecode(jsonEncode(next.toJson())) as Map<String, dynamic>,
    );
    expect(restored.rule('camera').mode, RecordingMode.detection);
    expect(restored.rule('camera').people, isFalse);
    expect(restored.rule('camera').animals, isTrue);
    expect(NvrSettings.fromJson({'quotaGb': -1}).quotaGb, 2);
  });

  test('Detection class toggles and confidence threshold are independent', () {
    final results = [
      {'label': 'person', 'score': .9},
      {'label': 'cat', 'score': .8},
      {'label': 'dog', 'score': .5},
      {'label': 'car', 'score': .99},
    ];
    expect(const CameraRule().matches(results), isEmpty);
    expect(const CameraRule(people: true).matches(results), ['person']);
    expect(const CameraRule(animals: true).matches(results), ['cat']);
    expect(const CameraRule(people: true, animals: true).matches(results), [
      'person',
      'cat',
    ]);
  });

  test('Native codec settings preserve nested camera rules', () {
    final platform = <String, dynamic>{
      'enabled': true,
      'rules': <Object?, Object?>{
        'a': <Object?, Object?>{'mode': 'continuous', 'people': true},
      },
    };
    final settings = NvrSettings.fromJson(platform);
    expect(settings.enabled, isTrue);
    expect(settings.rule('a').mode, RecordingMode.continuous);
    expect(settings.rule('a').people, isTrue);
  });

  group('Recording storage', () {
    late Directory root;
    late RecordingLibrary library;
    setUp(() async {
      root = await Directory.systemTemp.createTemp('home-cameras-test-');
      library = RecordingLibrary(root);
    });
    tearDown(() async {
      await root.delete(recursive: true);
    });

    Future<Recording> clip(int n, {bool pending = false}) async {
      final item = Recording(
        file: '${n}_test.mkv',
        cameraId: 'camera',
        cameraName: 'Camera',
        started: DateTime(2026, 9, 26, 0, n),
        seconds: 60,
        bytes: 2048,
      );
      await library.video(item.file).writeAsBytes(List.filled(2048, n));
      await library.save(item, pending: pending);
      return item;
    }

    test('Clips list newest first; active clips are excluded', () async {
      await clip(1);
      await clip(2);
      await clip(3, pending: true);
      expect((await library.list()).map((c) => c.file), [
        '2_test.mkv',
        '1_test.mkv',
      ]);
      expect(await library.usedBytes(), 6144);
    });
    test(
      'Quota removes oldest completed clip but preserves unrelated data',
      () async {
        await clip(1);
        await clip(2);
        await clip(3, pending: true);
        final unrelated = File('${root.path}/personal.txt');
        await unrelated.writeAsString('keep');
        expect(
          await library.enforce(
            quotaBytes: 5000,
            freeBytes: storageReserve * 2,
          ),
          isTrue,
        );
        expect(await library.video('1_test.mkv').exists(), isFalse);
        expect(await library.video('2_test.mkv').exists(), isTrue);
        expect(await library.video('3_test.mkv').exists(), isTrue);
        expect(await unrelated.readAsString(), 'keep');
      },
    );
    test('Reserve pauses when only active clips remain', () async {
      final active = await clip(1, pending: true);
      expect(await library.enforce(quotaBytes: 10000, freeBytes: 0), isFalse);
      await expectLater(library.delete(active), throwsStateError);
      expect(await library.video(active.file).exists(), isTrue);
    });
    test('Interrupted clip recovery preserves footage and marks it', () async {
      await clip(1, pending: true);
      await library.recover();
      expect((await library.list()).single.interrupted, isTrue);
      expect(
        await File('${root.path}/1_test.mkv.pending.json').exists(),
        isFalse,
      );
    });
    test(
      'Malformed or cross-file metadata and path traversal are rejected',
      () async {
        await File('${root.path}/bad.mkv.json').writeAsString('not json');
        await File('${root.path}/1_test.mkv.json').writeAsString(
          jsonEncode({
            'file': '../outside.mkv',
            'cameraId': 'a',
            'cameraName': 'a',
            'started': DateTime.now().toIso8601String(),
            'seconds': 0,
            'bytes': 1,
          }),
        );
        expect(await library.list(), isEmpty);
        expect(() => library.video('../outside.mkv'), throwsFormatException);
      },
    );
  });

  test(
    'Notification stop disables persisted NVR before later settings edits',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = AppStore(
        MemoryRepository(),
        await SharedPreferences.getInstance(),
      );
      final controller = NvrController(store)
        ..settings = const NvrSettings(enabled: true);
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(NvrController.channel, (call) async {
            calls.add(call.method);
            return call.method == 'status'
                ? {'running': false, 'stopped': true}
                : null;
          });
      await controller.refresh();
      expect(controller.settings.enabled, isFalse);
      await controller.save(controller.settings.copyWith(quotaGb: 4));
      expect(calls, isNot(contains('start')));
      controller.dispose();
      store.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(NvrController.channel, null);
    },
  );

  test(
    'Encrypted RTSP recording is rejected without altering viewing cameras',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repo = MemoryRepository()
        ..value = [
          const CameraConfig(
            id: 'a',
            name: 'Secure camera',
            mainUrl: 'rtsps://host/live',
          ),
        ];
      final store = AppStore(repo, await SharedPreferences.getInstance());
      await store.load();
      final controller = NvrController(store);
      await expectLater(
        controller.updateCamera(
          'a',
          const CameraRule(mode: RecordingMode.continuous),
        ),
        throwsStateError,
      );
      expect(store.cameras.single.mainUrl, 'rtsps://host/live');
      expect(controller.settings.enabled, isFalse);
      controller.settings = const NvrSettings(
        enabled: true,
        rules: {'a': CameraRule(mode: RecordingMode.continuous)},
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            NvrController.channel,
            (call) async => call.method == 'status' ? {'running': false} : null,
          );
      await controller.save(controller.settings.copyWith(enabled: false));
      expect(controller.settings.enabled, isFalse);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(NvrController.channel, null);
      controller.dispose();
      store.dispose();
    },
  );

  testWidgets(
    'Phone touch navigation, settings and camera grid fit at 360 pixels',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repo = MemoryRepository()
        ..value = [
          const CameraConfig(
            id: 'a',
            name: 'Front door',
            mainUrl: 'rtsp://host/live',
          ),
        ];
      final store = AppStore(repo, await SharedPreferences.getInstance());
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(TvPlatform.channel, (_) async => true);
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(HomeCamerasApp(store: store, renderVideo: false));
      await tester.pumpAndSettle();
      expect(find.byType(CameraTile), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Settings').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Enable NVR'));
      expect(
        tester
            .widget<SwitchListTile>(find.byKey(const ValueKey('nvr-enabled')))
            .value,
        isFalse,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Recordings').last);
      await tester.pumpAndSettle();
      expect(find.text('No recordings yet.'), findsOneWidget);
      await tester.tap(find.text('Cameras').last);
      await tester.pumpAndSettle();
      expect(find.text('Front door'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
      await tester.binding.setSurfaceSize(null);
    },
  );

  testWidgets('NVR settings support manual controls on narrow screens', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repo = MemoryRepository()
      ..value = [
        const CameraConfig(
          id: 'a',
          name: 'Garden',
          mainUrl: 'rtsp://host/live',
        ),
      ];
    final store = AppStore(repo, await SharedPreferences.getInstance());
    await store.load();
    final nvr = NvrController(store)
      ..settings = const NvrSettings(
        enabled: true,
        rules: {'a': CameraRule(mode: RecordingMode.manual)},
      );
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: NvrSettingsPanel(nvr: nvr, onRecordings: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Record now'));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    nvr.dispose();
    store.dispose();
    await tester.binding.setSurfaceSize(null);
  });
}
