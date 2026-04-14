import 'dart:ui' as ui;

import 'package:amap_flutter_base/amap_flutter_base.dart';
import 'package:amap_flutter_map/amap_flutter_map.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/location_api.dart';
import '../api/user_api.dart';
import '../providers/auth_provider.dart';
import '../services/location_service.dart';
import '../services/mqtt_service.dart';

/// 高德 SDK 8.1+ 要求首次展示地图前完成隐私合规；三者为 false 会白屏。
/// 正式上架前应在隐私弹窗取得用户同意后再设为 true。
const AMapPrivacyStatement _amapPrivacy = AMapPrivacyStatement(
  hasContains: true,
  hasShow: true,
  hasAgree: true,
);

/// 高德 Android Key（客户端内置，不请求后台）
const String _kAmapAndroidKey = '75499ac31c1dba8d9ffebc451f5332d3';

List<Map<String, dynamic>> _dedupeFamilyLocations(
    List<Map<String, dynamic>> raw) {
  final byId = <String, Map<String, dynamic>>{};
  for (final l in raw) {
    final id = l['user_id']?.toString() ?? '${l['latitude']}_${l['longitude']}';
    final existing = byId[id];
    if (existing == null) {
      byId[id] = l;
      continue;
    }
    final t1 = existing['recorded_at']?.toString() ?? '';
    final t2 = l['recorded_at']?.toString() ?? '';
    if (t2.compareTo(t1) > 0) byId[id] = l;
  }
  final list = byId.values.toList();
  list.sort((a, b) => (a['nickname']?.toString() ?? '')
      .compareTo(b['nickname']?.toString() ?? ''));
  return list;
}

String _fmtRecordedAt(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  final t = DateTime.tryParse(iso);
  if (t == null) return '—';
  return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});
  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final LocationService _locationService = LocationService();
  final MqttService _mqttService = MqttService();
  final LocationApi _locationApi = LocationApi();
  final UserApi _userApi = UserApi();
  List<Map<String, dynamic>> _familyLocations = [];
  Map<String, dynamic>? _myLocation;
  AMapController? _mapController;
  BitmapDescriptor _dotMarkerIcon =
      BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
  /// 延后一帧再挂载高德原生视图，减轻「VM Service 尚未就绪就加载 native .so」导致的调试连接失败；真机同样更稳。
  bool _mapSurfaceReady = false;

  @override
  void initState() {
    super.initState();
    _prepareDotMarkerIcon();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 400), () {
        if (mounted) setState(() => _mapSurfaceReady = true);
      });
    });
    _init();
  }

  Future<void> _init() async {
    final auth = ref.read(authProvider);
    if (auth.userId != null) {
      _mqttService.onLocationUpdate = (data) => setState(() {});
      await _mqttService.connect(auth.userId!);
    }
    await _loadLocations();
    await _startTracking();
  }

  Future<void> _loadLocations() async {
    try {
      _myLocation = await _locationApi.getLatest();
      final groups = await _userApi.getGroups();
      final locs = <Map<String, dynamic>>[];
      for (final g in groups) {
        try {
          final familyLocs = await _locationApi.getFamilyLocations(g['id']);
          for (final l in familyLocs) {
            locs.add(Map<String, dynamic>.from(l));
          }
        } catch (_) {}
      }
      setState(() => _familyLocations = _dedupeFamilyLocations(locs));
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _moveCameraToMyLocation());
    } catch (_) {}
  }

  Future<void> _startTracking() async {
    await _locationService.startTracking(
      onLocation: (pos) {
        setState(() {
          _myLocation = {'longitude': pos.longitude, 'latitude': pos.latitude};
        });
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _moveCameraToMyLocation());
      },
    );
  }

  Future<void> _prepareDotMarkerIcon() async {
    try {
      const size = 128.0;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final center = Offset(size / 2, size / 2);

      final outerPaint = Paint()..color = const Color(0x553E7FA5);
      canvas.drawCircle(center, 48, outerPaint);

      final middlePaint = Paint()..color = Colors.white;
      canvas.drawCircle(center, 32, middlePaint);

      final innerPaint = Paint()..color = const Color(0xFF0D66D0);
      canvas.drawCircle(center, 24, innerPaint);

      final image = await recorder.endRecording().toImage(size.toInt(), size.toInt());
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return;
      final bytes = data.buffer.asUint8List();
      if (!mounted) return;
      setState(() {
        _dotMarkerIcon = BitmapDescriptor.fromBytes(bytes);
      });
    } catch (_) {
      // 失败时保留默认 marker，避免影响地图功能。
    }
  }

  void _onMapCreated(AMapController controller) {
    _mapController = controller;
    _moveCameraToMyLocation();
  }

  void _moveCameraToMyLocation() {
    final m = _myLocation;
    final ctrl = _mapController;
    if (m == null || ctrl == null) return;
    final lat = (m['latitude'] as num?)?.toDouble();
    final lng = (m['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return;
    ctrl.moveCamera(CameraUpdate.newLatLngZoom(LatLng(lat, lng), 16));
  }

  Future<void> _locateNow() async {
    final pos = await _locationService.getCurrentPosition();
    if (!mounted) return;
    if (pos == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('定位失败，请检查定位权限和系统定位开关')),
      );
      return;
    }

    setState(() {
      _myLocation = {'longitude': pos.longitude, 'latitude': pos.latitude};
    });
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _moveCameraToMyLocation());
  }

  void _focusMember(Map<String, dynamic> l) {
    final lat = (l['latitude'] as num?)?.toDouble();
    final lng = (l['longitude'] as num?)?.toDouble();
    final ctrl = _mapController;
    if (lat == null || lng == null || ctrl == null) return;
    ctrl.moveCamera(CameraUpdate.newLatLngZoom(LatLng(lat, lng), 16));
  }

  Future<void> _openAmapNavigation(Map<String, dynamic> l) async {
    final lat = (l['latitude'] as num?)?.toDouble();
    final lng = (l['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('该家人暂无有效定位，无法导航')),
      );
      return;
    }

    final name = l['nickname']?.toString().trim().isNotEmpty == true
        ? l['nickname'].toString().trim()
        : '家人';
    final encodedName = Uri.encodeComponent(name);

    final appUri = Uri.parse(
      'androidamap://navi?sourceApplication=location_sharing'
      '&lat=$lat&lon=$lng&dev=0&style=2&poiname=$encodedName',
    );
    final webUri = Uri.parse(
      'https://uri.amap.com/navigation?to=$lng,$lat,$encodedName'
      '&mode=car&src=location_sharing&coordinate=gaode&callnative=1',
    );

    final launchedApp = await launchUrl(
      appUri,
      mode: LaunchMode.externalApplication,
    );
    if (launchedApp) return;

    final launchedWeb = await launchUrl(
      webUri,
      mode: LaunchMode.externalApplication,
    );
    if (launchedWeb || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('无法打开高德地图，请确认已安装')),
    );
  }

  CameraPosition _initialCameraPosition() {
    final m = _myLocation;
    if (m != null) {
      final lat = (m['latitude'] as num?)?.toDouble();
      final lng = (m['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        return CameraPosition(target: LatLng(lat, lng), zoom: 16);
      }
    }
    return const CameraPosition(
      target: LatLng(39.909187, 116.397451),
      zoom: 10,
    );
  }

  bool get _showAmap {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android;
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};
    final mine = _myLocation;
    if (mine != null) {
      final myLat = (mine['latitude'] as num?)?.toDouble();
      final myLng = (mine['longitude'] as num?)?.toDouble();
      if (myLat != null && myLng != null) {
        markers.add(
          Marker(
            position: LatLng(myLat, myLng),
            icon: _dotMarkerIcon,
            anchor: const Offset(0.5, 0.5),
            infoWindow: const InfoWindow(title: '我', snippet: '当前位置'),
          ),
        );
      }
    }

    for (final l in _familyLocations) {
      final lat = (l['latitude'] as num?)?.toDouble();
      final lng = (l['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      final name = l['nickname']?.toString() ?? '家人';
      markers.add(
        Marker(
          position: LatLng(lat, lng),
          icon: _dotMarkerIcon,
          anchor: const Offset(0.5, 0.5),
          infoWindow: InfoWindow(title: name),
        ),
      );
    }
    return markers;
  }

  Widget _buildUnsupportedMap() {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.map, size: 80, color: Colors.grey[400]),
              const SizedBox(height: 8),
              Text(
                '地图未就绪',
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                defaultTargetPlatform == TargetPlatform.iOS
                    ? '当前为 iOS，请配置 iosKey 后使用高德地图'
                    : '当前平台不支持高德地图组件',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final auth = ref.watch(authProvider);
    final src = auth.phone ?? auth.userId ?? '?';
    final letter = src.isNotEmpty ? src[0] : '?';
    return Material(
      elevation: 4,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(28),
      color: Colors.white.withOpacity(0.95),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.blue.shade100,
              child: Text(
                letter.toUpperCase(),
                style: TextStyle(
                    color: Colors.blue.shade800, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                '位置共享',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              tooltip: '通知',
              onPressed: () => context.go('/notifications'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roundMapActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Material(
      elevation: 4,
      shadowColor: Colors.black26,
      shape: const CircleBorder(),
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        icon: Icon(icon, color: Colors.blue),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }

  Widget _amapNavigateGlyph() {
    return SizedBox(
      width: 24,
      height: 24,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: 0.78539816339, // 45deg
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: const Color(0xFF1976D2),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const Icon(
            Icons.turn_right,
            color: Colors.white,
            size: 16,
          ),
        ],
      ),
    );
  }

  Widget _batteryPill(int? percent, int index) {
    final green = percent != null ? percent >= 50 : (index % 2 == 0);
    final label = percent != null ? '$percent%' : '—';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: green ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            green ? Icons.battery_charging_full : Icons.battery_5_bar,
            size: 14,
            color: green ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: green ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
            ),
          ),
        ],
      ),
    );
  }

  Widget _familyMemberTile(
    Map<String, dynamic> l,
    int index, {
    VoidCallback? onNavigateBeforeFocus,
  }) {
    final name = l['nickname']?.toString() ?? '家人';
    final letter = name.isNotEmpty ? name[0] : '?';
    final timeLabel = _fmtRecordedAt(l['recorded_at']?.toString());
    final rawBatt = l['battery_level'];
    final batt = rawBatt is int ? rawBatt : (rawBatt is num ? rawBatt.toInt() : null);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  onNavigateBeforeFocus?.call();
                  _focusMember(l);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.blue.shade50,
                        child: Text(
                          letter,
                          style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.place_outlined,
                                    size: 16, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '上次更新 $timeLabel',
                                    style: TextStyle(
                                        fontSize: 13, color: Colors.grey[700]),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      _batteryPill(batt, index),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.blue,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => _openAmapNavigation(l),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(child: _amapNavigateGlyph()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showFamilyStatusSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        final maxH = MediaQuery.sizeOf(sheetContext).height * 0.42;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SizedBox(
              height: maxH,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 4, 8),
                    child: Row(
                      children: [
                        const Text(
                          '家人状态',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.refresh, size: 22),
                          onPressed: () async {
                            await _loadLocations();
                            if (context.mounted) setModalState(() {});
                          },
                          tooltip: '刷新',
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _familyLocations.isEmpty
                        ? Center(
                            child: Text(
                              '暂无家人位置',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            itemCount: _familyLocations.length,
                            itemBuilder: (context, i) {
                              return _familyMemberTile(
                                _familyLocations[i],
                                i,
                                onNavigateBeforeFocus: () =>
                                    Navigator.of(sheetContext).pop(),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _locationService.stopTracking();
    _mqttService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showMap = _showAmap;

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.black,
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: showMap
                ? (!_mapSurfaceReady
                    ? Container(
                        color: const Color(0xFF1A1A1A),
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : AMapWidget(
                        privacyStatement: _amapPrivacy,
                        apiKey: const AMapApiKey(androidKey: _kAmapAndroidKey),
                        initialCameraPosition: _initialCameraPosition(),
                        myLocationStyleOptions: MyLocationStyleOptions(true),
                        markers: _buildMarkers(),
                        onMapCreated: _onMapCreated,
                      ))
                : _buildUnsupportedMap(),
          ),
          SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: _buildTopBar(context),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 16, bottom: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _roundMapActionButton(
                      icon: Icons.my_location,
                      tooltip: '回到我的位置',
                      onPressed: _locateNow,
                    ),
                    const SizedBox(height: 12),
                    _roundMapActionButton(
                      icon: Icons.view_list,
                      tooltip: '家人状态',
                      onPressed: _showFamilyStatusSheet,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
