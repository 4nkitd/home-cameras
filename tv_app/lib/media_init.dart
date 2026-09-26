import 'package:media_kit/media_kit.dart';
// media_kit's debug hot-restart cleanup otherwise quits the other engine's players.
// ignore: implementation_imports
import 'package:media_kit/src/player/native/utils/native_reference_holder.dart';
// ignore: implementation_imports
import 'package:media_kit/src/player/native/utils/android_helper.dart';

void initializeMedia() {
  AndroidHelper.ensureInitialized();
  NativeReferenceHolder.ensureInitialized((_) {});
  MediaKit.ensureInitialized();
}
