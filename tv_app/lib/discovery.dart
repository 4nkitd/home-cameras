import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:easy_onvif/onvif.dart';
import 'package:loggy/loggy.dart';
import 'package:xml/xml.dart';

import 'model.dart';
import 'platform_bridge.dart';

class DiscoveredCamera {
  const DiscoveredCamera(this.endpoint, this.name);
  final Uri endpoint;
  final String name;
}

class CameraProfile {
  const CameraProfile({
    required this.token,
    required this.name,
    required this.url,
    this.source = '',
    this.width = 0,
    this.height = 0,
  });
  final String token;
  final String name;
  final String url;
  final String source;
  final int width;
  final int height;
  int get pixels => width * height;
  String get label => '$name${width > 0 ? ' · $width×$height' : ''}';
}

Iterable<XmlElement> localElements(XmlNode node, String name) =>
    node.descendants.whereType<XmlElement>().where((e) => e.name.local == name);

List<DiscoveredCamera> parseDiscoveryReply(List<int> bytes, String sender) {
  if (bytes.length > 65507) return [];
  try {
    final xml = XmlDocument.parse(utf8.decode(bytes));
    final devices = <DiscoveredCamera>[];
    for (final match in localElements(xml, 'ProbeMatch')) {
      final addresses =
          localElements(
            match,
            'XAddrs',
          ).firstOrNull?.innerText.split(RegExp(r'\s+')) ??
          [];
      for (final address in addresses) {
        final uri = Uri.tryParse(address);
        // Discovery is untrusted. Do not forward camera credentials to an advertised third-party host.
        if (uri == null ||
            !['http', 'https'].contains(uri.scheme) ||
            uri.host != sender ||
            uri.userInfo.isNotEmpty ||
            uri.hasFragment) {
          continue;
        }
        final scopes =
            localElements(
              match,
              'Scopes',
            ).firstOrNull?.innerText.split(RegExp(r'\s+')) ??
            [];
        final names = scopes.where(
          (s) => s.startsWith('onvif://www.onvif.org/name/'),
        );
        final name = names.isEmpty
            ? 'Camera at $sender'
            : Uri.decodeComponent(names.first.split('/name/').last);
        devices.add(
          DiscoveredCamera(
            uri,
            name.length > 60 ? name.substring(0, 60) : name,
          ),
        );
        break;
      }
    }
    return devices;
  } catch (_) {
    return [];
  }
}

class CameraDiscovery {
  final List<RawDatagramSocket> _sockets = [];
  Completer<void>? _cancel;
  Dio? _dio;
  bool _disposed = false;
  Future<void> _scanDone = Future.value();

  Future<List<DiscoveredCamera>> scan() async {
    cancel();
    final cancellation = Completer<void>();
    _cancel = cancellation;
    final previous = _scanDone;
    final finished = Completer<void>();
    _scanDone = finished.future;
    await previous;
    final found = <String, DiscoveredCamera>{};
    bool acquired = false;
    try {
      if (_disposed || cancellation.isCompleted) return [];
      await TvPlatform.acquireDiscovery();
      acquired = true;
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );
      for (final network in interfaces) {
        if (_disposed || cancellation.isCompleted) break;
        for (final address in network.addresses) {
          final socket = await RawDatagramSocket.bind(address, 0);
          if (_disposed || cancellation.isCompleted) {
            socket.close();
            break;
          }
          _sockets.add(socket);
          socket.multicastHops = 1;
          socket.setRawOption(
            RawSocketOption(
              RawSocketOption.levelIPv4,
              RawSocketOption.IPv4MulticastInterface,
              address.rawAddress,
            ),
          );
          socket.listen((event) {
            if (event != RawSocketEvent.read || cancellation.isCompleted) {
              return;
            }
            Datagram? packet;
            while ((packet = socket.receive()) != null) {
              for (final camera in parseDiscoveryReply(
                packet!.data,
                packet.address.address,
              )) {
                if (found.length < 100) {
                  found.putIfAbsent(camera.endpoint.toString(), () => camera);
                }
              }
            }
          }, onError: (Object _) {});
          final suffix = List.generate(
            16,
            (_) =>
                Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
          ).join();
          final messageId =
              '${suffix.substring(0, 8)}-${suffix.substring(8, 12)}-4${suffix.substring(13, 16)}-8${suffix.substring(17, 20)}-${suffix.substring(20)}';
          final message =
              '''<?xml version="1.0" encoding="UTF-8"?>
<s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope" xmlns:a="http://schemas.xmlsoap.org/ws/2004/08/addressing" xmlns:d="http://schemas.xmlsoap.org/ws/2005/04/discovery" xmlns:dn="http://www.onvif.org/ver10/network/wsdl">
<s:Header><a:MessageID>urn:uuid:$messageId</a:MessageID><a:To>urn:schemas-xmlsoap-org:ws:2005:04:discovery</a:To><a:Action>http://schemas.xmlsoap.org/ws/2005/04/discovery/Probe</a:Action></s:Header>
<s:Body><d:Probe><d:Types>dn:NetworkVideoTransmitter</d:Types></d:Probe></s:Body></s:Envelope>''';
          socket.send(
            utf8.encode(message),
            InternetAddress('239.255.255.250'),
            3702,
          );
        }
      }
      if (_sockets.isEmpty && !cancellation.isCompleted) {
        throw const SocketException('No local network interface.');
      }
      await Future.any([
        Future<void>.delayed(const Duration(seconds: 6)),
        cancellation.future,
      ]);
      return found.values.toList()..sort((a, b) => a.name.compareTo(b.name));
    } finally {
      for (final socket in _sockets) {
        socket.close();
      }
      _sockets.clear();
      try {
        if (acquired) await TvPlatform.releaseDiscovery();
      } finally {
        finished.complete();
      }
    }
  }

  Future<List<CameraProfile>> profiles(
    DiscoveredCamera camera,
    String username,
    String password,
  ) async {
    _dio?.close(force: true);
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 7),
        receiveTimeout: const Duration(seconds: 8),
        sendTimeout: const Duration(seconds: 7),
        followRedirects: false,
      ),
    );
    _dio = dio;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.uri.host != camera.endpoint.host) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.cancel,
              ),
            );
            return;
          }
          if (options.uri.path == '/onvif/device_service') {
            options.path = camera.endpoint.toString();
          }
          handler.next(options);
        },
      ),
    );
    try {
      final onvif = await Onvif.connect(
        host: camera.endpoint.origin,
        username: username,
        password: password,
        dio: dio,
        logOptions: const LogOptions(LogLevel.off),
      );
      final profiles = await onvif.media.getProfiles(type: ['All']);
      final result = <CameraProfile>[];
      for (final profile in profiles.take(64)) {
        if (_disposed) break;
        try {
          final uri = Uri.parse(await onvif.media.getStreamUri(profile.token));
          if (!['rtsp', 'rtsps'].contains(uri.scheme)) continue;
          if (uri.host != camera.endpoint.host && uri.host != '0.0.0.0') {
            continue;
          }
          final safeUri = uri
              .replace(host: camera.endpoint.host, userInfo: '')
              .toString();
          if (validateStreamUrl(safeUri) != null) continue;
          final encoder =
              profile.videoEncoderConfiguration ??
              profile.configurations?.videoEncoderConfiguration;
          final source =
              profile.videoSourceConfiguration ??
              profile.configurations?.videoSourceConfiguration;
          result.add(
            CameraProfile(
              token: profile.token,
              name: profile.name,
              url: safeUri,
              source: source?.sourceToken ?? '',
              width: encoder?.resolution?.width ?? 0,
              height: encoder?.resolution?.height ?? 0,
            ),
          );
        } catch (_) {
          if (_disposed) break;
        }
      }
      if (result.isEmpty) {
        throw const FormatException('No usable RTSP profiles.');
      }
      return result;
    } finally {
      dio.close(force: true);
      if (identical(_dio, dio)) _dio = null;
    }
  }

  void cancel() {
    if (_cancel != null && !_cancel!.isCompleted) _cancel!.complete();
    for (final socket in _sockets) {
      socket.close();
    }
    _sockets.clear();
    _dio?.close(force: true);
    _dio = null;
  }

  void dispose() {
    _disposed = true;
    cancel();
  }
}
