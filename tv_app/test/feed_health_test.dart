import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_cameras/feed_health.dart';

void main() {
  test('A first frame arriving after the deadline still clears unavailable and unlocks preview', () {
    fakeAsync((clock) {
      final frame = Completer<void>();
      final states = <FeedStatus>[];
      int ready = 0;
      final health = FeedHealth(
        firstFrame: frame.future,
        onStatus: states.add,
        onReady: () => ready++,
      );
      clock.elapse(const Duration(seconds: 31));
      expect(health.status, FeedStatus.unavailable);
      expect(ready, 0);
      frame.complete();
      clock.flushMicrotasks();
      expect(health.status, FeedStatus.live);
      expect(health.hasFrame, isTrue);
      expect(ready, 1);
      expect(states, [FeedStatus.unavailable, FeedStatus.live]);
      health.dispose();
    });
  });

  test('Opening failure does not detach a frame which arrives later', () {
    fakeAsync((clock) {
      final frame = Completer<void>();
      int ready = 0;
      final health = FeedHealth(
        firstFrame: frame.future,
        onStatus: (_) {},
        onReady: () => ready++,
      );
      health.openingFailed();
      expect(health.status, FeedStatus.unavailable);
      frame.complete();
      clock.flushMicrotasks();
      expect(health.status, FeedStatus.live);
      expect(ready, 1);
      health.openingFailed();
      expect(health.status, FeedStatus.live);
      health.dispose();
    });
  });

  test('Buffering recovery after a stall clears unavailable and reissues readiness', () {
    fakeAsync((clock) {
      int ready = 0;
      final health = FeedHealth(
        firstFrame: Future.value(),
        onStatus: (_) {},
        onReady: () => ready++,
      );
      clock.flushMicrotasks();
      health.buffering(true);
      clock.elapse(const Duration(seconds: 16));
      expect(health.status, FeedStatus.unavailable);
      health.buffering(false);
      expect(health.status, FeedStatus.live);
      expect(ready, 2);
      clock.elapse(const Duration(seconds: 60));
      expect(health.status, FeedStatus.live);
      health.dispose();
    });
  });

  test('Repeated buffering notices do not postpone the stall deadline', () {
    fakeAsync((clock) {
      final health = FeedHealth(
        firstFrame: Future.value(),
        onStatus: (_) {},
        onReady: () {},
      );
      clock.flushMicrotasks();
      health.buffering(true);
      clock.elapse(const Duration(seconds: 10));
      health.buffering(true);
      clock.elapse(const Duration(seconds: 6));
      expect(health.status, FeedStatus.unavailable);
      health.dispose();
    });
  });

  test('Neither playing nor buffering flags can validate a camera before a first frame', () {
    fakeAsync((clock) {
      final frame = Completer<void>();
      int ready = 0;
      final health = FeedHealth(
        firstFrame: frame.future,
        onStatus: (_) {},
        onReady: () => ready++,
      );
      health.buffering(true);
      health.buffering(false);
      clock.elapse(const Duration(seconds: 20));
      expect(health.status, FeedStatus.connecting);
      expect(ready, 0);
      health.dispose();
    });
  });

  test('EOF does not become live from stale buffering or a queued first-frame event', () {
    fakeAsync((clock) {
      final frame = Completer<void>();
      int ready = 0;
      final health = FeedHealth(
        firstFrame: frame.future,
        onStatus: (_) {},
        onReady: () => ready++,
      );
      health.ended();
      health.buffering(false);
      frame.complete();
      clock.flushMicrotasks();
      expect(health.status, FeedStatus.unavailable);
      expect(ready, 0);
      health.dispose();
    });
  });

  test(
    'Disposed attempts cannot deliver late readiness or timer callbacks',
    () {
      fakeAsync((clock) {
        final frame = Completer<void>();
        final states = <FeedStatus>[];
        int ready = 0;
        final health = FeedHealth(
          firstFrame: frame.future,
          onStatus: states.add,
          onReady: () => ready++,
        );
        health.dispose();
        frame.complete();
        clock.flushMicrotasks();
        clock.elapse(const Duration(minutes: 2));
        expect(ready, 0);
        expect(states, isEmpty);
      });
    },
  );
}
