import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_info.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  Future<void> _openPrivacyUrl(BuildContext context) async {
    final uri = Uri.parse(AppInfo.privacyPolicyUrl);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('방침 페이지를 열 수 없습니다')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('앱 정보 · 개인정보')),
      body: FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snap) {
          final version = snap.data == null
              ? ''
              : '${snap.data!.version} (${snap.data!.buildNumber})';
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              Text(
                AppInfo.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                AppInfo.subtitle,
                style: const TextStyle(color: Color(0xFF7DD3FC), fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                [
                  if (version.isNotEmpty) '버전 $version',
                  AppInfo.credit,
                ].join('  ·  '),
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),
              const SizedBox(height: 20),
              const Text(
                '이용자가 등록한 IP카메라·제어보드·센서에만 연결합니다. '
                '영상과 제어 명령은 개발자 서버를 거치지 않으며, '
                '하이크비전·한화비전 등 제조사 공식 앱이 아닙니다.',
                style: TextStyle(height: 1.55, fontSize: 13),
              ),
              const SizedBox(height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.open_in_new, color: Color(0xFF38BDF8)),
                title: const Text('웹에서 개인정보처리방침 보기'),
                subtitle: Text(
                  AppInfo.privacyPolicyUrl,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
                onTap: () => _openPrivacyUrl(context),
              ),
              const Divider(height: 32),
              const Text(
                '개인정보처리방침',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: Color(0xFF7DD3FC),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                AppInfo.privacyPolicy,
                style: TextStyle(height: 1.55, fontSize: 13),
              ),
            ],
          );
        },
      ),
    );
  }
}
