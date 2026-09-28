import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/sensor_endpoint.dart';

/// ESP32 Analog API — GET /api/mcp3208 (로그인 불필요, Webpage_Mcp.h)
class Mcp3208Client {
  Mcp3208Client(this.endpoint, {http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  SensorEndpoint endpoint;
  final http.Client _http;
  String? lastError;

  Future<Mcp3208Reading?> fetch() async {
    lastError = null;
    try {
      final uri = endpoint.baseUri.replace(
        path: '/api/mcp3208',
        queryParameters: {'t': '${DateTime.now().millisecondsSinceEpoch}'},
      );
      final res = await _http.get(uri).timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) {
        lastError = '센서 HTTP ${res.statusCode}';
        return null;
      }
      final map = jsonDecode(res.body) as Map<String, dynamic>;
      return Mcp3208Reading.fromJson(map);
    } catch (e) {
      lastError = '센서 읽기 실패: $e';
      return null;
    }
  }

  void dispose() => _http.close();
}
