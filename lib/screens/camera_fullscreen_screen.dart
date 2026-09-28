import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';

import '../models/camera_source.dart';
import '../models/house_label.dart';
import '../state/farm_controller.dart';
import '../widgets/http_snapshot_player.dart';
import '../widgets/ptz_pad.dart';

/// Full-screen live view with pinch-to-zoom (+ PTZ when enabled).
/// Same-house cameras can be cycled with left/right controls.
class CameraFullscreenScreen extends StatefulWidget {
  const CameraFullscreenScreen({
    super.key,
    required this.camera,
    this.cameras,
  });

  final CameraSource camera;

  /// Same-house cameras to browse. If null, taken from the active site.
  final List<CameraSource>? cameras;

  @override
  State<CameraFullscreenScreen> createState() => _CameraFullscreenScreenState();
}

class _CameraFullscreenScreenState extends State<CameraFullscreenScreen> {
  late List<CameraSource> _cameras;
  late int _index;

  Player? _player;
  VideoController? _controller;
  final TransformationController _transform = TransformationController();
  String? _error;
  bool _busy = false;

  CameraSource get _camera => _cameras[_index];

  bool get _isSnapshot => _camera.isSnapshotType;

  bool get _canBrowse => _cameras.length > 1;

  @override
  void initState() {
    super.initState();
    _cameras = _resolveCameras();
    _index = _cameras.indexWhere((c) => c.id == widget.camera.id);
    if (_index < 0) {
      _cameras = [widget.camera, ..._cameras];
      _index = 0;
    }
    _startCurrent();
  }

  List<CameraSource> _resolveCameras() {
    final provided = widget.cameras;
    if (provided != null && provided.isNotEmpty) {
      return List<CameraSource>.from(provided);
    }
    final site = context.read<FarmController>().activeSite;
    if (site == null) return [widget.camera];
    final dong = widget.camera.dong;
    final same = site.cameras
        .where((c) => c.dong == dong && c.enabled)
        .toList();
    if (same.isEmpty) return [widget.camera];
    if (!same.any((c) => c.id == widget.camera.id)) {
      return [widget.camera, ...same];
    }
    return same;
  }

  void _startCurrent() {
    _error = null;
    _transform.value = Matrix4.identity();
    if (_isSnapshot) {
      _disposePlayer();
      return;
    }
    _player ??= Player(
      configuration: const PlayerConfiguration(
        bufferSize: 2 * 1024 * 1024,
        logLevel: MPVLogLevel.warn,
      ),
    );
    _controller ??= VideoController(_player!);
    _open();
  }

  void _disposePlayer() {
    _player?.dispose();
    _player = null;
    _controller = null;
  }

  Future<void> _open() async {
    final player = _player;
    if (player == null) return;
    final cam = _camera;
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      final platform = player.platform;
      if (platform is NativePlayer) {
        if (cam.usesRtspPort && cam.useTcp) {
          await platform.setProperty('rtsp-transport', 'tcp');
        }
        await platform.setProperty('network-timeout', '10');
        await platform.setProperty('hwdec', 'auto');
      }
      await player.open(Media(cam.playUrl), play: true);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _go(int delta) async {
    if (!_canBrowse || _busy) return;
    final next = (_index + delta) % _cameras.length;
    final wrapped = next < 0 ? next + _cameras.length : next;
    if (wrapped == _index) return;

    setState(() {
      _index = wrapped;
      _error = null;
      _transform.value = Matrix4.identity();
    });

    if (_isSnapshot) {
      _disposePlayer();
      setState(() {});
      return;
    }

    if (_player == null) {
      _player = Player(
        configuration: const PlayerConfiguration(
          bufferSize: 2 * 1024 * 1024,
          logLevel: MPVLogLevel.warn,
        ),
      );
      _controller = VideoController(_player!);
    }
    await _open();
  }

  @override
  void dispose() {
    _transform.dispose();
    _disposePlayer();
    super.dispose();
  }

  void _resetZoom() {
    _transform.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    final cam = _camera;
    final videoBody = _isSnapshot
        ? HttpSnapshotPlayer(
            key: ValueKey('snap_${cam.id}'),
            camera: cam,
            showExpand: false,
            interactive: true,
          )
        : _error != null
            ? Center(
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.white70),
                ),
              )
            : InteractiveViewer(
                transformationController: _transform,
                minScale: 1,
                maxScale: 6,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: _controller == null
                        ? const SizedBox.shrink()
                        : Video(
                            controller: _controller!,
                            controls: NoVideoControls,
                          ),
                  ),
                ),
              );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(cam.name, style: const TextStyle(fontSize: 16)),
            if (_canBrowse)
              Text(
                '${cam.dong} · ${_index + 1}/${_cameras.length}',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '줌 초기화',
            onPressed: _resetZoom,
            icon: const Icon(Icons.zoom_out_map),
          ),
          if (!_isSnapshot)
            IconButton(
              tooltip: '다시 연결',
              onPressed: _busy ? null : _open,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                videoBody,
                if (_busy)
                  const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                if (_canBrowse) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: _NavButton(
                        icon: Icons.chevron_left,
                        tooltip: '이전 카메라',
                        onPressed: _busy ? null : () => _go(-1),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: _NavButton(
                        icon: Icons.chevron_right,
                        tooltip: '다음 카메라',
                        onPressed: _busy ? null : () => _go(1),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (cam.ptzEnabled)
            Container(
              width: double.infinity,
              color: const Color(0xFF0F172A),
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: SafeArea(
                top: false,
                child: PtzPad(key: ValueKey('ptz_${cam.id}'), camera: cam),
              ),
            )
          else
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  _canBrowse
                      ? '← → 같은 $kControlGroupLabel 카메라 · 두 손가락으로 확대'
                      : '두 손가락으로 확대 · 드래그로 이동',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        iconSize: 36,
        color: Colors.white,
        icon: Icon(icon),
      ),
    );
  }
}
