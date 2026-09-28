import 'package:uuid/uuid.dart';

import 'house_label.dart';

/// 하우스별 센서 보드 종류.
enum SensorModel {
  /// ESP32 Analog — GET /api/mcp3208 (채널 수는 응답 adcCh/eng 기준)
  mcuEsp32,

  /// RP2040 PICO Calibration — GET /data (센서 14개, CH0–13)
  mcuPico,
}

class SensorEndpoint {
  SensorEndpoint({
    String? id,
    required this.name,
    this.enabled = true,
    this.dong = kDefaultHouse,
    this.host = '192.168.1.110',
    this.port = 8080,
    this.loginId = 'mcopia',
    this.loginPw = '1111',
    this.model = SensorModel.mcuEsp32,
    this.useHttps = false,
    List<bool>? channelVisible,
    List<String>? channelLabels,
    List<int>? channelOrder,
    this.windVisible = true,
  })  : id = id ?? const Uuid().v4(),
        channelVisible = _normalizeVisible(
          channelVisible,
          model,
        ),
        channelLabels = _normalizeLabels(channelLabels, model),
        channelOrder = _normalizeOrder(channelOrder, model);

  final String id;
  String name;
  bool enabled;
  String dong;
  String host;
  int port;
  String loginId;
  String loginPw;
  SensorModel model;
  bool useHttps;

  /// ADC 채널별 홈 화면 표시 여부 (인덱스 = CH0..)
  List<bool> channelVisible;

  /// 채널별 표시 이름. 빈 문자열이면 기본명(/data name 또는 defaultLabels).
  List<String> channelLabels;

  /// 홈 화면 표시 순서 (채널 인덱스). 비어 있으면 0,1,2… 순.
  List<int> channelOrder;

  /// MCU ESP32: 풍속 카운터(PPS, eng 마지막) 표시 — 응답에 wind/여분 eng가 있을 때
  bool windVisible;

  Uri get baseUri {
    final scheme = useHttps ? 'https' : 'http';
    return Uri(scheme: scheme, host: host.trim(), port: port);
  }

  String get displayHost => '${host.trim()}:$port';

  /// MCU ESP32 기본 라벨 (실제 표시 개수는 API adcCh/eng 길이)
  static const mcuEsp32Labels = [
    'NTC1',
    'NTC2',
    'HUMI',
    'ILSA',
    'CO2',
    'PH',
    'EC',
    'WINDDIR',
  ];

  /// RP2040 setconfig5 기본 센서명 — 실제 이름은 /data 응답을 우선 사용.
  static const mcuPicoLabels = [
    'GTEMP',
    'GVWC',
    'GEC',
    'CO2',
    'PH',
    'EC',
    'DTE',
    'DHU',
    'WINDSPEED',
    'S9',
    'S10',
    'S11',
    'S12',
    'S13',
  ];

  static const windCounterLabel = '풍속카운터';

  /// 설정 화면에서 토글할 수 있는 ADC 슬롯 수 (표시는 응답 길이에 맞춤)
  static int _channelCountFor(SensorModel m) {
    switch (m) {
      case SensorModel.mcuEsp32:
        return 8;
      case SensorModel.mcuPico:
        return 14;
    }
  }

  /// 홈에 나타날 수 있는 최대 칸 수
  int get displaySlotCount {
    switch (model) {
      case SensorModel.mcuEsp32:
        return 8 + 1; // ADC + 풍속카운터
      case SensorModel.mcuPico:
        return 14;
    }
  }

  String get modelSummary {
    switch (model) {
      case SensorModel.mcuEsp32:
        return 'MCU ESP32 · Analog';
      case SensorModel.mcuPico:
        return 'MCU PICO · Calibration 14개';
    }
  }

  /// API 경로 요약 (편집 화면 helper)
  String get apiPathHint {
    switch (model) {
      case SensorModel.mcuEsp32:
        return 'GET /api/mcp3208 (adcCh·eng 그대로 표시)';
      case SensorModel.mcuPico:
        return 'GET /data';
    }
  }

  static List<bool> _defaultVisible(SensorModel model) {
    final count = _channelCountFor(model);
    if (model == SensorModel.mcuPico) {
      return [for (var i = 0; i < count; i++) i < 3];
    }
    return List<bool>.filled(count, true);
  }

  static List<bool> _normalizeVisible(
    List<bool>? src,
    SensorModel model,
  ) {
    final defaults = _defaultVisible(model);
    final count = defaults.length;
    if (src == null || src.isEmpty) {
      return defaults;
    }
    return [
      for (var i = 0; i < count; i++) i < src.length ? src[i] : defaults[i],
    ];
  }

  static List<String> _normalizeLabels(List<String>? src, SensorModel model) {
    final count = _channelCountFor(model);
    if (src == null || src.isEmpty) {
      return List<String>.filled(count, '');
    }
    return [
      for (var i = 0; i < count; i++) i < src.length ? src[i] : '',
    ];
  }

  static List<int> _normalizeOrder(List<int>? src, SensorModel model) {
    final count = _channelCountFor(model);
    final natural = [for (var i = 0; i < count; i++) i];
    if (src == null || src.isEmpty) return natural;
    final seen = <int>{};
    final out = <int>[];
    for (final i in src) {
      if (i < 0 || i >= count) continue;
      if (seen.add(i)) out.add(i);
    }
    for (final i in natural) {
      if (seen.add(i)) out.add(i);
    }
    return out;
  }

  int get channelCount => _channelCountFor(model);

  List<String> defaultLabels() {
    switch (model) {
      case SensorModel.mcuEsp32:
        return List<String>.from(mcuEsp32Labels);
      case SensorModel.mcuPico:
        return List<String>.from(mcuPicoLabels);
    }
  }

  /// 표시용 이름: 사용자 지정 → API name → 기본 라벨 → CHn
  String labelForChannel(int index, {List<String>? apiLabels}) {
    if (index >= 0 &&
        index < channelLabels.length &&
        channelLabels[index].trim().isNotEmpty) {
      return channelLabels[index].trim();
    }
    if (apiLabels != null &&
        index >= 0 &&
        index < apiLabels.length &&
        apiLabels[index].trim().isNotEmpty) {
      return apiLabels[index].trim();
    }
    final defaults = defaultLabels();
    if (index >= 0 && index < defaults.length) return defaults[index];
    return 'CH$index';
  }

  /// 편집 화면에 채울 초기 이름 (지정값 없으면 기본명)
  String editableLabel(int index) {
    if (index >= 0 &&
        index < channelLabels.length &&
        channelLabels[index].trim().isNotEmpty) {
      return channelLabels[index].trim();
    }
    return labelForChannel(index);
  }

  bool isChannelVisible(int index) {
    if (index < 0 || index >= channelVisible.length) return true;
    return channelVisible[index];
  }

  void setModel(SensorModel m) {
    final changed = model != m;
    final oldVis = channelVisible;
    final oldLabels = channelLabels;
    final oldOrder = channelOrder;
    model = m;
    channelVisible = _normalizeVisible(changed ? null : oldVis, model);
    channelLabels = _normalizeLabels(changed ? null : oldLabels, model);
    channelOrder = _normalizeOrder(changed ? null : oldOrder, model);
  }

  /// 표시할 ADC 채널 인덱스 목록 (사용자 순서 반영)
  List<int> visibleChannelIndexes({int? adcChLimit}) {
    final limit = adcChLimit == null || adcChLimit <= 0
        ? channelCount
        : (adcChLimit < channelCount ? adcChLimit : channelCount);
    final order = channelOrder.isEmpty
        ? [for (var i = 0; i < limit; i++) i]
        : channelOrder.where((i) => i >= 0 && i < limit);
    return [
      for (final i in order)
        if (isChannelVisible(i)) i,
    ];
  }

  /// 구버전 JSON 모델명 → 현재 enum
  static SensorModel parseModel(String? raw) {
    switch (raw) {
      case 'mcuPico':
        return SensorModel.mcuPico;
      case 'mcuEsp32':
      case 'mcpEsp32': // 오타·구버전
      case 'mcp3208':
      case 'mcp3208s':
        return SensorModel.mcuEsp32;
      default:
        return SensorModel.mcuEsp32;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'enabled': enabled,
        'dong': dong,
        'host': host,
        'port': port,
        'loginId': loginId,
        'loginPw': loginPw,
        'model': model.name,
        'useHttps': useHttps,
        'channelVisible': channelVisible,
        'channelLabels': channelLabels,
        'channelOrder': channelOrder,
        'windVisible': windVisible,
      };

  factory SensorEndpoint.fromJson(Map<String, dynamic> j) {
    final model = parseModel(j['model'] as String?);
    List<bool>? visible;
    final raw = j['channelVisible'];
    if (raw is List) {
      visible = raw.map((e) {
        if (e is bool) return e;
        if (e is num) return e != 0;
        return true;
      }).toList();
    }
    List<String>? labels;
    final rawLabels = j['channelLabels'];
    if (rawLabels is List) {
      labels = rawLabels.map((e) => e?.toString() ?? '').toList();
    }
    List<int>? order;
    final rawOrder = j['channelOrder'];
    if (rawOrder is List) {
      order = rawOrder
          .map((e) => e is num ? e.toInt() : int.tryParse('$e') ?? -1)
          .toList();
    }
    return SensorEndpoint(
      id: j['id'] as String?,
      name: migrateLegacyHouseInText(
        (j['name'] as String? ?? '센서').replaceAll('2하우스', kDefaultHouse),
      ),
      enabled: j['enabled'] as bool? ?? true,
      dong: remapDefaultHouse(j['dong'] as String? ?? kDefaultHouse),
      host: j['host'] as String? ?? '192.168.1.110',
      port: (j['port'] as num?)?.toInt() ?? 8080,
      loginId: j['loginId'] as String? ?? 'mcopia',
      loginPw: j['loginPw'] as String? ?? '1111',
      model: model,
      useHttps: j['useHttps'] as bool? ?? false,
      channelVisible: visible,
      channelLabels: labels,
      channelOrder: order,
      windVisible: j['windVisible'] as bool? ?? true,
    );
  }

  SensorEndpoint copy() => SensorEndpoint.fromJson(toJson());
}

/// GET /api/mcp3208 응답 (Webpage_Mcp.h) — 채널 수는 adcCh/eng 길이 그대로 사용
class Mcp3208Reading {
  const Mcp3208Reading({
    required this.ok,
    required this.ready,
    required this.adcCh,
    required this.wind,
    required this.raw,
    required this.eng,
    this.labels = const [],
  });

  final bool ok;
  final bool ready;
  final int adcCh;
  final bool wind;
  final List<int> raw;
  final List<double> eng;

  /// API가 제공하는 센서명. RP2040 /data의 name을 홈 표시명으로 사용.
  final List<String> labels;

  bool get hasData => eng.isNotEmpty;

  factory Mcp3208Reading.fromJson(Map<String, dynamic> j) {
    final rawList = (j['raw'] as List?) ?? const [];
    final engList = (j['eng'] as List?) ?? const [];
    return Mcp3208Reading(
      ok: j['ok'] == true || j['ok'] == 1,
      ready: j['ready'] == true || j['ready'] == 1,
      adcCh: (j['adcCh'] as num?)?.toInt() ?? 0,
      wind: j['wind'] == true || j['wind'] == 1,
      raw: rawList.map((e) => (e as num).toInt()).toList(),
      eng: engList.map((e) => (e as num).toDouble()).toList(),
      labels: const [],
    );
  }

  static const empty = Mcp3208Reading(
    ok: false,
    ready: false,
    adcCh: 0,
    wind: false,
    raw: [],
    eng: [],
    labels: [],
  );
}
