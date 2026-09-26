import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'nvr_model.dart';
import 'recording_library.dart';
import 'store.dart';

class NvrController extends ChangeNotifier {
  NvrController(this.store);
  static const channel = MethodChannel('in.dagar.home_cameras/nvr');
  final AppStore store;
  NvrSettings settings = const NvrSettings();
  Map<String, dynamic> status = {};
  RecordingLibrary? library;
  List<Recording> recordings = [];
  bool busy = false;
  String? error;
  Timer? _timer;
  bool _disposed = false;
  bool _refreshing = false;

  Future<void> load() async {
    _timer?.cancel();
    try {
      final raw = store.preferences.getString('nvr_settings');
      if (raw != null) {
        settings = NvrSettings.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      }
      final paths = await channel.invokeMapMethod<String, dynamic>('paths');
      library = RecordingLibrary(Directory(paths!['root'] as String));
      await refresh();
      if (status['stopped'] == true) {
        settings = settings.copyWith(enabled: false);
        await store.preferences.setString(
          'nvr_settings',
          jsonEncode(settings.toJson()),
        );
      }
      if (settings.enabled) await _apply();
      _timer = Timer.periodic(
        const Duration(seconds: 3),
        (_) => unawaited(refresh()),
      );
    } on MissingPluginException {
      error = 'NVR requires Android.';
    } catch (_) {
      error = 'Could not load the recorder. Check storage and restart the app.';
    }
    _notify();
  }

  Future<void> _apply() async {
    if (!settings.enabled) {
      await channel.invokeMethod<void>('stop');
      return;
    }
    await channel.invokeMethod<void>('start', {
      'settings': settings.toJson(),
      'cameras': store.cameras.map((c) => c.toJson()).toList(),
    });
  }

  Future<void> save(NvrSettings next) async {
    if (busy) return;
    for (final camera in store.cameras) {
      if ((next.enabled ||
              next.rule(camera.id).mode != settings.rule(camera.id).mode) &&
          next.rule(camera.id).mode != RecordingMode.off &&
          Uri.parse(camera.mainUrl).scheme != 'rtsp') {
        throw StateError(
          '${camera.name}: recording supports ordinary RTSP, not RTSPS. Viewing remains available.',
        );
      }
    }
    if (store.cameras.where((c) => next.rule(c.id).active).length > 2) {
      throw StateError(
        'This build supports two NVR cameras at a time. Turn another camera off first.',
      );
    }
    busy = true;
    _notify();
    final previous = settings;
    try {
      if (!await store.preferences.setString(
        'nvr_settings',
        jsonEncode(next.toJson()),
      )) {
        throw StateError('Save failed');
      }
      settings = next;
      await _apply();
      error = null;
      await refresh();
    } catch (_) {
      settings = previous.copyWith(enabled: false);
      await store.preferences.setString(
        'nvr_settings',
        jsonEncode(settings.toJson()),
      );
      try {
        await channel.invokeMethod<void>('stop');
      } catch (_) {}
      rethrow;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> updateCamera(String id, CameraRule rule) =>
      save(settings.copyWith(rules: {...settings.rules, id: rule}));

  Future<void> syncCameras() async {
    if (settings.enabled) await _apply();
  }

  Future<void> manual(String id) async {
    await channel.invokeMethod<void>('manual', id);
    await refresh();
  }

  Future<void> refresh() async {
    if (_disposed || _refreshing) return;
    _refreshing = true;
    try {
      status = await channel.invokeMapMethod<String, dynamic>('status') ?? {};
      if (status['stopped'] == true && settings.enabled) {
        settings = settings.copyWith(enabled: false);
        await store.preferences.setString(
          'nvr_settings',
          jsonEncode(settings.toJson()),
        );
      }
      recordings = await library?.list() ?? [];
    } catch (_) {
      error = 'Recorder status unavailable.';
    } finally {
      _refreshing = false;
    }
    _notify();
  }

  Map<String, dynamic> cameraStatus(String id) =>
      (status['cameras'] as List? ?? [])
          .whereType<Map>()
          .map((s) => Map<String, dynamic>.from(s))
          .firstWhere((s) => s['id'] == id, orElse: () => {});

  Future<void> delete(Recording clip) async {
    await library!.delete(clip);
    await refresh();
  }

  Future<bool> export(Recording clip) async =>
      await channel.invokeMethod<bool>('export', clip.file) ?? false;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
