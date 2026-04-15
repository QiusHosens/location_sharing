import 'dart:math' as math;

class CoordPoint {
  const CoordPoint({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;
}

/// WGS84 -> GCJ02（仅中国大陆范围内生效，境外原样返回）
CoordPoint wgs84ToGcj02({
  required double latitude,
  required double longitude,
}) {
  if (_outOfChina(latitude, longitude)) {
    return CoordPoint(latitude: latitude, longitude: longitude);
  }

  const a = 6378245.0;
  const ee = 0.00669342162296594323;

  var dLat = _transformLat(longitude - 105.0, latitude - 35.0);
  var dLon = _transformLon(longitude - 105.0, latitude - 35.0);
  final radLat = latitude / 180.0 * math.pi;
  var magic = math.sin(radLat);
  magic = 1 - ee * magic * magic;
  final sqrtMagic = math.sqrt(magic);
  dLat = (dLat * 180.0) /
      (((a * (1 - ee)) / (magic * sqrtMagic)) * math.pi);
  dLon = (dLon * 180.0) / ((a / sqrtMagic) * math.cos(radLat) * math.pi);

  return CoordPoint(
    latitude: latitude + dLat,
    longitude: longitude + dLon,
  );
}

bool _outOfChina(double lat, double lon) {
  if (lon < 72.004 || lon > 137.8347) return true;
  if (lat < 0.8293 || lat > 55.8271) return true;
  return false;
}

double _transformLat(double x, double y) {
  var ret = -100.0 +
      2.0 * x +
      3.0 * y +
      0.2 * y * y +
      0.1 * x * y +
      0.2 * math.sqrt(x.abs());
  ret += (20.0 * math.sin(6.0 * x * math.pi) +
          20.0 * math.sin(2.0 * x * math.pi)) *
      2.0 /
      3.0;
  ret += (20.0 * math.sin(y * math.pi) +
          40.0 * math.sin(y / 3.0 * math.pi)) *
      2.0 /
      3.0;
  ret += (160.0 * math.sin(y / 12.0 * math.pi) +
          320 * math.sin(y * math.pi / 30.0)) *
      2.0 /
      3.0;
  return ret;
}

double _transformLon(double x, double y) {
  var ret = 300.0 +
      x +
      2.0 * y +
      0.1 * x * x +
      0.1 * x * y +
      0.1 * math.sqrt(x.abs());
  ret += (20.0 * math.sin(6.0 * x * math.pi) +
          20.0 * math.sin(2.0 * x * math.pi)) *
      2.0 /
      3.0;
  ret += (20.0 * math.sin(x * math.pi) +
          40.0 * math.sin(x / 3.0 * math.pi)) *
      2.0 /
      3.0;
  ret += (150.0 * math.sin(x / 12.0 * math.pi) +
          300.0 * math.sin(x / 30.0 * math.pi)) *
      2.0 /
      3.0;
  return ret;
}
