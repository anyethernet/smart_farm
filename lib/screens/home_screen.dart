import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/camera_source.dart';
import '../models/control_element.dart';
import '../models/house_label.dart';
import '../models/farm_site.dart';
import '../models/sensor_endpoint.dart';
import '../state/farm_controller.dart';
import '../widgets/camera_player.dart';
import '../widgets/control_panel.dart';
import '../widgets/sensor_panel.dart';
import 'site_editor_screen.dart';
import 'sites_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _house; // 예: 1제어기
  final _pageController = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _syncSelection(FarmSite site) {
    final houses = site.dongList;
    if (_house == null || !houses.contains(_house)) {
      _house = houses.isEmpty ? null : houses.first;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<FarmController>().setSensorDong(_house);
    });
  }

  List<SensorEndpoint> _sensorsForDong(FarmSite site, String? dong) {
    return site.sensorsForDong(dong);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<FarmController>();
    final site = ctrl.activeSite;
    if (site != null) _syncSelection(site);

    final dong = _house;
    final focused = ctrl.focusedControl;

    // 제어 선택/조작 시 → 해당 제어 영상, 아니면 하우스 대표 영상
    CameraSource? cam;
    if (site != null && focused != null && focused.dong == dong) {
      cam = site.cameraForControl(focused);
    } else if (site != null) {
      cam = site.cameraForDong(dong);
    }

    final houses = site?.dongList ?? const <String>[];
    final sensors =
        site == null ? const <SensorEndpoint>[] : _sensorsForDong(site, dong);

    return Scaffold(
      appBar: AppBar(
        title: _SiteTitleMenu(
          sites: ctrl.sites,
          active: site,
          subtitle: _page == 0 ? null : '센서 · ${dong ?? ""}',
          onSelect: (id) async {
            await ctrl.selectSite(id);
            if (mounted) setState(() => _house = null);
          },
          onManage: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SitesScreen()),
            );
          },
        ),
        actions: [
          IconButton(
            tooltip: '로그인',
            onPressed: ctrl.busy ? null : () => ctrl.ensureLogin(),
            icon: const Icon(Icons.login),
          ),
          IconButton(
            tooltip: '상태 새로고침',
            onPressed: () async {
              await ctrl.refreshState();
              await ctrl.refreshSensor();
            },
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: '사이트 / 설정',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SitesScreen()),
              );
            },
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: site == null
          ? _EmptyHome(
              onAddSite: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SitesScreen()),
                );
              },
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: _StatusBanner(ctrl: ctrl, site: site),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: Text(
                    kControlGroupLabel,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    scrollDirection: Axis.horizontal,
                    itemCount: houses.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final h = houses[i];
                      return ChoiceChip(
                        label: Text(h),
                        selected: _house == h,
                        onSelected: (_) {
                          setState(() => _house = h);
                          context.read<FarmController>().setSensorDong(h);
                          // 하우스 바꾸면 대표 영상으로 (제어 포커스 해제)
                          ctrl.focusControl(null);
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                _PageTabs(
                  page: _page,
                  onSelect: (i) {
                    _pageController.animateToPage(
                      i,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                    );
                  },
                ),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (i) => setState(() => _page = i),
                    children: [
                      _ControlPage(
                        site: site,
                        ctrl: ctrl,
                        cam: cam,
                        focused: focused,
                        house: dong,
                        onSelectControl: (el) {
                          setState(() => _house = el.dong);
                          ctrl.setSensorDong(el.dong);
                          ctrl.focusControl(el.id);
                        },
                      ),
                      _SensorPage(
                        ctrl: ctrl,
                        dong: dong,
                        sensors: sensors,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _PageTabs extends StatelessWidget {
  const _PageTabs({required this.page, required this.onSelect});

  final int page;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: _TabChip(
              label: '제어 · 영상',
              selected: page == 0,
              onTap: () => onSelect(0),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _TabChip(
              label: '센서 →',
              selected: page == 1,
              onTap: () => onSelect(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHome extends StatelessWidget {
  const _EmptyHome({required this.onAddSite});

  final VoidCallback onAddSite;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.agriculture_outlined,
              size: 64,
              color: Colors.white.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            const Text(
              '농장을 추가하세요',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            const Text(
              '제어보드·IP카메라·센서 주소를 직접 입력하면 같은 네트워크의 장비에 연결합니다. '
              '개발자 서버로 영상이 전송되지 않습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF94A3B8), height: 1.5),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAddSite,
              icon: const Icon(Icons.add),
              label: const Text('사이트 / 설정'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 좌측 상단 사이트 이름 — 탭하면 사이트 목록에서 선택.
class _SiteTitleMenu extends StatelessWidget {
  const _SiteTitleMenu({
    required this.sites,
    required this.active,
    required this.onSelect,
    required this.onManage,
    this.subtitle,
  });

  final List<FarmSite> sites;
  final FarmSite? active;
  final ValueChanged<String> onSelect;
  final VoidCallback onManage;
  final String? subtitle;

  static const _manageKey = '__manage_sites__';

  @override
  Widget build(BuildContext context) {
    final label = active?.name ?? '스마트팜';
    if (sites.isEmpty) {
      return Text(label);
    }

    return PopupMenuButton<String>(
      tooltip: '사이트 선택',
      offset: const Offset(0, 40),
      onSelected: (id) {
        if (id == _manageKey) {
          onManage();
          return;
        }
        if (id != active?.id) onSelect(id);
      },
      itemBuilder: (ctx) => [
        for (final s in sites)
          PopupMenuItem<String>(
            value: s.id,
            child: Row(
              children: [
                SizedBox(
                  width: 22,
                  child: s.id == active?.id
                      ? const Icon(Icons.check, size: 18, color: Colors.tealAccent)
                      : null,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    s.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: _manageKey,
          child: Row(
            children: [
              Icon(Icons.settings, size: 18),
              SizedBox(width: 10),
              Text('사이트 설정…'),
            ],
          ),
        ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Colors.white70,
                    ),
                  ),
              ],
            ),
          ),
          const Icon(Icons.arrow_drop_down),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFF0EA5E9) : const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : const Color(0xFF94A3B8),
            ),
          ),
        ),
      ),
    );
  }
}

class _ControlPage extends StatelessWidget {
  const _ControlPage({
    required this.site,
    required this.ctrl,
    required this.cam,
    required this.focused,
    required this.house,
    required this.onSelectControl,
  });

  final FarmSite site;
  final FarmController ctrl;
  final CameraSource? cam;
  final ControlElement? focused;
  final String? house;
  final ValueChanged<ControlElement> onSelectControl;

  @override
  Widget build(BuildContext context) {
    final showingControlCam =
        focused != null && house != null && focused!.dong == house;
    return RefreshIndicator(
      onRefresh: () => ctrl.refreshState(),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const Text(
            '옆으로 밀면 센서 화면으로 이동합니다 →',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 8),
          if (cam == null)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('이 $kControlGroupLabel에 연결된 영상이 없습니다.'),
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    showingControlCam
                        ? '${focused!.name} · ${cam!.name}'
                        : '대표 · ${cam!.name}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SiteEditorScreen(site: site.copy()),
                      ),
                    );
                  },
                  icon: const Icon(Icons.tune, size: 18),
                  label: const Text('정의'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            CameraPlayer(
              key: ValueKey('${cam!.id}_${cam!.playUrl}'),
              camera: cam!,
            ),
          ],
          const SizedBox(height: 12),
          Text(
            '제어 · ${house ?? ""}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          ControlPanel(
            dongFilter: house,
            onSelect: onSelectControl,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SensorPage extends StatelessWidget {
  const _SensorPage({
    required this.ctrl,
    required this.dong,
    required this.sensors,
  });

  final FarmController ctrl;
  final String? dong;
  final List<SensorEndpoint> sensors;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => ctrl.refreshSensor(),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text(
            '← 옆으로 밀면 제어·영상으로 돌아갑니다',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF64748B),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '센서 · Analog · ${dong ?? ""}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          if (sensors.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '이 $kControlGroupLabel에 등록된 센서가 없습니다.\n'
                  '사이트 편집 → 센서(Analog)에서 추가하세요.',
                ),
              ),
            )
          else ...[
            Text(
              '이 $kControlGroupLabel 센서 ${sensors.length}대',
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 6),
            for (final s in sensors)
              SensorPanel(
                sensor: s,
                reading: ctrl.readingForSensor(s.id),
                error: ctrl.errorForSensor(s.id),
              ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatefulWidget {
  const _StatusBanner({required this.ctrl, required this.site});

  final FarmController ctrl;
  final FarmSite site;

  @override
  State<_StatusBanner> createState() => _StatusBannerState();
}

class _StatusBannerState extends State<_StatusBanner> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.ctrl;
    final site = widget.site;
    final io = ctrl.ioState;
    final model = !io.hasData
        ? '미연결'
        : (io.tv16
            ? (io.ok ? 'TV16AVR (UART2)' : 'TV16AVR (AVR 대기)')
            : 'TV8BD/GPIO');
    final summary = ctrl.statusMessage.isNotEmpty
        ? ctrl.statusMessage
        : '보드 ${site.enabledBoards.length}대 · $model';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: const Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    '보드 상태',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '보드 ${site.enabledBoards.length}대 · '
                    '${site.enabledBoards.map((b) => b.displayHost).join(', ')}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Model: $model  ·  ${ctrl.statusMessage}',
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 13,
                    ),
                  ),
                  if (io.hasData) ...[
                    const SizedBox(height: 4),
                    Text(
                      'SETIOCONFIG=${io.setIoConfigText}'
                      '${io.tv16 ? (io.ok ? " · ok" : " · AVR대기") : ""}',
                      style: const TextStyle(
                        color: Color(0xFF7DD3FC),
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                  if (io.tv16 && io.hasData && !io.ok) ...[
                    const SizedBox(height: 6),
                    const Text(
                      'AVR allstate/MCO 대기 중 — 제어는 가능, 상태 표시는 응답 후 갱신',
                      style: TextStyle(color: Color(0xFFFBBF24), fontSize: 12),
                    ),
                  ],
                  if (io.hasData) ...[
                    const SizedBox(height: 6),
                    Text(
                      'RAW s=[${io.states.join(",")}] cfg=${io.cfg}',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
