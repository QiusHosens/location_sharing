import React, { useEffect, useRef, useState } from 'react';
import { Box, Typography, TextField, Button, Card, CardContent, Stack, CircularProgress } from '@mui/material';
import { PlayArrow, Stop } from '@mui/icons-material';
import { getTrajectory } from '@/api/location';
import { useAuthStore } from '@/store/auth';
import { loadAmapScript } from '@/utils/amap';
import dayjs from 'dayjs';

export default function TrajectoryPage() {
  const { userId } = useAuthStore();
  const mapRef = useRef<HTMLDivElement>(null);
  const mapInstance = useRef<any>(null);
  const polylineRef = useRef<any>(null);
  const markerRef = useRef<any>(null);
  const animRef = useRef<number | null>(null);
  const [targetUserId, setTargetUserId] = useState(userId || '');
  const [startDate, setStartDate] = useState(dayjs().format('YYYY-MM-DD'));
  const [endDate, setEndDate] = useState(dayjs().format('YYYY-MM-DD'));
  const [points, setPoints] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [playing, setPlaying] = useState(false);
  const [total, setTotal] = useState(0);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        await loadAmapScript();
        if (cancelled || !mapRef.current || !window.AMap) return;
        mapInstance.current = new window.AMap.Map(mapRef.current, { zoom: 14, viewMode: '2D' });
      } catch (e) {
        console.error('轨迹页地图初始化失败', e);
      }
    })();
    return () => { cancelled = true; if (animRef.current) cancelAnimationFrame(animRef.current); };
  }, []);

  const handleQuery = async () => {
    setLoading(true);
    try {
      const start = dayjs(startDate).startOf('day').toISOString();
      const end = dayjs(endDate).endOf('day').toISOString();
      const res = await getTrajectory(targetUserId, start, end);
      setPoints(res.points || []);
      setTotal(res.total || 0);
      drawTrajectory(res.points || []);
    } catch (err) {
      console.error(err);
    } finally { setLoading(false); }
  };

  const drawTrajectory = (pts: any[]) => {
    if (!mapInstance.current || pts.length === 0) return;
    if (polylineRef.current) mapInstance.current.remove(polylineRef.current);
    if (markerRef.current) mapInstance.current.remove(markerRef.current);
    const path = pts.map((p: any) => [p.longitude, p.latitude]);
    polylineRef.current = new window.AMap.Polyline({ path, strokeColor: '#2196f3', strokeWeight: 4, strokeOpacity: 0.8 });
    mapInstance.current.add(polylineRef.current);
    mapInstance.current.setFitView([polylineRef.current]);
  };

  const playAnimation = () => {
    if (points.length < 2 || !mapInstance.current) return;
    setPlaying(true);
    if (markerRef.current) mapInstance.current.remove(markerRef.current);
    markerRef.current = new window.AMap.Marker({
      position: [points[0].longitude, points[0].latitude],
      content: '<div style="background:#e91e63;width:12px;height:12px;border-radius:50%;border:2px solid #fff"></div>',
      anchor: 'center',
    });
    mapInstance.current.add(markerRef.current);
    let idx = 0;
    const step = () => {
      if (idx >= points.length - 1) { setPlaying(false); return; }
      idx++;
      markerRef.current.setPosition([points[idx].longitude, points[idx].latitude]);
      animRef.current = requestAnimationFrame(() => setTimeout(step, 100));
    };
    step();
  };

  const stopAnimation = () => { setPlaying(false); if (animRef.current) cancelAnimationFrame(animRef.current); };

  return (
    <Box sx={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
      <Card sx={{ m: 2, mb: 1 }}>
        <CardContent sx={{ py: 1.5, '&:last-child': { pb: 1.5 } }}>
          <Stack direction="row" spacing={1} alignItems="center" flexWrap="wrap">
            <TextField size="small" label="用户ID" value={targetUserId} onChange={(e) => setTargetUserId(e.target.value)} sx={{ width: 200 }} />
            <TextField size="small" type="date" label="开始日期" value={startDate} onChange={(e) => setStartDate(e.target.value)} InputLabelProps={{ shrink: true }} />
            <TextField size="small" type="date" label="结束日期" value={endDate} onChange={(e) => setEndDate(e.target.value)} InputLabelProps={{ shrink: true }} />
            <Button variant="contained" onClick={handleQuery} disabled={loading}>{loading ? <CircularProgress size={20} /> : '查询'}</Button>
            {points.length > 1 && (
              <Button variant="outlined" startIcon={playing ? <Stop /> : <PlayArrow />} onClick={playing ? stopAnimation : playAnimation}>
                {playing ? '停止' : '回放'}
              </Button>
            )}
            {total > 0 && <Typography variant="body2" color="text.secondary">共 {total} 个点</Typography>}
          </Stack>
        </CardContent>
      </Card>
      <Box ref={mapRef} sx={{ flex: 1, mx: 2, mb: 2, borderRadius: 2, overflow: 'hidden' }} />
    </Box>
  );
}
