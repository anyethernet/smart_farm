import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/camera_source.dart';
import '../models/control_element.dart';
import '../models/farm_site.dart';
import '../state/farm_controller.dart';
import 'camera_editor_screen.dart';
import 'control_editor_screen.dart';
import 'nvr_bulk_add_screen.dart';
import 'sensor_editor_screen.dart';
import '../models/house_label.dart';
import '../models/sensor_endpoint.dart';

class SiteEditorScreen extends StatefulWidget {
  const SiteEditorScreen({super.key, required this.site});

  final FarmSite site;

  @override
  State<SiteEditorScreen> createState() => _SiteEditorScreenState();
}

class _SiteEditorScreenState extends State<SiteEditorScreen> {
  late FarmSite _site;
  late final TextEditingController _name;
  late final TextEditingController _notes;
  late Set<String> _expandedBoardIds;

  @override
  void initState() {
    super.initState();
    _site = widget.site;
    if (_site.boards.isEmpty) {
      _site.boards = [
        Esp32Board.fromEndpoint(_site.esp32, name: '보드1', dong: kDefaultHouse),
      ];
    }
    _expandedBoardIds = _site.boards.isEmpty
        ? {}
        : {_site.boards.first.id};
    _name = TextEditingController(text: _site.name);
    _notes = TextEditingController(text: _site.notes);
  }

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _syncFields() {
    _site.name = _name.text.trim().isEmpty ? '스마트팜' : _name.text.trim();
    _site.notes = _notes.text;
  }

  Future<void> _save() async {
    _syncFields();
    _site.pruneHouseDefaultCameras();
    await context.read<FarmController>().upsertSite(_site);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('저장됨')),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _addStandardDong() async {
    final controller = TextEditingController(
      text: _nextDongName(),
    );
    final dong = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('표준 제어기그룹 추가'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '제어기그룹 이름',
            hintText: '2제어기',
            helperText: '보드 + 제어 8개 + 카메라 3개',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              final t = controller.text.trim();
              Navigator.pop(ctx, t.isEmpty ? null : t);
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (dong == null || !mounted) return;
    final pack = FarmSite.buildStandardDong(
      dong,
      cameraNameStartIndex: _site.cameras.length + 1,
    );
    setState(() {
      _site.boards.addAll(pack.boards);
      _site.cameras.addAll(pack.cameras);
      _site.controls.addAll(pack.controls);
      if (pack.cameras.isNotEmpty) {
        _site.setHouseDefaultCamera(dong, pack.cameras.first.id);
      }
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$dong: 보드 ${pack.boards.length} · 제어 ${pack.controls.length} 추가',
          ),
        ),
      );
    }
  }

  Future<bool> _confirmDelete({
    required String title,
    required String message,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  String _nextDongName() {
    for (var i = 1; i <= 20; i++) {
      final name = '$i제어기';
      if (!_site.dongList.contains(name)) return name;
    }
    return '새제어기';
  }

  /// 보드 소속 하우스가 바뀌면 해당 보드에 연결된 제어의 하우스도 맞춤.
  int _syncControlsDongForBoard({
    required String boardId,
    required String oldDong,
    required String newDong,
  }) {
    if (oldDong == newDong) return 0;
    var n = 0;
    for (final c in _site.controls) {
      final linked = c.boardId == boardId ||
          (c.boardId == null &&
              c.dong == oldDong &&
              _site.boardForControl(c)?.id == boardId);
      if (!linked) continue;
      if (c.dong == newDong) continue;
      c.dong = newDong;
      n++;
    }
    return n;
  }

  /// 보드 소속 하우스 변경 시 관련 영상소스의 하우스·이름도 맞춤.
  int _syncCamerasDongForBoard({
    required String boardId,
    required String oldDong,
    required String newDong,
  }) {
    if (oldDong == newDong) return 0;

    final linkedCamIds = <String>{};
    for (final c in _site.controls) {
      final linked = c.boardId == boardId ||
          (c.boardId == null &&
              c.dong == oldDong &&
              _site.boardForControl(c)?.id == boardId);
      if (linked && c.cameraId != null) linkedCamIds.add(c.cameraId!);
    }

    final otherBoardOnOld =
        _site.boards.any((b) => b.id != boardId && b.dong == oldDong);

    var n = 0;
    for (final cam in _site.cameras) {
      final move = linkedCamIds.contains(cam.id) ||
          (!otherBoardOnOld && cam.dong == oldDong);
      if (!move) continue;
      var changed = false;
      if (cam.dong == oldDong) {
        cam.dong = newDong;
        changed = true;
      }
      if (cam.name.contains(oldDong)) {
        cam.name = cam.name.replaceAll(oldDong, newDong);
        changed = true;
      }
      if (changed) n++;
    }
    if (n > 0) _site.pruneHouseDefaultCameras();
    return n;
  }

  /// 보드 소속 하우스 변경 시 관련 센서의 하우스·이름도 맞춤.
  int _syncSensorsDongForBoard({
    required String boardId,
    required String oldDong,
    required String newDong,
  }) {
    if (oldDong == newDong) return 0;

    final otherBoardOnOld =
        _site.boards.any((b) => b.id != boardId && b.dong == oldDong);
    // 같은 하우스에 다른 보드가 남아 있으면 센서는 그 하우스에 둠
    if (otherBoardOnOld) return 0;

    var n = 0;
    for (final s in _site.sensors) {
      if (s.dong != oldDong) continue;
      var changed = false;
      s.dong = newDong;
      changed = true;
      if (s.name.contains(oldDong)) {
        s.name = s.name.replaceAll(oldDong, newDong);
      }
      if (changed) n++;
    }
    return n;
  }

  Esp32Board? _firstBoardForDong(String dong) {
    for (final b in _site.boards) {
      if (b.dong == dong) return b;
    }
    return null;
  }

  /// 이 보드에 속한 제어 (boardId 일치 또는 미지정 시 동일 dong 첫 보드).
  List<ControlElement> _controlsForBoard(Esp32Board board) {
    return _site.controls.where((c) => _controlBelongsToBoard(c, board)).toList();
  }

  bool _controlBelongsToBoard(ControlElement c, Esp32Board board) {
    if (c.boardId != null) return c.boardId == board.id;
    return _firstBoardForDong(c.dong)?.id == board.id;
  }

  /// 보드 내 제어 순서 변경 → `_site.controls` 상대 순서 반영(홈 화면과 동일).
  void _reorderBoardControls(Esp32Board board, int oldIndex, int newIndex) {
    setState(() {
      final boardList = _controlsForBoard(board);
      if (oldIndex < 0 ||
          oldIndex >= boardList.length ||
          newIndex < 0 ||
          newIndex >= boardList.length) {
        return;
      }
      final moved = boardList.removeAt(oldIndex);
      boardList.insert(newIndex, moved);
      final queue = List<ControlElement>.from(boardList);
      final out = <ControlElement>[];
      for (final c in _site.controls) {
        if (_controlBelongsToBoard(c, board)) {
          if (queue.isNotEmpty) out.add(queue.removeAt(0));
        } else {
          out.add(c);
        }
      }
      out.addAll(queue);
      _site.controls
        ..clear()
        ..addAll(out);
    });
  }

  /// boardId가 깨졌거나 dong에 보드가 없는 제어.
  List<ControlElement> get _unassignedControls {
    return _site.controls.where((c) {
      if (c.boardId != null) return _site.boardById(c.boardId) == null;
      return _firstBoardForDong(c.dong) == null;
    }).toList();
  }

  void _toggleBoardExpanded(String boardId) {
    setState(() {
      if (_expandedBoardIds.contains(boardId)) {
        _expandedBoardIds.remove(boardId);
      } else {
        _expandedBoardIds.add(boardId);
      }
    });
  }

  Future<void> _addControlForBoard(Esp32Board board) async {
    final el = await Navigator.of(context).push<ControlElement>(
      MaterialPageRoute(
        builder: (_) => ControlEditorScreen(
          element: ControlElement(
            name: ControlElement.defaultPairName(0),
            dong: board.dong,
            boardId: board.id,
          ),
          cameras: _site.cameras,
          boards: _site.boards,
          dongOptions: _site.dongList,
        ),
      ),
    );
    if (el != null) {
      setState(() {
        el.boardId ??= board.id;
        if (el.dong.trim().isEmpty) el.dong = board.dong;
        _site.controls.add(el);
        _expandedBoardIds.add(board.id);
      });
    }
  }

  void _addStandardControlsForBoard(Esp32Board board, {bool silentIfBusy = false}) {
    final existing = _controlsForBoard(board).length;
    if (existing > 0) {
      if (!silentIfBusy && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '이 보드에 제어가 ${existing}개 있습니다. 표준 8개는 빈 보드에 추가하세요.',
            ),
          ),
        );
      }
      return;
    }
    setState(() {
      _appendStandardControlsForBoard(board);
      _expandedBoardIds.add(board.id);
    });
  }

  /// 보드에 표준 모터 쌍 8개 추가 (호출 측에서 setState).
  int _appendStandardControlsForBoard(Esp32Board board) {
    final byJung = <String, String>{
      for (final c in _site.cameras)
        if (c.dong == board.dong) c.jung: c.id,
    };
    var n = 0;
    for (final def in FarmSite.standardDongMotorDefs) {
      if (def.$3 >= FarmSite.pairsPerBoard) continue;
      _site.controls.add(
        ControlElement(
          name: ControlElement.defaultPairName(def.$3),
          kind: ControlKind.motorPair,
          pairIndex: def.$3,
          dong: board.dong,
          jung: def.$2,
          boardId: board.id,
          cameraId: byJung[def.$2],
        ),
      );
      n++;
    }
    return n;
  }

  Future<void> _applyControlEdit(
    ControlElement before,
    ControlElement? edited,
  ) async {
    if (edited == null) return;
    setState(() {
      final i = _site.controls.indexWhere((x) => x.id == before.id);
      if (i < 0) return;

      if (before.kind == ControlKind.motorPair &&
          edited.kind == ControlKind.relayToggle) {
        final (first, second) = ControlElement.splitPairToRelays(
          ControlElement(
            id: before.id,
            name: edited.name,
            kind: ControlKind.motorPair,
            pairIndex: before.pairIndex,
            enabled: edited.enabled,
            dong: edited.dong,
            jung: edited.jung,
            onLabel: edited.onLabel,
            offLabel: edited.offLabel,
            cameraId: edited.cameraId,
            boardId: edited.boardId,
          ),
        );
        if (edited.name.trim().isNotEmpty) {
          first.name = edited.name.trim();
        }
        final already = _site.controls.any((c) =>
            c.id != first.id &&
            c.kind == ControlKind.relayToggle &&
            c.pinIndex == second.pinIndex &&
            (c.boardId ?? '') == (second.boardId ?? '') &&
            c.dong == second.dong);
        _site.controls[i] = first;
        if (!already) {
          _site.controls.insert(i + 1, second);
        }
      } else if (before.kind == ControlKind.relayToggle &&
          edited.kind == ControlKind.motorPair) {
        // ON/OFF 1·2CH → UP/DOWN 쌍. 짝 PIN 제거.
        final pinForPair = before.pinIndex;
        final pair = ControlElement.mergeRelayToPair(
          ControlElement(
            id: before.id,
            name: edited.name,
            kind: ControlKind.relayToggle,
            pairIndex: edited.pairIndex,
            pinIndex: pinForPair,
            enabled: edited.enabled,
            dong: edited.dong,
            jung: edited.jung,
            upLabel: edited.upLabel,
            downLabel: edited.downLabel,
            stopLabel: edited.stopLabel,
            cameraId: edited.cameraId,
            boardId: edited.boardId ?? before.boardId,
          ),
          name: edited.name,
        );
        // 편집기에서 쌍 번호를 직접 바꿨으면 그 값 우선
        if (edited.pairIndex != ControlElement.pairIndexFromPin(pinForPair)) {
          pair.pairIndex = edited.pairIndex.clamp(0, 7);
          pair.pinIndex = pair.pairPinA;
          if (ControlElement.isDefaultChannelName(pair.name) ||
              pair.name.contains('·ch') ||
              RegExp(r'^핀\d+\s*\(ch\d+\)$').hasMatch(pair.name.trim())) {
            pair.name = ControlElement.defaultPairName(pair.pairIndex);
          }
        }
        final pinA = pair.pairPinA;
        final pinB = pair.pairPinB;
        final boardKey = pair.boardId ?? '';
        _site.controls[i] = pair;
        _site.controls.removeWhere(
          (c) =>
              c.id != pair.id &&
              c.kind == ControlKind.relayToggle &&
              (c.pinIndex == pinA || c.pinIndex == pinB) &&
              (c.boardId ?? '') == boardKey &&
              c.dong == pair.dong,
        );
      } else {
        _site.controls[i] = edited;
      }
    });
  }

  Future<void> _editControl(ControlElement e) async {
    final edited = await Navigator.of(context).push<ControlElement>(
      MaterialPageRoute(
        builder: (_) => ControlEditorScreen(
          element: e.copy(),
          cameras: _site.cameras,
          boards: _site.boards,
          dongOptions: _site.dongList,
        ),
      ),
    );
    await _applyControlEdit(e, edited);
  }

  Future<void> _deleteControl(ControlElement e) async {
    final ok = await _confirmDelete(
      title: '제어 요소 삭제',
      message: '"${e.name}" (${e.dong}) 을(를) 삭제할까요?',
    );
    if (ok && mounted) {
      setState(() => _site.controls.remove(e));
    }
  }

  Widget _buildControlListTile(
    ControlElement e, {
    Widget? leading,
  }) {
    final camName = _site.cameraById(e.cameraId)?.name ?? '기본 영상';
    final boardName = _site.boardForControl(e)?.name ?? '보드?';
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: leading,
      title: Text(e.name),
      subtitle: Text(
        e.kind == ControlKind.motorPair
            ? '${e.dong} · $boardName 쌍${e.pairIndex + 1} · $camName'
            : '${e.dong} · $boardName 핀${e.pinIndex + 1} · $camName',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(
            value: e.enabled,
            onChanged: (v) => setState(() => e.enabled = v),
          ),
          IconButton(
            icon: const Icon(Icons.edit, size: 20),
            onPressed: () => _editControl(e),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: () => _deleteControl(e),
          ),
        ],
      ),
    );
  }

  Widget _buildBoardCard(Esp32Board b) {
    final expanded = _expandedBoardIds.contains(b.id);
    final boardControls = _controlsForBoard(b);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            onTap: () => _toggleBoardExpanded(b.id),
            leading: Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
            ),
            title: Text(b.name),
            subtitle: Text(
              '${b.dong} · ${b.displayHost} · 제어 ${boardControls.length}개',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: b.enabled,
                  onChanged: (v) => setState(() => b.enabled = v),
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () async {
                    final oldDong = b.dong;
                    final edited = await _editBoard(b.copy());
                    if (edited == null) return;
                    final camN = _syncCamerasDongForBoard(
                      boardId: b.id,
                      oldDong: oldDong,
                      newDong: edited.dong,
                    );
                    final ctlN = _syncControlsDongForBoard(
                      boardId: b.id,
                      oldDong: oldDong,
                      newDong: edited.dong,
                    );
                    final senN = _syncSensorsDongForBoard(
                      boardId: b.id,
                      oldDong: oldDong,
                      newDong: edited.dong,
                    );
                    setState(() {
                      final i = _site.boards.indexWhere((x) => x.id == b.id);
                      if (i >= 0) _site.boards[i] = edited;
                    });
                    if ((camN > 0 || ctlN > 0 || senN > 0) && context.mounted) {
                      final parts = <String>[
                        if (ctlN > 0) '제어 $ctlN개',
                        if (camN > 0) '영상 $camN개',
                        if (senN > 0) '센서 $senN개',
                      ];
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${parts.join("·")} $kControlGroupLabel을 ${edited.dong}(으)로 맞춤',
                          ),
                        ),
                      );
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    if (_site.boards.length <= 1) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('보드는 최소 1대 필요합니다')),
                      );
                      return;
                    }
                    final ctlOnBoard = _controlsForBoard(b).length;
                    final msg = ctlOnBoard > 0
                        ? '"${b.name}" (${b.dong} · ${b.displayHost}) 과 연결된 제어 $ctlOnBoard개는 보드 지정이 해제됩니다. 삭제할까요?'
                        : '"${b.name}" (${b.dong} · ${b.displayHost}) 을(를) 삭제할까요?';
                    final ok = await _confirmDelete(
                      title: '보드 삭제',
                      message: msg,
                    );
                    if (ok && mounted) {
                      setState(() {
                        for (final c in _site.controls) {
                          if (c.boardId == b.id) c.boardId = null;
                        }
                        _site.boards.remove(b);
                        _expandedBoardIds.remove(b.id);
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  TextButton.icon(
                    onPressed: () => _addControlForBoard(b),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('제어 추가'),
                  ),
                  TextButton.icon(
                    onPressed: () => _addStandardControlsForBoard(b),
                    icon: const Icon(Icons.playlist_add, size: 18),
                    label: const Text('표준 8개'),
                  ),
                ],
              ),
            ),
            if (boardControls.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  '이 보드에 연결된 제어가 없습니다.',
                  style: TextStyle(fontSize: 13, color: Colors.white54),
                ),
              )
            else ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Text(
                  '≡ 드래그로 순서 변경 (홈 화면 제어 순서에 반영)',
                  style: TextStyle(fontSize: 11, color: Colors.white54),
                ),
              ),
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: boardControls.length,
                onReorderItem: (oldIndex, newIndex) =>
                    _reorderBoardControls(b, oldIndex, newIndex),
                itemBuilder: (context, index) {
                  final e = boardControls[index];
                  return Material(
                    key: ValueKey(e.id),
                    color: Colors.transparent,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildControlListTile(
                          e,
                          leading: ReorderableDragStartListener(
                            index: index,
                            child: const Icon(
                              Icons.drag_handle,
                              color: Colors.white54,
                            ),
                          ),
                        ),
                        if (index < boardControls.length - 1)
                          const Divider(
                            height: 1,
                            indent: 16,
                            endIndent: 16,
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }

  Future<Esp32Board?> _editBoard(Esp32Board board) async {
    final name = TextEditingController(text: board.name);
    final dong = TextEditingController(text: board.dong);
    final host = TextEditingController(text: board.host);
    final port = TextEditingController(text: '${board.port}');
    final loginId = TextEditingController(text: board.loginId);
    final loginPw = TextEditingController(text: board.loginPw);
    var useHttps = board.useHttps;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('ESP32 보드'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: '보드 이름'),
                ),
                TextField(
                  controller: dong,
                  decoration: const InputDecoration(
                    labelText: '소속 $kControlGroupLabel',
                    helperText:
                        '변경 시 연결된 제어·영상·센서의 $kControlGroupLabel(및 이름)도 같이 바뀝니다',
                  ),
                ),
                TextField(
                  controller: host,
                  decoration: const InputDecoration(labelText: 'IP'),
                ),
                TextField(
                  controller: port,
                  decoration: const InputDecoration(labelText: '포트'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: loginId,
                  decoration: const InputDecoration(labelText: '로그인 ID'),
                ),
                TextField(
                  controller: loginPw,
                  decoration: const InputDecoration(labelText: '비밀번호'),
                  obscureText: true,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('HTTPS'),
                  value: useHttps,
                  onChanged: (v) => setLocal(() => useHttps = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('확인'),
            ),
          ],
        ),
      ),
    );

    final result = ok == true
        ? Esp32Board(
            id: board.id,
            name: name.text.trim().isEmpty ? '보드' : name.text.trim(),
            dong: dong.text.trim().isEmpty ? kDefaultHouse : dong.text.trim(),
            host: host.text.trim(),
            port: int.tryParse(port.text.trim()) ?? 8080,
            loginId: loginId.text.trim(),
            loginPw: loginPw.text,
            useHttps: useHttps,
            enabled: board.enabled,
          )
        : null;
    name.dispose();
    dong.dispose();
    host.dispose();
    port.dispose();
    loginId.dispose();
    loginPw.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('사이트 편집'),
        actions: [
          TextButton(onPressed: _save, child: const Text('저장')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('기본', style: Theme.of(context).textTheme.titleMedium),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: '사이트 이름'),
          ),
          const SizedBox(height: 12),
          Text('바탕색', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final preset in FarmSite.bgColorPresets)
                _BgColorChip(
                  label: preset.$1,
                  color: Color(preset.$2),
                  selected: _site.bgColor == preset.$2,
                  onTap: () => setState(() => _site.bgColor = preset.$2),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('ESP32 보드 · 제어',
                  style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              TextButton.icon(
                onPressed: _addStandardDong,
                icon: const Icon(Icons.apartment),
                label: const Text('표준 제어기그룹'),
              ),
              TextButton.icon(
                onPressed: () async {
                  final b = await _editBoard(
                    Esp32Board(
                      name: '보드${_site.boards.length + 1}',
                      dong: _site.dongList.isNotEmpty
                          ? _site.dongList.first
                          : kDefaultHouse,
                    ),
                  );
                  if (b == null || !mounted) return;
                  var added = 0;
                  setState(() {
                    _site.boards.add(b);
                    added = _appendStandardControlsForBoard(b);
                    _expandedBoardIds.add(b.id);
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${b.name} 추가 · 기본 제어 $added개(쌍1–8)',
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('보드 추가'),
              ),
            ],
          ),
          const Text(
            '보드 추가 시 기본 제어(쌍1–8)가 자동으로 붙습니다. 보드를 펼쳐 수정·삭제하세요.',
            style: TextStyle(fontSize: 12, color: Colors.white54),
          ),
          if (_site.boards.isEmpty)
            const Text('보드 없음 — 추가하세요')
          else
            ..._site.boards.map(_buildBoardCard),
          if (_unassignedControls.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '보드 미연결 제어',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const Text(
              '아래 제어는 보드를 지정해 주세요 (편집 → ESP32 보드).',
              style: TextStyle(fontSize: 12, color: Colors.white54),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  for (final e in _unassignedControls) ...[
                    _buildControlListTile(e),
                    if (e != _unassignedControls.last)
                      const Divider(height: 1, indent: 16, endIndent: 16),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          TextField(
            controller: _notes,
            decoration: const InputDecoration(
              labelText: '메모',
              hintText: '여기에 메모하세요.',
            ),
            maxLines: 2,
          ),
          const Divider(height: 32),
          Row(
            children: [
              Text('영상 소스', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              TextButton.icon(
                onPressed: () async {
                  final list =
                      await Navigator.of(context).push<List<CameraSource>>(
                    MaterialPageRoute(
                      builder: (_) => const NvrBulkAddScreen(),
                    ),
                  );
                  if (list != null && list.isNotEmpty) {
                    // 이미 있는 카메라 뒤에 이어지는 번호로 이름 맞춤
                    final start = _site.cameras.length + 1;
                    for (var i = 0; i < list.length; i++) {
                      if (CameraSource.looksLikeLegacyName(list[i].name) ||
                          CameraSource.isNumberedDefaultName(list[i].name)) {
                        list[i].name = CameraSource.defaultName(start + i);
                      }
                    }
                    setState(() => _site.cameras.addAll(list));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('NVR 채널 ${list.length}개 추가됨')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.dvr),
                label: const Text('NVR 일괄'),
              ),
              TextButton.icon(
                onPressed: () async {
                  final cam = await Navigator.of(context).push<CameraSource>(
                    MaterialPageRoute(
                      builder: (_) => CameraEditorScreen(
                        camera: CameraSource(
                          name: _site.nextCameraDefaultName(),
                        ),
                        dongOptions: _site.dongList,
                      ),
                    ),
                  );
                  if (cam != null) setState(() => _site.cameras.add(cam));
                },
                icon: const Icon(Icons.add),
                label: const Text('추가'),
              ),
            ],
          ),
          if (_site.cameras.isEmpty)
            const Text('아직 없음 — 하이크/NVR/한화 등을 추가하세요.')
          else
            ..._site.cameras.map((c) {
              final isDefault = _site.isHouseDefaultCamera(c);
              return Card(
                child: ListTile(
                  title: Row(
                    children: [
                      Expanded(child: Text(c.name)),
                      if (isDefault)
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Chip(
                            label: Text('대표', style: TextStyle(fontSize: 11)),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            padding: EdgeInsets.symmetric(horizontal: 4),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Text(
                    '${c.dong} · ${c.type.name}'
                    '${c.isHikvisionNvr ? " · ch${c.channel}" : ""}'
                    '${c.ptzEnabled ? " · PTZ" : ""} · '
                    '${c.host.isEmpty ? c.customUrl : c.host}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: isDefault ? '대표 영상' : '이 $kControlGroupLabel 대표로',
                        icon: Icon(
                          isDefault ? Icons.star : Icons.star_border,
                          color: isDefault ? Colors.amber : null,
                        ),
                        onPressed: () {
                          setState(() {
                            if (isDefault) {
                              _site.setHouseDefaultCamera(c.dong, null);
                            } else {
                              _site.setHouseDefaultCamera(c.dong, c.id);
                            }
                          });
                        },
                      ),
                      Switch(
                        value: c.enabled,
                        onChanged: (v) => setState(() => c.enabled = v),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () async {
                          final edited =
                              await Navigator.of(context).push<CameraSource>(
                            MaterialPageRoute(
                              builder: (_) => CameraEditorScreen(
                                camera: c.copy(),
                                dongOptions: _site.dongList,
                              ),
                            ),
                          );
                          if (edited != null) {
                            setState(() {
                              final i =
                                  _site.cameras.indexWhere((x) => x.id == c.id);
                              if (i >= 0) _site.cameras[i] = edited;
                              _site.pruneHouseDefaultCameras();
                            });
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          final ok = await _confirmDelete(
                            title: '영상 소스 삭제',
                            message: '"${c.name}" (${c.dong}) 을(를) 삭제할까요?',
                          );
                          if (ok && mounted) {
                            setState(() {
                              _site.cameras.remove(c);
                              _site.pruneHouseDefaultCameras();
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            }),
          if (_site.cameras.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('$kControlGroupLabel 대표 영상',
                style: Theme.of(context).textTheme.titleMedium),
            const Text(
              '홈에서 $kControlGroupLabel을 선택했을 때 보여줄 카메라 (미설정 시 해당 $kControlGroupLabel 첫 영상)',
              style: TextStyle(fontSize: 12, color: Colors.white54),
            ),
            const SizedBox(height: 8),
            ..._site.dongList.map((dong) {
              final cams =
                  _site.cameras.where((c) => c.dong == dong).toList();
              if (cams.isEmpty) {
                return ListTile(
                  dense: true,
                  title: Text(dong),
                  subtitle: const Text('영상 소스 없음'),
                );
              }
              final ids = cams.map((c) => c.id).toSet();
              final cur = _site.houseDefaultCameras[dong];
              final value = (cur != null && ids.contains(cur)) ? cur : null;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: DropdownButtonFormField<String?>(
                  key: ValueKey('defcam_$dong-$value'),
                  initialValue: value,
                  decoration: InputDecoration(
                    labelText: dong,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('(자동 · 목록 첫 카메라)'),
                    ),
                    ...cams.map(
                      (c) => DropdownMenuItem<String?>(
                        value: c.id,
                        child: Text(
                          '${c.name}${c.enabled ? "" : " (꺼짐)"}',
                        ),
                      ),
                    ),
                  ],
                  onChanged: (v) {
                    setState(() => _site.setHouseDefaultCamera(dong, v));
                  },
                ),
              );
            }),
          ],
          const Divider(height: 32),
          Row(
            children: [
              Text('센서 (Analog)',
                  style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              TextButton.icon(
                onPressed: () async {
                  final s = await Navigator.of(context).push<SensorEndpoint>(
                    MaterialPageRoute(
                      builder: (_) => SensorEditorScreen(
                        sensor: SensorEndpoint(name: '새 센서'),
                        dongOptions: _site.dongList,
                      ),
                    ),
                  );
                  if (s != null) setState(() => _site.sensors.add(s));
                },
                icon: const Icon(Icons.add),
                label: const Text('추가'),
              ),
            ],
          ),
          const Text(
            '$kControlGroupLabel별 센서 여러 대 · MCU ESP32(/api/mcp3208) · MCU PICO(/data)',
            style: TextStyle(fontSize: 12, color: Colors.white54),
          ),
          if (_site.sensors.isEmpty)
            const Text('아직 없음')
          else
            ..._site.sensors.map((s) {
              return Card(
                child: ListTile(
                  title: Text(s.name),
                  subtitle: Text(
                    '${s.dong} · ${s.model.name} · ${s.displayHost}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: s.enabled,
                        onChanged: (v) => setState(() => s.enabled = v),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () async {
                          final edited =
                              await Navigator.of(context).push<SensorEndpoint>(
                            MaterialPageRoute(
                              builder: (_) => SensorEditorScreen(
                                sensor: s.copy(),
                                dongOptions: _site.dongList,
                              ),
                            ),
                          );
                          if (edited != null) {
                            setState(() {
                              final i =
                                  _site.sensors.indexWhere((x) => x.id == s.id);
                              if (i >= 0) _site.sensors[i] = edited;
                            });
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          final ok = await _confirmDelete(
                            title: '센서 삭제',
                            message: '"${s.name}" (${s.dong}) 을(를) 삭제할까요?',
                          );
                          if (ok && mounted) {
                            setState(() => _site.sensors.remove(s));
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('사이트 삭제'),
                  content: Text('"${_site.name}" 을(를) 삭제할까요?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('취소'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('삭제'),
                    ),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                await context.read<FarmController>().deleteSite(_site.id);
                if (context.mounted) Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
            label: const Text('이 사이트 삭제'),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _BgColorChip extends StatelessWidget {
  const _BgColorChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 72,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0xFF38BDF8) : const Color(0xFF475569),
            width: selected ? 2.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              selected ? Icons.check_circle : Icons.circle,
              size: 18,
              color: selected ? Colors.white : Colors.white38,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
