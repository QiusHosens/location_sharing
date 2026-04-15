import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../api/config_api.dart';
import '../api/location_api.dart';
import '../utils/coord_transform.dart';

/// 在地图上展示某用户某时段内的全部轨迹点（折线）
class TrajectoryDetailScreen extends StatefulWidget {
  const TrajectoryDetailScreen({
    super.key,
    required this.userId,
    required this.startIso,
    required this.endIso,
    required this.title,
  });

  final String userId;
  final String startIso;
  final String endIso;
  final String title;

  @override
  State<TrajectoryDetailScreen> createState() => _TrajectoryDetailScreenState();
}

class _TrajectoryDetailScreenState extends State<TrajectoryDetailScreen> {
  final ConfigApi _configApi = ConfigApi();
  final LocationApi _api = LocationApi();
  WebViewController? _webViewController;
  List<Map<String, dynamic>> _points = [];
  bool _loading = true;
  String? _error;
  bool _mapLoading = true;
  String? _mapError;
  bool _mapReady = false;

  CoordPoint? _toGcjFromTrajectory(dynamic p) {
    if (p is! Map) return null;
    final lat = (p['latitude'] as num?)?.toDouble();
    final lng = (p['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return wgs84ToGcj02(latitude: lat, longitude: lng);
  }

  @override
  void initState() {
    super.initState();
    _loadTrajectory();
    _initMapWebView();
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
              _syncTrajectoryToMap();
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
          _buildTrajectoryHtml(
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

  Future<void> _loadTrajectory() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.getTrajectory(
        widget.userId,
        widget.startIso,
        widget.endIso,
      );
      if (!mounted) return;
      setState(() {
        _points = (res['points'] as List? ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _loading = false;
      });
      _syncTrajectoryToMap();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '加载失败';
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _trajectoryPayload() {
    return _points
        .map(_toGcjFromTrajectory)
        .whereType<CoordPoint>()
        .map((p) => {'lng': p.longitude, 'lat': p.latitude})
        .toList();
  }

  Future<void> _runMapJs(String script) async {
    if (!_mapReady || _webViewController == null) return;
    try {
      await _webViewController!.runJavaScript(script);
    } catch (_) {}
  }

  void _syncTrajectoryToMap() {
    final pointsJson = jsonEncode(_trajectoryPayload());
    _runMapJs(
      'window.LSTrajectoryMap && window.LSTrajectoryMap.setTrajectory($pointsJson);',
    );
  }

  String _buildTrajectoryHtml({
    required String key,
    required String securitySecret,
  }) {
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
      let polyline = null;
      let startMarker = null;
      let endMarker = null;
      const clearMarkers = () => {
        if (!map) return;
        if (startMarker) map.remove(startMarker);
        if (endMarker) map.remove(endMarker);
        startMarker = null;
        endMarker = null;
      };

      window.LSTrajectoryMap = {
        setTrajectory(points) {
          if (!map) return;
          const list = Array.isArray(points)
            ? points.map((p) => [Number(p.lng), Number(p.lat)]).filter((p) => !Number.isNaN(p[0]) && !Number.isNaN(p[1]))
            : [];
          if (polyline) {
            map.remove(polyline);
            polyline = null;
          }
          clearMarkers();
          if (list.length === 0) return;
          if (list.length === 1) {
            const p = list[0];
            startMarker = new window.AMap.Marker({ position: p, title: '轨迹点' });
            map.add(startMarker);
            map.setZoomAndCenter(16, p);
            return;
          }
          polyline = new window.AMap.Polyline({
            path: list,
            strokeColor: '#1976D2',
            strokeWeight: 6,
            strokeOpacity: 0.8,
            lineJoin: 'round',
            lineCap: 'round'
          });
          startMarker = new window.AMap.Marker({ position: list[0], title: '起点' });
          endMarker = new window.AMap.Marker({ position: list[list.length - 1], title: '终点' });
          map.add([polyline, startMarker, endMarker]);
          map.setFitView([polyline], false, [48, 48, 48, 48], 17);
        }
      };

      const script = document.createElement('script');
      script.src = 'https://webapi.amap.com/maps?v=2.0&key=' + encodeURIComponent(key);
      script.async = true;
      script.onload = () => {
        map = new window.AMap.Map('map', {
          zoom: 14,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontSize: 16)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : _mapError != null
          ? Center(child: Text(_mapError!))
          : _webViewController == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Positioned.fill(
                  child: WebViewWidget(controller: _webViewController!),
                ),
                if (_mapLoading)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Color(0x33000000),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],
            ),
    );
  }
}
