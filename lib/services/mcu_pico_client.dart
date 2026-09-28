import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/sensor_endpoint.dart';

/// RP2040 PICO setconfig5 실시간 API — GET /data
/// 응답: `{"data":[{"name":"GTEMP","value":30.4}, ...]}` (14개)
class McuPicoClient {
  McuPicoClient(this.endpoint, {http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  SensorEndpoint endpoint;
  final http.Client _http;
  String? lastError;

  static const int channelCount = 14;

  Future<Mcp3208Reading?> fetch() async {
    lastError = null;
    try {
      final uri = endpoint.baseUri.replace(
        path: '/data',
        queryParameters: {'t': '${DateTime.now().millisecondsSinceEpoch}'},
      );
      final res = await _http.get(uri).timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) {
        lastError = 'PICO 센서 HTTP ${res.statusCode}';
        return null;
      }
      final map = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (map['data'] as List?) ?? const [];
      final eng = <double>[];
      final labels = <String>[];
      for (var i = 0; i < channelCount && i < list.length; i++) {
        final item = list[i];
        if (item is! Map) {
          throw const FormatException('PICO /data 항목 형식 오류');
        }
        final value = item['value'];
        if (value is! num) {
          throw const FormatException('PICO /data value 형식 오류');
        }
        eng.add(value.toDouble());
        final name = '${item['name'] ?? ''}'.trim();
        labels.add(name.isEmpty ? 'S$i' : name);
      }
      if (eng.isEmpty) {
        throw const FormatException('PICO /data 센서값 없음');
      }
      return Mcp3208Reading(
        ok: true,
        ready: true,
        adcCh: eng.length,
        wind: false,
        raw: const [],
        eng: eng,
        labels: labels,
      );
    } catch (e) {
      lastError = 'PICO 센서 읽기 실패: $e';
      return null;
    }
  }

  void dispose() => _http.close();
}
