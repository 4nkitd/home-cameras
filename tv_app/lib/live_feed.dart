import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'feed_health.dart';
import 'model.dart';
import 'theme.dart';

export 'feed_health.dart' show FeedStatus;

class LiveFeed extends StatefulWidget {
  const LiveFeed({
    super.key,
    required this.camera,
    this.grid = true,
    this.quality = ViewQuality.automatic,
    this.audio = false,
    this.onStatus,
    this.onReady,
    this.retry = true,
  });
  final CameraConfig camera;
  final bool grid;
  final ViewQuality quality;
  final bool audio;
  final ValueChanged<FeedStatus>? onStatus;
  final VoidCallback? onReady;
  final bool retry;

  @override
  State<LiveFeed> createState() => LiveFeedState();
}

class LiveFeedState extends State<LiveFeed> with WidgetsBindingObserver {
  Player? _player;
  VideoController? _video;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Timer? _retryTimer;
  FeedHealth? _health;
  FeedStatus _status = FeedStatus.connecting;
  int _generation = 0;
  int _attempts = 0;
  bool _foreground = true;
  bool _disposing = false;
  Future<void> _released = Future.value();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_start());
  }

  void _setStatus(FeedStatus status) {
    if (status == FeedStatus.live) {
      _retryTimer?.cancel();
      _attempts = 0;
    }
    if (!mounted || _disposing || _status == status) return;
    setState(() => _status = status);
    widget.onStatus?.call(status);
  }

  Future<void> _release() async {
    _retryTimer?.cancel();
    _health?.dispose();
    _health = null;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    final previous = _player;
    _player = null;
    _video = null;
    if (previous != null) {
      try {
        await previous.dispose();
      } catch (_) {}
    }
  }

  Future<void> _start() async {
    final generation = ++_generation;
    await _released;
    _released = _release();
    await _released;
    if (!mounted || _disposing || !_foreground || generation != _generation) {
      return;
    }
    _setStatus(
      _attempts == 0 ? FeedStatus.connecting : FeedStatus.reconnecting,
    );
    final player = Player(
      configuration: const PlayerConfiguration(
        logLevel: MPVLogLevel.error,
        bufferSize: 8 * 1024 * 1024,
      ),
    );
    _player = player;
    try {
      final native = player.platform;
      if (native is NativePlayer) {
        await native.setProperty('msg-level', 'all=no');
        await native.setProperty('rtsp-transport', 'tcp');
        await native.setProperty('network-timeout', '12');
        await native.setProperty('demuxer-max-back-bytes', '0');
        await native.setProperty('demuxer-readahead-secs', '0.5');
        await native.setProperty('cache-pause', 'no');
      }
      if (generation != _generation || !mounted || _disposing) return;
      final controller = VideoController(
        player,
        configuration: const VideoControllerConfiguration(
          enableHardwareAcceleration: true,
        ),
      );
      setState(() => _video = controller);
      final health = FeedHealth(
        firstFrame: controller.waitUntilFirstFrameRendered,
        onStatus: (status) {
          if (generation != _generation || !mounted || _disposing) return;
          if (status == FeedStatus.unavailable) {
            _failed(generation);
          } else {
            _setStatus(status);
          }
        },
        onReady: () {
          if (generation == _generation && mounted && !_disposing) {
            widget.onReady?.call();
          }
        },
      );
      _health = health;
      // media_kit error events include recoverable audio/decoder log messages.
      // First frames, buffering and EOF determine whether the video is usable.
      _subscriptions.add(
        player.stream.completed.listen((done) {
          if (done && generation == _generation) health.ended();
        }),
      );
      _subscriptions.add(
        player.stream.buffering.listen((buffering) {
          if (generation == _generation) health.buffering(buffering);
        }),
      );
      await player.setAudioTrack(
        widget.grid || !widget.audio ? AudioTrack.no() : AudioTrack.auto(),
      );
      await player.open(
        Media(
          widget.camera.playbackUri(grid: widget.grid, quality: widget.quality),
        ),
      );
    } catch (_) {
      if (generation != _generation || !mounted || _disposing) return;
      if (_health != null) {
        _health!.openingFailed();
      } else {
        _failed(generation);
      }
    }
  }

  bool get _retryTimerIsActive => _retryTimer?.isActive ?? false;

  void _failed(int generation) {
    if (!mounted ||
        _disposing ||
        !_foreground ||
        generation != _generation ||
        _retryTimerIsActive) {
      return;
    }
    _setStatus(FeedStatus.unavailable);
    if (widget.retry) {
      final delay = min(30, 2 * pow(2, min(_attempts++, 4)).toInt());
      _retryTimer = Timer(Duration(seconds: delay), () => unawaited(_start()));
    }
  }

  void retryNow() {
    _attempts = 0;
    unawaited(_start());
  }

  @override
  void didUpdateWidget(LiveFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.camera.playbackUri(
          grid: oldWidget.grid,
          quality: oldWidget.quality,
        ) !=
        widget.camera.playbackUri(grid: widget.grid, quality: widget.quality)) {
      unawaited(_start());
    } else if (oldWidget.audio != widget.audio) {
      unawaited(
        _player
                ?.setAudioTrack(
                  widget.grid || !widget.audio
                      ? AudioTrack.no()
                      : AudioTrack.auto(),
                )
                .catchError((Object _) {}) ??
            Future.value(),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_foreground) {
        _foreground = true;
        unawaited(_start());
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _foreground = false;
      ++_generation;
      _released = _release();
      _setStatus(FeedStatus.connecting);
    }
  }

  @override
  void dispose() {
    _disposing = true;
    ++_generation;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_release());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xff101713),
    child: Stack(
      fit: StackFit.expand,
      children: [
        if (_video != null)
          Video(
            controller: _video!,
            controls: NoVideoControls,
            fit: BoxFit.contain,
            wakelock: false,
            pauseUponEnteringBackgroundMode: false,
          ),
        if (_status != FeedStatus.live && !(_health?.hasFrame ?? false))
          ColoredBox(
            color: background.withValues(alpha: .92),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _status == FeedStatus.unavailable
                        ? Icons.videocam_off_outlined
                        : Icons.wifi_tethering,
                    size: widget.grid ? 25 : 34,
                    color: _status == FeedStatus.unavailable ? amber : sage,
                  ),
                  const SizedBox(height: 10),
                  Text(switch (_status) {
                    FeedStatus.connecting => 'Connecting…',
                    FeedStatus.reconnecting => 'Reconnecting…',
                    FeedStatus.unavailable => 'Camera unavailable',
                    FeedStatus.live => 'Live',
                  }, style: const TextStyle(fontSize: 13, color: fog)),
                  if (!widget.grid && _status == FeedStatus.unavailable)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'No video received yet. A late preview will appear automatically.',
                        style: TextStyle(fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          ),
        if (_status != FeedStatus.live && (_health?.hasFrame ?? false))
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: background.withValues(alpha: .85),
              child: Text(
                _status == FeedStatus.unavailable
                    ? 'Connection interrupted · Last received image'
                    : 'Buffering · Last received image',
                style: const TextStyle(color: amber, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    ),
  );
}
