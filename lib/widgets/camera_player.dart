import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../models/camera_source.dart';
import '../screens/camera_fullscreen_screen.dart';
import 'http_snapshot_player.dart';

class CameraPlayer extends StatelessWidget {
  const CameraPlayer({
    super.key,
    required this.camera,
    this.showExpand = true,
  });

  final CameraSource camera;
  final bool showExpand;

  @override
  Widget build(BuildContext context) {
    if (camera.isSnapshotType) {
      return HttpSnapshotPlayer(
        key: ValueKey('snap_${camera.id}_${camera.playUrl}'),
        camera: camera,
        showExpand: showExpand,
      );
    }
    return _MediaKitPlayer(
      key: ValueKey('mk_${camera.id}_${camera.playUrl}'),
      camera: camera,
      showExpand: showExpand,
    );
  }
}

class _MediaKitPlayer extends StatefulWidget {
  const _MediaKitPlayer({
    super.key,
    required this.camera,
    required this.showExpand,
  });

  final CameraSource camera;
  final bool showExpand;

  @override
  State<_MediaKitPlayer> createState() => _MediaKitPlayerState();
}

class _MediaKitPlayerState extends State<_MediaKitPlayer> {
  late final Player _player;
  late final VideoController _controller;
  String? _error;
  bool _buffering = true;
  StreamSubscription<String>? _errSub;
  StreamSubscription<bool>? _bufSub;
  StreamSubscription<bool>? _playingSub;

  @override
  void initState() {
    super.initState();
    _player = Player(
      configuration: const PlayerConfiguration(
        bufferSize: 2 * 1024 * 1024,
        logLevel: MPVLogLevel.warn,
      ),
    );
    _controller = VideoController(_player);
    _errSub = _player.stream.error.listen((e) {
      if (!mounted || e.isEmpty) return;
      setState(() {
        _error = e;
        _buffering = false;
      });
    });
    _bufSub = _player.stream.buffering.listen((b) {
      if (mounted) setState(() => _buffering = b);
    });
    _playingSub = _player.stream.playing.listen((p) {
      if (mounted && p) setState(() => _error = null);
    });
    _open();
  }

  @override
  void didUpdateWidget(covariant _MediaKitPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.camera.playUrl != widget.camera.playUrl ||
        oldWidget.camera.useTcp != widget.camera.useTcp) {
      _open();
    }
  }

  Future<void> _applyOptions() async {
    try {
      final platform = _player.platform;
      if (platform is NativePlayer) {
        if (widget.camera.usesRtspPort && widget.camera.useTcp) {
          await platform.setProperty('rtsp-transport', 'tcp');
        }
        await platform.setProperty('network-timeout', '10');
        await platform.setProperty('demuxer-readahead-secs', '0.8');
        await platform.setProperty('hwdec', 'auto');
      }
    } catch (_) {}
  }

  Future<void> _open() async {
    setState(() {
      _error = null;
      _buffering = true;
    });
    final url = widget.camera.playUrl;
    if (url.isEmpty) {
      setState(() {
        _error = '카메라 URL이 비어 있습니다.';
        _buffering = false;
      });
      return;
    }
    try {
      await _applyOptions();
      await _player.stop();
      await _player.open(Media(url), play: true);
    } catch (e) {
      setState(() {
        _error = '영상 연결 실패: $e\n${widget.camera.safePlayUrl}';
        _buffering = false;
      });
    }
  }

  @override
  void dispose() {
    _errSub?.cancel();
    _bufSub?.cancel();
    _playingSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = _error != null
        ? Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.videocam_off, color: Colors.white70, size: 40),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
              const SizedBox(height: 8),
              if (widget.camera.type == CameraStreamType.hikvisionHttpPreview)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'HTTP Preview가 안 되면 스트림 타입을 '
                    '「HTTP 스냅샷」으로 바꿔 보세요 (같은 80 포트).',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.orangeAccent, fontSize: 11),
                  ),
                ),
              const SizedBox(height: 12),
              FilledButton(onPressed: _open, child: const Text('다시 연결')),
            ],
          )
        : Stack(
            fit: StackFit.expand,
            children: [
              Video(controller: _controller, controls: NoVideoControls),
              if (_buffering)
                const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              Positioned(
                left: 10,
                bottom: 10,
                right: 56,
                child: Text(
                  widget.camera.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                  ),
                ),
              ),
              if (widget.showExpand)
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: IconButton.filledTonal(
                    tooltip: '전체화면 · 확대',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CameraFullscreenScreen(
                            camera: widget.camera,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.fullscreen),
                  ),
                ),
            ],
          );

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF0B1220),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: body,
        ),
      ),
    );
  }
}
