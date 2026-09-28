import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/farm_site.dart';
import '../state/farm_controller.dart';
import 'legal_screen.dart';
import 'site_editor_screen.dart';

class SitesScreen extends StatelessWidget {
  const SitesScreen({super.key});

  Future<void> _exportSettings(BuildContext context, FarmController ctrl) async {
    try {
      final json = ctrl.exportSettingsJson();
      final stamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '')
          .replaceAll('-', '')
          .split('.')
          .first;
      final name = 'smart_farm_backup_$stamp.json';
      final bytes = utf8.encode(json);
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              Uint8List.fromList(bytes),
              mimeType: 'application/json',
              name: name,
            ),
          ],
          fileNameOverrides: [name],
          subject: '스마트팜 설정 백업',
          text: '스마트팜 사이트 설정 ($name)',
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('내보내기 실패: $e')),
      );
    }
  }

  Future<void> _importSettings(BuildContext context, FarmController ctrl) async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return;

      final file = picked.files.first;
      String? raw;
      if (file.bytes != null && file.bytes!.isNotEmpty) {
        raw = utf8.decode(file.bytes!);
      } else if (file.path != null) {
        raw = await XFile(file.path!).readAsString();
      }
      if (raw == null || raw.trim().isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('파일을 읽을 수 없습니다')),
          );
        }
        return;
      }

      if (!context.mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('설정 가져오기'),
          content: Text(
            '선택한 파일(${file.name})의 사이트로 현재 앱 설정을 모두 바꿉니다.\n'
            '기존 사이트·보드·카메라·제어는 덮어씁니다. 계속할까요?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('가져오기'),
            ),
          ],
        ),
      );
      if (ok != true) return;

      final n = await ctrl.importSettingsJson(raw);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('가져오기 완료 — 사이트 $n개')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('가져오기 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<FarmController>();

    return Scaffold(
      appBar: AppBar(title: const Text('사이트 / 연결 설정')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final site = FarmSite(name: '새 스마트팜');
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => SiteEditorScreen(site: site)),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('사이트 추가'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.upload_file_outlined),
                  title: const Text('설정 내보내기 (JSON 공유)'),
                  subtitle: const Text('사이트·보드·카메라·제어·센서를 JSON으로 공유'),
                  onTap: () => _exportSettings(context, ctrl),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.download_outlined),
                  title: const Text('설정 가져오기'),
                  subtitle: const Text('백업 JSON 파일로 전체 설정 복원'),
                  onTap: () => _importSettings(context, ctrl),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (ctrl.sites.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 20, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '등록된 농장이 없습니다',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '아래 ‘사이트 추가’로 농장을 만든 뒤, 제어보드·카메라·센서 주소를 입력하세요. '
                      '같은 네트워크의 장비에만 연결되며 개발자 서버로 영상이 올라가지 않습니다.',
                      style: TextStyle(color: Color(0xFF94A3B8), height: 1.45),
                    ),
                  ],
                ),
              ),
            ),
          ...List.generate(ctrl.sites.length, (i) {
            final s = ctrl.sites[i];
            final selected = s.id == ctrl.activeId;
            return Card(
              color: Color(s.bgColor).withValues(alpha: 0.55),
              child: ListTile(
                selected: selected,
                leading: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Color(s.bgColor),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF94A3B8)),
                  ),
                  child: Icon(
                    selected ? Icons.check : Icons.circle,
                    size: 16,
                    color: selected ? Colors.tealAccent : Colors.transparent,
                  ),
                ),
                title: Text(s.name),
                subtitle: Text(
                  '보드 ${s.enabledBoards.length} · ${s.esp32.displayHost}\n'
                  '카메라 ${s.cameras.length} · 제어 ${s.controls.length}',
                ),
                isThreeLine: true,
                onTap: () async {
                  await ctrl.selectSite(s.id);
                  if (context.mounted) Navigator.pop(context);
                },
                trailing: IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SiteEditorScreen(site: s.copy()),
                      ),
                    );
                  },
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('앱 정보 · 개인정보처리방침'),
              subtitle: const Text('데이터 처리 방식과 개발자 표기'),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LegalScreen()),
                );
              },
            ),
          ),
          const SizedBox(height: 88),
        ],
      ),
    );
  }
}
