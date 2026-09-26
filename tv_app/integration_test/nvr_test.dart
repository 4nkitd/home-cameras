import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_cameras/main.dart' as app;
import 'package:home_cameras/model.dart';
import 'package:home_cameras/nvr_controller.dart';
import 'package:home_cameras/nvr_model.dart';
import 'package:home_cameras/recording_library.dart';
import 'package:home_cameras/store.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const channel = NvrController.channel;
  const camera = CameraConfig(
    id: 'nvr-fixture',
    name: 'Offline test camera',
    mainUrl: 'rtsp://10.0.2.2:8554/front',
    username: 'viewer',
    password: 'test-camera-only',
  );

  Future<void> waitFor(
    WidgetTester tester,
    Future<bool> Function() condition, {
    int seconds = 60,
  }) async {
    final until = DateTime.now().add(Duration(seconds: seconds));
    while (DateTime.now().isBefore(until)) {
      if (await condition()) return;
      await tester.pump(const Duration(milliseconds: 500));
    }
    fail(
      'Timed out waiting for NVR condition: ${await channel.invokeMethod<dynamic>('status')}',
    );
  }

  Future<void> start(CameraRule rule) => channel.invokeMethod<void>('start', {
    'settings': NvrSettings(enabled: true, rules: {camera.id: rule}).toJson(),
    'cameras': [camera.toJson()],
  });

  testWidgets(
    'Offline NVR: real RTSP, model inference, rollover, manual, event recording and playback',
    (tester) async {
      await channel.invokeMethod<void>('stop');
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove('nvr_settings');
      await SecureCameraRepository().save([camera]);
      await app.main();
      await tester.pump(const Duration(seconds: 2));
      final paths = await channel.invokeMapMethod<String, dynamic>('paths');
      final library = RecordingLibrary(Directory(paths!['root'] as String));
      for (final clip in await library.list()) {
        await library.delete(clip);
      }

      final http = HttpClient();
      try {
        for (final fixture in [
          ('cats_and_dogs.jpg', 'cat'),
          ('person.jpg', 'person'),
        ]) {
          final response = await (await http.getUrl(
            Uri.parse('http://10.0.2.2:8890/${fixture.$1}'),
          )).close();
          final bytes = <int>[];
          await for (final chunk in response) {
            bytes.addAll(chunk);
          }
          final results = await channel.invokeListMethod<dynamic>(
            'detect',
            Uint8List.fromList(bytes),
          );
          expect(
            results!.any((item) => (item as Map)['label'] == fixture.$2),
            isTrue,
            reason: 'Bundled model must detect ${fixture.$2}: $results',
          );
        }
      } finally {
        http.close(force: true);
      }

      await start(const CameraRule(mode: RecordingMode.continuous));
      await waitFor(tester, () async {
        final state = await channel.invokeMapMethod<String, dynamic>('status');
        return (state?['cameras'] as List? ?? []).any(
          (s) => (s as Map)['recording'] == true,
        );
      });
      await waitFor(
        tester,
        () async => (await library.list()).isNotEmpty,
        seconds: 90,
      );
      await channel.invokeMethod<void>('stop');
      final clips = await library.list();
      expect(clips, isNotEmpty);
      expect(clips.any((c) => c.seconds >= 55), isTrue);
      final player = Player();
      try {
        await player.open(Media(library.video(clips.last.file).path));
        await waitFor(tester, () async => player.state.position.inSeconds >= 2);
        expect(await player.screenshot(), isNotNull);
      } finally {
        await player.dispose();
      }

      final beforeManual = (await library.list()).length;
      await start(const CameraRule(mode: RecordingMode.manual));
      await waitFor(tester, () async {
        final state = await channel.invokeMapMethod<String, dynamic>('status');
        return (state?['cameras'] as List? ?? []).isNotEmpty;
      });
      await channel.invokeMethod<void>('manual', camera.id);
      await tester.pump(const Duration(seconds: 8));
      await channel.invokeMethod<void>('manual', camera.id);
      expect((await library.list()).length, greaterThan(beforeManual));
      await channel.invokeMethod<void>('stop');

      final beforeEvent = (await library.list()).length;
      await start(
        const CameraRule(mode: RecordingMode.detection, animals: true),
      );
      await waitFor(tester, () async {
        final state = await channel.invokeMapMethod<String, dynamic>('status');
        return (state?['cameras'] as List? ?? []).any(
          (s) =>
              (s as Map)['recording'] == true &&
              (s['detected'] as List).isNotEmpty,
        );
      });
      await tester.pump(const Duration(seconds: 8));
      await channel.invokeMethod<void>('stop');
      final events = await library.list();
      expect(events.length, greaterThan(beforeEvent));
      expect(
        events.any((c) => c.events.contains('cat') || c.events.contains('dog')),
        isTrue,
      );
      final stopped = await channel.invokeMapMethod<String, dynamic>('status');
      expect(stopped!['running'], isFalse);
      final size = await library.usedBytes();
      await tester.pump(const Duration(seconds: 5));
      expect(
        await library.usedBytes(),
        size,
        reason: 'Disabling must stop writing',
      );
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 6)),
  );
}
