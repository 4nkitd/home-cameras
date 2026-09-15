import 'dart:convert';

enum ViewQuality { automatic, high, low }

class CameraConfig {
  const CameraConfig({
    required this.id,
    required this.name,
    required this.mainUrl,
    this.gridUrl = '',
    this.username = '',
    this.password = '',
    this.room = '',
    this.favorite = false,
  });

  final String id;
  final String name;
  final String room;
  final String mainUrl;
  final String gridUrl;
  final String username;
  final String password;
  final bool favorite;

  String source({
    required bool grid,
    ViewQuality quality = ViewQuality.automatic,
  }) => (grid || quality == ViewQuality.low) && gridUrl.isNotEmpty
      ? gridUrl
      : mainUrl;

  String playbackUri({
    required bool grid,
    ViewQuality quality = ViewQuality.automatic,
  }) {
    final uri = Uri.parse(source(grid: grid, quality: quality));
    if (username.isEmpty) return uri.replace(userInfo: '').toString();
    return uri
        .replace(
          userInfo:
              '${Uri.encodeComponent(username)}:${Uri.encodeComponent(password)}',
        )
        .toString();
  }

  CameraConfig copyWith({
    String? name,
    String? room,
    String? mainUrl,
    String? gridUrl,
    String? username,
    String? password,
    bool? favorite,
  }) => CameraConfig(
    id: id,
    name: name ?? this.name,
    room: room ?? this.room,
    mainUrl: mainUrl ?? this.mainUrl,
    gridUrl: gridUrl ?? this.gridUrl,
    username: username ?? this.username,
    password: password ?? this.password,
    favorite: favorite ?? this.favorite,
  );

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'room': room,
    'mainUrl': mainUrl,
    'gridUrl': gridUrl,
    'username': username,
    'password': password,
    'favorite': favorite,
  };

  factory CameraConfig.fromJson(Map<String, dynamic> json) {
    final camera = CameraConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      mainUrl: json['mainUrl'] as String,
      gridUrl: json['gridUrl'] as String? ?? '',
      room: json['room'] as String? ?? '',
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
      favorite: json['favorite'] as bool? ?? false,
    );
    if (camera.id.isEmpty ||
        camera.name.trim().isEmpty ||
        camera.name.length > 60 ||
        camera.room.length > 40 ||
        validateStreamUrl(camera.mainUrl) != null ||
        camera.gridUrl.isNotEmpty &&
            validateStreamUrl(camera.gridUrl) != null) {
      throw const FormatException('Invalid saved camera.');
    }
    return camera;
  }
}

String? validateStreamUrl(String value) {
  try {
    final uri = Uri.parse(value.trim());
    final authority = value
        .trim()
        .split('://')
        .last
        .split(RegExp(r'[/#?]'))
        .first;
    if (!['rtsp', 'rtsps'].contains(uri.scheme) ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.hasFragment ||
        RegExp(r'\s').hasMatch(value.trim()) ||
        uri.port > 65535 ||
        RegExp(r':0+$').hasMatch(authority) ||
        uri.hasPort && uri.port == 0) {
      return 'Enter an RTSP address, such as rtsp://192.168.1.21:554/stream1.';
    }
    if (uri.userInfo.isNotEmpty) {
      return 'Enter credentials in the username and password fields, not in the address.';
    }
    return null;
  } catch (_) {
    return 'The stream address is not valid.';
  }
}

List<CameraConfig> decodeCameras(String? value) {
  if (value == null) return [];
  final data = jsonDecode(value) as Map<String, dynamic>;
  if (data['version'] != 1) {
    throw const FormatException('Unsupported saved data version.');
  }
  final cameras = (data['cameras'] as List)
      .map((item) => CameraConfig.fromJson(item as Map<String, dynamic>))
      .toList();
  if (cameras.length > 48 ||
      cameras.map((c) => c.id).toSet().length != cameras.length) {
    throw const FormatException('Invalid saved camera list.');
  }
  return cameras;
}

String encodeCameras(List<CameraConfig> cameras) => jsonEncode({
  'version': 1,
  'cameras': cameras.map((c) => c.toJson()).toList(),
});
