# Changes

## 0.1.2+3

- Add field-local Up/Down navigation and IME Next/Done actions. Username can move directly to password without consuming Left/Right caret editing.
- Give focused white primary buttons a contrasting blue, 3px border.
- Keep listening for the first video frame after the startup deadline. A late frame can clear the unavailable state and unlock onboarding instead of being abandoned by an awaited timeout.
- Stop treating every media_kit error-log event as a failed connection. Recoverable audio/decoder messages no longer hide usable video. First-frame, buffering, EOF and opening-failure signals drive state.
- Cancel pending reconnects when a frame arrives or buffering recovers. Buffering notices cannot indefinitely reset the stall deadline.
- Once the preview has validated a camera, retain the name fields and Save action through a later connection interruption. Recovery clears the warning.
- Show a compact stale-image warning during an interruption after video has been received, rather than obscuring the whole image. A stale image is not labelled live.
- Add first-frame deadline, recovery, EOF, stale-event/disposal and onboarding-save regression tests. All 27 unit/widget tests and static analysis pass. Camera/TV confirmation remains pending.
- No polling, per-frame Dart work, extra decoders or changes to the stream buffers are added.

## 0.1.1+2

- Restore Flutter's default keyboard and D-pad shortcut map. The previous custom map only included Select and controller A, accidentally removing arrow navigation, Enter, numpad Enter and Tab.
- Keep the standard Select/controller-A bindings, which already exist in Flutter's default map. No native key interception or video-path changes are introduced.
- Add regression tests for all four arrow directions, activation of the selected tile with Enter, focus restoration after fullscreen, and first-launch setup using Enter/numpad Enter without touch.
- Reproduced the arrow-navigation failure before the fix. All 17 unit/widget tests and static analysis pass after the fix. Physical TV confirmation remains pending.
- Increment Android version code to 2. The application ID, secure-storage schema and development signing identity remain unchanged so this APK can update 0.1.0 in place.

## 0.1.0+1

Initial device-test build. See RELEASE.md for the original build details and testing limitations.
