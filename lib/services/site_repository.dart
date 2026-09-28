import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/farm_site.dart';

class SiteRepository {
  static const _keySites = 'farm_sites_v1';
  static const _keyActive = 'farm_active_id_v1';
  static const _keyHouseMigrate = 'farm_house2_to_1_v1';
  static const _keyCtrlDefaultNames = 'farm_ctrl_default_names_v1';
  static const _keyCamNumberedNames = 'farm_cam_numbered_names_v1';
  static const _keyCtrlTrim8 = 'farm_ctrl_trim8_v1';
  static const _keyControllerGroup = 'farm_controller_group_v1';

  Future<List<FarmSite>> loadSites() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keySites);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    final list = jsonDecode(raw) as List;
    final sites = list
        .map((e) => FarmSite.fromJson((e as Map).cast<String, dynamic>()))
        .toList();

    var dirty = false;

    // fromJson에서 2하우스→1하우스 반영. 한 번 저장해 디스크도 맞춤.
    final migrated = prefs.getBool(_keyHouseMigrate) ?? false;
    if (!migrated) {
      dirty = true;
      await prefs.setBool(_keyHouseMigrate, true);
    }

    // 제어 이름을 DEFAULT(쌍/핀 번호)로 일괄 변경.
    final namesMigrated = prefs.getBool(_keyCtrlDefaultNames) ?? false;
    if (!namesMigrated) {
      for (final s in sites) {
        s.applyDefaultControlNames();
      }
      dirty = true;
      await prefs.setBool(_keyCtrlDefaultNames, true);
    }

    // 영상소스 이름을 1번·2번… 카메라로 일괄 변경 (이후 영상소스 정의에서 수정 가능).
    final camsMigrated = prefs.getBool(_keyCamNumberedNames) ?? false;
    if (!camsMigrated) {
      for (final s in sites) {
        s.applyNumberedCameraNames();
      }
      dirty = true;
      await prefs.setBool(_keyCamNumberedNames, true);
    }

    // 하우스별 제어를 앞에서부터 8개만 유지.
    final trimMigrated = prefs.getBool(_keyCtrlTrim8) ?? false;
    if (!trimMigrated) {
      for (final s in sites) {
        s.trimControlsToFirstEightPerDong();
      }
      dirty = true;
      await prefs.setBool(_keyCtrlTrim8, true);
    }

    // 하우스 → 제어기그룹 (`1하우스` → `1제어기`) 용어·데이터 마이그레이션.
    final groupMigrated = prefs.getBool(_keyControllerGroup) ?? false;
    if (!groupMigrated) {
      for (final s in sites) {
        s.applyControllerGroupLabelMigration();
      }
      dirty = true;
      await prefs.setBool(_keyControllerGroup, true);
    }

    if (dirty) {
      await saveSites(sites, activeId: await loadActiveId());
    }
    return sites;
  }

  Future<String?> loadActiveId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyActive);
  }

  Future<void> saveSites(List<FarmSite> sites, {String? activeId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keySites,
      jsonEncode(sites.map((e) => e.toJson()).toList()),
    );
    if (activeId != null) {
      await prefs.setString(_keyActive, activeId);
    } else {
      await prefs.remove(_keyActive);
    }
  }
}
