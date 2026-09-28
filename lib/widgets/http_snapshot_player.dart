import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/camera_source.dart';
import '../screens/camera_fullscreen_screen.dart';

/// HTTP 80 ISAPI JPEG 폴링 — 웹 포트만 열려 있을 때 사용.
class HttpSnapshotPlayer extends StatefulWidget {
  const HttpSnapshotPlayer({
    super.key,
    required this.camera,
    this.showExpand = true,
    this.interactive = false,
  });

  final CameraSource camera;
  final bool showExpand;
  final bool interactive;

  @override
  State<HttpSnapshotPlayer> createState() => _HttpSnapshotPlayerState();
}

class _HttpSnapshotPlayerState extends State<HttpSnapshotPlayer> {
  final http.Client _client = http.Client();
  Uint8List? _bytes;
  String? _error;
  Timer? _timer;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(
      Duration(milliseconds: widget.camera.snapshotIntervalMs.clamp(150, 2000)),
      (_) => _tick(),
    );
  }

  @override
  void didUpdateWidget(covariant HttpSnapshotPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.camera.playUrl != widget.camera.playUrl ||
        oldWidget.camera.snapshotIntervalMs !=
            widget.camera.snapshotIntervalMs) {
      _timer?.cancel();
      _timer = Timer.periodic(
        Duration(
          milliseconds: widget.camera.snapshotIntervalMs.clamp(150, 2000),
        ),
        (_) => _tick(),
      );
      _tick();
    }
  }

  Future<void> _tick() async {
    if (_loading || !mounted) return;
    _loading = true;
    try {
      final res = await _client
          .get(
            widget.camera.snapshotUri,
            headers: widget.camera.basicAuthHeaders,
          )
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        if (mounted) {
          setState(() {
            _bytes = res.bodyBytes;
            _error = null;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'HTTP ${res.statusCode} (웹 포트 ${widget.camera.httpPort})\n'
                'Basic 인증이 꺼져 있으면 카메라에서 허용하거나 Digest 지원 필요';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'HTTP 스냅샷 실패: $e');
      }
    } finally {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _client.close();
    super.dispose();
  }

  Widget _image() {
    if (_error != null && _bytes == null) {
      return Column(
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
          const SizedBox(height: 12),
          FilledButton(onPressed: _tick, child: const Text('다시 시도')),
        ],
      );
    }
    if (_bytes == null) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    final img = Image.memory(
      _bytes!,
      fit: BoxFit.contain,
      gaplessPlayback: true,
    );
    if (widget.interactive) {
      return InteractiveViewer(
        minScale: 1,
        maxScale: 6,
        child: Center(child: img),
      );
    }
    return img;
  }

  @override
  Widget build(BuildContext context) {
    final stack = Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: const Color(0xFF0B1220), child: _image()),
        Positioned(
          left: 10,
          bottom: 10,
          right: 56,
          child: Text(
            '${widget.camera.name} · HTTP:${widget.camera.httpPort}',
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
                    builder: (_) =>
                        CameraFullscreenScreen(camera: widget.camera),
                  ),
                );
              },
              icon: const Icon(Icons.fullscreen),
            ),
          ),
      ],
    );

    if (widget.interactive) {
      return stack;
    }

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
          child: stack,
        ),
      ),
    );
  }
}
