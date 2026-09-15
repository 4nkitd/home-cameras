import 'package:flutter/services.dart';

class TvPlatform {
  static const channel = MethodChannel('in.dagar.home_cameras/tv');

  static Future<bool> requestNetwork() async =>
      await channel.invokeMethod<bool>('requestNetwork') ?? false;
  static Future<void> acquireDiscovery() =>
      channel.invokeMethod('acquireDiscovery');
  static Future<void> releaseDiscovery() =>
      channel.invokeMethod('releaseDiscovery');
  static Future<void> setAwake(bool enabled) =>
      channel.invokeMethod('setAwake', enabled);
  static Future<void> openNetworkSettings() =>
      channel.invokeMethod('openNetworkSettings');
}
