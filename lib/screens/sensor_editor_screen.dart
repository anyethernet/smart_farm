import 'package:flutter/material.dart';

import '../models/house_label.dart';
import '../models/sensor_endpoint.dart';

class SensorEditorScreen extends StatefulWidget {
  const SensorEditorScreen({
    super.key,
    required this.sensor,
    this.dongOptions = kDefaultHouses,
  });

  final SensorEndpoint sensor;

  /// 사이트에 있는 제어기그룹 목록 (제어·카메라 기준)
  final List<String> dongOptions;

  @override
  State<SensorEditorScreen> createState() => _SensorEditorScreenState();
}

class _SensorEditorScreenState extends State<SensorEditorScreen> {
  late SensorEndpoint _s;
  late final TextEditingController _name;
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _loginId;
  late final TextEditingController _loginPw;
  late List<String> _dongChoices;
  late List<TextEditingController> _labelCtrls;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    _s = widget.sensor;
    // 이전 버전에서 저장된 표시 배열이 짧아도 CH13까지 체크 가능하도록 복구.
    _s.setModel(_s.model);
    _name = TextEditingController(text: _s.name);
    _host = TextEditingController(text: _s.host);
    _port = TextEditingController(text: '${_s.port}');
    _loginId = TextEditingController(text: _s.loginId);
    _loginPw = TextEditingController(text: _s.loginPw);
    _labelCtrls = _makeLabelCtrls();
    _dongChoices = _buildDongChoices();
    if (!_dongChoices.contains(_s.dong) && _s.dong.trim().isNotEmpty) {
      _dongChoices = [..._dongChoices, _s.dong];
    }
    if (_s.dong.trim().isEmpty || !_dongChoices.contains(_s.dong)) {
      _s.dong = _dongChoices.first;
    }
  }

  List<TextEditingController> _makeLabelCtrls() {
    return [
      for (var i = 0; i < _s.channelCount; i++)
        TextEditingController(text: _s.editableLabel(i)),
    ];
  }

  void _disposeLabelCtrls() {
    for (final c in _labelCtrls) {
      c.dispose();
    }
  }

  void _reloadLabelCtrls() {
    _disposeLabelCtrls();
    _labelCtrls = _makeLabelCtrls();
  }

  List<String> _buildDongChoices() {
    final seen = <String>{};
    final out = <String>[];
    void add(String d) {
      final t = d.trim();
      if (t.isEmpty) return;
      if (seen.add(t)) out.add(t);
    }

    for (final d in kDefaultHouses) {
      add(d);
    }
    for (final d in widget.dongOptions) {
      add(d);
    }
    return out;
  }

  @override
  void dispose() {
    _name.dispose();
    _host.dispose();
    _port.dispose();
    _loginId.dispose();
    _loginPw.dispose();
    _disposeLabelCtrls();
    super.dispose();
  }

  void _applyLabelsFromCtrls() {
    final defaults = _s.defaultLabels();
    for (var i = 0; i < _s.channelCount; i++) {
      final t = i < _labelCtrls.length ? _labelCtrls[i].text.trim() : '';
      final def = i < defaults.length ? defaults[i] : 'CH$i';
      if (t.isEmpty || t == def) {
        _s.channelLabels[i] = '';
      } else {
        _s.channelLabels[i] = t;
      }
    }
  }

  void _apply() {
    _s.name = _name.text.trim().isEmpty ? '센서' : _name.text.trim();
    if (_s.dong.trim().isEmpty) _s.dong = _dongChoices.first;
    _s.host = _host.text.trim();
    _s.port = int.tryParse(_port.text.trim()) ?? 8080;
    _s.loginId = _loginId.text;
    _s.loginPw = _loginPw.text;
    _applyLabelsFromCtrls();
  }

  void _setAllChannels(bool on) {
    setState(() {
      for (var i = 0; i < _s.channelVisible.length; i++) {
        _s.channelVisible[i] = on;
      }
      if (_s.model == SensorModel.mcuEsp32) {
        _s.windVisible = on;
      }
    });
  }

  void _resetLabelsAndOrder() {
    setState(() {
      _applyLabelsFromCtrls();
      for (var i = 0; i < _s.channelLabels.length; i++) {
        _s.channelLabels[i] = '';
      }
      _s.channelOrder = [for (var i = 0; i < _s.channelCount; i++) i];
      _reloadLabelCtrls();
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      final item = _s.channelOrder.removeAt(oldIndex);
      _s.channelOrder.insert(newIndex, item);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('센서(Analog) 정의'),
        actions: [
          TextButton(
            onPressed: () {
              _apply();
              Navigator.pop(context, _s);
            },
            child: const Text('확인'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            const Text(
              '보드 종류를 고르면 해당 API에서 아날로그 값을 읽습니다.\n'
              'MCU ESP32 = GET /api/mcp3208 (응답 채널 수 그대로)\n'
              'MCU PICO = GET /data (Calibration 14채널)\n'
              '$kControlGroupLabel을 고르면 홈에서 해당 $kControlGroupLabel 선택 시 이 센서가 표시됩니다.',
              style:
                  TextStyle(fontSize: 12, color: Colors.white54, height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: '이름'),
            ),
            DropdownButtonFormField<String>(
              key: ValueKey('dong_${_s.dong}_${_dongChoices.join()}'),
              initialValue:
                  _dongChoices.contains(_s.dong) ? _s.dong : _dongChoices.first,
              decoration: const InputDecoration(
                labelText: kControlGroupLabel,
                helperText: '홈 화면 구역과 같은 $kControlGroupLabel의 센서만 표시',
              ),
              items: [
                for (final d in _dongChoices)
                  DropdownMenuItem(value: d, child: Text(d)),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => _s.dong = v);
              },
            ),
            DropdownButtonFormField<SensorModel>(
              key: ValueKey(_s.model),
              initialValue: _s.model,
              decoration: const InputDecoration(labelText: '모델'),
              items: const [
                DropdownMenuItem(
                  value: SensorModel.mcuEsp32,
                  child: Text('MCU ESP32'),
                ),
                DropdownMenuItem(
                  value: SensorModel.mcuPico,
                  child: Text('MCU PICO'),
                ),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _applyLabelsFromCtrls();
                  _s.setModel(v);
                  _reloadLabelCtrls();
                });
              },
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Text(
                '${_s.modelSummary} · ${_s.apiPathHint}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF7DD3FC)),
              ),
            ),
            TextField(
              controller: _host,
              decoration: InputDecoration(
                labelText: '센서 IP',
                hintText: _s.model == SensorModel.mcuPico
                    ? '192.168.1.144'
                    : '192.168.1.110',
              ),
            ),
            TextField(
              controller: _port,
              decoration: const InputDecoration(
                labelText: '웹 포트',
                helperText: '기본 8080',
              ),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _loginId,
              decoration: InputDecoration(
                labelText: 'ID',
                helperText: _s.model == SensorModel.mcuPico
                    ? 'Calibration 페이지 로그인 (데이터 API는 로그인 불필요)'
                    : '/api/mcp3208 은 로그인 불필요 (저장용)',
              ),
            ),
            TextField(
              controller: _loginPw,
              decoration: InputDecoration(
                labelText: '비밀번호',
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _showPassword = !_showPassword),
                  icon: Icon(
                    _showPassword ? Icons.visibility_off : Icons.visibility,
                  ),
                ),
              ),
              obscureText: !_showPassword,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('사용'),
              value: _s.enabled,
              onChanged: (v) => setState(() => _s.enabled = v),
            ),
            const Divider(height: 28),
            Row(
              children: [
                Text(
                  '표시 채널',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                TextButton(
                  onPressed: _resetLabelsAndOrder,
                  child: const Text('이름·순서 초기화'),
                ),
                TextButton(
                  onPressed: () => _setAllChannels(true),
                  child: const Text('전체'),
                ),
                TextButton(
                  onPressed: () => _setAllChannels(false),
                  child: const Text('없음'),
                ),
              ],
            ),
            Text(
              _s.model == SensorModel.mcuPico
                  ? '드래그로 순서 변경 · 이름 수정 · 체크로 표시 여부. setconfig5 14채널.'
                  : '드래그로 순서 변경 · 이름 수정 · 체크. ADC(최대 8) + 풍속카운터.',
              style: const TextStyle(fontSize: 12, color: Colors.white54),
            ),
            const SizedBox(height: 8),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: _s.channelOrder.length,
              onReorderItem: _onReorder,
              itemBuilder: (context, pos) {
                final ch = _s.channelOrder[pos];
                final ctrl = ch < _labelCtrls.length
                    ? _labelCtrls[ch]
                    : TextEditingController(text: 'CH$ch');
                return Material(
                  key: ValueKey('ch_$ch'),
                  color: Colors.transparent,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        ReorderableDragStartListener(
                          index: pos,
                          child: const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(Icons.drag_handle, color: Colors.white54),
                          ),
                        ),
                        Checkbox(
                          value: _s.isChannelVisible(ch),
                          onChanged: (v) {
                            setState(() {
                              if (ch < _s.channelVisible.length) {
                                _s.channelVisible[ch] = v ?? false;
                              }
                            });
                          },
                        ),
                        SizedBox(
                          width: 44,
                          child: Text(
                            'CH$ch',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white54,
                            ),
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: ctrl,
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: _s.defaultLabels().length > ch
                                  ? _s.defaultLabels()[ch]
                                  : '이름',
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            if (_s.model == SensorModel.mcuEsp32)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('풍속카운터 (PPS)'),
                subtitle: const Text('응답에 wind/여분 eng가 있을 때만 표시 (맨 뒤)'),
                value: _s.windVisible,
                onChanged: (v) => setState(() => _s.windVisible = v ?? false),
              ),
          ],
        ),
      ),
    );
  }
}
