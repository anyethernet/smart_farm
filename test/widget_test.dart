import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_farm/models/camera_source.dart';
import 'package:smart_farm/models/control_element.dart';
import 'package:smart_farm/models/esp32_board.dart';
import 'package:smart_farm/models/farm_site.dart';
import 'package:smart_farm/models/house_label.dart';
import 'package:smart_farm/models/io_state.dart';
import 'package:smart_farm/models/sensor_endpoint.dart';
import 'package:smart_farm/services/mcu_pico_client.dart';
import 'package:smart_farm/services/settings_backup.dart';
import 'dart:convert';

void main() {
  test('demo has per-dong ESP32 standard controls', () {
    final site = FarmSite.demo();
    expect(site.dongList, ['1\uC81C\uC5B4\uAE30']);
    expect(site.dongList, isNot(contains('2\uC81C\uC5B4\uAE30')));
    expect(site.zoneList, contains('1\uC81C\uC5B4\uAE301\uC911'));
    expect(site.zoneList, contains('1\uC81C\uC5B4\uAE30\uBD80\uC9C1\uD3EC'));
    expect(site.zoneList, isNot(contains('1\uC81C\uC5B4\uAE30\uCEE4\uD2BC')));
    expect(site.zoneList, isNot(contains('2\uC81C\uC5B4\uAE301\uC911')));

    final expected = FarmSite.standardDongMotorDefs
        .map((e) => ControlElement.defaultPairName(e.$3 % FarmSite.pairsPerBoard))
        .toList();
    final d1 = site.controls.where((c) => c.dong == '1\uC81C\uC5B4\uAE30').map((c) => c.name);
    expect(d1, containsAll(expected));
    expect(d1, isNot(contains('\uC218\uD3C9\uCEE4\uD2BC')));
    expect(d1.length, 8);
    expect(site.controlsFor(dong: '1\uC81C\uC5B4\uAE30'), hasLength(8));
    expect(site.controls.where((c) => c.dong == '2\uC81C\uC5B4\uAE30'), isEmpty);
    expect(site.cameras.where((c) => c.dong == '2\uC81C\uC5B4\uAE30'), isEmpty);

    final cam1 = site.cameraForDong('1\uC81C\uC5B4\uAE30');
    expect(cam1, isNotNull);
    expect(cam1!.dong, '1\uC81C\uC5B4\uAE30');
    final ctrl = site.controlsFor(dong: '1\uC81C\uC5B4\uAE30').firstWhere(
          (c) => c.jung == '2\uC911',
        );
    final camCtrl = site.cameraForControl(ctrl);
    expect(camCtrl, isNotNull);
    expect(camCtrl!.jung, '2\uC911');

    final d1Boards = site.boardsForDong('1\uC81C\uC5B4\uAE30');
    expect(d1Boards, hasLength(1));
    final pack = FarmSite.buildStandardDong('3\uC81C\uC5B4\uAE30');
    expect(pack.boards, hasLength(1));
    expect(pack.cameras, hasLength(3));
    expect(pack.controls, hasLength(8));
    expect(pack.controls.first.dong, '3\uC81C\uC5B4\uAE30');
    expect(pack.controls.first.pairIndex, 0);
    expect(pack.controls.first.boardId, pack.boards.first.id);
    expect(pack.controls.first.name, ControlElement.defaultPairName(0));
    expect(pack.controls.last.name, ControlElement.defaultPairName(7));
    expect(pack.controls.last.pairIndex, 7);
    expect(pack.controls.last.boardId, pack.boards.first.id);

    final two = FarmSite.demo(dongs: const ['1\uC81C\uC5B4\uAE30', '2\uC81C\uC5B4\uAE30']);
    expect(two.dongList, containsAll(['1\uC81C\uC5B4\uAE30', '2\uC81C\uC5B4\uAE30']));
    expect(two.controls.where((c) => c.dong == '2\uC81C\uC5B4\uAE30'), hasLength(8));
  });

  test('legacy N\uB3D9 migrates to N\uC81C\uC5B4\uAE30', () {
    expect(normalizeHouseName('1\uB3D9'), '1\uC81C\uC5B4\uAE30');
    expect(normalizeHouseName('2\uB3D9'), '2\uC81C\uC5B4\uAE30');
    expect(normalizeHouseName('1\uD558\uC6B0\uC2A4'), '1\uC81C\uC5B4\uAE30');
    expect(normalizeHouseName('1\uC81C\uC5B4\uAE30'), '1\uC81C\uC5B4\uAE30');
    final (d, j) = FarmSite.splitZone('1\uC81C\uC5B4\uAE301\uC911');
    expect(d, '1\uC81C\uC5B4\uAE30');
    expect(j, '1\uC911');
    final (d2, j2) = FarmSite.splitZone('2\uD558\uC6B0\uC2A4\uBD80\uC9C1\uD3EC');
    expect(d2, '2\uC81C\uC5B4\uAE30');
    expect(j2, '\uBD80\uC9C1\uD3EC');
  });

  test('legacy esp32 json migrates to boards', () {
    final site = FarmSite.fromJson({
      'name': 'old',
      'esp32': {
        'host': '10.0.0.1',
        'port': 8080,
        'loginId': 'a',
        'loginPw': 'b',
      },
      'cameras': [],
      'controls': [],
      'sensors': [],
    });
    expect(site.boards, hasLength(1));
    expect(site.boards.first.host, '10.0.0.1');
    expect(site.esp32.host, '10.0.0.1');
  });

  test('motor UI is independent per pair', () {
    const io = IoState(
      tv16: true,
      src: 'uart2',
      ok: true,
      cfg: 31,
      states: [1, 0, 0, 1, 0, 0, 0, 0, 0, 0],
    );
    expect(io.motorUi(0), MotorPairUi.up);
    expect(io.motorUi(1), MotorPairUi.down);
    expect(io.motorUi(2), MotorPairUi.stop);
  });

  test('TV16 statusTrusted requires ok', () {
    const waiting = IoState(
      tv16: true,
      src: 'uart2',
      ok: false,
      cfg: 255,
      states: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    );
    expect(waiting.statusTrusted, isFalse);
    expect(waiting.setIoConfigText, '11111111');
    expect(waiting.isMotorPair(0), isTrue);
    const ready = IoState(
      tv16: true,
      src: 'uart2',
      ok: true,
      cfg: 255,
      states: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    );
    expect(ready.statusTrusted, isTrue);
    const tv8 = IoState(
      tv16: false,
      src: 'gpio',
      ok: false,
      cfg: 15,
      states: [0, 0, 0, 0, 0, 0, 0, 0],
    );
    expect(tv8.statusTrusted, isTrue);
    expect(tv8.setIoConfigText, '1111');
  });

  test('SETIOCONFIG cfg bit drives motor vs individual', () {
    const io = IoState(
      tv16: false,
      src: 'gpio',
      ok: true,
      cfg: 3,
      states: [0, 0, 0, 0, 0, 0, 0, 0],
    );
    expect(io.setIoConfigText, '1100');
    expect(io.isMotorPair(0), isTrue);
    expect(io.isMotorPair(1), isTrue);
    expect(io.isMotorPair(2), isFalse);
    expect(io.isMotorPair(3), isFalse);

    const waiting = IoState(
      tv16: true,
      src: 'uart2',
      ok: false,
      cfg: 0x0F,
      states: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    );
    expect(waiting.setIoConfigText, '11110000');
    expect(waiting.isMotorPair(3), isTrue);
    expect(waiting.isMotorPair(4), isFalse);
  });

  test('Hik NVR bulk channels map to 102/202', () {
    expect(CameraSource.nvrChannel(1), 102);
    expect(CameraSource.nvrChannel(2), 202);
    expect(CameraSource.nvrChannel(3, mainStream: true), 301);
    expect(CameraSource.nvrCameraNo(202), 2);
    expect(CameraSource.nvrIsMainStream(101), isTrue);
    expect(CameraSource.nvrIsMainStream(102), isFalse);

    final list = CameraSource.buildNvrChannels(
      host: '192.168.1.100',
      username: 'admin',
      password: 'pw',
      channelCount: 4,
    );
    expect(list, hasLength(4));
    expect(list[0].type, CameraStreamType.hikvisionNvrRtsp);
    expect(list[0].channel, 102);
    expect(list[3].channel, 402);
    expect(list[1].playUrl, contains('/Streaming/Channels/202'));
  });

  test('demo 1\uC81C\uC5B4\uAE30 sensor is MCU PICO at 192.168.1.144', () {
    final site = FarmSite.demo();
    expect(site.sensors, isNotEmpty);
    final s1 = site.sensorForDong('1\uC81C\uC5B4\uAE30');
    expect(s1, isNotNull);
    expect(s1!.host, '192.168.1.144');
    expect(s1.port, 8080);
    expect(s1.model, SensorModel.mcuPico);
    expect(s1.loginId, 'mcopia');
    expect(s1.loginPw, '1234');
    expect(s1.channelCount, 14);
    expect(s1.defaultLabels(), hasLength(14));
    expect(s1.defaultLabels(), containsAll(['GTEMP', 'GVWC', 'GEC', 'CO2']));
  });

  test('sensor channel visibility filters indexes', () {
    final s = SensorEndpoint(
      name: 't',
      model: SensorModel.mcuEsp32,
      channelVisible: [true, false, true, false, false, true, false, false],
    );
    expect(s.visibleChannelIndexes(), [0, 2, 5]);
    expect(s.isChannelVisible(1), isFalse);
    final json = s.toJson();
    final back = SensorEndpoint.fromJson(json);
    expect(back.visibleChannelIndexes(), [0, 2, 5]);
  });

  test('sensor channel labels and display order', () {
    final s = SensorEndpoint(
      name: 't',
      model: SensorModel.mcuEsp32,
      channelVisible: List<bool>.filled(8, true),
      channelLabels: ['\uC628\uB3C4', '', '습도'],
      channelOrder: [2, 0, 1, 3, 4, 5, 6, 7],
    );
    expect(s.labelForChannel(0), '\uC628\uB3C4');
    expect(s.labelForChannel(1), 'NTC2');
    expect(s.visibleChannelIndexes(), [2, 0, 1, 3, 4, 5, 6, 7]);
    s.channelVisible[1] = false;
    expect(s.visibleChannelIndexes(), [2, 0, 3, 4, 5, 6, 7]);
    final back = SensorEndpoint.fromJson(s.toJson());
    expect(back.channelOrder.first, 2);
    expect(back.labelForChannel(0), '\uC628\uB3C4');
  });

  test('sensor models: MCU ESP32 / MCU PICO + legacy migrate', () {
    final mcp = SensorEndpoint(name: 'm', model: SensorModel.mcuEsp32);
    expect(mcp.channelCount, 8);
    expect(mcp.displaySlotCount, 9);
    expect(mcp.defaultLabels(), hasLength(8));
    expect(mcp.windVisible, isTrue);
    expect(mcp.apiPathHint, contains('/api/mcp3208'));

    final pico = SensorEndpoint(name: 'p', model: SensorModel.mcuPico);
    expect(pico.channelCount, 14);
    expect(pico.displaySlotCount, 14);
    expect(pico.defaultLabels(), hasLength(14));
    expect(pico.apiPathHint, contains('/data'));
    expect(pico.visibleChannelIndexes(), [0, 1, 2]);

    pico.channelVisible = List<bool>.filled(13, true);
    pico.setModel(SensorModel.mcuPico);
    expect(pico.channelVisible, hasLength(14));
    expect(pico.isChannelVisible(13), isFalse);

    expect(SensorEndpoint.parseModel('mcp3208s'), SensorModel.mcuEsp32);
    expect(SensorEndpoint.parseModel('mcp3208'), SensorModel.mcuEsp32);
    expect(SensorEndpoint.parseModel('mcpEsp32'), SensorModel.mcuEsp32);
    expect(SensorEndpoint.parseModel('mcuEsp32'), SensorModel.mcuEsp32);
    expect(SensorEndpoint.parseModel('mcuPico'), SensorModel.mcuPico);

    final legacy = SensorEndpoint.fromJson({
      'name': 'old',
      'model': 'mcp3208s',
      'channelVisible': [true, false, true, false, false, true],
    });
    expect(legacy.model, SensorModel.mcuEsp32);
    expect(legacy.channelVisible, hasLength(8));
  });

  test('MCU PICO parses RP2040 /data name-value objects', () async {
    final endpoint = SensorEndpoint(
      name: 'pico',
      model: SensorModel.mcuPico,
      host: '192.168.1.144',
    );
    final mock = MockClient((request) async {
      expect(request.url.path, '/data');
      return http.Response(
        '{"data":[{"name":"GTEMP","value":30.4},'
        '{"name":"GVWC","value":8.5},'
        '{"name":"","value":0.0}]}',
        200,
      );
    });
    final client = McuPicoClient(endpoint, httpClient: mock);
    final reading = await client.fetch();

    expect(reading, isNotNull);
    expect(reading!.eng, [30.4, 8.5, 0.0]);
    expect(reading.labels, ['GTEMP', 'GVWC', 'S2']);
    expect(reading.adcCh, 3);
    client.dispose();
  });

  test('one dong can hold multiple sensor devices', () {
    final site = FarmSite(
      name: 't',
      sensors: [
        SensorEndpoint(name: 'A', dong: '1\uC81C\uC5B4\uAE30', host: '192.168.1.110'),
        SensorEndpoint(name: 'B', dong: '1\uC81C\uC5B4\uAE30', host: '192.168.1.111'),
        SensorEndpoint(name: 'C', dong: '2\uC81C\uC5B4\uAE30', host: '192.168.1.112'),
      ],
    );
    expect(site.sensorsForDong('1\uC81C\uC5B4\uAE30'), hasLength(2));
    expect(site.sensorsForDong('2\uC81C\uC5B4\uAE30'), hasLength(1));
    expect(site.sensorForDong('1\uC81C\uC5B4\uAE30')!.name, 'A');
  });

  test('settings backup encode/decode roundtrip', () {
    final a = FarmSite.demo();
    final json = SettingsBackup.encode(sites: [a], activeId: a.id);
    expect(json, contains('smart_farm_backup'));
    final data = SettingsBackup.decode(json);
    expect(data.sites, hasLength(1));
    expect(data.activeId, a.id);
    expect(data.sites.first.name, a.name);
    expect(data.sites.first.controls.length, a.controls.length);

    final asList = SettingsBackup.decode(
      jsonEncode([a.toJson()]),
    );
    expect(asList.sites, hasLength(1));

    final single = SettingsBackup.decode(jsonEncode(a.toJson()));
    expect(single.sites.first.id, a.id);
  });

  test('legacy 2\uD558\uC6B0\uC2A4 remaps to 1\uC81C\uC5B4\uAE30 on load', () {
    final board = Esp32Board.fromJson({
      'name': '2\uD558\uC6B0\uC2A4-\uBCF4\uB4DC1',
      'dong': '2\uD558\uC6B0\uC2A4',
      'host': '10.0.0.2',
    });
    expect(board.dong, '1\uC81C\uC5B4\uAE30');
    expect(board.name, '2\uC81C\uC5B4\uAE30-\uBCF4\uB4DC1');

    final cam = CameraSource.fromJson({
      'name': '2\uD558\uC6B0\uC2A4 1\uC911 \uCE74\uBA54\uB77C',
      'dong': '2\uD558\uC6B0\uC2A4',
      'jung': '1\uC911',
    });
    expect(cam.dong, '1\uC81C\uC5B4\uAE30');
    expect(cam.name, '1\uC81C\uC5B4\uAE30 1\uC911 \uCE74\uBA54\uB77C');

    final ctl = ControlElement.fromJson({
      'name': '\uCC9C\uCC3D',
      'dong': '2\uD558\uC6B0\uC2A4',
      'jung': '1\uC911',
    });
    expect(ctl.dong, '1\uC81C\uC5B4\uAE30');

    final sensor = SensorEndpoint.fromJson({
      'name': '2\uD558\uC6B0\uC2A4 \uC13C\uC11C',
      'dong': '2\uD558\uC6B0\uC2A4',
    });
    expect(sensor.dong, '1\uC81C\uC5B4\uAE30');
    expect(sensor.name, '1\uC81C\uC5B4\uAE30 \uC13C\uC11C');
  });

  test('site bgColor persists in json', () {
    final site = FarmSite(name: 'c', bgColor: 0xFF14532D);
    final back = FarmSite.fromJson(site.toJson());
    expect(back.bgColor, 0xFF14532D);
    final legacy = FarmSite.fromJson({
      'name': 'old',
      'cameras': [],
      'controls': [],
    });
    expect(legacy.bgColor, FarmSite.kDefaultSiteBgColor);
  });

  test('house default camera selection', () {
    final site = FarmSite.demo();
    final cams = site.cameras.where((c) => c.dong == '1\uC81C\uC5B4\uAE30').toList();
    expect(cams.length, greaterThanOrEqualTo(2));
    expect(site.cameraForDong('1\uC81C\uC5B4\uAE30')!.id, cams.first.id);

    site.setHouseDefaultCamera('1\uC81C\uC5B4\uAE30', cams.last.id);
    expect(site.cameraForDong('1\uC81C\uC5B4\uAE30')!.id, cams.last.id);
    expect(site.isHouseDefaultCamera(cams.last), isTrue);

    final back = FarmSite.fromJson(site.toJson());
    expect(back.houseDefaultCameras['1\uC81C\uC5B4\uAE30'], cams.last.id);
    expect(back.cameraForDong('1\uC81C\uC5B4\uAE30')!.id, cams.last.id);

    site.cameras.removeWhere((c) => c.id == cams.last.id);
    site.pruneHouseDefaultCameras();
    expect(site.houseDefaultCameras.containsKey('1\uC81C\uC5B4\uAE30'), isFalse);
    expect(site.cameraForDong('1\uC81C\uC5B4\uAE30')!.id, isNot(cams.last.id));
  });

  test('control default pair name and presets', () {
    expect(ControlElement.defaultPairName(0), ControlElement.defaultPairName(0));
    expect(ControlElement.defaultPairName(7), ControlElement.defaultPairName(7));
    expect(ControlElement.isDefaultChannelName(ControlElement.defaultPairName(0)), isTrue);
    expect(ControlElement.isDefaultChannelName('1\uC911\uCC9C\uCC3D(\uC88C)'), isFalse);
    expect(ControlElement.presetNames, contains('\uBD80\uC9C1\uD3EC(\uB4A4)'));
    expect(ControlElement.presetNames, containsAll(['\uC218\uD3C9\uCEE4\uD2BC', '\uADF8\uB298\uB9C9']));
    expect(ControlElement.jungForPreset('2\uC911\uCE21\uCC3D'), '2\uC911');
    expect(ControlElement.jungForPreset('\uC218\uD3C9\uCEE4\uD2BC'), '\uCEE4\uD2BC');
    expect(ControlElement.jungForPreset('\uADF8\uB298\uB9C9'), '\uADF8\uB298\uB9C9');

    final site = FarmSite.demo();
    expect(
      site.controls.every((c) => ControlElement.isDefaultChannelName(c.name)),
      isTrue,
    );
    final renamed = FarmSite.fromJson({
      'name': 't',
      'controls': [
        {
          'name': '1\uC911\uCC9C\uCC3D(\uC88C)',
          'kind': 'motorPair',
          'pairIndex': 2,
          'dong': '1\uC81C\uC5B4\uAE30',
        },
      ],
      'cameras': [],
    });
    renamed.applyDefaultControlNames();
    expect(renamed.controls.single.name, ControlElement.defaultPairName(2));
  });

  test('motor pair splits into two relay pins', () {
    final pair = ControlElement(
      name: ControlElement.defaultPairName(0),
      kind: ControlKind.motorPair,
      pairIndex: 0,
      dong: '1\uC81C\uC5B4\uAE30',
      boardId: 'board-a',
    );
    final (a, b) = ControlElement.splitPairToRelays(pair);
    expect(a.id, pair.id);
    expect(a.kind, ControlKind.relayToggle);
    expect(a.pinIndex, 0);
    expect(a.name, ControlElement.defaultPinName(0));
    expect(b.id, isNot(pair.id));
    expect(b.kind, ControlKind.relayToggle);
    expect(b.pinIndex, 1);
    expect(b.name, ControlElement.defaultPinName(1));
    expect(b.boardId, 'board-a');

    final named = ControlElement(
      name: '\uCE21\uCC3D',
      kind: ControlKind.motorPair,
      pairIndex: 1,
    );
    final (c, d) = ControlElement.splitPairToRelays(named);
    expect(c.name, '\uCE21\uCC3D\u00B7ch3');
    expect(d.name, '\uCE21\uCC3D\u00B7ch4');
    expect(c.pinIndex, 2);
    expect(d.pinIndex, 3);
  });

  test('relay pins merge back into motor pair', () {
    final pin1 = ControlElement(
      name: ControlElement.defaultPinName(0),
      kind: ControlKind.relayToggle,
      pinIndex: 0,
      pairIndex: 0,
      dong: '1\uC81C\uC5B4\uAE30',
      boardId: 'board-a',
    );
    final pair = ControlElement.mergeRelayToPair(pin1);
    expect(pair.kind, ControlKind.motorPair);
    expect(pair.pairIndex, 0);
    expect(pair.name, ControlElement.defaultPairName(0));
    expect(ControlElement.siblingPinIndex(0), 1);
    expect(ControlElement.siblingPinIndex(1), 0);
    expect(ControlElement.pairIndexFromPin(3), 1);

    final pin2 = ControlElement(
      name: ControlElement.defaultPinName(1),
      kind: ControlKind.relayToggle,
      pinIndex: 1,
      boardId: 'board-a',
    );
    final fromB = ControlElement.mergeRelayToPair(pin2);
    expect(fromB.pairIndex, 0);
    expect(fromB.name, ControlElement.defaultPairName(0));
  });

  test('camera numbered default names', () {
    final site = FarmSite.demo();
    expect(site.cameras.map((c) => c.name).toList(), [
      '1\uBC88 \uCE74\uBA54\uB77C',
      '2\uBC88 \uCE74\uBA54\uB77C',
      '3\uBC88 \uCE74\uBA54\uB77C',
    ]);
    final legacy = FarmSite.fromJson({
      'name': 't',
      'cameras': [
        {'name': '1\uD558\uC6B0\uC2A4 1\uC911 \uCE74\uBA54\uB77C', 'dong': '1\uD558\uC6B0\uC2A4'},
        {'name': '1\uD558\uC6B0\uC2A4 \uBD80\uC9C1\uD3EC \uCE74\uBA54\uB77C', 'dong': '1\uD558\uC6B0\uC2A4'},
      ],
      'controls': [],
    });
    legacy.applyNumberedCameraNames();
    expect(legacy.cameras[0].name, '1\uBC88 \uCE74\uBA54\uB77C');
    expect(legacy.cameras[1].name, '2\uBC88 \uCE74\uBA54\uB77C');
    expect(legacy.nextCameraDefaultName(), '3\uBC88 \uCE74\uBA54\uB77C');
  });

  test('applyControllerGroupLabelMigration rewrites legacy house', () {
    final site = FarmSite.fromJson({
      'name': 't',
      'boards': [
        {'name': '1\uD558\uC6B0\uC2A4-\uBCF4\uB4DC1', 'dong': '1\uD558\uC6B0\uC2A4'},
      ],
      'cameras': [
        {'id': 'x', 'name': 'cam', 'dong': '1\uD558\uC6B0\uC2A4'},
      ],
      'controls': [],
      'sensors': [
        {'name': '1\uD558\uC6B0\uC2A4 \uC13C\uC11C', 'dong': '1\uD558\uC6B0\uC2A4'},
      ],
      'houseDefaultCameras': {'1\uD558\uC6B0\uC2A4': 'x'},
    });
    site.applyControllerGroupLabelMigration();
    expect(site.boards.first.dong, '1\uC81C\uC5B4\uAE30');
    expect(site.boards.first.name, '1\uC81C\uC5B4\uAE30-\uBCF4\uB4DC1');
    expect(site.sensors.first.dong, '1\uC81C\uC5B4\uAE30');
    expect(site.houseDefaultCameras.containsKey('1\uC81C\uC5B4\uAE30'), isTrue);
  });
}
