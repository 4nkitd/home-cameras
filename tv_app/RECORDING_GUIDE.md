# Recording on TV and phone

## First run

1. Install the TV APK on Android TV, or the phone APK on an ordinary Android
   phone. Add your existing IP cameras through discovery or an RTSP address.
2. Open Settings and scroll to Local recorder.
3. Choose the rolling storage limit. The default is 2 GB. The app deletes the
   oldest completed clips when the limit is reached or storage falls below the
   512 MB reserve. Export footage you need to preserve.
4. Choose each camera's recording mode and detection switches, then enable NVR.
   At most two cameras may have NVR features configured at once.
5. Allow notifications when prompted. The foreground notification lets you stop
   the NVR without reopening the application. Always check the per-camera status
   in Settings, because an enabled NVR does not mean a camera is reachable.

## Modes

- Off: no recording. Detection may still run if either detector is enabled.
- Manual: use Record now and Stop recording in Settings.
- Continuous: record one-minute clips while the camera is reachable.
- On detection: start a clip after a selected person or animal class is detected.
  Continue for about 15 seconds after the last match, with one-minute rollover.

Turning off the master NVR switch stops and finalizes recording, releases camera
connections and turns off detection. Stored clips and camera choices stay intact.
Finalization can take several seconds.

## Storage and playback

Open Recordings to play, seek, export or delete completed clips. Active clips
appear after they finish. Video is stored in app-private internal storage, not in
the system photo gallery. The app does not encrypt video files separately from
Android's device storage encryption. Use a device lock where supported.

Export opens Android's document picker. You can choose USB, SD card or another
destination if the device exposes it there. Exported copies are outside the
rolling archive and are not deleted by the app. Direct recording to removable
storage is not supported in this version. Uninstalling the app removes its
private recordings.

An interrupted clip recovered after a crash is marked as interrupted and may
not play completely. Recording is best effort, not a guarantee against lost
footage.

## Camera and device requirements

- Android 7.0 or newer, with enough free internal storage.
- Recording supports H.264 and H.265 over ordinary RTSP using TCP. Viewing may
  support other formats, but those formats and RTSPS are not recording inputs.
- Video is copied without re-encoding. Audio is not recorded.
- Detection requires a stream at 1280×720 or below and prefers the camera's
  configured low-resolution substream. Higher-resolution detection is paused,
  without stopping main-stream recording. Use short
  keyframe intervals, ideally one or two seconds, for prompt detections.
- Segment starts reconnect and wait for a keyframe. There may be gaps between
  clips. There is no pre-event buffer in this version.
- Phones should remain plugged in. Manufacturer battery optimization can stop
  background work. TV standby can suspend networking or the entire application.
- After a reboot or force-stop, open the app again. There is no boot autostart.
  A normal app restart resumes configured continuous/detection modes. Manual
  recording does not survive a process being killed.

## Offline detection

The APK includes EfficientDet Lite0. No account, cloud API, internet connection
or runtime model download is needed. Your local camera network must remain
available. People and animals have separate switches.

Supported animals are bird, cat, dog, horse, sheep, cow, elephant, bear, zebra
and giraffe. The model is not a general wildlife identifier. Sampling, lighting,
occlusion, small subjects and unfamiliar camera angles can cause misses or false
matches. Detection is not a safety-critical alarm and does not send phone pushes
to another device.
