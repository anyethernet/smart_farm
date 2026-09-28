import 'dart:convert';

import '../models/farm_site.dart';

/// 앱 설정(사이트 목록) JSON 백업/복원.
class SettingsBackup {
  static const formatId = 'smart_farm_backup';
  static const formatVersion = 1;

  /// 들여쓰기 JSON 문자열.
  static String encode({
    required List<FarmSite> sites,
    String? activeId,
  }) {
    final map = <String, dynamic>{
      'format': formatId,
      'version': formatVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'activeId': activeId,
      'sites': sites.map((e) => e.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  /// 백업 객체 또는 사이트 배열 / 단일 사이트 JSON 파싱.
  static SettingsBackupData decode(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('빈 파일입니다.');
    }
    final decoded = jsonDecode(trimmed);
    if (decoded is List) {
      final sites = decoded
          .map((e) => FarmSite.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
      if (sites.isEmpty) {
        throw const FormatException('사이트 목록이 비어 있습니다.');
      }
      return SettingsBackupData(sites: sites);
    }
    if (decoded is! Map) {
      throw const FormatException('JSON 형식이 올바르지 않습니다.');
    }
    final map = decoded.cast<String, dynamic>();

    if (map['sites'] is List) {
      final list = map['sites'] as List;
      final sites = list
          .map((e) => FarmSite.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
      if (sites.isEmpty) {
        throw const FormatException('사이트 목록이 비어 있습니다.');
      }
      final active = map['activeId']?.toString();
      return SettingsBackupData(sites: sites, activeId: active);
    }

    // 단일 FarmSite JSON
    if (map.containsKey('cameras') ||
        map.containsKey('controls') ||
        map.containsKey('esp32') ||
        map.containsKey('boards')) {
      final site = FarmSite.fromJson(map);
      return SettingsBackupData(sites: [site], activeId: site.id);
    }

    throw const FormatException(
      '스마트팜 백업 JSON이 아닙니다. (sites 배열 또는 format=smart_farm_backup)',
    );
  }
}

class SettingsBackupData {
  const SettingsBackupData({required this.sites, this.activeId});

  final List<FarmSite> sites;
  final String? activeId;
}
