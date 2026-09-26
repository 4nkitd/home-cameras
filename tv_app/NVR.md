# Offline NVR, version 0.2

## Scope

One Flutter application, TV and phone Android flavors. TV keeps its package and
signer for upgrades. Phone uses `in.dagar.home_cameras.mobile` and supports portrait
and touch. The existing dark Home Cameras palette and Roboto typography stay.
Settings gains NVR controls; a recordings screen lists clips by time and camera.
Phone navigation moves below the content and camera tiles scroll vertically.

NVR is disabled initially. Each camera starts with recording and detection off.
Modes are off, manual, continuous, and detection-triggered. Person and animal
detection are separate opt-ins. All inference uses a bundled model. There is no
cloud, account, analytics, or model download at runtime.

A foreground Android service owns a separate Flutter engine, so leaving the
viewer does not stop recording. The service starts only from the visible app.
Android force-stop, reboot, manufacturer suspension, and loss of power stop it.
Reopen the app to resume configured recording. A notification provides Stop.

Record the configured main RTSP stream into short Matroska segments without
re-encoding. Detection samples decoded frames, with at most two monitored cameras
to bound device load. Detection-triggered clips include a post-event tail, not
pre-event footage. Model-supported animals are listed in the UI; this is not
general animal recognition or a safety-critical alarm.

App-private internal storage defaults to 2 GB, with a 512 MB free-space reserve.
Cleanup removes only oldest completed app recordings. It never removes unrelated
files or active clips. Export uses Android's document picker. Uninstall removes
private recordings. Disabling NVR finalizes clips and releases streams and locks,
but preserves recordings and per-camera choices.

## Verification gate

- Analyze, unit/widget tests including narrow phone layouts and settings defaults.
- Android TV and phone install/launch, navigation, actual RTSP recording, playable
  clips, offline model inference, event clips, disable/stop, background behavior.
- Low space, reconnect, retention, and malformed metadata tests.
- Independent /review, signature and packaged-model checks.
- Publish both APKs and SHA-256 checksums with actual results and limitations.

Physical-TV performance, vendor battery policies, and real-camera compatibility
remain unverified without the target hardware.
