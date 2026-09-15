import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'model.dart';

abstract interface class CameraRepository {
  Future<List<CameraConfig>> load();
  Future<void> save(List<CameraConfig> cameras);
}

class SecureCameraRepository implements CameraRepository {
  static const _storage = FlutterSecureStorage();
  static const _key = 'home_cameras_v1';

  @override
  Future<List<CameraConfig>> load() async =>
      decodeCameras(await _storage.read(key: _key));

  @override
  Future<void> save(List<CameraConfig> cameras) =>
      _storage.write(key: _key, value: encodeCameras(cameras));
}

class AppStore extends ChangeNotifier {
  AppStore(this.repository, this.preferences);

  final CameraRepository repository;
  final SharedPreferences preferences;
  List<CameraConfig> _cameras = [];
  List<CameraConfig> get cameras => List.unmodifiable(_cameras);
  bool ready = false;
  bool busy = false;
  String? loadError;
  int get columns => preferences.getInt('layout') == 6 ? 3 : 2;
  int get pageSize => columns * 2;
  bool get keepAwake => preferences.getBool('keep_awake') ?? true;
  ViewQuality get quality => ViewQuality.values.firstWhere(
    (q) => q.name == preferences.getString('quality'),
    orElse: () => ViewQuality.automatic,
  );

  Future<void> load() async {
    loadError = null;
    ready = false;
    notifyListeners();
    try {
      _cameras = await repository.load();
      ready = true;
    } catch (_) {
      loadError = 'Saved cameras could not be unlocked. Your stored data has not been changed. Try again, or check this TV’s screen lock and storage settings.';
    }
    notifyListeners();
  }

  Future<void> _write(List<CameraConfig> next) async {
    if (!ready || busy) {
      throw StateError('Wait for the current save to finish.');
    }
    busy = true;
    notifyListeners();
    try {
      await repository.save(next);
      _cameras = next;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> upsert(CameraConfig camera) {
    final next = [..._cameras];
    final index = next.indexWhere((c) => c.id == camera.id);
    if (index < 0) {
      if (next.length >= 48) {
        throw StateError('Remove a camera before adding another.');
      }
      next.add(camera);
    } else {
      next[index] = camera;
    }
    return _write(next);
  }

  Future<void> remove(String id) =>
      _write(_cameras.where((c) => c.id != id).toList());

  Future<void> move(String id, int direction) async {
    final next = [..._cameras];
    final index = next.indexWhere((c) => c.id == id);
    final target = index + direction;
    if (index < 0 || target < 0 || target >= next.length) return;
    final camera = next.removeAt(index);
    next.insert(target, camera);
    await _write(next);
  }

  Future<void> setLayout(int count) async {
    if (!await preferences.setInt('layout', count == 6 ? 6 : 4)) {
      throw StateError('Could not save preference.');
    }
    notifyListeners();
  }

  Future<void> setKeepAwake(bool value) async {
    if (!await preferences.setBool('keep_awake', value)) {
      throw StateError('Could not save preference.');
    }
    notifyListeners();
  }

  Future<void> setQuality(ViewQuality value) async {
    if (!await preferences.setString('quality', value.name)) {
      throw StateError('Could not save preference.');
    }
    notifyListeners();
  }
}
