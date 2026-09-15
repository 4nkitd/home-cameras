import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_cameras/discovery.dart';
import 'package:home_cameras/live_feed.dart';
import 'package:home_cameras/main.dart' as app;
import 'package:home_cameras/model.dart';
import 'package:home_cameras/store.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> waitFor(
    WidgetTester tester,
    Finder finder, {
    int seconds = 45,
  }) async {
    final until = DateTime.now().add(Duration(seconds: seconds));
    while (DateTime.now().isBefore(until)) {
      await tester.pump(const Duration(milliseconds: 300));
      if (finder.evaluate().isNotEmpty) return;
    }
    fail('Expected widget was not found: $finder');
  }

  Future<void> tap(WidgetTester tester, String text) async {
    final finder = find.text(text).first;
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> field(WidgetTester tester, String label, String value) async {
    final finder = find.widgetWithText(TextFormField, label);
    await tester.ensureVisible(finder);
    await tester.enterText(finder, value);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets(
    'Real Android TV app: secure storage, ONVIF fixture, authenticated RTSP and camera grid',
    (tester) async {
      final repository = SecureCameraRepository();
      await repository.save([]);
      await app.main();
      await waitFor(tester, find.text('A home for your cameras.'));
      await binding.convertFlutterSurfaceToImage();
      await tester.pump();
      await File('${Directory.systemTemp.path}/home-cameras-empty.png')
          .writeAsBytes(await binding.takeScreenshot('empty'));

      final discovery = CameraDiscovery();
      final profiles = await discovery.profiles(
        DiscoveredCamera(
          Uri.parse('http://10.0.2.2:8899/onvif/device_service'),
          'Fixture camera',
        ),
        'viewer',
        'test-camera-only',
      );
      expect(profiles.length, 2);
      expect(profiles.first.source, profiles.last.source);
      expect(profiles.first.width, 960);
      discovery.dispose();

      await tap(tester, 'Add your first camera');
      await tap(tester, 'Add with an RTSP address');
      await field(tester, 'Main RTSP address', 'rtsp://10.0.2.2:8554/front');
      await field(
        tester,
        'Grid substream · optional',
        'rtsp://10.0.2.2:8554/sub',
      );
      await field(tester, 'Username · optional', 'viewer');
      await field(tester, 'Password · optional', 'test-camera-only');
      await tap(tester, 'Test connection');
      await waitFor(tester, find.text('There you are.'), seconds: 60);
      await field(tester, 'Camera name', 'Front door');
      await field(tester, 'Room or area · optional', 'Entrance');
      await tap(tester, 'Add to home');
      await waitFor(tester, find.text('Right where it belongs.'));
      await tap(tester, 'View my cameras');
      await waitFor(tester, find.text('●  Live'));

      final saved = await repository.load();
      expect(saved.single.name, 'Front door');
      expect(saved.single.password, 'test-camera-only');
      final camera = saved.single;
      final four = [
        camera,
        for (int i = 1; i < 4; i++)
          CameraConfig(
            id: 'fixture-$i',
            name: ['Driveway', 'Garden', 'Living room'][i - 1],
            mainUrl: camera.mainUrl,
            gridUrl: camera.gridUrl,
            username: camera.username,
            password: camera.password,
            room: 'Fixture',
          ),
      ];
      final screen = tester.widget<app.HomeScreen>(find.byType(app.HomeScreen));
      for (final item in four.skip(1)) {
        await screen.store.upsert(item);
      }
      final until = DateTime.now().add(const Duration(seconds: 60));
      while (DateTime.now().isBefore(until) &&
          find.text('●  Live').evaluate().length != 4) {
        await tester.pump(const Duration(milliseconds: 400));
      }
      expect(find.text('●  Live'), findsNWidgets(4));
      await File('${Directory.systemTemp.path}/home-cameras-grid.png')
          .writeAsBytes(await binding.takeScreenshot('grid'));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await waitFor(tester, find.text('Audio off'));
      expect(find.byType(LiveFeed), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await waitFor(tester, find.byType(app.CameraTile));
      expect(find.byType(app.CameraTile), findsNWidgets(4));
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
