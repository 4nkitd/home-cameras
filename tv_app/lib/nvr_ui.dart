import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'nvr_controller.dart';
import 'nvr_model.dart';
import 'recording_library.dart';
import 'theme.dart';

String recordingModeLabel(RecordingMode mode) => switch (mode) {
  RecordingMode.off => 'Off',
  RecordingMode.manual => 'Manual',
  RecordingMode.continuous => 'Continuous',
  RecordingMode.detection => 'On detection',
};

Future<void> nvrAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error is StateError ? error.message.toString() : 'Recorder operation failed. Check storage, network and NVR status.',
        ),
      ),
    );
  }
}

class NvrSettingsPanel extends StatelessWidget {
  const NvrSettingsPanel({
    super.key,
    required this.nvr,
    required this.onRecordings,
  });
  final NvrController nvr;
  final VoidCallback onRecordings;

  @override
  Widget build(BuildContext context) {
    final settings = nvr.settings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          'Local recorder',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'Turn this device into an offline NVR. Recording and detection are optional, and never upload footage.',
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          key: const ValueKey('nvr-enabled'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Enable NVR'),
          subtitle: const Text(
            'Runs in the background while Android allows it. Keep the device powered. Reopen after reboot or force-stop.',
          ),
          value: settings.enabled,
          onChanged: nvr.busy
              ? null
              : (v) => nvrAction(
                  context,
                  () => nvr.save(settings.copyWith(enabled: v)),
                ),
        ),
        if (nvr.error != null)
          Text(nvr.error!, style: const TextStyle(color: amber)),
        if (settings.enabled)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              nvr.status['running'] == true
                  ? nvr.status['message'] as String? ?? 'Starting NVR'
                  : 'NVR stopped. Turn it off and on to restart.',
              style: const TextStyle(color: sage),
            ),
          ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Rolling storage limit'),
          subtitle: const Text(
            'Oldest completed clips are deleted automatically. Keeps 512 MB free. Uninstalling removes private recordings.',
          ),
          trailing: DropdownButton<int>(
            value: settings.quotaGb,
            items: [1, 2, 4, 8, 16]
                .map((gb) => DropdownMenuItem(value: gb, child: Text('$gb GB')))
                .toList(),
            onChanged: nvr.busy
                ? null
                : (v) {
                    if (v != null) {
                      nvrAction(
                        context,
                        () => nvr.save(settings.copyWith(quotaGb: v)),
                      );
                    }
                  },
          ),
        ),
        const SizedBox(height: 10),
        TvButton(
          'Browse recordings',
          icon: Icons.video_library_outlined,
          onPressed: onRecordings,
        ),
        const SizedBox(height: 20),
        const Text(
          'Up to two NVR cameras at once. Main-stream video, no audio, in one-minute clips. Detection clips end about 15 seconds after the last match; no pre-event footage.',
        ),
        const SizedBox(height: 8),
        const Text(
          'Detection needs a stream at 1280×720 or below. It samples keyframes about every two seconds. Animal classes: bird, cat, dog, horse, sheep, cow, elephant, bear, zebra and giraffe. Small, fast or poorly lit subjects can be missed.',
        ),
        const SizedBox(height: 12),
        if (nvr.store.cameras.isEmpty)
          const Text('Add an IP camera to configure recording.'),
        for (final camera in nvr.store.cameras)
          Builder(
            builder: (context) {
              final rule = settings.rule(camera.id);
              final state = nvr.cameraStatus(camera.id);
              final labels = (state['detected'] as List? ?? []).join(', ');
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(),
                    const SizedBox(height: 10),
                    Text(
                      camera.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Recording mode'),
                      trailing: DropdownButton<RecordingMode>(
                        value: rule.mode,
                        items: RecordingMode.values
                            .map(
                              (m) => DropdownMenuItem(
                                value: m,
                                child: Text(recordingModeLabel(m)),
                              ),
                            )
                            .toList(),
                        onChanged: nvr.busy
                            ? null
                            : (mode) {
                                if (mode != null) {
                                  nvrAction(
                                    context,
                                    () => nvr.updateCamera(
                                      camera.id,
                                      rule.copyWith(mode: mode),
                                    ),
                                  );
                                }
                              },
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Detect people'),
                      value: rule.people,
                      onChanged: nvr.busy
                          ? null
                          : (v) => nvrAction(
                              context,
                              () => nvr.updateCamera(
                                camera.id,
                                rule.copyWith(people: v),
                              ),
                            ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Detect animals'),
                      value: rule.animals,
                      onChanged: nvr.busy
                          ? null
                          : (v) => nvrAction(
                              context,
                              () => nvr.updateCamera(
                                camera.id,
                                rule.copyWith(animals: v),
                              ),
                            ),
                    ),
                    if (rule.mode == RecordingMode.detection && !rule.detects)
                      const Text(
                        'Enable person or animal detection to trigger recordings.',
                        style: TextStyle(color: amber),
                      ),
                    if (settings.enabled && rule.active)
                      Text(
                        '${state['message'] ?? 'Starting'}${labels.isEmpty ? '' : ' · $labels'}',
                        style: const TextStyle(color: sage),
                      ),
                    if (state['detectionError'] != null)
                      Text(
                        state['detectionError'] as String,
                        style: const TextStyle(color: amber),
                      ),
                    if (rule.mode == RecordingMode.manual)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: TvButton(
                          state['manual'] == true
                              ? 'Stop recording'
                              : 'Record now',
                          icon: Icons.fiber_manual_record,
                          onPressed: settings.enabled && !nvr.busy
                              ? () => nvrAction(
                                  context,
                                  () => nvr.manual(camera.id),
                                )
                              : null,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

class RecordingsScreen extends StatelessWidget {
  const RecordingsScreen({super.key, required this.nvr});
  final NvrController nvr;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 16),
      Text('Recordings', style: Theme.of(context).textTheme.headlineLarge),
      const SizedBox(height: 8),
      Text(
        '${nvr.recordings.length} completed clips on this device. Export clips you want to keep before the rolling archive removes them.',
      ),
      const SizedBox(height: 16),
      Expanded(
        child: nvr.recordings.isEmpty
            ? const EmptyView(
                title: 'No recordings yet.',
                message: 'Enable NVR in Settings and choose a camera recording mode. Active clips appear here after they finish.',
                icon: Icons.video_library_outlined,
              )
            : ListView.separated(
                itemCount: nvr.recordings.length,
                separatorBuilder: (_, _) => const Divider(),
                itemBuilder: (context, index) {
                  final clip = nvr.recordings[index];
                  final date = clip.started.toLocal();
                  final timestamp =
                      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${TimeOfDay.fromDateTime(date).format(context)}';
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          clip.cameraName,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$timestamp · ${clip.seconds}s · ${(clip.bytes / 1048576).toStringAsFixed(1)} MB',
                        ),
                        if (clip.events.isNotEmpty)
                          Text(
                            clip.events.join(', '),
                            style: const TextStyle(color: sage),
                          ),
                        if (clip.interrupted)
                          const Text(
                            'Interrupted recording. Playback may be incomplete.',
                            style: TextStyle(color: amber),
                          ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            TvButton(
                              'Play',
                              icon: Icons.play_arrow,
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => RecordingPlayer(
                                    path: nvr.library!.video(clip.file).path,
                                    clip: clip,
                                  ),
                                ),
                              ),
                            ),
                            TvButton(
                              'Export',
                              icon: Icons.save_alt,
                              onPressed: () => nvrAction(context, () async {
                                final exported = await nvr.export(clip);
                                if (exported && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Recording exported.'),
                                    ),
                                  );
                                }
                              }),
                            ),
                            TvButton(
                              'Delete',
                              icon: Icons.delete_outline,
                              danger: true,
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Delete this recording?'),
                                    content: const Text(
                                      'This removes the clip from this device. Exported copies are not affected.',
                                    ),
                                    actions: [
                                      TvButton(
                                        'Cancel',
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                      ),
                                      TvButton(
                                        'Delete',
                                        danger: true,
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true && context.mounted) {
                                  await nvrAction(
                                    context,
                                    () => nvr.delete(clip),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    ],
  );
}

class RecordingPlayer extends StatefulWidget {
  const RecordingPlayer({super.key, required this.path, required this.clip});
  final String path;
  final Recording clip;
  @override
  State<RecordingPlayer> createState() => _RecordingPlayerState();
}

class _RecordingPlayerState extends State<RecordingPlayer> {
  late final Player _player;
  late final VideoController _video;
  @override
  void initState() {
    super.initState();
    _player = Player();
    _video = VideoController(_player);
    _player.open(Media(widget.path));
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.clip.cameraName)),
    body: Column(
      children: [
        Expanded(
          child: Video(controller: _video, controls: NoVideoControls),
        ),
        StreamBuilder(
          stream: _player.stream.position,
          builder: (context, snapshot) => Text(
            '${(snapshot.data ?? Duration.zero).inSeconds}s / ${_player.state.duration.inSeconds}s',
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TvButton(
                'Back 10s',
                onPressed: () => _player.seek(
                  Duration(
                    milliseconds:
                        (_player.state.position.inMilliseconds - 10000).clamp(
                          0,
                          _player.state.duration.inMilliseconds,
                        ),
                  ),
                ),
              ),
              TvButton(
                'Play / pause',
                autofocus: true,
                icon: Icons.play_arrow,
                onPressed: _player.playOrPause,
              ),
              TvButton(
                'Forward 10s',
                onPressed: () => _player.seek(
                  Duration(
                    milliseconds:
                        (_player.state.position.inMilliseconds + 10000).clamp(
                          0,
                          _player.state.duration.inMilliseconds,
                        ),
                  ),
                ),
              ),
              TvButton('Close', onPressed: () => Navigator.pop(context)),
            ],
          ),
        ),
      ],
    ),
  );
}
