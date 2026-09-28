import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 제어 버튼용 삑 소리 (앱에서 생성한 WAV 톤).
class ControlBeep {
  ControlBeep._();

  static AudioPlayer? _player;
  static bool _contextReady = false;
  static Future<void>? _chain;
  static final Map<String, String> _wavPaths = {};

  static Future<AudioPlayer> _playerReady() async {
    final existing = _player;
    if (existing != null) return existing;

    final p = AudioPlayer();
    await p.setReleaseMode(ReleaseMode.stop);
    await p.setVolume(1.0);
    // lowLatency + BytesSource 조합은 Android에서 재재생이 깨지는 경우가 많음
    await p.setPlayerMode(PlayerMode.mediaPlayer);

    if (!_contextReady) {
      try {
        await AudioPlayer.global.setAudioContext(
          AudioContext(
            android: const AudioContextAndroid(
              isSpeakerphoneOn: false,
              stayAwake: false,
              contentType: AndroidContentType.sonification,
              usageType: AndroidUsageType.assistanceSonification,
              audioFocus: AndroidAudioFocus.gainTransientMayDuck,
            ),
            iOS: AudioContextIOS(
              category: AVAudioSessionCategory.ambient,
              options: {AVAudioSessionOptions.mixWithOthers},
            ),
          ),
        );
      } catch (e) {
        debugPrint('ControlBeep audioContext: $e');
      }
      _contextReady = true;
    }

    _player = p;
    return p;
  }

  /// 열기 / ON
  static Future<void> open() => _enqueue(
        () => _play(freqHz: 2000, ms: 90),
      );

  /// 닫기
  static Future<void> close() => _enqueue(
        () => _play(freqHz: 1600, ms: 90),
      );

  /// 정지 / OFF — 삑삑
  static Future<void> stop() => _enqueue(() async {
        await _play(freqHz: 1400, ms: 55);
        await Future<void>.delayed(const Duration(milliseconds: 60));
        await _play(freqHz: 1400, ms: 55);
      });

  static Future<void> forMotorAction(int action) async {
    if (action == 1) {
      await open();
    } else if (action == 2) {
      await close();
    } else {
      await stop();
    }
  }

  static Future<void> forRelay(int val) async {
    if (val != 0) {
      await open();
    } else {
      await stop();
    }
  }

  static Future<void> _enqueue(Future<void> Function() job) {
    final prev = _chain ?? Future<void>.value();
    _chain = prev.then((_) => job()).catchError((Object e, StackTrace st) {
      debugPrint('ControlBeep chain: $e\n$st');
    });
    return _chain!;
  }

  static Future<String> _wavFile({required int freqHz, required int ms}) async {
    final key = '${freqHz}_$ms';
    final cached = _wavPaths[key];
    if (cached != null && File(cached).existsSync()) return cached;

    final dir = await Directory.systemTemp.createTemp('smart_farm_beep_');
    final path = '${dir.path}/beep_$key.wav';
    final file = File(path);
    await file.writeAsBytes(
      _sineWav(freqHz: freqHz, durationMs: ms),
      flush: true,
    );
    _wavPaths[key] = path;
    return path;
  }

  static Future<void> _play({required int freqHz, required int ms}) async {
    try {
      final path = await _wavFile(freqHz: freqHz, ms: ms);
      final player = await _playerReady();
      await player.stop();
      await player.play(DeviceFileSource(path));
      await Future<void>.delayed(Duration(milliseconds: ms + 30));
    } catch (e, st) {
      debugPrint('ControlBeep play failed: $e\n$st');
      try {
        // 최후 수단: 시스템 클릭음이라도 재생
        await SystemSound.play(SystemSoundType.click);
      } catch (_) {}
    }
  }

  static Uint8List _sineWav({
    required int freqHz,
    required int durationMs,
    int sampleRate = 22050,
  }) {
    final n = (sampleRate * durationMs / 1000).round().clamp(1, sampleRate);
    final dataSize = n * 2;
    final bytes = BytesBuilder();

    void writeString(String s) => bytes.add(s.codeUnits);
    void writeUint32(int v) {
      bytes
          .add([v & 0xff, (v >> 8) & 0xff, (v >> 16) & 0xff, (v >> 24) & 0xff]);
    }

    void writeUint16(int v) {
      bytes.add([v & 0xff, (v >> 8) & 0xff]);
    }

    writeString('RIFF');
    writeUint32(36 + dataSize);
    writeString('WAVE');
    writeString('fmt ');
    writeUint32(16);
    writeUint16(1); // PCM
    writeUint16(1); // mono
    writeUint32(sampleRate);
    writeUint32(sampleRate * 2);
    writeUint16(2);
    writeUint16(16);
    writeString('data');
    writeUint32(dataSize);

    final twoPiF = 2 * pi * freqHz;
    final fade = (sampleRate * 0.004).round().clamp(1, n ~/ 3);
    for (var i = 0; i < n; i++) {
      final t = i / sampleRate;
      var env = 1.0;
      if (i < fade) env = i / fade;
      if (i > n - fade) env = (n - i) / fade;
      final sample = (sin(twoPiF * t) * 0.85 * env * 32767).round().clamp(
            -32768,
            32767,
          );
      writeUint16(sample < 0 ? sample + 65536 : sample);
    }
    return bytes.toBytes();
  }
}
