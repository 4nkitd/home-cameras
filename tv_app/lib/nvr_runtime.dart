import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';

import 'model.dart';
import 'media_init.dart';
import 'nvr_model.dart';
import 'recording_library.dart';

const nvrChannel = MethodChannel('in.dagar.home_cameras/nvr');

class NvrRuntime {
  final Map<String, _CameraRecorder> _sessions = {};
  late RecordingLibrary library;
  NvrSettings settings = const NvrSettings();
  Future<void> _queue = Future.value();
  Timer? _timer;
  bool _stopped = false;
  bool _tickPending = false;
  String? _error;

  Future<void> run() async {
    WidgetsFlutterBinding.ensureInitialized();
    initializeMedia();
    final paths = await nvrChannel.invokeMapMethod<String, dynamic>('paths');
    library = RecordingLibrary(Directory(paths!['root'] as String));
    await library.recover();
    nvrChannel.setMethodCallHandler(
      (call) => _serialize(() async {
        switch (call.method) {
          case 'configure':
            final config = Map<String, dynamic>.from(call.arguments as Map);
            settings = NvrSettings.fromJson(
              Map<String, dynamic>.from(config['settings'] as Map),
            );
            _error = null;
            final cameras = (config['cameras'] as List)
                .map(
                  (c) => CameraConfig.fromJson(
                    Map<String, dynamic>.from(c as Map),
                  ),
                )
                .where((c) => settings.enabled && settings.rule(c.id).active)
                .take(2)
                .toList();
            for (final id in _sessions.keys.toList()) {
              final matching = cameras.where((c) => c.id == id);
              final old = _sessions[id]!;
              if (matching.isEmpty ||
                  matching.first.toJson().toString() !=
                      old.camera.toJson().toString() ||
                  settings.rule(id).toJson().toString() !=
                      old.rule.toJson().toString()) {
                await old.close();
                _sessions.remove(id);
              }
            }
            for (final camera in cameras) {
              if (_sessions.containsKey(camera.id)) continue;
              _sessions[camera.id] = _CameraRecorder(
                camera,
                settings.rule(camera.id),
                library,
              );
            }
            await _tick();
          case 'manual':
            final session = _sessions[call.arguments];
            if (session == null || session.rule.mode != RecordingMode.manual) {
              throw PlatformException(
                code: 'MODE',
                message: 'Select manual recording for this camera first.',
              );
            }
            session.manual = !session.manual;
            await _tick();
          case 'stop':
            _stopped = true;
            _timer?.cancel();
            await _closeSessions();
            // media_kit 1.2.6 defers mpv destruction for five seconds after dispose.
            await Future<void>.delayed(const Duration(milliseconds: 5200));
          default:
            throw MissingPluginException();
        }
      }),
    );
    await nvrChannel.invokeMethod<void>('ready');
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!_stopped && !_tickPending) {
        _tickPending = true;
        unawaited(
          _serialize(_tick)
              .catchError((Object _) {})
              .whenComplete(() => _tickPending = false),
        );
      }
    });
  }

  Future<void> _serialize(Future<void> Function() work) {
    final next = _queue.then((_) => work());
    _queue = next.catchError((Object _) {});
    return next;
  }

  Future<void> _closeSessions() async {
    for (final session in _sessions.values) {
      try {
        await session.close();
      } catch (_) {
        _error = 'A recording could not be finalized. It will be checked on restart.';
      }
    }
    _sessions.clear();
  }

  Future<void> _tick() async {
    if (_stopped) return;
    try {
      final paths = await nvrChannel.invokeMapMethod<String, dynamic>('paths');
      final room = await library.enforce(
        quotaBytes: settings.quotaGb * 1024 * 1024 * 1024,
        freeBytes: paths!['freeBytes'] as int,
      );
      _error = room
          ? null
          : 'Storage full. Recording paused until space is available.';
      for (final session in _sessions.values) {
        try {
          await session.tick(room);
        } catch (_) {
          session.message = 'Camera or recording unavailable. Retrying.';
          await session.close();
        }
      }
    } catch (_) {
      _error =
          'Recorder storage unavailable. Check free space and restart NVR.';
      for (final session in _sessions.values) {
        await session.close();
      }
    }
    await nvrChannel.invokeMethod<void>('publish', {
      'message':
          _error ??
          (_sessions.isEmpty
              ? 'Choose a camera below to begin.'
              : 'NVR enabled'),
      'cameras': _sessions.values.map((s) => s.status).toList(),
      'usedBytes': await library.usedBytes(),
    });
  }
}

class _CameraRecorder {
  _CameraRecorder(this.camera, this.rule, this.library);
  final CameraConfig camera;
  final CameraRule rule;
  final RecordingLibrary library;
  Player? _player;
  NativePlayer get _native => _player!.platform as NativePlayer;
  Recording? _clip;
  DateTime? _clipStarted;
  DateTime? _lastGrowth;
  DateTime? _eventUntil;
  DateTime? _lastFrame;
  DateTime? _opened;
  Duration _position = Duration.zero;
  int _lastSize = 0;
  final Set<String> _events = {};
  bool manual = false;
  String message = 'Ready';
  List<String> detected = [];
  String? detectionError;
  bool _detectionTooLarge = false;

  Map<String, dynamic> get status => {
    'id': camera.id,
    'recording': _clip != null && _lastSize > 1024,
    'manual': manual,
    'message': message,
    'detected': detected,
    'detectionError': detectionError,
  };

  Future<void> _open() async {
    final player = Player(
      configuration: const PlayerConfiguration(
        vo: 'null',
        logLevel: MPVLogLevel.error,
        bufferSize: 2 * 1024 * 1024,
      ),
    );
    _player = player;
    for (final entry in {
      'msg-level': 'all=no',
      'rtsp-transport': 'tcp',
      'network-timeout': '10',
      'demuxer-max-back-bytes': '0',
      'demuxer-readahead-secs': '0.2',
      'cache-pause': 'no',
      'audio': 'no',
      'hwdec': 'no',
      'vd-lavc-threads': '1',
      'vd-lavc-skipframe': 'nonkey',
    }.entries) {
      await _native.setProperty(entry.key, entry.value);
    }
    await player.open(Media(camera.playbackUri(grid: true)));
    _opened = DateTime.now();
    _lastFrame = null;
    _position = Duration.zero;
  }

  Future<void> tick(bool room) async {
    final now = DateTime.now();
    final needsStream =
        rule.detects || rule.mode == RecordingMode.continuous || manual;
    if (!needsStream) {
      await close();
      message = 'Ready for manual recording';
      return;
    }
    if (rule.detects && !_detectionTooLarge) await _detect(now);
    final shouldRecord =
        room &&
        (rule.mode == RecordingMode.continuous ||
            manual ||
            rule.mode == RecordingMode.detection &&
                _eventUntil != null &&
                now.isBefore(_eventUntil!));
    if (_clip != null &&
        (!shouldRecord || now.difference(_clipStarted!).inSeconds >= 60)) {
      await _finish();
    }
    if (shouldRecord && _clip == null) {
      final name =
          '${now.microsecondsSinceEpoch}_${Random.secure().nextInt(0x7fffffff).toRadixString(36)}.mkv';
      _clip = Recording(
        file: name,
        cameraId: camera.id,
        cameraName: camera.name,
        started: now,
        seconds: 0,
        bytes: 0,
      );
      _clipStarted = now;
      _lastGrowth = now;
      await library.save(_clip!, pending: true);
      await nvrChannel.invokeMethod<void>('recordStart', {
        'id': camera.id,
        'url': camera.playbackUri(grid: false),
        'path': library.video(name).path,
      });
    }
    if (_clip != null) {
      final nativeState = await nvrChannel.invokeMethod<int>('recordStatus', {
        'id': camera.id,
      });
      if (nativeState == -1) {
        await close();
        message = 'Recording unavailable. Check H.264/H.265 RTSP and storage. Retrying.';
        return;
      }
      final stat = await library.video(_clip!.file).stat();
      final size = stat.type == FileSystemEntityType.file ? stat.size : 0;
      if (size > _lastSize) _lastGrowth = now;
      if (now.difference(_lastGrowth!).inSeconds > 20) {
        await close();
        message = 'No recording data. Retrying camera.';
        return;
      }
      _lastSize = size;
      message = size > 1024 ? 'Recording' : 'Waiting for recording data';
    } else {
      message = !room
          ? 'Recording paused: storage full'
          : rule.detects
          ? 'Watching for detections'
          : 'Ready';
    }
  }

  Future<void> _releaseDetector() async {
    final player = _player;
    _player = null;
    detected = [];
    if (player != null) await player.dispose();
  }

  Future<void> _detect(DateTime now) async {
    try {
      if (_player == null) await _open();
      final player = _player!;
      if (player.state.position != _position) {
        _position = player.state.position;
        _lastFrame = now;
      }
      if (now.difference(_lastFrame ?? _opened!).inSeconds > 25 ||
          player.state.completed) {
        await _releaseDetector();
        detectionError =
            'Detection stream unavailable. Retrying. Recording is unaffected.';
        return;
      }
      final width = player.state.videoParams.w ?? 0;
      final height = player.state.videoParams.h ?? 0;
      if (width > 1280 || height > 720) {
        _detectionTooLarge = true;
        await _releaseDetector();
        detectionError = 'Detection needs a substream at 1280×720 or below. Edit this camera to add one.';
        return;
      }
      if (width == 0 || height == 0) {
        detectionError = 'Waiting for a detection frame';
        return;
      }
      final frame = await player.screenshot(format: 'image/jpeg');
      if (frame == null) {
        detectionError = 'Waiting for a decodable detection frame';
        return;
      }
      final results =
          await nvrChannel.invokeListMethod<dynamic>('detect', frame) ?? [];
      detected = rule.matches(results);
      detectionError = null;
      if (detected.isNotEmpty) {
        _eventUntil = now.add(const Duration(seconds: 15));
        _events.addAll(detected);
      }
    } catch (_) {
      await _releaseDetector();
      detectionError = 'Offline detector unavailable. Recording is unaffected.';
    }
  }

  Future<void> _finish() async {
    final clip = _clip;
    if (clip == null) return;
    await nvrChannel.invokeMethod<void>('recordStop', {'id': camera.id});
    final file = library.video(clip.file);
    if (await file.exists() && await file.length() > 1024) {
      await library.save(
        Recording(
          file: clip.file,
          cameraId: clip.cameraId,
          cameraName: clip.cameraName,
          started: clip.started,
          seconds: DateTime.now().difference(clip.started).inSeconds,
          bytes: await file.length(),
          events: _events.toList(),
        ),
      );
    } else {
      if (await file.exists()) await file.delete();
      final pending = File('${file.path}.pending.json');
      if (await pending.exists()) await pending.delete();
    }
    _clip = null;
    _clipStarted = null;
    _lastSize = 0;
    _events.clear();
  }

  Future<void> close() async {
    try {
      await _finish();
    } finally {
      final player = _player;
      _player = null;
      _clip = null;
      _clipStarted = null;
      _lastSize = 0;
      _events.clear();
      if (player != null) await player.dispose();
      _eventUntil = null;
      detected = [];
    }
  }
}
