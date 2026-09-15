import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:home_cameras/model.dart';
import 'package:home_cameras/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MemoryRepository implements CameraRepository {
  List<CameraConfig> value = [];
  bool fail = false;
  Completer<void>? wait;
  @override
  Future<List<CameraConfig>> load() async {
    if (fail) throw StateError('Locked');
    return [...value];
  }

  @override
  Future<void> save(List<CameraConfig> cameras) async {
    if (wait != null) await wait!.future;
    if (fail) throw StateError('Full');
    value = [...cameras];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MemoryRepository repository;
  late AppStore store;
  const a = CameraConfig(id: 'a', name: 'Door', mainUrl: 'rtsp://host/main');
  const b = CameraConfig(id: 'b', name: 'Garden', mainUrl: 'rtsp://host/sub');
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = MemoryRepository();
    store = AppStore(repository, await SharedPreferences.getInstance());
    await store.load();
  });
  tearDown(() => store.dispose());

  test('Save, reorder, edit and remove are persisted', () async {
    await store.upsert(a);
    await store.upsert(b);
    await store.move('b', -1);
    expect(store.cameras.first.id, 'b');
    await store.upsert(a.copyWith(name: 'Entrance', favorite: true));
    expect(repository.value.last.name, 'Entrance');
    await store.remove('b');
    expect(store.cameras.single.favorite, isTrue);
  });

  test(
    'Failed secure write does not mutate cameras or leave store busy',
    () async {
      await store.upsert(a);
      repository.fail = true;
      await expectLater(store.upsert(b), throwsStateError);
      expect(store.cameras.map((c) => c.id), ['a']);
      expect(store.busy, isFalse);
    },
  );

  test(
    'Locked or corrupt saved data is not silently replaced with an empty list',
    () async {
      await store.upsert(a);
      repository.fail = true;
      await store.load();
      expect(store.ready, isFalse);
      expect(store.loadError, isNotNull);
      await expectLater(store.remove('a'), throwsStateError);
      expect(repository.value.single.id, 'a');
    },
  );

  test('Concurrent writes cannot overwrite each other', () async {
    repository.wait = Completer<void>();
    final first = store.upsert(a);
    await expectLater(store.upsert(b), throwsStateError);
    repository.wait!.complete();
    await first;
    expect(store.cameras.single.id, 'a');
  });

  test('Layout and viewing preferences survive store re-creation', () async {
    await store.setLayout(6);
    await store.setKeepAwake(false);
    await store.setQuality(ViewQuality.low);
    final second = AppStore(repository, await SharedPreferences.getInstance());
    expect(second.pageSize, 6);
    expect(second.keepAwake, isFalse);
    expect(second.quality, ViewQuality.low);
    second.dispose();
  });
}
