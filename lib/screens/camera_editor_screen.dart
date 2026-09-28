import 'package:flutter/material.dart';

import '../models/camera_source.dart';
import '../models/house_label.dart';
import '../widgets/camera_player.dart';

class CameraEditorScreen extends StatefulWidget {
  const CameraEditorScreen({
    super.key,
    required this.camera,
    this.dongOptions = const [],
  });

  final CameraSource camera;

  /// 사이트에 있는 제어기그룹 목록
  final List<String> dongOptions;

  @override
  State<CameraEditorScreen> createState() => _CameraEditorScreenState();
}

class _CameraEditorScreenState extends State<CameraEditorScreen> {
  late CameraSource _cam;
  late final TextEditingController _name;
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _httpPort;
  late final TextEditingController _user;
  late final TextEditingController _pass;
  late final TextEditingController _channel;
  late final TextEditingController _customUrl;
  late final TextEditingController _snapMs;
  late final TextEditingController _ptzCh;
  late final TextEditingController _nvrCamNo;
  late List<String> _dongChoices;
  bool _showPassword = false;
  bool _nvrMainStream = false;
  static const _customNameKey = '__custom__';
  late String _namePresetKey;
  CameraSource? _previewCam;
  int _previewGen = 0;

  @override
  void initState() {
    super.initState();
    _cam = widget.camera;
    _name = TextEditingController(text: _cam.name);
    _host = TextEditingController(text: _cam.host);
    _port = TextEditingController(text: '${_cam.port}');
    _httpPort = TextEditingController(text: '${_cam.httpPort}');
    _user = TextEditingController(text: _cam.username);
    _pass = TextEditingController(text: _cam.password);
    _channel = TextEditingController(text: '${_cam.channel}');
    _customUrl = TextEditingController(text: _cam.customUrl);
    _snapMs = TextEditingController(text: '${_cam.snapshotIntervalMs}');
    _ptzCh = TextEditingController(text: '${_cam.ptzChannel}');
    _nvrMainStream = CameraSource.nvrIsMainStream(_cam.channel);
    _nvrCamNo = TextEditingController(
      text: '${CameraSource.nvrCameraNo(_cam.channel)}',
    );
    _namePresetKey = CameraSource.namePresets.contains(_cam.name)
        ? _cam.name
        : _customNameKey;
    _dongChoices = _buildDongChoices();
    if (!_dongChoices.contains(_cam.dong) && _cam.dong.trim().isNotEmpty) {
      _dongChoices = [..._dongChoices, _cam.dong];
    }
    if (_cam.dong.trim().isEmpty || !_dongChoices.contains(_cam.dong)) {
      _cam.dong = _dongChoices.first;
    }
  }

  List<String> _buildDongChoices() {
    final seen = <String>{};
    final out = <String>[];
    void add(String d) {
      final t = normalizeHouseName(d.trim());
      if (t.isEmpty) return;
      if (seen.add(t)) out.add(t);
    }

    for (final d in widget.dongOptions) {
      add(d);
    }
    if (out.isEmpty) {
      add(kDefaultHouse);
    }
    return out;
  }

  @override
  void dispose() {
    _name.dispose();
    _host.dispose();
    _port.dispose();
    _httpPort.dispose();
    _user.dispose();
    _pass.dispose();
    _channel.dispose();
    _customUrl.dispose();
    _snapMs.dispose();
    _ptzCh.dispose();
    _nvrCamNo.dispose();
    super.dispose();
  }

  void _syncNvrChannel() {
    final n = int.tryParse(_nvrCamNo.text.trim()) ?? 1;
    _cam.channel = CameraSource.nvrChannel(n, mainStream: _nvrMainStream);
    _channel.text = '${_cam.channel}';
    _ptzCh.text = '$n';
    _cam.ptzChannel = n;
  }

  void _apply() {
    var name = _name.text.trim().isEmpty ? 'Camera' : _name.text.trim();
    _cam.name = name;
    _cam.host = _host.text.trim();
    _cam.port = int.tryParse(_port.text.trim()) ?? 554;
    _cam.httpPort = int.tryParse(_httpPort.text.trim()) ?? 80;
    _cam.username = _user.text;
    _cam.password = _pass.text;
    final defaultCh = _cam.isHanwha ? 2 : 102;
    _cam.channel = int.tryParse(_channel.text.trim()) ?? defaultCh;
    _cam.customUrl = _customUrl.text.trim();
    _cam.snapshotIntervalMs = int.tryParse(_snapMs.text.trim()) ?? 300;
    if (_cam.dong.trim().isEmpty || !_dongChoices.contains(_cam.dong)) {
      _cam.dong = _dongChoices.first;
    }
    _cam.ptzChannel =
        int.tryParse(_ptzCh.text.trim()) ?? (_cam.isHanwha ? 0 : 1);
  }

  void _startPreview() {
    _apply();
    if (_cam.playUrl.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('IP 또는 URL을 입력한 뒤 미리보기 하세요.')),
      );
      return;
    }
    setState(() {
      _previewCam = _cam.copy();
      _previewGen++;
    });
  }

  void _stopPreview() {
    setState(() => _previewCam = null);
  }

  String get _channelHelper {
    if (_cam.isHanwha) {
      return '한화 프로파일: 1=메인, 2=서브(모바일 권장)';
    }
    if (_cam.isHikvisionNvr) {
      return 'NVR: 카메라N ×100 +1=메인, +2=서브 (예: 3번 서브=302)';
    }
    return '하이크비전 채널: 102=서브, 101=메인';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('영상 소스 정의'),
        actions: [
          TextButton(
            onPressed: () {
              _stopPreview();
              _apply();
              Navigator.pop(context, _cam);
            },
            child: const Text('확인'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '한화(Wisenet)·하이크비전·Hik NVR 지원.\n'
            'NVR은 IP 하나에 채널(101/102, 201/202…)로 카메라를 구분합니다.',
            style: TextStyle(fontSize: 12, color: Colors.white54, height: 1.4),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey('campreset_$_namePresetKey'),
            initialValue: _namePresetKey,
            decoration: const InputDecoration(
              labelText: '기본 이름',
              helperText: '나중에 아래에서 원하는 이름으로 바꿀 수 있습니다',
            ),
            items: [
              ...CameraSource.namePresets.map(
                (n) => DropdownMenuItem(value: n, child: Text(n)),
              ),
              const DropdownMenuItem(
                value: _customNameKey,
                child: Text('(직접 입력)'),
              ),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                _namePresetKey = v;
                if (v != _customNameKey) _name.text = v;
              });
            },
          ),
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: '이름',
              hintText: '1번 카메라',
              helperText: '영상소스마다 원하는 이름으로 정의하세요',
            ),
            onChanged: (v) {
              final key = CameraSource.namePresets.contains(v)
                  ? v
                  : _customNameKey;
              if (key != _namePresetKey) {
                setState(() => _namePresetKey = key);
              }
            },
          ),
          DropdownButtonFormField<String>(
            key: ValueKey('dong_${_cam.dong}'),
            initialValue:
                _dongChoices.contains(_cam.dong) ? _cam.dong : _dongChoices.first,
            decoration: const InputDecoration(
              labelText: kControlGroupLabel,
              helperText: '사이트에 등록된 $kControlGroupLabel만 표시',
            ),
            items: [
              for (final d in _dongChoices)
                DropdownMenuItem(value: d, child: Text(d)),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() => _cam.dong = v);
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('PTZ 사용 (틸트/팬/줌)'),
            subtitle: Text(
              _cam.supportsPtzApi
                  ? 'PTZ 기종만 동작 · ${_cam.isHanwha ? "한화 CGI" : "하이크 ISAPI"}'
                  : '한화/하이크 타입에서만 PTZ API 사용',
            ),
            value: _cam.ptzEnabled,
            onChanged: _cam.supportsPtzApi
                ? (v) => setState(() => _cam.ptzEnabled = v)
                : null,
          ),
          if (_cam.ptzEnabled)
            TextField(
              controller: _ptzCh,
              decoration: InputDecoration(
                labelText: 'PTZ 채널',
                helperText: _cam.isHanwha
                    ? '한화 기본 0'
                    : _cam.isHikvisionNvr
                        ? 'NVR 카메라 번호와 동일(스트리밍 201 → PTZ 2)'
                        : '하이크비전 기본 1 (스트리밍 101 → PTZ 1)',
              ),
              keyboardType: TextInputType.number,
            ),
          const SizedBox(height: 12),
          DropdownButtonFormField<CameraStreamType>(
            key: ValueKey(_cam.type),
            initialValue: _cam.type,
            decoration: const InputDecoration(labelText: '스트림 타입'),
            items: const [
              DropdownMenuItem(
                value: CameraStreamType.hanwhaRtsp,
                child: Text('한화 RTSP (profile/media.smp)'),
              ),
              DropdownMenuItem(
                value: CameraStreamType.hanwhaSnapshot,
                child: Text('한화 HTTP 스냅샷 (80)'),
              ),
              DropdownMenuItem(
                value: CameraStreamType.hikvisionRtsp,
                child: Text('하이크비전 RTSP (단일 카메라)'),
              ),
              DropdownMenuItem(
                value: CameraStreamType.hikvisionNvrRtsp,
                child: Text('하이크비전 NVR RTSP (채널)'),
              ),
              DropdownMenuItem(
                value: CameraStreamType.hikvisionHttpPreview,
                child: Text('하이크비전 HTTP Preview'),
              ),
              DropdownMenuItem(
                value: CameraStreamType.hikvisionSnapshot,
                child: Text('하이크비전 HTTP 스냅샷'),
              ),
              DropdownMenuItem(
                value: CameraStreamType.customUrl,
                child: Text('사용자 URL'),
              ),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                _cam.type = v;
                if (v == CameraStreamType.hanwhaRtsp ||
                    v == CameraStreamType.hanwhaSnapshot) {
                  if (_cam.channel >= 100) {
                    _cam.channel = 2;
                    _channel.text = '2';
                  }
                } else if (v == CameraStreamType.hikvisionNvrRtsp) {
                  if (_cam.channel < 100) {
                    _cam.channel = 102;
                    _channel.text = '102';
                  }
                  _nvrMainStream = CameraSource.nvrIsMainStream(_cam.channel);
                  _nvrCamNo.text = '${CameraSource.nvrCameraNo(_cam.channel)}';
                } else if (v == CameraStreamType.hikvisionRtsp ||
                    v == CameraStreamType.hikvisionHttpPreview ||
                    v == CameraStreamType.hikvisionSnapshot) {
                  if (_cam.channel < 100) {
                    _cam.channel = 102;
                    _channel.text = '102';
                  }
                }
              });
            },
          ),
          if (_cam.type != CameraStreamType.customUrl) ...[
            TextField(
              controller: _host,
              decoration: InputDecoration(
                labelText:
                    _cam.isHikvisionNvr ? 'NVR IP / 도메인' : '카메라 IP / 도메인',
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
                  onPressed: () =>
                      setState(() => _showPassword = !_showPassword),
                  icon: Icon(
                    _showPassword ? Icons.visibility_off : Icons.visibility,
                  ),
                ),
              ),
              obscureText: !_showPassword,
            ),
            if (_cam.isHikvisionNvr) ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nvrCamNo,
                      decoration: const InputDecoration(
                        labelText: 'NVR 카메라 번호',
                        helperText: '1부터',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(_syncNvrChannel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<bool>(
                      key: ValueKey(_nvrMainStream),
                      initialValue: _nvrMainStream,
                      decoration: const InputDecoration(labelText: '스트림'),
                      items: const [
                        DropdownMenuItem(value: false, child: Text('서브(…02)')),
                        DropdownMenuItem(value: true, child: Text('메인(…01)')),
                      ],
                      onChanged: (main) {
                        if (main == null) return;
                        setState(() {
                          _nvrMainStream = main;
                          _syncNvrChannel();
                        });
                      },
                    ),
                  ),
                ],
              ),
            ],
            TextField(
              controller: _channel,
              decoration: InputDecoration(
                labelText: _cam.isHanwha
                    ? '프로파일 번호'
                    : _cam.isHikvisionNvr
                        ? '스트림 채널 (자동)'
                        : '채널',
                helperText: _channelHelper,
              ),
              keyboardType: TextInputType.number,
              readOnly: _cam.isHikvisionNvr,
            ),
            if (_cam.usesRtspPort) ...[
              TextField(
                controller: _port,
                decoration: const InputDecoration(
                  labelText: 'RTSP 포트',
                  helperText: '기본 554. 포트포워딩 시 외부 포트',
                ),
                keyboardType: TextInputType.number,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('RTSP TCP 전송'),
                subtitle: const Text('안드로이드에서 끊김 줄이기 (권장)'),
                value: _cam.useTcp,
                onChanged: (v) => setState(() => _cam.useTcp = v),
              ),
            ],
            if (_cam.usesHttpPort)
              TextField(
                controller: _httpPort,
                decoration: const InputDecoration(
                  labelText: 'HTTP(웹) 포트',
                  helperText: '기본 80',
                ),
                keyboardType: TextInputType.number,
              ),
            if (_cam.isSnapshotType)
              TextField(
                controller: _snapMs,
                decoration: const InputDecoration(
                  labelText: '스냅샷 간격(ms)',
                  helperText: '300≈초당 3장',
                ),
                keyboardType: TextInputType.number,
              ),
          ] else
            TextField(
              controller: _customUrl,
              decoration: const InputDecoration(
                labelText: '전체 URL',
                hintText: 'rtsp://user:pass@ip:554/profile2/media.smp',
              ),
              maxLines: 2,
            ),
          const SizedBox(height: 16),
          const Divider(),
          Row(
            children: [
              Text('미리보기', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              if (_previewCam != null)
                TextButton(
                  onPressed: _stopPreview,
                  child: const Text('중지'),
                ),
              FilledButton.tonalIcon(
                onPressed: _startPreview,
                icon: const Icon(Icons.videocam, size: 18),
                label: Text(_previewCam == null ? '미리보기' : '다시 연결'),
              ),
            ],
          ),
          const Text(
            'IP·계정·채널을 입력한 뒤 미리보기로 연결을 확인하세요.',
            style: TextStyle(fontSize: 12, color: Colors.white54),
          ),
          const SizedBox(height: 8),
          Builder(
            builder: (_) {
              _apply();
              return Text(
                _cam.safePlayUrl.isEmpty
                    ? 'URL: (입력 대기)'
                    : 'URL: ${_cam.safePlayUrl}',
                style: const TextStyle(fontSize: 11, color: Colors.white38),
              );
            },
          ),
          const SizedBox(height: 10),
          if (_previewCam == null)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF0B1220),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: const Center(
                  child: Text(
                    '미리보기 버튼을 누르면\n영상이 여기에 표시됩니다',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ),
              ),
            )
          else
            CameraPlayer(
              key: ValueKey('preview_$_previewGen'),
              camera: _previewCam!,
              showExpand: false,
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
