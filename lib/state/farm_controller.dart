import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/control_element.dart';
import '../models/farm_site.dart';
import '../models/io_state.dart';
import '../models/sensor_endpoint.dart';
import '../services/control_beep.dart';
import '../services/esp32_client.dart';
import '../services/mcp3208_client.dart';
import '../services/mcu_pico_client.dart';
import '../services/settings_backup.dart';
import '../services/site_repository.dart';

class FarmController extends ChangeNotifier {
  FarmController(this._repo);

  final SiteRepository _repo;
  final List<FarmSite> sites = [];
  String? activeId;

  final Map<String, Esp32Client> _clients = {};
  final Map<String, IoState> boardIoStates = {};

  /// 호환: 포커스 제어 보드 상태, 없으면 첫 보드.
  IoState get ioState {
    final el = focusedControl;
    if (el != null) return ioStateFor(el);
    if (boardIoStates.isEmpty) return IoState.empty;
    return boardIoStates.values.first;
  }

  final Map<String, Mcp3208Reading> mcpReadings = {};
  final Map<String, String?> mcpErrors = {};

  Mcp3208Reading get mcpReading {
    final s = activeSensor;
    if (s == null) return Mcp3208Reading.empty;
    return mcpReadings[s.id] ?? Mcp3208Reading.empty;
  }

  String? get mcpError {
    final s = activeSensor;
    if (s == null) return null;
    return mcpErrors[s.id];
  }

  String? sensorDong;
  bool busy = false;
  bool polling = false;
  String statusMessage = '';
  Timer? _poll;

  final Map<String, int> optimisticMotor = {};
  final Map<String, int> optimisticRelay = {};

  String? focusedControlId;
  int? focusedPinIndex;

  FarmSite? get activeSite {
    if (sites.isEmpty) return null;
    for (final s in sites) {
      if (s.id == activeId) return s;
    }
    return sites.first;
  }

  ControlElement? get focusedControl {
    final site = activeSite;
    if (site == null || focusedControlId == null) return null;
    for (final c in site.controls) {
      if (c.id == focusedControlId) return c;
    }
    return null;
  }

  Future<void> init() async {
    sites
      ..clear()
      ..addAll(await _repo.loadSites());
    activeId =
        await _repo.loadActiveId() ?? (sites.isEmpty ? null : sites.first.id);
    focusedControlId = null;
    focusedPinIndex = null;
    _bindClients();
    notifyListeners();
    startPolling();
  }

  void focusControl(String? id, {int? pinIndex}) {
    focusedControlId = id;
    focusedPinIndex = pinIndex;
    notifyListeners();
  }

  void _disposeClients() {
    for (final c in _clients.values) {
      c.dispose();
    }
    _clients.clear();
    boardIoStates.clear();
  }

  void _bindClients() {
    _disposeClients();
    mcpReadings.clear();
    mcpErrors.clear();
    final site = activeSite;
    if (site == null) return;
    for (final b in site.enabledBoards) {
      _clients[b.id] = Esp32Client(b.asEndpoint);
      boardIoStates[b.id] = IoState.empty;
    }
  }

  Esp32Client? _clientFor(ControlElement el) {
    final site = activeSite;
    if (site == null) return null;
    final board = site.boardForControl(el);
    if (board == null) return null;
    return _clients[board.id];
  }

  String? boardIdFor(ControlElement el) {
    return activeSite?.boardForControl(el)?.id;
  }

  IoState ioStateFor(ControlElement el) {
    final id = boardIdFor(el);
    if (id == null) return IoState.empty;
    return boardIoStates[id] ?? IoState.empty;
  }

  void setSensorDong(String? dong) {
    if (sensorDong == dong) return;
    sensorDong = dong;
    notifyListeners();
    refreshSensor(silent: true);
  }

  SensorEndpoint? get activeSensor {
    final list = sensorsForActiveDong;
    return list.isEmpty ? null : list.first;
  }

  List<SensorEndpoint> get sensorsForActiveDong {
    final site = activeSite;
    if (site == null) return const [];
    final dong = sensorDong ??
        (site.enabledSensors.isNotEmpty
            ? site.enabledSensors.first.dong
            : null);
    return site.sensorsForDong(dong);
  }

  Mcp3208Reading readingForSensor(String sensorId) =>
      mcpReadings[sensorId] ?? Mcp3208Reading.empty;

  String? errorForSensor(String sensorId) => mcpErrors[sensorId];

  Future<void> _persist() async {
    await _repo.saveSites(sites, activeId: activeId);
  }

  Future<void> selectSite(String id) async {
    activeId = id;
    optimisticMotor.clear();
    optimisticRelay.clear();
    focusedControlId = null;
    focusedPinIndex = null;
    _bindClients();
    await _persist();
    notifyListeners();
    await refreshState();
  }

  Future<void> upsertSite(FarmSite site) async {
    final i = sites.indexWhere((s) => s.id == site.id);
    if (i >= 0) {
      sites[i] = site;
    } else {
      sites.add(site);
    }
    activeId ??= site.id;
    if (activeId == site.id) _bindClients();
    await _persist();
    notifyListeners();
  }

  Future<void> deleteSite(String id) async {
    sites.removeWhere((s) => s.id == id);
    if (activeId == id) {
      activeId = sites.isEmpty ? null : sites.first.id;
      focusedControlId = null;
      focusedPinIndex = null;
      _bindClients();
    }
    await _persist();
    notifyListeners();
  }

  Future<void> resetActiveSiteToDemo() async {
    final demo = FarmSite.demo();
    final i = sites.indexWhere((s) => s.id == activeId);
    if (i >= 0) {
      final oldId = sites[i].id;
      final replaced = FarmSite(
        id: oldId,
        name: demo.name,
        boards: demo.boards,
        cameras: demo.cameras,
        controls: demo.controls,
        sensors: demo.sensors,
        houseDefaultCameras: demo.houseDefaultCameras,
        notes: demo.notes,
        bgColor: sites[i].bgColor,
      );
      sites[i] = replaced;
      focusedControlId = replaced.enabledControls.first.id;
    } else {
      sites.add(demo);
      activeId = demo.id;
      focusedControlId = demo.enabledControls.first.id;
    }
    _bindClients();
    await _persist();
    notifyListeners();
  }

  /// 사이트·보드·카메라·제어·센서 전체를 JSON으로 직렬화.
  String exportSettingsJson() =>
      SettingsBackup.encode(sites: sites, activeId: activeId);

  /// 백업 JSON으로 전체 설정을 교체. 반환값 = 가져온 사이트 수.
  Future<int> importSettingsJson(String raw) async {
    final data = SettingsBackup.decode(raw);
    sites
      ..clear()
      ..addAll(data.sites.map((s) => s.copy()));
    final want = data.activeId;
    if (want != null && sites.any((s) => s.id == want)) {
      activeId = want;
    } else {
      activeId = sites.first.id;
    }
    optimisticMotor.clear();
    optimisticRelay.clear();
    focusedControlId = null;
    focusedPinIndex = null;
    sensorDong = null;
    _bindClients();
    await _persist();
    notifyListeners();
    await refreshState(silent: true);
    await refreshSensor(silent: true);
    return sites.length;
  }

  void startPolling() {
    _poll?.cancel();
    polling = true;
    _poll = Timer.periodic(const Duration(milliseconds: 700), (_) {
      refreshState(silent: true);
      refreshSensor(silent: true);
    });
    refreshState();
    refreshSensor();
  }

  void stopPolling() {
    _poll?.cancel();
    polling = false;
  }

  Future<void> refreshState({bool silent = false}) async {
    if (_clients.isEmpty) return;
    await Future.wait(_clients.entries.map((e) async {
      final st = await e.value.fetchIoState();
      if (st != null) {
        boardIoStates[e.key] = st;
        _reconcileOptimistic(e.key, st);
      }
    }));

    if (!silent) {
      final site = activeSite;
      final n = site?.enabledBoards.length ?? 0;
      final okTv16 = boardIoStates.values.any((s) => s.tv16 && s.ok);
      final anyTv16 = boardIoStates.values.any((s) => s.tv16);
      if (anyTv16) {
        statusMessage =
            okTv16 ? '보드 $n대 · TV16AVR 연결' : '보드 $n대 · TV16AVR 상태 대기';
      } else if (boardIoStates.values.any((s) => s.hasData)) {
        statusMessage = '보드 $n대 · TV8BD';
      } else {
        String? err;
        for (final c in _clients.values) {
          if (c.lastError != null) {
            err = c.lastError;
            break;
          }
        }
        statusMessage = err ?? '상태 없음';
      }
    }
    notifyListeners();
  }

  Future<void> refreshSensor({bool silent = false}) async {
    final sensors = sensorsForActiveDong;
    if (sensors.isEmpty) {
      if (mcpReadings.isNotEmpty || mcpErrors.isNotEmpty) {
        mcpReadings.clear();
        mcpErrors.clear();
        notifyListeners();
      }
      return;
    }

    final byEndpoint = <String, List<SensorEndpoint>>{};
    for (final s in sensors) {
      final key = '${s.host.trim()}:${s.port}:${s.model.name}';
      byEndpoint.putIfAbsent(key, () => []).add(s);
    }

    await Future.wait(byEndpoint.entries.map((e) async {
      final group = e.value;
      final primary = group.first;
      if (primary.model == SensorModel.mcuPico) {
        final client = McuPicoClient(primary);
        try {
          final st = await client.fetch();
          for (final s in group) {
            if (st != null) {
              mcpReadings[s.id] = st;
              mcpErrors[s.id] = null;
            } else {
              mcpErrors[s.id] = client.lastError;
            }
          }
        } finally {
          client.dispose();
        }
        return;
      }
      final client = Mcp3208Client(primary);
      try {
        final st = await client.fetch();
        for (final s in group) {
          if (st != null) {
            mcpReadings[s.id] = st;
            mcpErrors[s.id] = st.ready ? null : 'ADC not ready';
          } else {
            mcpErrors[s.id] = client.lastError;
          }
        }
      } finally {
        client.dispose();
      }
    }));

    notifyListeners();
  }

  Future<void> _refreshAfterControl(ControlElement el) async {
    final st = ioStateFor(el);
    final tv16 = st.tv16;
    if (tv16) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
    final attempts = tv16 ? 6 : 1;
    for (var i = 0; i < attempts; i++) {
      await refreshState(silent: true);
      if (!tv16 || ioStateFor(el).ok) break;
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
  }

  void _reconcileOptimistic(String boardId, IoState st) {
    if (!st.statusTrusted) return;
    final site = activeSite;
    if (site == null) return;

    final doneMotor = <String>[];
    for (final e in optimisticMotor.entries) {
      ControlElement? el;
      for (final c in site.controls) {
        if (c.id == e.key) {
          el = c;
          break;
        }
      }
      if (el == null) {
        doneMotor.add(e.key);
        continue;
      }
      if (site.boardForControl(el)?.id != boardId) continue;
      final ui = st.motorUi(el.pairIndex);
      final want = e.value;
      if (want == MotorAction.up && ui == MotorPairUi.up) doneMotor.add(e.key);
      if (want == MotorAction.down && ui == MotorPairUi.down) {
        doneMotor.add(e.key);
      }
      if (want == MotorAction.stop && ui == MotorPairUi.stop) {
        doneMotor.add(e.key);
      }
    }
    for (final k in doneMotor) {
      optimisticMotor.remove(k);
    }

    final doneRelay = <String>[];
    for (final e in optimisticRelay.entries) {
      final key = e.key;
      final parts = key.split(':');
      final id = parts.first;
      ControlElement? el;
      for (final c in site.controls) {
        if (c.id == id) {
          el = c;
          break;
        }
      }
      if (el == null) {
        doneRelay.add(key);
        continue;
      }
      if (site.boardForControl(el)?.id != boardId) continue;
      final pin = parts.length > 1
          ? (int.tryParse(parts[1]) ?? el.pinIndex)
          : el.pinIndex;
      if (st.channel(pin) == e.value) doneRelay.add(key);
    }
    for (final k in doneRelay) {
      optimisticRelay.remove(k);
    }
  }

  MotorPairUi displayMotor(ControlElement el) {
    final o = optimisticMotor[el.id];
    if (o != null) {
      if (o == MotorAction.up) return MotorPairUi.up;
      if (o == MotorAction.down) return MotorPairUi.down;
      return MotorPairUi.stop;
    }
    final st = ioStateFor(el);
    if (!st.statusTrusted) return MotorPairUi.unknown;
    return st.motorUi(el.pairIndex);
  }

  bool displayRelayOn(ControlElement el, {int? pinOverride}) {
    final pin = pinOverride ?? el.pinIndex;
    final key = pinOverride == null ? el.id : '${el.id}:$pin';
    final o = optimisticRelay[key] ?? optimisticRelay[el.id];
    if (o != null) return o != 0;
    final st = ioStateFor(el);
    if (!st.statusTrusted) return false;
    return st.channel(pin) != 0;
  }

  /// 채널 쌍(motorPair)은 항상 UP/DOWN/STOP UI.
  /// 단일 핀(relayToggle)만 ON/OFF. SETIOCONFIG는 보드 표시용으로만 참고.
  bool usesMotorUi(ControlElement el) {
    return el.kind == ControlKind.motorPair;
  }

  Future<bool> ensureLogin() async {
    final el = focusedControl;
    final client = el != null
        ? _clientFor(el)
        : (_clients.isEmpty ? null : _clients.values.first);
    if (client == null) return false;
    busy = true;
    notifyListeners();
    final ok = await client.login();
    statusMessage = ok ? '로그인 성공' : (client.lastError ?? '로그인 실패');
    busy = false;
    notifyListeners();
    return ok;
  }

  Future<void> _playControlFeedback(
      {required int motorAction, int? relayVal}) async {
    if (relayVal != null) {
      await ControlBeep.forRelay(relayVal);
      HapticFeedback.lightImpact();
      return;
    }
    await ControlBeep.forMotorAction(motorAction);
    if (motorAction == MotorAction.stop) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }
  }

  Future<void> runMotor(ControlElement el, int action) async {
    final client = _clientFor(el);
    if (client == null) return;
    // 네트워크보다 먼저 소리/햅틱 (대기하지 않음)
    unawaited(_playControlFeedback(motorAction: action));
    focusedControlId = el.id;
    focusedPinIndex = null;
    optimisticMotor[el.id] = action;
    busy = true;
    notifyListeners();
    final ok = await client.motor(el.pairIndex, action);
    final board = activeSite?.boardForControl(el);
    statusMessage = ok
        ? '${board?.name ?? ''} ${el.name} → ${_actionName(el, action)}'
        : (client.lastError ?? '명령 실패');
    if (!ok) optimisticMotor.remove(el.id);
    busy = false;
    notifyListeners();
    await _refreshAfterControl(el);
  }

  Future<void> runRelay(ControlElement el, int val, {int? pinOverride}) async {
    final client = _clientFor(el);
    if (client == null) return;
    final pin = pinOverride ?? el.pinIndex;
    final key = pinOverride == null ? el.id : '${el.id}:$pin';
    unawaited(_playControlFeedback(motorAction: 0, relayVal: val));
    focusedControlId = el.id;
    focusedPinIndex = pin;
    optimisticRelay[key] = val;
    busy = true;
    notifyListeners();
    final ok = await client.relay(pin, val);
    statusMessage = ok
        ? '${el.name} ch${pin + 1} ${val == 1 ? el.onLabel : el.offLabel}'
        : (client.lastError ?? '명령 실패');
    if (!ok) optimisticRelay.remove(key);
    busy = false;
    notifyListeners();
    await _refreshAfterControl(el);
  }

  String _actionName(ControlElement el, int action) {
    if (action == MotorAction.up) return el.upLabel;
    if (action == MotorAction.down) return el.downLabel;
    return el.stopLabel;
  }

  @override
  void dispose() {
    stopPolling();
    _disposeClients();
    super.dispose();
  }
}
