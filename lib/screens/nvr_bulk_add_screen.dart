import 'package:flutter/material.dart';

import '../models/house_label.dart';

import '../models/camera_source.dart';

/// Hikvision NVR 채널 1..N 을 한 번에 카메라 목록으로 생성.
class NvrBulkAddScreen extends StatefulWidget {
  const NvrBulkAddScreen({super.key});

  @override
  State<NvrBulkAddScreen> createState() => _NvrBulkAddScreenState();
}

class _NvrBulkAddScreenState extends State<NvrBulkAddScreen> {
  final _host = TextEditingController();
  final _user = TextEditingController(text: 'admin');
  final _pass = TextEditingController();
  final _count = TextEditingController(text: '8');
  final _prefix = TextEditingController();
  final _dong = TextEditingController(text: kDefaultHouse);
  final _port = TextEditingController(text: '554');
  bool _mainStream = false;
  bool _useTcp = true;
  bool _showPassword = false;

  @override
  void dispose() {
    _host.dispose();
    _user.dispose();
    _pass.dispose();
    _count.dispose();
    _prefix.dispose();
    _dong.dispose();
    _port.dispose();
    super.dispose();
  }

  void _submit() {
    final host = _host.text.trim();
    if (host.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('NVR IP / 도메인을 입력하세요.')),
      );
      return;
    }
    final count = int.tryParse(_count.text.trim()) ?? 0;
    if (count < 1 || count > 64) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('채널 수는 1~64 로 입력하세요.')),
      );
      return;
    }
    final list = CameraSource.buildNvrChannels(
      host: host,
      username: _user.text,
      password: _pass.text,
      channelCount: count,
      mainStream: _mainStream,
      namePrefix: _prefix.text.trim().isEmpty ? 'NVR' : _prefix.text.trim(),
      dong: _dong.text.trim().isEmpty ? kDefaultHouse : _dong.text.trim(),
      rtspPort: int.tryParse(_port.text.trim()) ?? 554,
      useTcp: _useTcp,
    );
    Navigator.pop(context, list);
  }

  @override
  Widget build(BuildContext context) {
    final previewCount = (int.tryParse(_count.text.trim()) ?? 0).clamp(0, 64);
    final sampleCh = previewCount > 0
        ? CameraSource.nvrChannel(1, mainStream: _mainStream)
        : 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hik NVR 채널 일괄 추가'),
        actions: [
          TextButton(onPressed: _submit, child: const Text('추가')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'NVR IP·계정·채널 수를 입력하면 1번·2번… 카메라로 등록됩니다.\n'
            '스트림 채널: 1번 서브=102, 2번 서브=202, 메인=101/201…\n'
            '추가 후 영상소스 정의에서 이름을 원하는 대로 바꿀 수 있습니다.',
            style: TextStyle(fontSize: 12, color: Colors.white54, height: 1.4),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _host,
            decoration: const InputDecoration(
              labelText: 'NVR IP / 도메인',
              hintText: '192.168.1.100',
            ),
          ),
          TextField(
            controller: _user,
            decoration: const InputDecoration(labelText: 'ID'),
          ),
          TextField(
            controller: _pass,
            decoration: InputDecoration(
              labelText: '비밀번호',
              suffixIcon: IconButton(
                tooltip: _showPassword ? '숨기기' : '보기',
                onPressed: () => setState(() => _showPassword = !_showPassword),
                icon: Icon(
                  _showPassword ? Icons.visibility_off : Icons.visibility,
                ),
              ),
            ),
            obscureText: !_showPassword,
          ),
          TextField(
            controller: _count,
            decoration: const InputDecoration(
              labelText: '채널(카메라) 수',
              helperText: '1~64',
            ),
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
          ),
          TextField(
            controller: _prefix,
            decoration: const InputDecoration(
              labelText: '이름 접두어 (선택)',
              helperText: '비우면 1번 카메라, 2번 카메라… / 입력 시 "접두어 1번 카메라"',
            ),
          ),
          TextField(
            controller: _dong,
            decoration: const InputDecoration(
              labelText: '기본 $kControlGroupLabel',
              hintText: kDefaultHouse,
            ),
          ),
          TextField(
            controller: _port,
            decoration: const InputDecoration(
              labelText: 'RTSP 포트',
              helperText: '기본 554',
            ),
            keyboardType: TextInputType.number,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('메인 스트림 사용'),
            subtitle: Text(
              _mainStream ? '메인(…01) — 고화질, 대역폭 큼' : '서브(…02) — 모바일·원격 권장',
            ),
            value: _mainStream,
            onChanged: (v) => setState(() => _mainStream = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('RTSP TCP 전송'),
            subtitle: const Text('안드로이드에서 끊김 줄이기 (권장)'),
            value: _useTcp,
            onChanged: (v) => setState(() => _useTcp = v),
          ),
          const SizedBox(height: 12),
          if (previewCount > 0)
            Text(
              '미리보기: $previewCount대 · '
              'ch1 → Streaming/Channels/$sampleCh'
              '${previewCount > 1 ? " · ch$previewCount → "
                  "${CameraSource.nvrChannel(previewCount, mainStream: _mainStream)}" : ""}',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
        ],
      ),
    );
  }
}
