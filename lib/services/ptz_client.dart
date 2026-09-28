import 'package:http/http.dart' as http;

import '../models/camera_source.dart';

enum PtzDir { up, down, left, right, zoomIn, zoomOut, stop }

/// 하이크비전 ISAPI / 한화 stw-cgi PTZ
class PtzClient {
  PtzClient(this.camera, {http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final CameraSource camera;
  final http.Client _http;
  String? lastError;

  Future<bool> move(PtzDir dir) async {
    lastError = null;
    if (!camera.supportsPtzApi) {
      lastError = '이 카메라 타입은 PTZ API가 없습니다';
      return false;
    }
    try {
      if (camera.isHikvision) {
        return await _hikvision(dir);
      }
      return await _hanwha(dir);
    } catch (e) {
      lastError = '$e';
      return false;
    }
  }

  Future<bool> stop() => move(PtzDir.stop);

  Future<bool> _hikvision(PtzDir dir) async {
    var pan = 0;
    var tilt = 0;
    var zoom = 0;
    const speed = 60;
    switch (dir) {
      case PtzDir.left:
        pan = -speed;
      case PtzDir.right:
        pan = speed;
      case PtzDir.up:
        tilt = speed;
      case PtzDir.down:
        tilt = -speed;
      case PtzDir.zoomIn:
        zoom = speed;
      case PtzDir.zoomOut:
        zoom = -speed;
      case PtzDir.stop:
        break;
    }
    final ch = camera.effectivePtzChannel;
    final uri = Uri(
      scheme: 'http',
      host: camera.host.trim(),
      port: camera.httpPort,
      path: '/ISAPI/PTZCtrl/channels/$ch/continuous',
    );
    final body = '<?xml version="1.0" encoding="UTF-8"?>'
        '<PTZData><pan>$pan</pan><tilt>$tilt</tilt><zoom>$zoom</zoom></PTZData>';
    final res = await _http
        .put(
          uri,
          headers: {
            ...camera.basicAuthHeaders,
            'Content-Type': 'application/xml',
          },
          body: body,
        )
        .timeout(const Duration(seconds: 4));
    if (res.statusCode >= 200 && res.statusCode < 300) return true;
    lastError = 'Hikvision PTZ HTTP ${res.statusCode}';
    return false;
  }

  Future<bool> _hanwha(PtzDir dir) async {
    // continuous: Pan/Tilt/Zoom -100..100, 0=stop
    var pan = 0;
    var tilt = 0;
    var zoom = 0;
    const speed = 50;
    switch (dir) {
      case PtzDir.left:
        pan = -speed;
      case PtzDir.right:
        pan = speed;
      case PtzDir.up:
        tilt = speed;
      case PtzDir.down:
        tilt = -speed;
      case PtzDir.zoomIn:
        zoom = speed;
      case PtzDir.zoomOut:
        zoom = -speed;
      case PtzDir.stop:
        break;
    }
    final uri = Uri(
      scheme: 'http',
      host: camera.host.trim(),
      port: camera.httpPort,
      path: '/stw-cgi/ptzcontrol.cgi',
      queryParameters: {
        'msubmenu': 'continuous',
        'action': 'control',
        'Channel': '${camera.effectivePtzChannel}',
        'Pan': '$pan',
        'Tilt': '$tilt',
        'Zoom': '$zoom',
      },
    );
    final res = await _http
        .get(uri, headers: camera.basicAuthHeaders)
        .timeout(const Duration(seconds: 4));
    if (res.statusCode >= 200 && res.statusCode < 300) return true;
    // 일부 펌웨어는 move API
    if (dir != PtzDir.stop) {
      final move = switch (dir) {
        PtzDir.up => 'Up',
        PtzDir.down => 'Down',
        PtzDir.left => 'Left',
        PtzDir.right => 'Right',
        PtzDir.zoomIn => 'ZoomIn',
        PtzDir.zoomOut => 'ZoomOut',
        PtzDir.stop => 'Stop',
      };
      final uri2 = Uri(
        scheme: 'http',
        host: camera.host.trim(),
        port: camera.httpPort,
        path: '/stw-cgi/ptzcontrol.cgi',
        queryParameters: {
          'msubmenu': 'move',
          'action': 'control',
          'Channel': '${camera.effectivePtzChannel}',
          'Move': move,
        },
      );
      final res2 = await _http
          .get(uri2, headers: camera.basicAuthHeaders)
          .timeout(const Duration(seconds: 4));
      if (res2.statusCode >= 200 && res2.statusCode < 300) return true;
      lastError = 'Hanwha PTZ HTTP ${res.statusCode}/${res2.statusCode}';
      return false;
    }
    lastError = 'Hanwha PTZ HTTP ${res.statusCode}';
    return false;
  }

  void dispose() => _http.close();
}
