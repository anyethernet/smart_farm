/// Response of GET /io/state (Webpage.h webHandleIOState).
class IoState {
  const IoState({
    required this.tv16,
    required this.src,
    required this.ok,
    required this.cfg,
    required this.states,
  });

  final bool tv16;
  final String src;
  final bool ok;
  /// Bitmask: bit i == 1 → pair i is motor (SETIOCONFIG[i]=='1').
  final int cfg;
  final List<int> states;

  int get pairCount => tv16 ? 8 : 4;
  int get channelCount => tv16 ? 16 : 8;

  bool get hasData => states.isNotEmpty;

  /// TV16AVR: MCO(allstate 응답)를 받기 전까지는 채널값이 신뢰되지 않음.
  bool get statusTrusted => !tv16 || ok;

  /// SETIOCONFIG 문자열 (예: 11110000). 펌웨어 setIOConfig와 동일 의미.
  String get setIoConfigText {
    final n = pairCount;
    return [
      for (var i = 0; i < n; i++) ((cfg >> i) & 1) == 1 ? '1' : '0',
    ].join();
  }

  bool isMotorPair(int pairIndex) {
    if (pairIndex < 0 || pairIndex >= pairCount) return false;
    return ((cfg >> pairIndex) & 1) == 1;
  }

  int channel(int index) {
    if (index < 0 || index >= states.length) return 0;
    return states[index] != 0 ? 1 : 0;
  }

  /// Independent status for one motor pair (never shared across pairs).
  MotorPairUi motorUi(int pairIndex) {
    if (!hasData) return MotorPairUi.unknown;
    final s0 = channel(pairIndex * 2);
    final s1 = channel(pairIndex * 2 + 1);
    if (s0 == 1 && s1 == 0) return MotorPairUi.up;
    if (s0 == 0 && s1 == 1) return MotorPairUi.down;
    if (s0 == 0 && s1 == 0) return MotorPairUi.stop;
    return MotorPairUi.conflict; // both ON — invalid / mid-switch
  }

  String motorDetail(int pairIndex) {
    if (!hasData) return '상태 없음';
    final a = pairIndex * 2 + 1;
    final b = pairIndex * 2 + 2;
    return 'ch$a=${channel(pairIndex * 2)} ch$b=${channel(pairIndex * 2 + 1)}';
  }

  factory IoState.fromJson(Map<String, dynamic> j) {
    final raw = (j['s'] as List?) ?? const [];
    return IoState(
      tv16: j['tv16'] == true,
      src: j['src'] as String? ?? '',
      ok: j['ok'] != false,
      cfg: (j['cfg'] as num?)?.toInt() ?? 0,
      states: raw.map((e) => (e as num).toInt()).toList(),
    );
  }

  static const empty = IoState(
    tv16: false,
    src: '',
    ok: false,
    cfg: 0,
    states: [],
  );
}

enum MotorPairUi { up, down, stop, unknown, conflict }

class MotorAction {
  static const stop = 0;
  static const up = 1;
  static const down = 2;
}
