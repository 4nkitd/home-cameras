# Performance acceptance

Boss's explicit priority: performance comes before cosmetic effects.

## Implemented limits

- Only cameras on the current grid page create players. Four slots are the default; six is optional.
- Opening fullscreen unmounts the grid. Camera setup suspends grid/fullscreen players so its connection preview does not compete with them.
- The grid requests the configured substream. Fullscreen requests the main stream unless Low bandwidth is selected.
- Grid audio tracks are disabled, not merely mixed at zero volume.
- Native hardware acceleration is enabled. This is a request, not proof of a particular device's decoder selection. media_kit explicitly uses software rendering in Android emulators.
- Demuxer forward buffers are capped at 8 MiB per player; backward history is disabled for live viewing. The cap does not include decoded frames, textures or native decoder allocations.
- Forward read-ahead is limited to 0.5 seconds. Automatic cache pausing is disabled. Actual glass-to-glass latency still depends on camera encoding, keyframes, TCP jitter and TV decoding.
- Failed feeds retry with exponential backoff capped at 30 seconds. Only one retry timer runs per player.
- The startup UI deadline is 30 seconds, without detaching the first-frame listener. A late frame cancels pending retries. Buffer stalls have a 15-second deadline; recovery clears the warning. Recoverable native error-log messages do not cause repeated player destruction/recreation.
- Player resources are released when the app enters the background and recreated when it returns.
- There are no per-frame Flutter state updates, timer-driven thumbnail downloads, continuous blur effects, analytics or recording jobs. The clock updates once per minute.
- Setup uses blur only during a user-initiated modal, with background feeds suspended.

## Target-TV acceptance tests

These are targets and test procedures, not measured results yet.

1. Check the actual TV model, Android version, ABI, available memory and camera codecs. Start with H.264 substreams at 360p–720p and 10–15 fps.
2. Run one, two and four independent cameras. Test six only after four passes. Record the real codec and decoder selected, first-frame time and glass-to-glass latency using a filmed clock.
3. Profile release/profile mode, not debug mode. Aim for responsive remote navigation without visible dropped UI frames; target p95 UI frame time within the display's frame budget where practical.
4. Run a 60-minute grid session. Capture memory at 1, 10, 30 and 60 minutes. Fail acceptance for unbounded growth, decoder exhaustion, thermal slowdown or feed stalls that do not recover.
5. Switch grid/fullscreen 50 times and change pages repeatedly. Check that old players release and memory returns near a steady level.
6. Disconnect one camera, then Wi-Fi/Ethernet. Verify bounded retries and recovery without restarting the application.
7. Sleep/wake the TV repeatedly. Verify streams return and the app does not hold active network readers while backgrounded.

If the decoder limit is reached, reduce the camera substream resolution/frame rate or the visible layout. Do not silently claim six streams are supported because the UI has six slots. Do not treat a smaller Flutter tile as cheaper decoding of a high-resolution input.

## Evidence boundaries

Unit and widget tests verify source selection, layout, focus and resource-owning widget transitions. The emulator integration test uses a local synthetic RTSP source and an ONVIF HTTP fixture. It is a correctness check, not a benchmark of Boss's television or proof of compatibility with a physical camera.

No target-TV memory, latency, hardware-decoder or sustained performance numbers have been verified yet.
