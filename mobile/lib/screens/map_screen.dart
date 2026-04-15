import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../api/config_api.dart';
import '../api/client.dart';
import '../api/location_api.dart';
import '../api/user_api.dart';
import '../providers/auth_provider.dart';
import '../services/location_service.dart';
import '../services/mqtt_service.dart';
import '../utils/coord_transform.dart';

List<Map<String, dynamic>> _dedupeFamilyLocations(
  List<Map<String, dynamic>> raw,
) {
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
  list.sort(
    (a, b) => (a['nickname']?.toString() ?? '').compareTo(
      b['nickname']?.toString() ?? '',
    ),
  );
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
  final ApiClient _apiClient = ApiClient();
  final ConfigApi _configApi = ConfigApi();
  final LocationService _locationService = LocationService();
  final MqttService _mqttService = MqttService();
  final LocationApi _locationApi = LocationApi();
  final UserApi _userApi = UserApi();
  List<Map<String, dynamic>> _familyLocations = [];
  Map<String, dynamic>? _myLocation;
  WebViewController? _webViewController;
  bool _mapReady = false;
  bool _mapLoading = true;
  String? _mapError;

  CoordPoint? _toGcjFromMap(Map<String, dynamic>? m) {
    if (m == null) return null;
    final lat = (m['latitude'] as num?)?.toDouble();
    final lng = (m['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return wgs84ToGcj02(latitude: lat, longitude: lng);
  }

  @override
  void initState() {
    super.initState();
    _initMapWebView();
    _init();
  }

  Future<void> _initMapWebView() async {
    setState(() {
      _mapLoading = true;
      _mapError = null;
    });
    try {
      final cfg = await _configApi.getMapConfig();
      final webKey = cfg.webKey.trim();
      if (webKey.isEmpty) {
        if (!mounted) return;
        setState(() {
          _mapLoading = false;
          _mapError = '高德地图 key 未配置';
        });
        return;
      }

      final c = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.black)
        ..addJavaScriptChannel(
          'MapBridge',
          onMessageReceived: (msg) {
            final m = msg.message;
            if (m == 'ready') {
              if (!mounted) return;
              setState(() {
                _mapReady = true;
                _mapLoading = false;
              });
              _syncMarkersToMap();
              _moveCameraToMyLocation();
            } else if (m.startsWith('error:')) {
              if (!mounted) return;
              setState(() {
                _mapLoading = false;
                _mapError = m.substring(6);
              });
            }
          },
        )
        ..loadHtmlString(
          _buildAmapHtml(
            key: webKey,
            securitySecret: cfg.webSecuritySecret.trim(),
          ),
        );
      if (!mounted) return;
      setState(() => _webViewController = c);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _mapLoading = false;
        _mapError = '地图配置加载失败';
      });
    }
  }

  Future<void> _init() async {
    final auth = ref.read(authProvider);
    if (auth.userId != null) {
      _mqttService.onLocationUpdate = (data) {
        setState(() {
          final uid = data['user_id']?.toString();
          if (uid == null || uid.isEmpty) return;
          final lng = (data['longitude'] as num?)?.toDouble();
          final lat = (data['latitude'] as num?)?.toDouble();
          if (lng == null || lat == null) return;
          final isSelf = auth.userId == uid;
          if (isSelf) {
            _myLocation = {'longitude': lng, 'latitude': lat};
            return;
          }
          final next = List<Map<String, dynamic>>.from(_familyLocations);
          final idx = next.indexWhere((e) => e['user_id']?.toString() == uid);
          final patch = <String, dynamic>{
            'user_id': uid,
            'longitude': lng,
            'latitude': lat,
            'nickname': data['nickname'],
            'recorded_at': DateTime.now()
                .toUtc()
                .toIso8601String()
                .replaceFirst('Z', ''),
          };
          if (idx >= 0) {
            next[idx] = {...next[idx], ...patch};
          } else {
            next.add(patch);
          }
          _familyLocations = _dedupeFamilyLocations(next);
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _syncMarkersToMap();
          _moveCameraToMyLocation();
        });
      };
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _syncMarkersToMap();
        _moveCameraToMyLocation();
      });
    } catch (_) {}
  }

  Future<void> _startTracking() async {
    await _locationService.startTracking(
      onLocation: (pos) {
        setState(() {
          _myLocation = {'longitude': pos.longitude, 'latitude': pos.latitude};
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _syncMarkersToMap();
          _moveCameraToMyLocation();
        });
      },
    );
  }

  Future<void> _runMapJs(String script) async {
    if (!_mapReady || _webViewController == null) return;
    try {
      await _webViewController!.runJavaScript(script);
    } catch (_) {}
  }

  List<Map<String, dynamic>> _buildMarkerPayload() {
    final payload = <Map<String, dynamic>>[];
    final mine = _toGcjFromMap(_myLocation);
    if (mine != null) {
      payload.add({
        'id': '__self__',
        'lat': mine.latitude,
        'lng': mine.longitude,
        'label': '我',
        'isSelf': true,
        'avatarUrl': null,
      });
    }
    for (final l in _familyLocations) {
      final gcj = _toGcjFromMap(l);
      if (gcj == null) continue;
      final uid =
          l['user_id']?.toString() ?? '${gcj.latitude}_${gcj.longitude}';
      final label = (l['nickname']?.toString().trim().isNotEmpty ?? false)
          ? l['nickname'].toString().trim()
          : '家人';
      payload.add({
        'id': uid,
        'lat': gcj.latitude,
        'lng': gcj.longitude,
        'label': label,
        'isSelf': false,
        'avatarUrl': _apiClient.resolveMediaUrl(l['avatar_url']?.toString()),
      });
    }
    return payload;
  }

  void _syncMarkersToMap() {
    final markersJson = jsonEncode(_buildMarkerPayload());
    _runMapJs('window.LSMap && window.LSMap.setMarkers($markersJson);');
  }

  void _moveCameraToMyLocation({bool keepZoomIfClose = false}) {
    final m = _myLocation;
    if (m == null || !_mapReady) return;
    final gcj = _toGcjFromMap(m);
    if (gcj == null) return;
    if (keepZoomIfClose) {
      _runMapJs(
        'window.LSMap && window.LSMap.moveToWithMinZoom(${gcj.longitude}, ${gcj.latitude}, 15, 16);',
      );
      return;
    }
    _runMapJs(
      'window.LSMap && window.LSMap.moveTo(${gcj.longitude}, ${gcj.latitude}, 16);',
    );
  }

  Future<void> _locateNow() async {
    final prev = _myLocation;
    final pos = await _locationService.getLastKnownPosition();
    if (!mounted) return;
    if (pos == null) {
      if (prev != null) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _moveCameraToMyLocation(),
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('未获取到最近定位，已回到上次定位位置')));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('未获取到最近定位，请稍后再试')));
      }
      return;
    }

    setState(() {
      _myLocation = {'longitude': pos.longitude, 'latitude': pos.latitude};
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncMarkersToMap();
      _moveCameraToMyLocation(keepZoomIfClose: true);
    });
  }

  void _focusMember(Map<String, dynamic> l) {
    final gcj = _toGcjFromMap(l);
    if (gcj == null || !_mapReady) return;
    _runMapJs(
      'window.LSMap && window.LSMap.moveTo(${gcj.longitude}, ${gcj.latitude}, 16);',
    );
  }

  Future<void> _openAmapNavigation(Map<String, dynamic> l) async {
    final gcj = _toGcjFromMap(l);
    if (gcj == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('该家人暂无有效定位，无法导航')));
      return;
    }

    final name = l['nickname']?.toString().trim().isNotEmpty == true
        ? l['nickname'].toString().trim()
        : '家人';
    final encodedName = Uri.encodeComponent(name);

    final appUri = Uri.parse(
      'amapuri://route/plan/?sourceApplication=location_sharing'
      '&dlat=${gcj.latitude}&dlon=${gcj.longitude}&dname=$encodedName&dev=0&t=0',
    );
    final webUri = Uri.parse(
      'https://uri.amap.com/navigation?to=${gcj.longitude},${gcj.latitude},$encodedName'
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

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('无法打开高德地图，请确认已安装')));
  }

  String _buildAmapHtml({required String key, required String securitySecret}) {
    final keyJs = jsonEncode(key);
    final secJs = jsonEncode(securitySecret);
    return '''
<!doctype html>
<html>
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no" />
  <style>
    html, body, #map { width:100%; height:100%; margin:0; padding:0; background:#1a1a1a; overflow:hidden; }
    .amap-logo { display:none !important; }
    .amap-copyright { display:none !important; }
  </style>
</head>
<body>
  <div id="map"></div>
  <script>
    (function() {
      const key = $keyJs;
      const securitySecret = $secJs;
      const bridge = window.MapBridge;
      const post = (msg) => bridge && bridge.postMessage && bridge.postMessage(msg);
      if (securitySecret) {
        window._AMapSecurityConfig = { securityJsCode: securitySecret };
      }

      let map = null;
      const markers = new Map();
      const escHtml = (s) => String(s || '')
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;');

      const markerHtml = (label, isSelf, avatarUrl) => {
        const safe = escHtml(label || '家人');
        const initial = safe ? safe.slice(0, 1) : '?';
        if (isSelf) {
          // 当前用户：同心圆定位样式
          return '<div style="width:48px;height:48px;border-radius:50%;'
            + 'display:flex;align-items:center;justify-content:center;'
            + 'background:rgba(158,173,184,.45);">'
            +   '<div style="width:28px;height:28px;border-radius:50%;'
            +   'display:flex;align-items:center;justify-content:center;'
            +   'background:#fff;">'
            +     '<div style="width:20px;height:20px;border-radius:50%;background:#1565C0;"></div>'
            +   '</div>'
            + '</div>';
        }

        const hasAvatar = !!(avatarUrl && String(avatarUrl).trim());
        const safeUrl = escHtml(avatarUrl || '');
        const avatar = hasAvatar
          ? '<img src="' + safeUrl + '" style="width:44px;height:44px;border-radius:50%;object-fit:cover;display:block;" '
            + 'onerror="this.style.display=\\'none\\';this.nextElementSibling.style.display=\\'flex\\';" />'
            + '<div style="display:none;width:44px;height:44px;border-radius:50%;background:#1565C0;'
            + 'color:#fff;align-items:center;justify-content:center;font-weight:700;font-size:18px;">' + initial + '</div>'
          : '<div style="width:44px;height:44px;border-radius:50%;background:#1565C0;'
            + 'color:#fff;display:flex;align-items:center;justify-content:center;font-weight:700;font-size:18px;">' + initial + '</div>';

        // 家人：头像/首字 + 双层圆环
        return '<div style="width:56px;height:56px;border-radius:50%;'
          + 'display:flex;align-items:center;justify-content:center;'
          + 'background:#1565C0;box-shadow:0 2px 8px rgba(0,0,0,.22);">'
          +   '<div style="width:50px;height:50px;border-radius:50%;background:#fff;'
          +   'display:flex;align-items:center;justify-content:center;">'
          +     avatar
          +   '</div>'
          + '</div>';
      };

      window.LSMap = {
        setMarkers(list) {
          if (!map) return;
          const items = Array.isArray(list) ? list : [];
          const seen = new Set();
          for (const m of items) {
            const id = String(m.id || '');
            const lng = Number(m.lng);
            const lat = Number(m.lat);
            if (!id || Number.isNaN(lng) || Number.isNaN(lat)) continue;
            seen.add(id);
            const content = markerHtml(
              m.label || '家人',
              !!m.isSelf,
              m.avatarUrl || '',
            );
            if (markers.has(id)) {
              const mk = markers.get(id);
              mk.setPosition([lng, lat]);
              mk.setContent(content);
            } else {
              const mk = new window.AMap.Marker({
                position: [lng, lat],
                content: content,
                offset: !!m.isSelf
                  ? new window.AMap.Pixel(-28, -28)
                  : new window.AMap.Pixel(-28, -56),
              });
              map.add(mk);
              markers.set(id, mk);
            }
          }
          for (const [id, mk] of markers) {
            if (!seen.has(id)) {
              map.remove(mk);
              markers.delete(id);
            }
          }
        },
        moveTo(lng, lat, zoom) {
          if (!map) return;
          map.setZoomAndCenter(Number(zoom || 16), [Number(lng), Number(lat)]);
        },
        moveToWithMinZoom(lng, lat, minZoom, targetZoom) {
          if (!map) return;
          const minZ = Number(minZoom || 15);
          const targetZ = Number(targetZoom || 16);
          const cur = Number(map.getZoom ? map.getZoom() : targetZ);
          const nextZoom = cur < minZ ? targetZ : cur;
          map.setZoomAndCenter(nextZoom, [Number(lng), Number(lat)]);
        }
      };

      const script = document.createElement('script');
      script.src = 'https://webapi.amap.com/maps?v=2.0&key=' + encodeURIComponent(key);
      script.async = true;
      script.onload = () => {
        map = new window.AMap.Map('map', {
          zoom: 15,
          center: [116.397428, 39.90923],
          viewMode: '2D'
        });
        map.on('complete', () => post('ready'));
      };
      script.onerror = () => post('error:高德脚本加载失败');
      document.head.appendChild(script);
    })();
  </script>
</body>
</html>
''';
  }

  Widget _buildMapLayer() {
    final c = _webViewController;
    if (_mapError != null) {
      return Container(
        color: const Color(0xFF1A1A1A),
        alignment: Alignment.center,
        child: Text(_mapError!, style: const TextStyle(color: Colors.white70)),
      );
    }
    if (c == null) {
      return const ColoredBox(
        color: Color(0xFF1A1A1A),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Stack(
      children: [
        Positioned.fill(child: WebViewWidget(controller: c)),
        if (_mapLoading)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x33000000),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
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
      color: Colors.white.withValues(alpha: 0.95),
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
                  color: Colors.blue.shade800,
                  fontWeight: FontWeight.w600,
                ),
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
          const Icon(Icons.turn_right, color: Colors.white, size: 16),
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
    final batt = rawBatt is int
        ? rawBatt
        : (rawBatt is num ? rawBatt.toInt() : null);

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
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.place_outlined,
                                  size: 16,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '上次更新 $timeLabel',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[700],
                                    ),
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
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
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
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.black,
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: _buildMapLayer()),
          SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
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
