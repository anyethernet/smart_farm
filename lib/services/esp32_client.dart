import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/farm_site.dart';
import '../models/io_state.dart';

/// ESP32-P4-ETH web IOCTL client (Webpage.h).
///
/// Login:  POST /login/check  (loginid, loginpw)
/// State:  GET  /io/state     (no login required)
/// Control: POST /config/io/ctrl  (requires login)
///
/// TV8BD  — 로컬 GPIO, 상태 즉시 반영
/// TV16AVR — ESP32가 UART2로 AVR에 `control output` / `allstate` 중계.
///           `/io/state` 폴링 시 펌웨어가 allstate를 유도하고 MCO DO로 상태를 갱신.
///           (TCP remote 클라이언트가 allstate를 안 보내도 웹/앱 제어 가능)
class Esp32Client {
  Esp32Client(this.endpoint, {http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  Esp32Endpoint endpoint;
  final http.Client _http;
  bool loggedIn = false;
  String? lastError;

  Uri _u(String path) => endpoint.baseUri.replace(path: path);

  Future<bool> login() async {
    lastError = null;
    try {
      final res = await _http.post(
        _u('/login/check'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'loginid': endpoint.loginId,
          'loginpw': endpoint.loginPw,
        },
      ).timeout(const Duration(seconds: 8));

      // Firmware sets a global session flag and redirects (303) on success.
      if (res.statusCode == 200 ||
          res.statusCode == 302 ||
          res.statusCode == 303) {
        final loc = res.headers['location'] ?? '';
        if (loc.contains('err') || res.body.contains('Invalid')) {
          loggedIn = false;
          lastError = '로그인 실패 (ID/PW 확인)';
          return false;
        }
        loggedIn = true;
        return true;
      }
      loggedIn = false;
      lastError = '로그인 HTTP ${res.statusCode}';
      return false;
    } catch (e) {
      loggedIn = false;
      lastError = '연결 실패: $e';
      return false;
    }
  }

  Future<IoState?> fetchIoState() async {
    lastError = null;
    try {
      final res =
          await _http.get(_u('/io/state')).timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) {
        lastError = '상태 HTTP ${res.statusCode}';
        return null;
      }
      final map = jsonDecode(res.body) as Map<String, dynamic>;
      return IoState.fromJson(map);
    } catch (e) {
      lastError = '상태 읽기 실패: $e';
      return null;
    }
  }

  Future<bool> motor(int pair, int action) async {
    return _ctrl({'pair': '$pair', 'action': '$action'});
  }

  Future<bool> relay(int pin, int val) async {
    return _ctrl({'pin': '$pin', 'val': '$val'});
  }

  Future<bool> _ctrl(Map<String, String> fields) async {
    lastError = null;
    if (!loggedIn) {
      final ok = await login();
      if (!ok) return false;
    }
    try {
      final res = await _http
          .post(
            _u('/config/io/ctrl'),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: fields,
          )
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200 ||
          res.statusCode == 302 ||
          res.statusCode == 303) {
        final loc = res.headers['location'] ?? '';
        if (loc.contains('needlogin')) {
          loggedIn = false;
          final retried = await login();
          if (!retried) {
            lastError = '제어 권한 없음 — 로그인 필요';
            return false;
          }
          final res2 = await _http
              .post(
                _u('/config/io/ctrl'),
                headers: {'Content-Type': 'application/x-www-form-urlencoded'},
                body: fields,
              )
              .timeout(const Duration(seconds: 8));
          return res2.statusCode == 200 ||
              res2.statusCode == 302 ||
              res2.statusCode == 303;
        }
        return true;
      }
      lastError = '제어 HTTP ${res.statusCode}';
      return false;
    } catch (e) {
      lastError = '제어 실패: $e';
      return false;
    }
  }

  void dispose() => _http.close();
}
