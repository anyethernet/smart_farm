/// 상위 구역(제어기그룹) 이름 — 저장 값 예: `1제어기` (예전: 1동, 1하우스).

/// UI에 쓰는 구역 종류 라벨.
const kControlGroupLabel = '제어기그룹';

String normalizeHouseName(String raw) {
  var t = raw.replaceAll('층', '중').trim();
  if (t == '새하우스') return '새제어기';

  final dong = RegExp(r'^(\d+)\s*동$').firstMatch(t);
  if (dong != null) return '${dong[1]}제어기';

  final legacyHouse = RegExp(r'^(\d+)\s*하우스$').firstMatch(t);
  if (legacyHouse != null) return '${legacyHouse[1]}제어기';

  final ctrl = RegExp(r'^(\d+)\s*제어기$').firstMatch(t);
  if (ctrl != null) return '${ctrl[1]}제어기';

  return t;
}

const kDefaultHouse = '1제어기';
const kDefaultHouses = ['1제어기'];

/// 예전 기본 템플릿의 `2하우스` / `2제어기` → `1제어기`.
String remapDefaultHouse(String dong) {
  final t = normalizeHouseName(dong);
  if (t == '2제어기' || t == '2하우스') return kDefaultHouse;
  return t;
}

String migrateLegacyHouseInText(String text) {
  return text.replaceAllMapped(
    RegExp(r'(\d+)하우스'),
    (m) => '${m[1]}제어기',
  );
}

(String, String) splitControlGroupZone(String zone) {
  final h = zone.indexOf('제어기');
  if (h >= 0) {
    return (
      zone.substring(0, h + '제어기'.length),
      zone.substring(h + '제어기'.length),
    );
  }
  final legacy = zone.indexOf('하우스');
  if (legacy >= 0) {
    final dong = normalizeHouseName(
      zone.substring(0, legacy + '하우스'.length),
    );
    return (dong, zone.substring(legacy + '하우스'.length));
  }
  final i = zone.indexOf('동');
  if (i >= 0 && i + 1 < zone.length) {
    return (
      normalizeHouseName(zone.substring(0, i + 1)),
      zone.substring(i + 1),
    );
  }
  return (normalizeHouseName(zone), '1중');
}
