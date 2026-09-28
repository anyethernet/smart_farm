import 'package:uuid/uuid.dart';

import 'camera_source.dart';
import 'control_element.dart';
import 'esp32_board.dart';
import 'house_label.dart';
import 'sensor_endpoint.dart';

export 'esp32_board.dart';
export 'house_label.dart';

class FarmSite {
  FarmSite({
    String? id,
    required this.name,
    Esp32Endpoint? esp32,
    List<Esp32Board>? boards,
    List<CameraSource>? cameras,
    List<ControlElement>? controls,
    List<SensorEndpoint>? sensors,
    Map<String, String>? houseDefaultCameras,
    this.notes = '',
    int? bgColor,
  })  : id = id ?? const Uuid().v4(),
        boards = _normalizeBoards(boards, esp32),
        cameras = cameras ?? [],
        controls = controls ?? [],
        sensors = sensors ?? [],
        houseDefaultCameras = Map<String, String>.from(
          houseDefaultCameras ?? const {},
        ),
        bgColor = bgColor ?? kDefaultSiteBgColor;

  final String id;
  String name;
  List<Esp32Board> boards;
  List<CameraSource> cameras;
  List<ControlElement> controls;
  List<SensorEndpoint> sensors;
  String notes;

  /// 하우스(동) → 대표 카메라 id. 홈에서 하우스만 선택했을 때 표시.
  Map<String, String> houseDefaultCameras;

  /// 사이트 바탕색 (ARGB). 홈·설정 화면 Scaffold 배경.
  int bgColor;

  static const kDefaultSiteBgColor = 0xFF0F172A;

  /// 선택 가능한 바탕색 프리셋 (라벨, ARGB).
  static const bgColorPresets = <(String, int)>[
    ('슬레이트', 0xFF0F172A),
    ('숲녹', 0xFF14532D),
    ('딥블루', 0xFF1E3A5F),
    ('와인', 0xFF3B1F2B),
    ('인디고', 0xFF1A1A2E),
    ('스톤', 0xFF292524),
    ('앰버', 0xFF422006),
    ('시안', 0xFF164E63),
    ('퍼플', 0xFF2E1065),
    ('차콜', 0xFF18181B),
  ];

  static List<Esp32Board> _normalizeBoards(
    List<Esp32Board>? boards,
    Esp32Endpoint? esp32,
  ) {
    if (boards != null && boards.isNotEmpty) return boards;
    return [
      Esp32Board.fromEndpoint(
        esp32 ?? Esp32Endpoint(),
        name: '보드1',
        dong: kDefaultHouse,
      ),
    ];
  }

  /// 하위 호환: 첫 번째(또는 활성) 보드 엔드포인트.
  Esp32Endpoint get esp32 =>
      enabledBoards.isEmpty ? Esp32Endpoint() : enabledBoards.first.asEndpoint;

  set esp32(Esp32Endpoint e) {
    if (boards.isEmpty) {
      boards = [Esp32Board.fromEndpoint(e)];
    } else {
      boards.first.applyEndpoint(e);
    }
  }

  List<Esp32Board> get enabledBoards => boards.where((b) => b.enabled).toList();

  List<CameraSource> get enabledCameras =>
      cameras.where((c) => c.enabled).toList();

  List<ControlElement> get enabledControls =>
      controls.where((c) => c.enabled).toList();

  List<SensorEndpoint> get enabledSensors =>
      sensors.where((s) => s.enabled).toList();

  Esp32Board? boardById(String? id) {
    if (id == null) return null;
    for (final b in boards) {
      if (b.id == id) return b;
    }
    return null;
  }

  /// 제어에 연결된 보드. boardId 없으면 같은 하우스의 첫 보드 → 사이트 첫 보드.
  Esp32Board? boardForControl(ControlElement el) {
    final linked = boardById(el.boardId);
    if (linked != null && linked.enabled) return linked;
    for (final b in enabledBoards) {
      if (b.dong == el.dong) return b;
    }
    return enabledBoards.isEmpty ? null : enabledBoards.first;
  }

  List<Esp32Board> boardsForDong(String dong) =>
      enabledBoards.where((b) => b.dong == dong).toList();

  SensorEndpoint? sensorForDong(String? dong) {
    if (dong == null) return null;
    for (final s in enabledSensors) {
      if (s.dong == dong) return s;
    }
    return null;
  }

  List<SensorEndpoint> sensorsForDong(String? dong) {
    if (dong == null) return const [];
    return enabledSensors.where((s) => s.dong == dong).toList();
  }

  List<String> get dongList {
    final seen = <String>{};
    final out = <String>[];
    for (final c in enabledControls) {
      if (seen.add(c.dong)) out.add(c.dong);
    }
    for (final c in enabledCameras) {
      if (seen.add(c.dong)) out.add(c.dong);
    }
    for (final b in enabledBoards) {
      if (seen.add(b.dong)) out.add(b.dong);
    }
    for (final s in enabledSensors) {
      if (seen.add(s.dong)) out.add(s.dong);
    }
    if (out.isEmpty) out.add(kDefaultHouse);
    return out;
  }

  List<String> jungListFor(String dong) {
    final seen = <String>{};
    final out = <String>[];
    for (final c in enabledControls.where((e) => e.dong == dong)) {
      if (seen.add(c.jung)) out.add(c.jung);
    }
    for (final c in enabledCameras.where((e) => e.dong == dong)) {
      if (seen.add(c.jung)) out.add(c.jung);
    }
    if (out.isEmpty) {
      out.addAll(['1중', '2중']);
    }
    return out;
  }

  List<String> get zoneList {
    final seen = <String>{};
    final out = <String>[];
    for (final c in enabledControls) {
      final z = '${c.dong}${c.jung}';
      if (seen.add(z)) out.add(z);
    }
    for (final c in enabledCameras) {
      final z = '${c.dong}${c.jung}';
      if (seen.add(z)) out.add(z);
    }
    if (out.isEmpty) {
      out.addAll(['${kDefaultHouse}1중', '${kDefaultHouse}2중']);
    }
    return out;
  }

  static (String dong, String jung) splitZone(String zone) =>
      splitControlGroupZone(zone);

  List<ControlElement> controlsFor(
      {required String dong, String? jung}) {
    return enabledControls
        .where((e) =>
            e.dong == dong && (jung == null || e.jung == jung))
        .toList();
  }

  /// 하우스 대표 영상 — 설정된 카메라, 없으면 해당 하우스의 첫 활성 카메라.
  CameraSource? cameraForDong(String? dong) {
    if (dong == null) return null;
    final preferredId = houseDefaultCameras[dong];
    if (preferredId != null) {
      final preferred = cameraById(preferredId);
      if (preferred != null &&
          preferred.enabled &&
          preferred.dong == dong) {
        return preferred;
      }
    }
    for (final c in enabledCameras) {
      if (c.dong == dong) return c;
    }
    return null;
  }

  CameraSource? cameraById(String? id) {
    if (id == null) return null;
    for (final c in cameras) {
      if (c.id == id) return c;
    }
    return null;
  }

  bool isHouseDefaultCamera(CameraSource cam) =>
      houseDefaultCameras[cam.dong] == cam.id;

  /// 하우스 대표 영상 지정. [cameraId]가 null이면 자동(목록 첫 카메라)으로.
  void setHouseDefaultCamera(String dong, String? cameraId) {
    if (cameraId == null || cameraId.isEmpty) {
      houseDefaultCameras.remove(dong);
      return;
    }
    final cam = cameraById(cameraId);
    if (cam == null || cam.dong != dong) {
      houseDefaultCameras.remove(dong);
      return;
    }
    houseDefaultCameras[dong] = cameraId;
  }

  /// 삭제·하우스 변경 후 잘못된 대표 영상 매핑 정리.
  void pruneHouseDefaultCameras() {
    final valid = <String, String>{};
    for (final e in houseDefaultCameras.entries) {
      final cam = cameraById(e.value);
      if (cam != null && cam.dong == e.key) {
        valid[e.key] = e.value;
      }
    }
    houseDefaultCameras
      ..clear()
      ..addAll(valid);
  }

  CameraSource? cameraForControl(ControlElement el) {
    final linked = cameraById(el.cameraId);
    if (linked != null && linked.enabled) return linked;
    for (final c in enabledCameras) {
      if (c.dong == el.dong && c.jung == el.jung) return c;
    }
    return cameraForDong(el.dong);
  }

  List<String> get controlGroups => dongList;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'esp32': esp32.toJson(),
        'boards': boards.map((e) => e.toJson()).toList(),
        'cameras': cameras.map((e) => e.toJson()).toList(),
        'controls': controls.map((e) => e.toJson()).toList(),
        'sensors': sensors.map((e) => e.toJson()).toList(),
        'houseDefaultCameras': houseDefaultCameras,
        'notes': notes,
        'bgColor': bgColor,
      };

  factory FarmSite.fromJson(Map<String, dynamic> j) {
    final esp = Esp32Endpoint.fromJson(
      (j['esp32'] as Map?)?.cast<String, dynamic>() ?? {},
    );
    final rawBoards = (j['boards'] as List?) ?? const [];
    final boards = rawBoards
        .map((e) => Esp32Board.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    final rawBg = j['bgColor'];
    int? bg;
    if (rawBg is int) {
      bg = rawBg;
    } else if (rawBg is num) {
      bg = rawBg.toInt();
    } else if (rawBg is String) {
      bg = int.tryParse(rawBg.replaceFirst('#', ''), radix: 16);
      if (bg != null && bg <= 0xFFFFFF) bg = 0xFF000000 | bg;
    }
    final rawDefaults = j['houseDefaultCameras'];
    final defaults = <String, String>{};
    if (rawDefaults is Map) {
      for (final e in rawDefaults.entries) {
        final k = normalizeHouseName(e.key.toString());
        final v = e.value?.toString();
        if (k.isNotEmpty && v != null && v.isNotEmpty) {
          defaults[k] = v;
        }
      }
    }

    final site = FarmSite(
      id: j['id'] as String?,
      name: (j['name'] as String? ?? 'Farm').replaceAll('층', '중'),
      esp32: esp,
      boards: boards,
      cameras: ((j['cameras'] as List?) ?? [])
          .map((e) => CameraSource.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      controls: ((j['controls'] as List?) ?? [])
          .map((e) =>
              ControlElement.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      sensors: ((j['sensors'] as List?) ?? [])
          .map((e) =>
              SensorEndpoint.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      houseDefaultCameras: defaults,
      notes: j['notes'] as String? ?? '',
      bgColor: bg,
    );
    site.pruneHouseDefaultCameras();
    return site;
  }

  /// 모든 제어 표시 이름을 DEFAULT(쌍/핀 채널 번호)로 맞춤.
  void applyDefaultControlNames() {
    for (final c in controls) {
      c.name = c.kind == ControlKind.motorPair
          ? ControlElement.defaultPairName(c.pairIndex)
          : ControlElement.defaultPinName(c.pinIndex);
    }
  }

  /// 하우스별로 앞에서부터 8개 제어만 남기고 나머지 삭제.
  void trimControlsToFirstEightPerDong() {
    final countByDong = <String, int>{};
    final kept = <ControlElement>[];
    for (final c in controls) {
      final n = countByDong[c.dong] ?? 0;
      if (n < ControlElement.standardControlCount) {
        kept.add(c);
        countByDong[c.dong] = n + 1;
      }
    }
    controls
      ..clear()
      ..addAll(kept);
  }

  FarmSite copy() => FarmSite.fromJson(toJson());

  static CameraSource _cam({
    required String name,
    required String dong,
    required String jung,
    bool ptz = false,
  }) {
    return CameraSource(
      name: name,
      type: CameraStreamType.hanwhaRtsp,
      host: '192.168.1.151',
      username: 'admin',
      password: 'mcopia2328!',
      channel: 2,
      dong: dong,
      jung: jung,
      ptzEnabled: ptz,
      ptzChannel: 0,
    );
  }

  static ControlElement _ctl({
    required String name,
    required String dong,
    required String jung,
    required int pair,
    String? boardId,
    String? cameraId,
    String up = 'UP',
    String down = 'DOWN',
  }) {
    return ControlElement(
      name: name,
      dong: dong,
      jung: jung,
      kind: ControlKind.motorPair,
      pairIndex: pair,
      boardId: boardId,
      cameraId: cameraId,
      upLabel: up,
      downLabel: down,
      stopLabel: 'STOP',
    );
  }

  /// 논리 순번(0..) — 보드당 8쌍으로 나눠 실제 pairIndex·board에 매핑.
  static const standardDongMotorDefs = ControlElement.presetDefs;

  static const pairsPerBoard = 8;

  static List<CameraSource> standardDongCameras(
    String dong, {
    int nameStartIndex = 1,
  }) {
    final start = nameStartIndex < 1 ? 1 : nameStartIndex;
    return [
      _cam(
        name: CameraSource.defaultName(start),
        dong: dong,
        jung: '1중',
        ptz: true,
      ),
      _cam(
        name: CameraSource.defaultName(start + 1),
        dong: dong,
        jung: '2중',
        ptz: true,
      ),
      _cam(
        name: CameraSource.defaultName(start + 2),
        dong: dong,
        jung: '부직포',
        ptz: true,
      ),
    ];
  }

  /// 영상소스 이름을 사이트 순서대로 1번·2번… 카메라로 맞춤.
  /// 이후 영상소스 정의에서 원하는 이름으로 바꿀 수 있습니다.
  void applyNumberedCameraNames() {
    for (var i = 0; i < cameras.length; i++) {
      cameras[i].name = CameraSource.defaultName(i + 1);
    }
  }

  /// 다음 추가 시 쓸 기본 카메라 이름.
  String nextCameraDefaultName() =>
      CameraSource.defaultName(cameras.length + 1);

  /// 하우스 1개: 카메라 + 보드(필요 시) + 제어 8개.
  /// TV16/TV8 보드당 쌍 8개 → 표준은 보드 1대 분량.
  static ({
    List<Esp32Board> boards,
    List<CameraSource> cameras,
    List<ControlElement> controls,
  }) buildStandardDong(
    String dong, {
    String hostBoard1 = '192.168.1.214',
    String hostBoard2 = '192.168.1.215',
    int cameraNameStartIndex = 1,
  }) {
    dong = normalizeHouseName(dong);
    final maxSeq = standardDongMotorDefs
        .map((e) => e.$3)
        .fold<int>(0, (a, b) => a > b ? a : b);
    final boardCount = (maxSeq ~/ pairsPerBoard) + 1;
    final boards = <Esp32Board>[
      for (var i = 0; i < boardCount; i++)
        Esp32Board(
          name: '$dong-보드${i + 1}',
          dong: dong,
          host: i == 0 ? hostBoard1 : hostBoard2,
          port: 8080,
          loginId: 'mcopia',
          loginPw: '1111',
        ),
    ];

    final cams = standardDongCameras(
      dong,
      nameStartIndex: cameraNameStartIndex,
    );
    final byJung = <String, String>{for (final c in cams) c.jung: c.id};

    final controls = <ControlElement>[
      for (final def in standardDongMotorDefs)
        _ctl(
          name: ControlElement.defaultPairName(def.$3 % pairsPerBoard),
          dong: dong,
          jung: def.$2,
          pair: def.$3 % pairsPerBoard,
          boardId: boards[def.$3 ~/ pairsPerBoard].id,
          cameraId: byJung[def.$2],
        ),
    ];

    return (boards: boards, cameras: cams, controls: controls);
  }

  /// 저장된 `N하우스` 표기를 `N제어기`로 맞춤 (이름·dong·대표영상 키).
  void applyControllerGroupLabelMigration() {
    for (final b in boards) {
      b.dong = remapDefaultHouse(b.dong);
      b.name = migrateLegacyHouseInText(b.name);
    }
    for (final c in cameras) {
      c.dong = remapDefaultHouse(c.dong);
      c.name = migrateLegacyHouseInText(c.name);
    }
    for (final c in controls) {
      c.dong = remapDefaultHouse(c.dong);
      c.name = migrateLegacyHouseInText(c.name);
    }
    for (final s in sensors) {
      s.dong = remapDefaultHouse(s.dong);
      s.name = migrateLegacyHouseInText(s.name);
    }
    final next = <String, String>{};
    for (final e in houseDefaultCameras.entries) {
      next[remapDefaultHouse(e.key)] = e.value;
    }
    houseDefaultCameras
      ..clear()
      ..addAll(next);
    pruneHouseDefaultCameras();
  }

  static FarmSite demo({List<String> dongs = const ['1제어기']}) {
    final boards = <Esp32Board>[];
    final cameras = <CameraSource>[];
    final controls = <ControlElement>[];
    var hostBase = 214;
    var camStart = 1;
    for (final dong in dongs) {
      final pack = buildStandardDong(
        dong,
        hostBoard1: '192.168.1.$hostBase',
        hostBoard2: '192.168.1.${hostBase + 1}',
        cameraNameStartIndex: camStart,
      );
      hostBase += 2;
      camStart += pack.cameras.length;
      boards.addAll(pack.boards);
      cameras.addAll(pack.cameras);
      controls.addAll(pack.controls);
    }

    return FarmSite(
      name: '스마트팜',
      boards: boards,
      cameras: cameras,
      controls: controls,
      houseDefaultCameras: {
        for (final dong in dongs)
          if (cameras.any((c) => c.dong == dong))
            dong: cameras.firstWhere((c) => c.dong == dong).id,
      },
      sensors: [
        for (final dong in dongs)
          SensorEndpoint(
            name: '$dong 센서',
            dong: dong,
            host: dong.startsWith('1') ? '192.168.1.144' : '192.168.1.110',
            port: 8080,
            loginId: 'mcopia',
            loginPw: dong.startsWith('1') ? '1234' : '1111',
            model: dong.startsWith('1')
                ? SensorModel.mcuPico
                : SensorModel.mcuEsp32,
          ),
      ],
      notes: '',
    );
  }
}
