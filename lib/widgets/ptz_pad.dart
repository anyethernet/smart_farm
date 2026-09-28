import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/camera_source.dart';
import '../services/control_beep.dart';
import '../services/ptz_client.dart';

/// 길게 누르는 동안 PTZ 이동, 손을 떼면 정지.
class PtzPad extends StatefulWidget {
  const PtzPad({super.key, required this.camera});

  final CameraSource camera;

  @override
  State<PtzPad> createState() => _PtzPadState();
}

class _PtzPadState extends State<PtzPad> {
  late PtzClient _client;
  String? _status;

  @override
  void initState() {
    super.initState();
    _client = PtzClient(widget.camera);
  }

  @override
  void didUpdateWidget(covariant PtzPad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.camera.id != widget.camera.id ||
        oldWidget.camera.host != widget.camera.host) {
      _client.dispose();
      _client = PtzClient(widget.camera);
    }
  }

  @override
  void dispose() {
    _client.stop();
    _client.dispose();
    super.dispose();
  }

  Future<void> _start(PtzDir dir) async {
    HapticFeedback.selectionClick();
    ControlBeep.open();
    final ok = await _client.move(dir);
    if (!mounted) return;
    setState(() {
      _status = ok ? null : (_client.lastError ?? 'PTZ 실패');
    });
  }

  Future<void> _stop() async {
    await _client.stop();
  }

  Widget _btn({
    required IconData icon,
    required PtzDir dir,
    String? label,
  }) {
    return Listener(
      onPointerDown: (_) => _start(dir),
      onPointerUp: (_) => _stop(),
      onPointerCancel: (_) => _stop(),
      child: Material(
        color: const Color(0xFF334155),
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 52,
          height: 52,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              if (label != null)
                Text(label,
                    style: const TextStyle(fontSize: 9, color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.camera.ptzEnabled) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Text(
          'PTZ (${widget.camera.isHanwha ? "한화" : "하이크"}) — 길게 눌러 이동',
          style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _btn(icon: Icons.zoom_in, dir: PtzDir.zoomIn, label: '줌+'),
            const SizedBox(width: 12),
            Column(
              children: [
                _btn(icon: Icons.keyboard_arrow_up, dir: PtzDir.up),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _btn(icon: Icons.keyboard_arrow_left, dir: PtzDir.left),
                    const SizedBox(width: 6),
                    _btn(icon: Icons.stop, dir: PtzDir.stop, label: '정지'),
                    const SizedBox(width: 6),
                    _btn(icon: Icons.keyboard_arrow_right, dir: PtzDir.right),
                  ],
                ),
                const SizedBox(height: 6),
                _btn(icon: Icons.keyboard_arrow_down, dir: PtzDir.down),
              ],
            ),
            const SizedBox(width: 12),
            _btn(icon: Icons.zoom_out, dir: PtzDir.zoomOut, label: '줌-'),
          ],
        ),
        if (_status != null) ...[
          const SizedBox(height: 6),
          Text(
            _status!,
            style: const TextStyle(color: Colors.orangeAccent, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
