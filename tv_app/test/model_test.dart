import 'package:flutter_test/flutter_test.dart';
import 'package:home_cameras/model.dart';

void main() {
  test('Stream URLs reject unsupported schemes and embedded credentials', () {
    for (final invalid in [
      '',
      'https://camera.local/video',
      'rtsp://',
      'rtsp://host:0/live',
      'rtsp://host:99999/live',
      'rtsp://user:password@host/live',
      'rtsp://host/live#secret',
      'rtsp://host/a b',
    ]) {
      expect(validateStreamUrl(invalid), isNotNull, reason: invalid);
    }
    expect(validateStreamUrl('rtsp://192.168.1.21:554/stream1'), isNull);
    expect(validateStreamUrl('rtsps://camera.local/stream'), isNull);
    expect(validateStreamUrl('rtsp://[fd00::1234]:554/stream'), isNull);
  });

  test('Credentials are encoded once and substreams are selected by mode', () {
    const camera = CameraConfig(
      id: 'a',
      name: 'Door',
      mainUrl: 'rtsp://192.168.1.2/main',
      gridUrl: 'rtsp://192.168.1.2/sub',
      username: 'user@home',
      password: 'p:@/?#%',
    );
    final playback = Uri.parse(camera.playbackUri(grid: true));
    expect(playback.path, '/sub');
    expect(Uri.decodeComponent(playback.userInfo), 'user@home:p:@/?#%');
    expect(Uri.parse(camera.playbackUri(grid: false)).path, '/main');
    expect(
      Uri.parse(camera.playbackUri(grid: false, quality: ViewQuality.low)).path,
      '/sub',
    );
    expect(camera.toString(), isNot(contains('p:@/?#%')));
    expect(camera.copyWith(name: 'New name').password, camera.password);
  });

  test('Missing substream falls back to main', () {
    const camera = CameraConfig(
      id: 'a',
      name: 'Door',
      mainUrl: 'rtsp://camera.local/main',
    );
    expect(camera.source(grid: true), camera.mainUrl);
    expect(camera.playbackUri(grid: false), camera.mainUrl);
  });

  test('Encrypted payload codec preserves data and rejects corruption and duplicates', () {
    const camera = CameraConfig(
      id: 'a',
      name: 'Door',
      mainUrl: 'rtsp://host/main',
      username: 'viewer',
      password: 'secret',
    );
    expect(decodeCameras(encodeCameras([camera])).single.password, 'secret');
    expect(decodeCameras(null), isEmpty);
    expect(() => decodeCameras(''), throwsFormatException);
    expect(
      () => decodeCameras('{"version":2,"cameras":[]}'),
      throwsFormatException,
    );
    expect(
      () => decodeCameras(encodeCameras([camera, camera])),
      throwsFormatException,
    );
  });
}
