import 'dart:convert';
import 'dart:io';

const storageReserve = 512 * 1024 * 1024;

class Recording {
  const Recording({
    required this.file,
    required this.cameraId,
    required this.cameraName,
    required this.started,
    required this.seconds,
    required this.bytes,
    this.events = const [],
    this.interrupted = false,
  });
  final String file;
  final String cameraId;
  final String cameraName;
  final DateTime started;
  final int seconds;
  final int bytes;
  final List<String> events;
  final bool interrupted;
  Map<String, dynamic> toJson() => {
    'file': file,
    'cameraId': cameraId,
    'cameraName': cameraName,
    'started': started.toUtc().toIso8601String(),
    'seconds': seconds,
    'bytes': bytes,
    'events': events,
    'interrupted': interrupted,
  };
  factory Recording.fromJson(Map<String, dynamic> json) {
    final file = json['file'] as String;
    if (!RegExp(r'^\d+_[a-z0-9]+\.mkv$').hasMatch(file)) {
      throw const FormatException('Invalid clip filename');
    }
    return Recording(
      file: file,
      cameraId: json['cameraId'] as String,
      cameraName: json['cameraName'] as String,
      started: DateTime.parse(json['started'] as String),
      seconds: (json['seconds'] as num).toInt(),
      bytes: (json['bytes'] as num).toInt(),
      events: (json['events'] as List? ?? []).cast<String>(),
      interrupted: json['interrupted'] == true,
    );
  }
}

class RecordingLibrary {
  RecordingLibrary(this.root);
  final Directory root;
  File video(String name) {
    if (!RegExp(r'^\d+_[a-z0-9]+\.mkv$').hasMatch(name)) {
      throw const FormatException('Invalid clip filename');
    }
    return File('${root.path}/$name');
  }

  Future<List<Recording>> list() async {
    if (!await root.exists()) return [];
    final recordings = <Recording>[];
    await for (final entry in root.list(followLinks: false)) {
      if (entry is! File || !entry.path.endsWith('.mkv.json')) continue;
      try {
        final recording = Recording.fromJson(
          jsonDecode(await entry.readAsString()) as Map<String, dynamic>,
        );
        if (entry.path != '${video(recording.file).path}.json') continue;
        final stat = await video(recording.file).stat();
        if (stat.type == FileSystemEntityType.file && stat.size > 0) {
          recordings.add(recording);
        }
      } on Object {
        continue;
      }
    }
    recordings.sort((a, b) => b.started.compareTo(a.started));
    return recordings;
  }

  Future<void> save(Recording clip, {bool pending = false}) async {
    await root.create(recursive: true);
    final destination =
        '${video(clip.file).path}.${pending ? 'pending.json' : 'json'}';
    final temp = File('$destination.tmp');
    await temp.writeAsString(jsonEncode(clip.toJson()), flush: true);
    await temp.rename(destination);
    if (!pending) {
      final prior = File('${video(clip.file).path}.pending.json');
      if (await prior.exists()) await prior.delete();
    }
  }

  Future<void> recover() async {
    await root.create(recursive: true);
    await for (final entry in root.list(followLinks: false)) {
      if (entry is! File || !entry.path.endsWith('.mkv.pending.json')) continue;
      try {
        final clip = Recording.fromJson(
          jsonDecode(await entry.readAsString()) as Map<String, dynamic>,
        );
        if (entry.path != '${video(clip.file).path}.pending.json') continue;
        final stat = await video(clip.file).stat();
        if (stat.type == FileSystemEntityType.file && stat.size > 1024) {
          await save(
            Recording(
              file: clip.file,
              cameraId: clip.cameraId,
              cameraName: clip.cameraName,
              started: clip.started,
              seconds: stat.modified
                  .difference(clip.started)
                  .inSeconds
                  .clamp(0, 86400),
              bytes: stat.size,
              events: clip.events,
              interrupted: true,
            ),
          );
        } else {
          if (stat.type == FileSystemEntityType.file) {
            await video(clip.file).delete();
          }
          await entry.delete();
        }
      } on Object {
        continue;
      }
    }
  }

  Future<void> delete(Recording clip) async {
    final file = video(clip.file);
    if (await File('${file.path}.pending.json').exists()) {
      throw StateError('Clip is active');
    }
    if (await file.exists()) await file.delete();
    final metadata = File('${file.path}.json');
    if (await metadata.exists()) await metadata.delete();
  }

  Future<int> usedBytes() async {
    var total = 0;
    if (!await root.exists()) return 0;
    await for (final entry in root.list(followLinks: false)) {
      if (entry is File &&
          RegExp(r'/\d+_[a-z0-9]+\.mkv$').hasMatch(entry.path)) {
        total += (await entry.stat()).size;
      }
    }
    return total;
  }

  Future<bool> enforce({
    required int quotaBytes,
    required int freeBytes,
  }) async {
    var used = await usedBytes();
    var free = freeBytes;
    for (final clip in (await list()).reversed) {
      if (used < quotaBytes && free > storageReserve) break;
      try {
        final size = await video(clip.file).length();
        await delete(clip);
        used -= size;
        free += size;
      } on FileSystemException {
        if (await video(clip.file).exists()) rethrow;
        used = await usedBytes();
      }
    }
    return used < quotaBytes && free > storageReserve;
  }
}
