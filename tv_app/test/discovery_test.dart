import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:home_cameras/discovery.dart';

String reply(
  String endpoint, {
  String scopes = 'onvif://www.onvif.org/name/Front%20door',
}) => '''
<s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope" xmlns:d="http://schemas.xmlsoap.org/ws/2005/04/discovery"><s:Body><d:ProbeMatches><d:ProbeMatch><d:XAddrs>$endpoint</d:XAddrs><d:Scopes>$scopes</d:Scopes></d:ProbeMatch></d:ProbeMatches></s:Body></s:Envelope>''';

void main() {
  test('WS-Discovery reads names and custom device-service paths', () {
    final result = parseDiscoveryReply(
      utf8.encode(reply('http://192.168.1.21:8000/custom/device')),
      '192.168.1.21',
    );
    expect(result.single.name, 'Front door');
    expect(result.single.endpoint.path, '/custom/device');
    expect(result.single.endpoint.port, 8000);
  });

  test('Untrusted discovery cannot redirect credentials to another host', () {
    for (final endpoint in [
      'https://attacker.example/service',
      'http://192.168.1.22/onvif/device',
      'file:///etc/passwd',
      'http://user:pass@192.168.1.21/service',
    ]) {
      expect(
        parseDiscoveryReply(utf8.encode(reply(endpoint)), '192.168.1.21'),
        isEmpty,
      );
    }
  });

  test('Malformed and oversized UDP replies are ignored', () {
    expect(parseDiscoveryReply([0xff, 0xff], '192.168.1.21'), isEmpty);
    expect(
      parseDiscoveryReply(utf8.encode('<broken'), '192.168.1.21'),
      isEmpty,
    );
    expect(parseDiscoveryReply(List.filled(65508, 0), '192.168.1.21'), isEmpty);
    expect(
      parseDiscoveryReply(
        utf8.encode(reply('http://192.168.1.21/device', scopes: '')),
        '192.168.1.21',
      ).single.name,
      'Camera at 192.168.1.21',
    );
  });
}
