import 'dart:async';

enum FeedStatus { connecting, live, reconnecting, unavailable }

class FeedHealth {
  FeedHealth({
    required Future<void> firstFrame,
    required this.onStatus,
    required this.onReady,
  }) {
    _startupDeadline = Timer(const Duration(seconds: 30), () {
      if (!hasFrame) _change(FeedStatus.unavailable);
    });
    // A deadline changes the UI; it must not detach the late-frame listener.
    firstFrame.then((_) {
      if (_disposed || _ended) return;
      hasFrame = true;
      _live();
    }, onError: (Object _) => openingFailed());
  }

  final void Function(FeedStatus) onStatus;
  final void Function() onReady;
  FeedStatus status = FeedStatus.connecting;
  bool hasFrame = false;
  bool _disposed = false;
  bool _ended = false;
  Timer? _startupDeadline;
  Timer? _stallDeadline;

  void _change(FeedStatus next) {
    if (_disposed || status == next) return;
    status = next;
    onStatus(next);
  }

  void _live() {
    if (_disposed || _ended || !hasFrame) return;
    _startupDeadline?.cancel();
    _stallDeadline?.cancel();
    _stallDeadline = null;
    final recovered = status != FeedStatus.live;
    _change(FeedStatus.live);
    if (recovered) onReady();
  }

  void buffering(bool value) {
    if (_disposed || _ended || !hasFrame) return;
    if (value) {
      if (status != FeedStatus.unavailable) _change(FeedStatus.reconnecting);
      _stallDeadline ??= Timer(
        const Duration(seconds: 15),
        () => _change(FeedStatus.unavailable),
      );
    } else {
      _live();
    }
  }

  void openingFailed() {
    if (_disposed || _ended || hasFrame) return;
    _startupDeadline?.cancel();
    _change(FeedStatus.unavailable);
  }

  void ended() {
    if (_disposed) return;
    _ended = true;
    _startupDeadline?.cancel();
    _stallDeadline?.cancel();
    _change(FeedStatus.unavailable);
  }

  void dispose() {
    _disposed = true;
    _startupDeadline?.cancel();
    _stallDeadline?.cancel();
  }
}
