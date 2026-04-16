/// 轨迹回放优化：对原始定位点序列进行降噪、抽稀和平滑，
/// 生成适合轨迹回放的精简点序列。
///
/// 管线：
///   1. 速度异常点剔除（漂移剔除）
///   2. Douglas-Peucker 抽稀
///   3. 三点加权滑动平均平滑

/// 二维点（经纬度）+ 时间戳（Unix 秒）
#[derive(Debug, Clone, Copy)]
pub struct TrajectoryPt {
    pub lng: f64,
    pub lat: f64,
    /// Unix timestamp（秒，f64 以兼容亚秒精度）
    pub ts: f64,
    pub altitude: Option<f64>,
    pub speed: Option<f32>,
    pub accuracy: Option<f32>,
}

/// 优化参数
#[derive(Debug, Clone)]
pub struct OptimizeOptions {
    /// 相邻两点间最大合理速度（m/s），超过视为漂移；默认 80 m/s ≈ 288 km/h
    pub max_speed_mps: f64,
    /// Douglas-Peucker 容差（米）；越大点越少，默认 10m
    pub dp_tolerance_m: f64,
    /// 平滑滑窗半径（前后各取 n 个点），0 = 不平滑；默认 1
    pub smooth_radius: usize,
}

impl Default for OptimizeOptions {
    fn default() -> Self {
        Self {
            max_speed_mps: 80.0,
            dp_tolerance_m: 10.0,
            smooth_radius: 1,
        }
    }
}

/// 一站式优化入口
pub fn optimize(pts: &[TrajectoryPt], opts: &OptimizeOptions) -> Vec<TrajectoryPt> {
    if pts.len() < 2 {
        return pts.to_vec();
    }
    let cleaned = remove_drift(pts, opts.max_speed_mps);
    if cleaned.len() < 2 {
        return cleaned;
    }
    let simplified = douglas_peucker(&cleaned, opts.dp_tolerance_m);
    if opts.smooth_radius == 0 || simplified.len() < 3 {
        return simplified;
    }
    smooth(&simplified, opts.smooth_radius)
}

// ── 1. 速度异常剔除 ──────────────────────────────────────────

fn remove_drift(pts: &[TrajectoryPt], max_speed: f64) -> Vec<TrajectoryPt> {
    let mut out = Vec::with_capacity(pts.len());
    out.push(pts[0]);
    for i in 1..pts.len() {
        let prev = out.last().unwrap();
        let cur = &pts[i];
        let dt = (cur.ts - prev.ts).abs();
        if dt < 1e-6 {
            continue;
        }
        let dist = haversine_m(prev.lat, prev.lng, cur.lat, cur.lng);
        if dist / dt <= max_speed {
            out.push(*cur);
        }
    }
    out
}

// ── 2. Douglas-Peucker 抽稀 ──────────────────────────────────

fn douglas_peucker(pts: &[TrajectoryPt], tolerance: f64) -> Vec<TrajectoryPt> {
    if pts.len() <= 2 {
        return pts.to_vec();
    }
    let mut keep = vec![false; pts.len()];
    keep[0] = true;
    keep[pts.len() - 1] = true;
    dp_recursive(pts, 0, pts.len() - 1, tolerance, &mut keep);
    pts.iter()
        .enumerate()
        .filter(|(i, _)| keep[*i])
        .map(|(_, p)| *p)
        .collect()
}

fn dp_recursive(pts: &[TrajectoryPt], start: usize, end: usize, tol: f64, keep: &mut [bool]) {
    if end <= start + 1 {
        return;
    }
    let (mut max_dist, mut max_idx) = (0.0_f64, start);
    let a = &pts[start];
    let b = &pts[end];
    for i in (start + 1)..end {
        let d = point_to_line_distance_m(a, b, &pts[i]);
        if d > max_dist {
            max_dist = d;
            max_idx = i;
        }
    }
    if max_dist > tol {
        keep[max_idx] = true;
        dp_recursive(pts, start, max_idx, tol, keep);
        dp_recursive(pts, max_idx, end, tol, keep);
    }
}

/// 点到线段（大地近似）的距离（米）——使用"cross-track distance"简化公式
fn point_to_line_distance_m(a: &TrajectoryPt, b: &TrajectoryPt, p: &TrajectoryPt) -> f64 {
    let d_ap = haversine_m(a.lat, a.lng, p.lat, p.lng);
    let d_ab = haversine_m(a.lat, a.lng, b.lat, b.lng);
    if d_ab < 1e-9 {
        return d_ap;
    }
    let bearing_ap = initial_bearing(a.lat, a.lng, p.lat, p.lng);
    let bearing_ab = initial_bearing(a.lat, a.lng, b.lat, b.lng);
    let cross = (d_ap / EARTH_R).sin() * (bearing_ap - bearing_ab).sin();
    (cross.asin() * EARTH_R).abs()
}

// ── 3. 滑动平均平滑 ──────────────────────────────────────────

fn smooth(pts: &[TrajectoryPt], radius: usize) -> Vec<TrajectoryPt> {
    let n = pts.len();
    let mut out = Vec::with_capacity(n);
    for i in 0..n {
        let lo = if i >= radius { i - radius } else { 0 };
        let hi = (i + radius).min(n - 1);
        let cnt = (hi - lo + 1) as f64;
        let mut slng = 0.0;
        let mut slat = 0.0;
        for j in lo..=hi {
            slng += pts[j].lng;
            slat += pts[j].lat;
        }
        out.push(TrajectoryPt {
            lng: slng / cnt,
            lat: slat / cnt,
            ts: pts[i].ts,
            altitude: pts[i].altitude,
            speed: pts[i].speed,
            accuracy: pts[i].accuracy,
        });
    }
    out
}

// ── 地理工具 ─────────────────────────────────────────────────

const EARTH_R: f64 = 6_371_000.0;

fn to_rad(d: f64) -> f64 {
    d * std::f64::consts::PI / 180.0
}

fn haversine_m(lat1: f64, lng1: f64, lat2: f64, lng2: f64) -> f64 {
    let (rlat1, rlat2) = (to_rad(lat1), to_rad(lat2));
    let dlat = to_rad(lat2 - lat1);
    let dlng = to_rad(lng2 - lng1);
    let a = (dlat / 2.0).sin().powi(2) + rlat1.cos() * rlat2.cos() * (dlng / 2.0).sin().powi(2);
    2.0 * a.sqrt().asin() * EARTH_R
}

fn initial_bearing(lat1: f64, lng1: f64, lat2: f64, lng2: f64) -> f64 {
    let (rlat1, rlat2) = (to_rad(lat1), to_rad(lat2));
    let dlng = to_rad(lng2 - lng1);
    let y = dlng.sin() * rlat2.cos();
    let x = rlat1.cos() * rlat2.sin() - rlat1.sin() * rlat2.cos() * dlng.cos();
    y.atan2(x)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn make_pts(coords: &[(f64, f64, f64)]) -> Vec<TrajectoryPt> {
        coords
            .iter()
            .map(|&(lng, lat, ts)| TrajectoryPt {
                lng,
                lat,
                ts,
                altitude: None,
                speed: None,
                accuracy: None,
            })
            .collect()
    }

    #[test]
    fn test_drift_removal() {
        let pts = make_pts(&[
            (116.0, 39.0, 0.0),
            (116.001, 39.0, 10.0),
            (120.0, 39.0, 11.0),   // 瞬移漂移
            (116.002, 39.0, 20.0), // 因为 prev 是 [0]，这个也可能被标为漂移
        ]);
        let out = remove_drift(&pts, 80.0);
        assert!(out.len() < pts.len(), "should remove drift point");
    }

    #[test]
    fn test_dp_preserves_endpoints() {
        let pts = make_pts(&[
            (116.0, 39.0, 0.0),
            (116.0001, 39.00005, 5.0),
            (116.001, 39.0, 10.0),
        ]);
        let out = douglas_peucker(&pts, 50.0);
        assert_eq!(out.len(), 2);
        assert!((out[0].lng - 116.0).abs() < 1e-9);
        assert!((out[1].lng - 116.001).abs() < 1e-9);
    }

    #[test]
    fn test_optimize_smoke() {
        let pts = make_pts(&[
            (116.0, 39.0, 0.0),
            (116.001, 39.001, 60.0),
            (116.002, 39.002, 120.0),
            (116.003, 39.003, 180.0),
        ]);
        let out = optimize(&pts, &OptimizeOptions::default());
        assert!(!out.is_empty());
    }
}
