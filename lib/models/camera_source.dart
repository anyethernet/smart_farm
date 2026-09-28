import 'dart:convert';

import 'package:uuid/uuid.dart';

import 'house_label.dart';

enum CameraStreamType {
  hikvisionRtsp,
  hikvisionNvrRtsp,
  hikvisionHttpPreview,
  hikvisionSnapshot,
  hanwhaRtsp,
  hanwhaSnapshot,
  customUrl,
}

class CameraSource {
  CameraSource({
    String? id,
    required this.name,
    this.enabled = true,
    this.type = CameraStreamType.hanwhaRtsp,
    this.host = '',
    this.port = 554,
    this.username = 'admin',
    this.password = '',
    this.channel = 2,
    this.customUrl = '',
    this.httpPort = 80,
    this.useTcp = true,
    this.snapshotIntervalMs = 300,
    this.dong = kDefaultHouse,
    this.jung = '1중',
    this.ptzEnabled = false,
    this.ptzChannel = 0,
  }) : id = id ?? const Uuid().v4();

  final String id;
  String name;
  bool enabled;
  CameraStreamType type;

  String host;
  int port;
  String username;
  String password;
  int channel;
  String customUrl;
  int httpPort;
  bool useTcp;
  int snapshotIntervalMs;

  String dong;
  String jung;

  /// PTZ(팬/틸트/줌) UI·API 사용
  bool ptzEnabled;

  /// 하이크비전 PTZ 채널(보통 1). 한화는 보통 0.
  int ptzChannel;

  /// NVR 카메라 번호(1-based) → 스트림 채널. 메인=N01, 서브=N02.
  static int nvrChannel(int cameraNo, {bool mainStream = false}) {
    final n = cameraNo < 1 ? 1 : cameraNo;
    return n * 100 + (mainStream ? 1 : 2);
  }

  /// 하이크/NVR 채널에서 카메라 번호 추출 (102→1, 203→2).
  static int nvrCameraNo(int streamChannel) {
    if (streamChannel >= 100) return streamChannel ~/ 100;
    return streamChannel;
  }

  /// 하이크/NVR 채널이 메인(…01)인지.
  static bool nvrIsMainStream(int streamChannel) {
    if (streamChannel < 100) return streamChannel == 1 || streamChannel == 101;
    return streamChannel % 100 == 1;
  }

  /// 표시 이름 — 예: 1번 카메라
  static String defaultName(int index1Based) {
    final n = index1Based < 1 ? 1 : index1Based;
    return '$n번 카메라';
  }

  static bool isNumberedDefaultName(String name) =>
      RegExp(r'^\d+번\s*카메라$').hasMatch(name.trim());

  /// 예전 "1하우스 1중 카메라" / "NVR ch1" / "새 카메라" 등.
  static bool looksLikeLegacyName(String name) {
    final t = name.trim();
    if (t.isEmpty || t == 'Camera' || t == '새 카메라') return true;
    if (isNumberedDefaultName(t)) return false;
    if (RegExp(r'^NVR\s*ch\d+$', caseSensitive: false).hasMatch(t)) {
      return true;
    }
    if (!t.contains('카메라')) return false;
    return t.contains('하우스') ||
        t.contains('제어기') ||
        RegExp(r'\d+\s*동').hasMatch(t) ||
        RegExp(r'\d중|부직포|커튼|그늘').hasMatch(t);
  }

  static const namePresets = <String>[
    '1번 카메라',
    '2번 카메라',
    '3번 카메라',
    '4번 카메라',
    '5번 카메라',
    '6번 카메라',
    '7번 카메라',
    '8번 카메라',
    '9번 카메라',
    '10번 카메라',
    '11번 카메라',
    '12번 카메라',
    '13번 카메라',
    '14번 카메라',
    '15번 카메라',
    '16번 카메라',
  ];

  /// NVR IP 기준으로 채널 1..count 카메라 일괄 생성.
  static List<CameraSource> buildNvrChannels({
    required String host,
    required String username,
    required String password,
    required int channelCount,
    bool mainStream = false,
    String namePrefix = '',
    String dong = kDefaultHouse,
    int rtspPort = 554,
    bool useTcp = true,
    CameraStreamType type = CameraStreamType.hikvisionNvrRtsp,
    int nameStartIndex = 1,
  }) {
    final count = channelCount.clamp(1, 64);
    final start = nameStartIndex < 1 ? 1 : nameStartIndex;
    return [
      for (var i = 1; i <= count; i++)
        CameraSource(
          name: namePrefix.trim().isEmpty
              ? defaultName(start + i - 1)
              : '${namePrefix.trim()} ${defaultName(start + i - 1)}',
          type: type,
          host: host.trim(),
          port: rtspPort,
          username: username,
          password: password,
          channel: nvrChannel(i, mainStream: mainStream),
          useTcp: useTcp,
          dong: dong,
          jung: '$i중',
          ptzEnabled: false,
          ptzChannel: i,
        ),
    ];
  }

  bool get isSnapshotType =>
      type == CameraStreamType.hikvisionSnapshot ||
      type == CameraStreamType.hanwhaSnapshot;

  bool get isHanwha =>
      type == CameraStreamType.hanwhaRtsp ||
      type == CameraStreamType.hanwhaSnapshot;

  bool get isHikvisionNvr => type == CameraStreamType.hikvisionNvrRtsp;

  bool get isHikvision =>
      type == CameraStreamType.hikvisionRtsp ||
      type == CameraStreamType.hikvisionNvrRtsp ||
      type == CameraStreamType.hikvisionHttpPreview ||
      type == CameraStreamType.hikvisionSnapshot;

  bool get usesHttpPort =>
      type == CameraStreamType.hikvisionHttpPreview ||
      type == CameraStreamType.hikvisionSnapshot ||
      type == CameraStreamType.hanwhaSnapshot;

  bool get usesRtspPort =>
      type == CameraStreamType.hikvisionRtsp ||
      type == CameraStreamType.hikvisionNvrRtsp ||
      type == CameraStreamType.hanwhaRtsp;

  bool get supportsPtzApi => isHikvision || isHanwha;

  String get _userEnc => Uri.encodeComponent(username);
  String get _passEnc => Uri.encodeComponent(password);

  int get hanwhaProfile {
    if (channel == 101 || channel == 1) return 1;
    if (channel == 102 || channel == 2) return 2;
    if (channel >= 1 && channel <= 10) return channel;
    return 2;
  }

  /// 하이크 스트리밍 101 → PTZ 채널 1 / 한화는 보통 0
  int get effectivePtzChannel {
    if (isHanwha) return ptzChannel;
    if (ptzChannel > 0) return ptzChannel;
    if (channel >= 100) return channel ~/ 100;
    return 1;
  }

  String get playUrl {
    switch (type) {
      case CameraStreamType.customUrl:
        return customUrl.trim();
      case CameraStreamType.hikvisionRtsp:
      case CameraStreamType.hikvisionNvrRtsp:
        return 'rtsp://$_userEnc:$_passEnc@$host:$port/Streaming/Channels/$channel';
      case CameraStreamType.hikvisionHttpPreview:
        return 'http://$_userEnc:$_passEnc@$host:$httpPort'
            '/ISAPI/Streaming/channels/$channel/httpPreview';
      case CameraStreamType.hikvisionSnapshot:
        return 'http://$_userEnc:$_passEnc@$host:$httpPort'
            '/ISAPI/Streaming/channels/$channel/picture';
      case CameraStreamType.hanwhaRtsp:
        return 'rtsp://$_userEnc:$_passEnc@$host:$port'
            '/profile$hanwhaProfile/media.smp';
      case CameraStreamType.hanwhaSnapshot:
        return 'http://$_userEnc:$_passEnc@$host:$httpPort'
            '/stw-cgi/video.cgi?msubmenu=jpg&action=view&Profile=$hanwhaProfile';
    }
  }

  Uri get snapshotUri {
    if (type == CameraStreamType.hanwhaSnapshot) {
      return Uri(
        scheme: 'http',
        host: host.trim(),
        port: httpPort,
        path: '/stw-cgi/video.cgi',
        queryParameters: {
          'msubmenu': 'jpg',
          'action': 'view',
          'Profile': '$hanwhaProfile',
        },
      );
    }
    return Uri(
      scheme: 'http',
      host: host.trim(),
      port: httpPort,
      path: '/ISAPI/Streaming/channels/$channel/picture',
    );
  }

  Map<String, String> get basicAuthHeaders {
    final token = base64Encode(utf8.encode('$username:$password'));
    return {'Authorization': 'Basic $token'};
  }

  String get safePlayUrl =>
      playUrl.replaceFirst(RegExp(r'//[^@/]+@'), '//***@');

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'enabled': enabled,
        'type': type.name,
        'host': host,
        'port': port,
        'username': username,
        'password': password,
        'channel': channel,
        'customUrl': customUrl,
        'httpPort': httpPort,
        'useTcp': useTcp,
        'snapshotIntervalMs': snapshotIntervalMs,
        'dong': dong,
        'jung': jung,
        'ptzEnabled': ptzEnabled,
        'ptzChannel': ptzChannel,
      };

  factory CameraSource.fromJson(Map<String, dynamic> j) {
    var jung = j['jung'] as String? ?? '1중';
    jung = jung.replaceAll('층', '중');
    return CameraSource(
      id: j['id'] as String?,
      name: migrateLegacyHouseInText(
        (j['name'] as String? ?? 'Camera')
            .replaceAll('층', '중')
            .replaceAll('2하우스', kDefaultHouse),
      ),
      enabled: j['enabled'] as bool? ?? true,
      type: CameraStreamType.values.firstWhere(
        (e) => e.name == j['type'],
        orElse: () => CameraStreamType.hanwhaRtsp,
      ),
      host: j['host'] as String? ?? '',
      port: (j['port'] as num?)?.toInt() ?? 554,
      username: j['username'] as String? ?? 'admin',
      password: j['password'] as String? ?? '',
      channel: (j['channel'] as num?)?.toInt() ?? 2,
      customUrl: j['customUrl'] as String? ?? '',
      httpPort: (j['httpPort'] as num?)?.toInt() ?? 80,
      useTcp: j['useTcp'] as bool? ?? true,
      snapshotIntervalMs: (j['snapshotIntervalMs'] as num?)?.toInt() ?? 300,
      dong: remapDefaultHouse(j['dong'] as String? ?? kDefaultHouse),
      jung: jung,
      ptzEnabled: j['ptzEnabled'] as bool? ?? false,
      ptzChannel: (j['ptzChannel'] as num?)?.toInt() ?? 1,
    );
  }

  CameraSource copy() => CameraSource.fromJson(toJson());
}
