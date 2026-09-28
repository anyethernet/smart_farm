import 'package:uuid/uuid.dart';

import 'house_label.dart';

/// Maps to ESP32 web IOCTL (`Webpage.h` PATH_IO_CTRL).
enum ControlKind {
  motorPair,
  relayToggle,
}

class ControlElement {
  ControlElement({
    String? id,
    required this.name,
    this.kind = ControlKind.motorPair,
    this.pairIndex = 0,
    this.pinIndex = 0,
    this.enabled = true,
    this.dong = kDefaultHouse,
    this.jung = '1중',
    this.upLabel = 'UP',
    this.downLabel = 'DOWN',
    this.stopLabel = 'STOP',
    this.onLabel = 'ON',
    this.offLabel = 'OFF',
    this.cameraId,
    this.boardId,
  }) : id = id ?? const Uuid().v4();

  final String id;
  String name;
  ControlKind kind;
  int pairIndex;
  int pinIndex;
  bool enabled;

  /// 하우스 — 예: 1하우스
  String dong;

  /// 하우스 안의 중 — 예: 1중, 2중
  String jung;

  String upLabel;
  String downLabel;
  String stopLabel;
  String onLabel;
  String offLabel;
  String? cameraId;

  /// 이 제어가 속한 ESP32 보드. null이면 하우스의 첫 보드.
  String? boardId;

  String get group => jung;

  /// 채널 쌍 기본 표시명 — 예: 쌍1 (ch1–ch2)
  static String defaultPairName(int pairIndex) {
    final p = pairIndex.clamp(0, 7);
    return '쌍${p + 1} (ch${p * 2 + 1}–ch${p * 2 + 2})';
  }

  /// 단일 핀 기본 표시명 — 예: 핀3 (ch3)
  static String defaultPinName(int pinIndex) {
    final p = pinIndex.clamp(0, 15);
    return '핀${p + 1} (ch${p + 1})';
  }

  static bool isDefaultChannelName(String name) {
    final t = name.trim();
    if (t.isEmpty || t == '새 제어' || t == 'Control') return true;
    return RegExp(r'^쌍\d+\s*\(ch\d+[–-]\s*ch\d+\)$').hasMatch(t) ||
        RegExp(r'^핀\d+\s*\(ch\d+\)$').hasMatch(t);
  }

  /// 제어 이름 프리셋 (표준 하우스 목록) · (이름, 중, 논리순번).
  /// 표준 추가는 앞에서부터 8개(보드 1대 분량).
  static const presetDefs = <(String name, String jung, int seq)>[
    ('1중천창(좌)', '1중', 0),
    ('1중천창(우)', '1중', 1),
    ('1중측창', '1중', 2),
    ('1중(앞)', '1중', 3),
    ('1중(뒤)', '1중', 4),
    ('2중천창', '2중', 5),
    ('2중측창', '2중', 6),
    ('2중(앞)', '2중', 7),
  ];

  /// 표준 8개 외 추가 선택 이름 · (이름, 중).
  static const extraPresetNames = <(String name, String jung)>[
    ('2중(뒤)', '2중'),
    ('부직포천창', '부직포'),
    ('부직포측창', '부직포'),
    ('부직포(앞)', '부직포'),
    ('부직포(뒤)', '부직포'),
    ('수평커튼', '커튼'),
    ('그늘막', '그늘막'),
  ];

  /// 하우스당 표준 제어 개수.
  static const standardControlCount = 8;

  static List<String> get presetNames => [
        for (final d in presetDefs) d.$1,
        for (final d in extraPresetNames) d.$1,
      ];

  /// 프리셋 이름 → 중(구역). 없으면 null.
  static String? jungForPreset(String name) {
    for (final d in presetDefs) {
      if (d.$1 == name) return d.$2;
    }
    for (final d in extraPresetNames) {
      if (d.$1 == name) return d.$2;
    }
    return null;
  }

  /// 채널 쌍 → 단일 핀 2개(chA, chB)로 분리할 때 쓰는 핀 번호(0-based).
  int get pairPinA => (pairIndex.clamp(0, 7)) * 2;
  int get pairPinB => pairPinA + 1;

  /// 모터쌍을 단일 핀 ON/OFF 두 개로 나눈다. (첫 요소=기존 id 유지, 둘째=신규)
  static (ControlElement first, ControlElement second) splitPairToRelays(
    ControlElement pair,
  ) {
    final p0 = pair.pairPinA;
    final p1 = pair.pairPinB;
    final keepPairName = !isDefaultChannelName(pair.name) &&
        pair.name != defaultPairName(pair.pairIndex);

    final first = ControlElement(
      id: pair.id,
      name: keepPairName ? '${pair.name}·ch${p0 + 1}' : defaultPinName(p0),
      kind: ControlKind.relayToggle,
      pairIndex: pair.pairIndex,
      pinIndex: p0,
      enabled: pair.enabled,
      dong: pair.dong,
      jung: pair.jung,
      upLabel: pair.upLabel,
      downLabel: pair.downLabel,
      stopLabel: pair.stopLabel,
      onLabel: pair.onLabel,
      offLabel: pair.offLabel,
      cameraId: pair.cameraId,
      boardId: pair.boardId,
    );
    final second = ControlElement(
      name: keepPairName ? '${pair.name}·ch${p1 + 1}' : defaultPinName(p1),
      kind: ControlKind.relayToggle,
      pairIndex: pair.pairIndex,
      pinIndex: p1,
      enabled: pair.enabled,
      dong: pair.dong,
      jung: pair.jung,
      upLabel: pair.upLabel,
      downLabel: pair.downLabel,
      stopLabel: pair.stopLabel,
      onLabel: pair.onLabel,
      offLabel: pair.offLabel,
      cameraId: pair.cameraId,
      boardId: pair.boardId,
    );
    return (first, second);
  }

  /// 단일 핀 ON/OFF → 채널 쌍(UP/DOWN)으로 합칠 때 쌍 번호(0-based).
  static int pairIndexFromPin(int pinIndex) =>
      (pinIndex.clamp(0, 15) ~/ 2).clamp(0, 7);

  /// 같은 쌍의 상대 핀(0-based). 예: ch1↔ch2, ch3↔ch4.
  static int siblingPinIndex(int pinIndex) {
    final p = pinIndex.clamp(0, 15);
    return p.isEven ? p + 1 : p - 1;
  }

  /// 단일 핀을 채널 쌍으로 되돌린다. (id·보드·구역 유지, 이름은 DEFAULT 쌍명 또는 지정명)
  static ControlElement mergeRelayToPair(
    ControlElement relay, {
    String? name,
  }) {
    final pairIndex = pairIndexFromPin(relay.pinIndex);
    final useDefault = name == null ||
        name.trim().isEmpty ||
        isDefaultChannelName(name) ||
        RegExp(r'^핀\d+\s*\(ch\d+\)$').hasMatch(name.trim()) ||
        name.contains('·ch');
    return ControlElement(
      id: relay.id,
      name: useDefault ? defaultPairName(pairIndex) : name.trim(),
      kind: ControlKind.motorPair,
      pairIndex: pairIndex,
      pinIndex: pairIndex * 2,
      enabled: relay.enabled,
      dong: relay.dong,
      jung: relay.jung,
      upLabel: relay.upLabel,
      downLabel: relay.downLabel,
      stopLabel: relay.stopLabel,
      onLabel: relay.onLabel,
      offLabel: relay.offLabel,
      cameraId: relay.cameraId,
      boardId: relay.boardId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'pairIndex': pairIndex,
        'pinIndex': pinIndex,
        'enabled': enabled,
        'dong': dong,
        'jung': jung,
        'group': jung,
        'upLabel': upLabel,
        'downLabel': downLabel,
        'stopLabel': stopLabel,
        'onLabel': onLabel,
        'offLabel': offLabel,
        'cameraId': cameraId,
        'boardId': boardId,
      };

  factory ControlElement.fromJson(Map<String, dynamic> j) {
    var jung = (j['jung'] as String?) ?? (j['group'] as String?) ?? '1중';
    jung = jung.replaceAll('층', '중');
    if (jung == '커튼') jung = '2중';
    return ControlElement(
      id: j['id'] as String?,
      name: (j['name'] as String? ?? 'Control').replaceAll('층', '중'),
      kind: ControlKind.values.firstWhere(
        (e) => e.name == j['kind'],
        orElse: () => ControlKind.motorPair,
      ),
      pairIndex: (j['pairIndex'] as num?)?.toInt() ?? 0,
      pinIndex: (j['pinIndex'] as num?)?.toInt() ?? 0,
      enabled: j['enabled'] as bool? ?? true,
      dong: remapDefaultHouse(j['dong'] as String? ?? kDefaultHouse),
      jung: jung,
      upLabel: j['upLabel'] as String? ?? 'UP',
      downLabel: j['downLabel'] as String? ?? 'DOWN',
      stopLabel: j['stopLabel'] as String? ?? 'STOP',
      onLabel: j['onLabel'] as String? ?? 'ON',
      offLabel: j['offLabel'] as String? ?? 'OFF',
      cameraId: j['cameraId'] as String?,
      boardId: j['boardId'] as String?,
    );
  }

  ControlElement copy() => ControlElement.fromJson(toJson());
}
