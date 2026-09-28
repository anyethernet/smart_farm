import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/control_element.dart';
import '../models/io_state.dart';
import '../models/house_label.dart';
import '../state/farm_controller.dart';

class ControlPanel extends StatelessWidget {
  const ControlPanel({
    super.key,
    this.dongFilter,
    this.onSelect,
  });

  final String? dongFilter;
  final ValueChanged<ControlElement>? onSelect;

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<FarmController>();
    final site = ctrl.activeSite;
    if (site == null) return const Text('사이트를 추가하세요.');

    var items = site.enabledControls;
    if (dongFilter != null) {
      items = items.where((e) => e.dong == dongFilter).toList();
    }
    if (items.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('이 $kControlGroupLabel에 제어 요소가 없습니다. 설정에서 추가하세요.'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (ctrl.activeSite != null &&
            ctrl.activeSite!.enabledBoards.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              ctrl.activeSite!.enabledBoards.map((b) {
                final st = ctrl.boardIoStates[b.id];
                if (st == null || !st.hasData) {
                  return '${b.name}(대기)';
                }
                final model = st.tv16 ? 'TV16' : 'TV8';
                return '${b.name}($model SETIOCONFIG=${st.setIoConfigText})';
              }).join(' · '),
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          ),
        for (final el in items) ..._cardsFor(ctrl, el, onSelect),
      ],
    );
  }

  List<Widget> _cardsFor(
    FarmController ctrl,
    ControlElement el,
    ValueChanged<ControlElement>? onSelect,
  ) {
    // 채널 쌍이지만 개별 ON/OFF UI인 경우(현재는 relay만) — 하위 호환 분기
    if (el.kind == ControlKind.motorPair && !ctrl.usesMotorUi(el)) {
      final p0 = el.pairIndex * 2;
      final p1 = p0 + 1;
      return [
        _ControlCard(
          key: ValueKey('${el.id}:$p0'),
          element: el,
          pinOverride: p0,
          selected:
              ctrl.focusedControlId == el.id && ctrl.focusedPinIndex == p0,
          onSelect: onSelect,
        ),
        _ControlCard(
          key: ValueKey('${el.id}:$p1'),
          element: el,
          pinOverride: p1,
          selected:
              ctrl.focusedControlId == el.id && ctrl.focusedPinIndex == p1,
          onSelect: onSelect,
        ),
      ];
    }
    return [
      _ControlCard(
        key: ValueKey(el.id),
        element: el,
        selected: ctrl.focusedControlId == el.id,
        onSelect: onSelect,
      ),
    ];
  }
}

Future<bool> _confirmControl(
  BuildContext context, {
  required ControlElement element,
  required String actionLabel,
  String? channelLabel,
}) async {
  final ch = channelLabel == null ? '' : ' · $channelLabel';
  final title = '${element.name}$ch';
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('제어 확인'),
      content: Text('$title\n\n「$actionLabel」을(를) 실행할까요?'),
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
  );
  return ok == true;
}

class _ControlCard extends StatelessWidget {
  const _ControlCard({
    super.key,
    required this.element,
    required this.selected,
    this.onSelect,
    this.pinOverride,
  });

  final ControlElement element;
  final bool selected;
  final ValueChanged<ControlElement>? onSelect;

  /// 개별 모드에서 분리된 채널 핀(0-based). null이면 모터쌍/단일 핀 정의 그대로.
  final int? pinOverride;

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<FarmController>();
    final io = ctrl.ioStateFor(element);
    final theme = Theme.of(context);
    final motorUi = ctrl.usesMotorUi(element);

    if (pinOverride != null) {
      return _singleRelayCard(
        context,
        ctrl,
        theme,
        pin: pinOverride!,
      );
    }

    if (element.kind == ControlKind.motorPair && motorUi) {
      return _motorCard(context, ctrl, io, theme);
    }

    return _singleRelayCard(
      context,
      ctrl,
      theme,
      pin: element.pinIndex,
    );
  }

  Future<void> _runMotor(
    BuildContext context,
    FarmController ctrl,
    int action,
    String actionLabel,
  ) async {
    ctrl.focusControl(element.id);
    onSelect?.call(element);
    final ok = await _confirmControl(
      context,
      element: element,
      actionLabel: actionLabel,
    );
    if (!ok || !context.mounted) return;
    await ctrl.runMotor(element, action);
  }

  Future<void> _runRelay(
    BuildContext context,
    FarmController ctrl,
    int val,
    String actionLabel, {
    required int pin,
  }) async {
    ctrl.focusControl(element.id, pinIndex: pin);
    onSelect?.call(element);
    final ok = await _confirmControl(
      context,
      element: element,
      actionLabel: actionLabel,
      channelLabel: 'ch${pin + 1}',
    );
    if (!ok || !context.mounted) return;
    await ctrl.runRelay(element, val, pinOverride: pin);
  }

  Widget _shell({required Widget child}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? const Color(0xFF38BDF8) : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // focus handled by parent via Provider in buttons; still allow tap
        },
        child: Padding(padding: const EdgeInsets.all(12), child: child),
      ),
    );
  }

  Widget _motorCard(
    BuildContext context,
    FarmController ctrl,
    IoState io,
    ThemeData theme,
  ) {
    final ui = ctrl.displayMotor(element);
    final detail = io.motorDetail(element.pairIndex);
    return _shell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  element.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _StatusChip(ui: ui),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${ctrl.activeSite?.boardForControl(element)?.name ?? '보드'} · '
            '쌍 ${element.pairIndex + 1} · $detail',
            style: theme.textTheme.bodySmall?.copyWith(
              color: const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _CmdButton(
                  label: element.upLabel,
                  emphasized: ui == MotorPairUi.up,
                  color: Colors.teal,
                  onPressed: () => _runMotor(
                    context,
                    ctrl,
                    MotorAction.up,
                    element.upLabel,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CmdButton(
                  label: element.stopLabel,
                  emphasized: ui == MotorPairUi.stop,
                  color: Colors.blueGrey,
                  onPressed: () => _runMotor(
                    context,
                    ctrl,
                    MotorAction.stop,
                    element.stopLabel,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CmdButton(
                  label: element.downLabel,
                  emphasized: ui == MotorPairUi.down,
                  color: Colors.indigo,
                  onPressed: () => _runMotor(
                    context,
                    ctrl,
                    MotorAction.down,
                    element.downLabel,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _singleRelayCard(
    BuildContext context,
    FarmController ctrl,
    ThemeData theme, {
    required int pin,
  }) {
    final on = ctrl.displayRelayOn(element, pinOverride: pin);
    final chLabel = 'ch${pin + 1}';
    final fromPair = element.kind == ControlKind.motorPair;
    return _shell(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fromPair ? '${element.name} · ch${pin + 1}' : element.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  fromPair
                      ? '${ctrl.activeSite?.boardForControl(element)?.name ?? '보드'} · '
                          'SETIOCONFIG 쌍${element.pairIndex + 1}=개별 · '
                          '${on ? "ON" : "OFF"}'
                      : '핀 ${pin + 1} · ${on ? "ON" : "OFF"}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: on ? Colors.teal : Colors.blueGrey.shade700,
            ),
            onPressed: () {
              final next = on ? 0 : 1;
              final label =
                  '$chLabel ${next == 1 ? element.onLabel : element.offLabel}';
              _runRelay(context, ctrl, next, label, pin: pin);
            },
            child: Text(
              '$chLabel ${on ? element.onLabel : element.offLabel}',
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.ui});

  final MotorPairUi ui;

  @override
  Widget build(BuildContext context) {
    late String label;
    late Color color;
    switch (ui) {
      case MotorPairUi.up:
        label = '열림';
        color = Colors.teal;
      case MotorPairUi.down:
        label = '닫힘';
        color = Colors.indigo;
      case MotorPairUi.stop:
        label = '정지';
        color = Colors.blueGrey;
      case MotorPairUi.unknown:
        label = '대기';
        color = Colors.grey;
      case MotorPairUi.conflict:
        label = '충돌';
        color = Colors.orange;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _CmdButton extends StatelessWidget {
  const _CmdButton({
    required this.label,
    required this.emphasized,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final bool emphasized;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (emphasized) {
      return FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: onPressed,
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      );
    }
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white70,
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}
