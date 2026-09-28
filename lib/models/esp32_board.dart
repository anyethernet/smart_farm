import 'package:uuid/uuid.dart';

import 'house_label.dart';

/// 사이트 안의 TV16AVR / TV8BD 한 대.
/// 한 하우스에 보드 여러 대를 둘 수 있음.
class Esp32Board {
  Esp32Board({
    String? id,
    required this.name,
    this.dong = kDefaultHouse,
    this.host = '192.168.1.214',
    this.port = 8080,
    this.loginId = 'mcopia',
    this.loginPw = '1111',
    this.useHttps = false,
    this.enabled = true,
  }) : id = id ?? const Uuid().v4();

  final String id;
  String name;
  String dong;
  String host;
  int port;
  String loginId;
  String loginPw;
  bool useHttps;
  bool enabled;

  Uri get baseUri {
    final scheme = useHttps ? 'https' : 'http';
    return Uri(scheme: scheme, host: host.trim(), port: port);
  }

  String get displayHost => '${host.trim()}:$port';

  String get summary => '$name · $dong · $displayHost';

  Esp32Endpoint get asEndpoint => Esp32Endpoint(
        host: host,
        port: port,
        loginId: loginId,
        loginPw: loginPw,
        useHttps: useHttps,
      );

  void applyEndpoint(Esp32Endpoint e) {
    host = e.host;
    port = e.port;
    loginId = e.loginId;
    loginPw = e.loginPw;
    useHttps = e.useHttps;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'dong': dong,
        'host': host,
        'port': port,
        'loginId': loginId,
        'loginPw': loginPw,
        'useHttps': useHttps,
        'enabled': enabled,
      };

  factory Esp32Board.fromJson(Map<String, dynamic> j) {
    final dong = remapDefaultHouse(j['dong'] as String? ?? kDefaultHouse);
    var name = j['name'] as String? ?? '보드';
    name = migrateLegacyHouseInText(name);
    return Esp32Board(
      id: j['id'] as String?,
      name: name,
      dong: dong,
      host: j['host'] as String? ?? '192.168.1.214',
      port: (j['port'] as num?)?.toInt() ?? 8080,
      loginId: j['loginId'] as String? ?? 'mcopia',
      loginPw: j['loginPw'] as String? ?? '1111',
      useHttps: j['useHttps'] as bool? ?? false,
      enabled: j['enabled'] as bool? ?? true,
    );
  }

  factory Esp32Board.fromEndpoint(
    Esp32Endpoint e, {
    String? id,
    String name = '보드1',
    String dong = kDefaultHouse,
  }) {
    return Esp32Board(
      id: id,
      name: name,
      dong: remapDefaultHouse(dong),
      host: e.host,
      port: e.port,
      loginId: e.loginId,
      loginPw: e.loginPw,
      useHttps: e.useHttps,
    );
  }

  Esp32Board copy() => Esp32Board.fromJson(toJson());
}

/// 하위 호환·단일 보드 편의용 엔드포인트.
class Esp32Endpoint {
  Esp32Endpoint({
    this.host = '192.168.1.214',
    this.port = 8080,
    this.loginId = 'mcopia',
    this.loginPw = '1111',
    this.useHttps = false,
  });

  String host;
  int port;
  String loginId;
  String loginPw;
  bool useHttps;

  Uri get baseUri {
    final scheme = useHttps ? 'https' : 'http';
    return Uri(scheme: scheme, host: host.trim(), port: port);
  }

  String get displayHost => '${host.trim()}:$port';

  Map<String, dynamic> toJson() => {
        'host': host,
        'port': port,
        'loginId': loginId,
        'loginPw': loginPw,
        'useHttps': useHttps,
      };

  factory Esp32Endpoint.fromJson(Map<String, dynamic> j) {
    return Esp32Endpoint(
      host: j['host'] as String? ?? '192.168.1.214',
      port: (j['port'] as num?)?.toInt() ?? 8080,
      loginId: j['loginId'] as String? ?? 'mcopia',
      loginPw: j['loginPw'] as String? ?? '1111',
      useHttps: j['useHttps'] as bool? ?? false,
    );
  }
}
