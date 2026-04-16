/// 轨迹回放优化：对原始定位点序列进行降噪、抽稀和平滑，
/// 生成适合轨迹回放的精简点序列。
///
/// 管线：
///   1. Kalman Filter（常速度模型，按时间间隔自适应）
///   2. Savitzky–Golay 平滑（对 x/y 分别滤波）
///   3. Douglas-Peucker 抽稀（按米级容差）

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
    /// Kalman：过程噪声强度（越大越“跟随”变化），默认 0.05
    pub kalman_q: f64,
    /// Kalman：观测噪声（米），越大越“相信模型”，默认 5m
    pub kalman_r: f64,
    /// Savitzky–Golay：窗口长度（奇数，>=3），默认 5
    pub sg_window: usize,
    /// Savitzky–Golay：多项式阶数（>=1 且 < window），默认 3
    pub sg_poly_order: usize,
}

impl Default for OptimizeOptions {
    fn default() -> Self {
        Self {
            max_speed_mps: 80.0,
            dp_tolerance_m: 10.0,
            kalman_q: 0.05,
            kalman_r: 5.0,
            sg_window: 5,
            sg_poly_order: 3,
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

    let kf = kalman_filter_latlng(&cleaned, opts.max_speed_mps, opts.kalman_q, opts.kalman_r);
    if kf.len() < 2 {
        return kf;
    }

    let sg = savitzky_golay_latlng(&kf, opts.sg_window, opts.sg_poly_order);
    if sg.len() < 2 {
        return sg;
    }

    douglas_peucker(&sg, opts.dp_tolerance_m)
}

// ── 0) 漂移剔除（速度门限）────────────────────────────────────

fn remove_drift(pts: &[TrajectoryPt], max_speed_mps: f64) -> Vec<TrajectoryPt> {
    if pts.len() < 2 {
        return pts.to_vec();
    }

    let mut out = Vec::with_capacity(pts.len());
    out.push(pts[0]);

    for i in 1..pts.len() {
        let prev = *out.last().unwrap();
        let cur = pts[i];

        let dt = (cur.ts - prev.ts).abs();
        if !dt.is_finite() || dt < 1e-6 {
            continue;
        }
        let dist = haversine_m(prev.lat, prev.lng, cur.lat, cur.lng);
        if dist.is_finite() && dist / dt <= max_speed_mps {
            out.push(cur);
        }
    }

    out
}

// ── 1) Kalman Filter（常速度）──────────────────────────────────

#[derive(Debug, Clone, Copy)]
struct Kalman1D {
    // state: [pos, vel]
    x0: f64,
    x1: f64,
    // covariance (symmetric 2x2)
    p00: f64,
    p01: f64,
    p11: f64,
}

impl Kalman1D {
    fn new(pos: f64) -> Self {
        Self {
            x0: pos,
            x1: 0.0,
            p00: 1.0,
            p01: 0.0,
            p11: 1.0,
        }
    }

    fn predict(&mut self, dt: f64, q: f64) {
        // F = [[1, dt], [0, 1]]
        self.x0 += self.x1 * dt;

        // P = F P F^T + Q
        // Q for constant-velocity model (scaled by q)
        let dt2 = dt * dt;
        let dt3 = dt2 * dt;
        let dt4 = dt2 * dt2;
        let q00 = q * dt4 / 4.0;
        let q01 = q * dt3 / 2.0;
        let q11 = q * dt2;

        let p00 = self.p00 + dt * (self.p01 + self.p01) + dt2 * self.p11;
        let p01 = self.p01 + dt * self.p11;
        let p11 = self.p11;

        self.p00 = p00 + q00;
        self.p01 = p01 + q01;
        self.p11 = p11 + q11;
    }

    fn update(&mut self, z: f64, r: f64) {
        // H = [1, 0], so innovation y = z - x0
        let y = z - self.x0;
        // S = P00 + R
        let s = self.p00 + r;
        if s <= 1e-12 {
            return;
        }
        // K = P H^T S^-1 = [P00, P01]^T / S
        let k0 = self.p00 / s;
        let k1 = self.p01 / s;

        self.x0 += k0 * y;
        self.x1 += k1 * y;

        // Joseph form not needed; simple update with symmetry
        let p00 = (1.0 - k0) * self.p00;
        let p01 = (1.0 - k0) * self.p01;
        let p11 = self.p11 - k1 * self.p01;

        self.p00 = p00.max(0.0);
        self.p01 = p01;
        self.p11 = p11.max(0.0);
    }
}

fn kalman_filter_latlng(pts: &[TrajectoryPt], max_speed_mps: f64, q: f64, r_m: f64) -> Vec<TrajectoryPt> {
    if pts.is_empty() {
        return vec![];
    }

    // local tangent plane projection (meters)
    let lat0 = pts[0].lat;
    let lng0 = pts[0].lng;
    let (x0m, y0m) = latlng_to_xy_m(lat0, lng0, lat0, lng0);

    let mut kx = Kalman1D::new(x0m);
    let mut ky = Kalman1D::new(y0m);

    let mut out = Vec::with_capacity(pts.len());
    out.push(pts[0]);

    let mut prev_ts = pts[0].ts;
    let mut prev_fx = x0m;
    let mut prev_fy = y0m;

    let r = r_m * r_m; // measurement variance

    for i in 1..pts.len() {
        let cur = pts[i];
        let mut dt = cur.ts - prev_ts;
        if !dt.is_finite() || dt <= 1e-3 {
            dt = 1.0;
        }

        kx.predict(dt, q);
        ky.predict(dt, q);

        let (mx, my) = latlng_to_xy_m(cur.lat, cur.lng, lat0, lng0);

        // gating by max speed (measurement jump)
        let dd = ((mx - prev_fx).powi(2) + (my - prev_fy).powi(2)).sqrt();
        let meas_speed = dd / dt;
        if meas_speed <= max_speed_mps {
            kx.update(mx, r);
            ky.update(my, r);
        }

        let fx = kx.x0;
        let fy = ky.x0;
        prev_fx = fx;
        prev_fy = fy;
        prev_ts = cur.ts;

        let (lat, lng) = xy_m_to_latlng(fx, fy, lat0, lng0);
        out.push(TrajectoryPt { lat, lng, ..cur });
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

// ── 2) Savitzky–Golay 平滑 ────────────────────────────────────

fn savitzky_golay_latlng(pts: &[TrajectoryPt], window: usize, poly: usize) -> Vec<TrajectoryPt> {
    let n = pts.len();
    if n < 3 {
        return pts.to_vec();
    }

    let mut w = window;
    if w % 2 == 0 {
        w += 1;
    }
    w = w.max(3).min(n | 1); // ensure odd and <= n (keep odd by OR 1)
    let p = poly.max(1).min(w - 1);

    let half = w / 2;
    let weights = sg_weights(half, p);

    // project to meters around first point to avoid lat/lng nonlinearity for smoothing
    let lat0 = pts[0].lat;
    let lng0 = pts[0].lng;
    let mut xs = Vec::with_capacity(n);
    let mut ys = Vec::with_capacity(n);
    for pt in pts {
        let (x, y) = latlng_to_xy_m(pt.lat, pt.lng, lat0, lng0);
        xs.push(x);
        ys.push(y);
    }

    let fx = apply_sg(&xs, &weights, half);
    let fy = apply_sg(&ys, &weights, half);

    let mut out = Vec::with_capacity(n);
    for i in 0..n {
        let (lat, lng) = xy_m_to_latlng(fx[i], fy[i], lat0, lng0);
        out.push(TrajectoryPt { lat, lng, ..pts[i] });
    }
    out
}

fn apply_sg(series: &[f64], weights: &[f64], half: usize) -> Vec<f64> {
    let n = series.len();
    let mut out = vec![0.0; n];
    for i in 0..n {
        let mut acc = 0.0;
        for (j, &w) in weights.iter().enumerate() {
            let k = j as isize - half as isize;
            let idx = (i as isize + k).clamp(0, (n - 1) as isize) as usize;
            acc += w * series[idx];
        }
        out[i] = acc;
    }
    out
}

fn sg_weights(half: usize, poly: usize) -> Vec<f64> {
    // window points are k in [-half, half]
    // weights w = e0^T (A^T A)^{-1} A^T
    let m = (2 * half + 1) as usize;
    let p = poly as usize;
    let dim = p + 1;

    // ATA (dim x dim)
    let mut ata = vec![vec![0.0_f64; dim]; dim];
    for k in -(half as isize)..=(half as isize) {
        let mut pow = vec![1.0_f64; dim];
        for j in 1..dim {
            pow[j] = pow[j - 1] * (k as f64);
        }
        for i in 0..dim {
            for j in 0..dim {
                ata[i][j] += pow[i] * pow[j];
            }
        }
    }

    let inv = invert_matrix(ata).unwrap_or_else(|| {
        // fallback: identity (should be rare for these small well-conditioned matrices)
        let mut id = vec![vec![0.0_f64; dim]; dim];
        for i in 0..dim {
            id[i][i] = 1.0;
        }
        id
    });

    let g = &inv[0]; // first row

    let mut weights = vec![0.0; m];
    for (idx, k) in (-(half as isize)..=(half as isize)).enumerate() {
        let mut s = 0.0;
        let mut kj = 1.0;
        for j in 0..dim {
            s += g[j] * kj;
            kj *= k as f64;
        }
        weights[idx] = s;
    }
    weights
}

fn invert_matrix(mut a: Vec<Vec<f64>>) -> Option<Vec<Vec<f64>>> {
    let n = a.len();
    if n == 0 || a.iter().any(|r| r.len() != n) {
        return None;
    }
    let mut inv = vec![vec![0.0_f64; n]; n];
    for i in 0..n {
        inv[i][i] = 1.0;
    }

    for i in 0..n {
        // pivot
        let mut pivot = i;
        let mut best = a[i][i].abs();
        for r in (i + 1)..n {
            let v = a[r][i].abs();
            if v > best {
                best = v;
                pivot = r;
            }
        }
        if best < 1e-12 {
            return None;
        }
        if pivot != i {
            a.swap(i, pivot);
            inv.swap(i, pivot);
        }

        let diag = a[i][i];
        for j in 0..n {
            a[i][j] /= diag;
            inv[i][j] /= diag;
        }

        for r in 0..n {
            if r == i {
                continue;
            }
            let factor = a[r][i];
            if factor.abs() < 1e-15 {
                continue;
            }
            for c in 0..n {
                a[r][c] -= factor * a[i][c];
                inv[r][c] -= factor * inv[i][c];
            }
        }
    }

    Some(inv)
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

fn latlng_to_xy_m(lat: f64, lng: f64, lat0: f64, lng0: f64) -> (f64, f64) {
    // equirectangular approximation around (lat0, lng0)
    let rlat0 = to_rad(lat0);
    let x = to_rad(lng - lng0) * EARTH_R * rlat0.cos();
    let y = to_rad(lat - lat0) * EARTH_R;
    (x, y)
}

fn xy_m_to_latlng(x: f64, y: f64, lat0: f64, lng0: f64) -> (f64, f64) {
    let rlat0 = to_rad(lat0);
    let lat = lat0 + (y / EARTH_R) * 180.0 / std::f64::consts::PI;
    let lng = lng0 + (x / (EARTH_R * rlat0.cos().max(1e-12))) * 180.0 / std::f64::consts::PI;
    (lat, lng)
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
    fn test_kalman_gates_jump() {
        let pts = make_pts(&[
            (116.0, 39.0, 0.0),
            (116.0002, 39.0001, 10.0),
            (120.0, 39.0, 11.0), // 瞬移
            (116.0004, 39.0002, 20.0),
        ]);
        let out = kalman_filter_latlng(&pts, 80.0, 0.05, 5.0);
        assert_eq!(out.len(), pts.len());
        // 第 3 个点不应被跳跃拉走太远（粗略：经度不应接近 120）
        assert!((out[2].lng - 120.0).abs() > 0.5);
    }

    #[test]
    fn test_remove_drift_drops_jump_point() {
        let pts = make_pts(&[
            (116.0, 39.0, 0.0),
            (116.0002, 39.0001, 10.0),
            (120.0, 39.0, 11.0), // 瞬移漂移
            (116.0004, 39.0002, 20.0),
        ]);
        let cleaned = remove_drift(&pts, 80.0);
        assert!(cleaned.len() < pts.len());
        assert!(cleaned.iter().all(|p| (p.lng - 120.0).abs() > 1e-6));
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
