import 'package:flutter/material.dart';

import '../models/camera_source.dart';
import '../models/control_element.dart';
import '../models/esp32_board.dart';
import '../models/house_label.dart';

class ControlEditorScreen extends StatefulWidget {
  const ControlEditorScreen({
    super.key,
    required this.element,
    this.cameras = const [],
    this.boards = const [],
    this.dongOptions = const [],
  });

  final ControlElement element;
  final List<CameraSource> cameras;
  final List<Esp32Board> boards;

  /// 사이트에 있는 제어기그룹 목록
  final List<String> dongOptions;

  @override
  State<ControlEditorScreen> createState() => _ControlEditorScreenState();
}

class _ControlEditorScreenState extends State<ControlEditorScreen> {
  late ControlElement _el;
  late final TextEditingController _name;
  late final TextEditingController _pin;
  late final TextEditingController _up;
  late final TextEditingController _down;
  late final TextEditingController _stop;
  late List<String> _dongChoices;

  /// null = DEFAULT(핀/쌍 번호), 그 외 프리셋 또는 직접입력 마커.
  static const _customKey = '__custom__';
  static const _defaultKey = '__default__';
  late String _namePresetKey;

  @override
  void initState() {
    super.initState();
    _el = widget.element;
    _name = TextEditingController(text: _el.name);
    _pin = TextEditingController(text: '${_el.pinIndex + 1}');
    _up = TextEditingController(text: _el.upLabel);
    _down = TextEditingController(text: _el.downLabel);
    _stop = TextEditingController(text: _el.stopLabel);
    _dongChoices = _buildDongChoices();
    if (!_dongChoices.contains(_el.dong) && _el.dong.trim().isNotEmpty) {
      _dongChoices = [..._dongChoices, _el.dong];
    }
    if (_el.dong.trim().isEmpty || !_dongChoices.contains(_el.dong)) {
      _el.dong = _dongChoices.first;
    }
    if (_el.boardId == null && widget.boards.isNotEmpty) {
      final sameDong = widget.boards.where((b) => b.dong == _el.dong);
      _el.boardId =
          (sameDong.isNotEmpty ? sameDong.first : widget.boards.first).id;
    }
    _namePresetKey = _resolvePresetKey(_el.name);
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

  String _resolvePresetKey(String name) {
    if (ControlElement.isDefaultChannelName(name)) return _defaultKey;
    if (ControlElement.presetNames.contains(name)) return name;
    return _customKey;
  }

  String _defaultNameForCurrent() {
    if (_el.kind == ControlKind.motorPair) {
      return ControlElement.defaultPairName(_el.pairIndex);
    }
    return ControlElement.defaultPinName(_el.pinIndex);
  }

  void _applyDefaultNameIfNeeded({bool force = false}) {
    if (!force && _namePresetKey != _defaultKey) return;
    final next = _defaultNameForCurrent();
    if (_name.text != next) {
      _name.text = next;
    }
    _namePresetKey = _defaultKey;
  }

  void _onPresetChanged(String? key) {
    if (key == null) return;
    setState(() {
      _namePresetKey = key;
      if (key == _defaultKey) {
        _name.text = _defaultNameForCurrent();
      } else if (key != _customKey) {
        _name.text = key;
        final jung = ControlElement.jungForPreset(key);
        if (jung != null) _el.jung = jung;
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _pin.dispose();
    _up.dispose();
    _down.dispose();
    _stop.dispose();
    super.dispose();
  }

  void _apply() {
    _el.name = _name.text.trim().isEmpty
        ? _defaultNameForCurrent()
        : _name.text.trim();
    if (_el.dong.trim().isEmpty || !_dongChoices.contains(_el.dong)) {
      _el.dong = _dongChoices.first;
    }
    final pinHuman = int.tryParse(_pin.text.trim()) ?? 1;
    _el.pairIndex = _el.pairIndex.clamp(0, 7);
    _el.pinIndex = (pinHuman - 1).clamp(0, 15);
    _el.upLabel = _up.text.trim().isEmpty ? 'UP' : _up.text.trim();
    _el.downLabel = _down.text.trim().isEmpty ? 'DOWN' : _down.text.trim();
    _el.stopLabel = _stop.text.trim().isEmpty ? 'STOP' : _stop.text.trim();
  }

  @override
  Widget build(BuildContext context) {
    final boardIds = widget.boards.map((b) => b.id).toSet();
    final boardId = (_el.boardId != null && boardIds.contains(_el.boardId))
        ? _el.boardId
        : null;
    final defaultLabel = _defaultNameForCurrent();
    final dongValue =
        _dongChoices.contains(_el.dong) ? _el.dong : _dongChoices.first;

    return Scaffold(
      appBar: AppBar(
        title: const Text('제어 요소 정의'),
        actions: [
          TextButton(
            onPressed: () {
              _apply();
              Navigator.pop(context, _el);
            },
            child: const Text('확인'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            key: ValueKey('preset_$_namePresetKey'),
            initialValue: _namePresetKey,
            decoration: const InputDecoration(
              labelText: '기본 이름',
              helperText: 'DEFAULT는 채널 쌍/핀 번호로 표시',
            ),
            items: [
              DropdownMenuItem(
                value: _defaultKey,
                child: Text('DEFAULT · $defaultLabel'),
              ),
              ...ControlElement.presetNames.map(
                (n) => DropdownMenuItem(value: n, child: Text(n)),
              ),
              const DropdownMenuItem(
                value: _customKey,
                child: Text('(직접 입력)'),
              ),
            ],
            onChanged: _onPresetChanged,
          ),
          TextField(
            controller: _name,
            decoration: InputDecoration(
              labelText: '표시 이름',
              hintText: defaultLabel,
              helperText: _namePresetKey == _defaultKey
                  ? '쌍/핀을 바꾸면 DEFAULT 이름도 함께 갱신됩니다'
                  : null,
            ),
            onChanged: (v) {
              final key = _resolvePresetKey(v);
              if (key != _namePresetKey) {
                setState(() => _namePresetKey = key);
              }
            },
          ),
          DropdownButtonFormField<String>(
            key: ValueKey('dong_$dongValue'),
            initialValue: dongValue,
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
              setState(() {
                _el.dong = v;
                // 하우스 바꾸면 같은 하우스 보드로 맞춤
                final same = widget.boards.where((b) => b.dong == v);
                if (same.isNotEmpty) {
                  _el.boardId = same.first.id;
                }
              });
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ControlKind>(
            key: ValueKey(_el.kind),
            initialValue: _el.kind,
            decoration: const InputDecoration(
              labelText: '제어 타입',
              helperText: '채널 쌍 = UP/DOWN/STOP · 단일 핀 = ON/OFF',
            ),
            items: const [
              DropdownMenuItem(
                value: ControlKind.motorPair,
                child: Text('채널 쌍 (UP / DOWN / 정지)'),
              ),
              DropdownMenuItem(
                value: ControlKind.relayToggle,
                child: Text('단일 핀 ON/OFF'),
              ),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                final wasPair = _el.kind == ControlKind.motorPair;
                _el.kind = v;
                if (wasPair && v == ControlKind.relayToggle) {
                  // 쌍의 첫 채널(chA)로 핀 맞춤. 둘째 채널은 저장 시 추가.
                  _el.pinIndex = _el.pairPinA;
                  _pin.text = '${_el.pinIndex + 1}';
                } else if (!wasPair && v == ControlKind.motorPair) {
                  // ON/OFF 핀 → UP/DOWN 쌍. 짝 핀은 저장 시 삭제.
                  _el.pairIndex =
                      ControlElement.pairIndexFromPin(_el.pinIndex);
                }
                _applyDefaultNameIfNeeded(force: true);
              });
            },
          ),
          if (_el.kind == ControlKind.relayToggle &&
              widget.element.kind == ControlKind.motorPair)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                '저장 시 이 쌍의 두 채널(chA·chB)이 각각 ON/OFF 제어로 등록됩니다.',
                style: TextStyle(fontSize: 12, color: Color(0xFF7DD3FC)),
              ),
            ),
          if (_el.kind == ControlKind.motorPair &&
              widget.element.kind == ControlKind.relayToggle)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '저장 시 UP/DOWN 쌍${_el.pairIndex + 1}'
                '(ch${_el.pairPinA + 1}–ch${_el.pairPinB + 1})로 합쳐지고, '
                '짝 ON/OFF 핀은 목록에서 제거됩니다.',
                style: const TextStyle(fontSize: 12, color: Color(0xFF7DD3FC)),
              ),
            ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            key: ValueKey(boardId ?? 'noboard'),
            initialValue: boardId,
            decoration: const InputDecoration(
              labelText: 'ESP32 보드',
              helperText: '한 $kControlGroupLabel에 TV16/TV8 여러 대일 때 이 제어가 속한 보드',
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('($kControlGroupLabel의 첫 보드)'),
              ),
              ...widget.boards.map(
                (b) => DropdownMenuItem<String?>(
                  value: b.id,
                  child: Text('${b.name} · ${b.dong} · ${b.displayHost}'),
                ),
              ),
            ],
            onChanged: (v) => setState(() => _el.boardId = v),
          ),
          const SizedBox(height: 12),
          Builder(
            builder: (context) {
              final ids = widget.cameras.map((c) => c.id).toSet();
              final camId = (_el.cameraId != null && ids.contains(_el.cameraId))
                  ? _el.cameraId
                  : null;
              return DropdownButtonFormField<String?>(
                key: ValueKey(camId ?? 'none'),
                initialValue: camId,
                decoration: const InputDecoration(
                  labelText: '연결 영상',
                  helperText:
                      '이 제어를 선택할 때 표시할 카메라 (이름은 영상소스 정의에서 설정)',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('(같은 $kControlGroupLabel 대표 카메라)'),
                  ),
                  ...widget.cameras.map(
                    (c) => DropdownMenuItem<String?>(
                      value: c.id,
                      child: Text('${c.dong} · ${c.name}'),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _el.cameraId = v),
              );
            },
          ),
          if (_el.kind == ControlKind.motorPair) ...[
            DropdownButtonFormField<int>(
              key: ValueKey('pair_${_el.pairIndex}'),
              initialValue: _el.pairIndex.clamp(0, 7),
              decoration: const InputDecoration(
                labelText: '이 보드의 채널 쌍 번호',
                helperText: 'TV8BD: 1–4 · TV16AVR: 1–8',
              ),
              items: [
                for (var i = 0; i < 8; i++)
                  DropdownMenuItem<int>(
                    value: i,
                    child: Text(ControlElement.defaultPairName(i)),
                  ),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _el.pairIndex = v;
                  _applyDefaultNameIfNeeded();
                });
              },
            ),
            TextField(
              controller: _up,
              decoration: const InputDecoration(labelText: 'UP 버튼 라벨'),
            ),
            TextField(
              controller: _down,
              decoration: const InputDecoration(labelText: 'DOWN 버튼 라벨'),
            ),
            TextField(
              controller: _stop,
              decoration: const InputDecoration(labelText: 'STOP 버튼 라벨'),
            ),
          ] else
            TextField(
              controller: _pin,
              decoration: const InputDecoration(
                labelText: '이 보드의 채널(핀) 번호 (1부터)',
                helperText: 'TV8BD: 1–8 · TV16AVR: 1–16',
              ),
              keyboardType: TextInputType.number,
              onChanged: (_) {
                final pinHuman = int.tryParse(_pin.text.trim()) ?? 1;
                _el.pinIndex = (pinHuman - 1).clamp(0, 15);
                if (_namePresetKey == _defaultKey) {
                  setState(() => _applyDefaultNameIfNeeded(force: true));
                }
              },
            ),
        ],
      ),
    );
  }
}
