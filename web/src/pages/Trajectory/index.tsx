import React, { useCallback, useEffect, useRef, useState } from 'react';
import {
  Box, Typography, Card, CardContent, CircularProgress, Dialog, DialogTitle, DialogContent,
  IconButton, Collapse, List, ListItemButton, ListItemText, Divider,
} from '@mui/material';
import { ChevronLeft, ChevronRight, Close, ExpandMore, ExpandLess } from '@mui/icons-material';
import { getTrajectoryDaySummary, getTrajectory } from '@/api/location';
import { loadAmapScript } from '@/utils/amap';
import dayjs from 'dayjs';

type Segment = { start_time: string; end_time: string; point_count: number };
type UserDay = { user_id: string; phone: string; nickname?: string; segments: Segment[] };

function buildCalendarMatrix(month: dayjs.Dayjs) {
  const start = month.startOf('month');
  const days = month.daysInMonth();
  const firstDow = start.day();
  const cells: (number | null)[] = [];
  for (let i = 0; i < firstDow; i++) cells.push(null);
  for (let d = 1; d <= days; d++) cells.push(d);
  while (cells.length % 7 !== 0) cells.push(null);
  const rows: (number | null)[][] = [];
  for (let i = 0; i < cells.length; i += 7) rows.push(cells.slice(i, i + 7));
  return rows;
}

export default function TrajectoryPage() {
  const mapRef = useRef<HTMLDivElement>(null);
  const mapInstance = useRef<any>(null);
  const polylineRef = useRef<any>(null);
  const [month, setMonth] = useState(dayjs());
  const [selectedDate, setSelectedDate] = useState(dayjs().format('YYYY-MM-DD'));
  const [summary, setSummary] = useState<{ date: string; users: UserDay[] } | null>(null);
  const [loading, setLoading] = useState(false);
  const [openUser, setOpenUser] = useState<Record<string, boolean>>({});
  const [detailOpen, setDetailOpen] = useState(false);
  const [detailTitle, setDetailTitle] = useState('');
  const [detailLoading, setDetailLoading] = useState(false);
  const [detailPoints, setDetailPoints] = useState<any[]>([]);

  const loadSummary = useCallback(async (dateStr: string) => {
    setLoading(true);
    try {
      const data = await getTrajectoryDaySummary(dateStr);
      setSummary(data);
    } catch (e) {
      console.error(e);
      setSummary({ date: dateStr, users: [] });
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadSummary(selectedDate);
  }, [selectedDate, loadSummary]);

  useEffect(() => {
    loadAmapScript().catch(() => {});
  }, []);

  useEffect(() => {
    if (!detailOpen || detailLoading || !mapRef.current || !window.AMap || detailPoints.length === 0) {
      return;
    }
    if (mapInstance.current) {
      mapInstance.current.destroy();
      mapInstance.current = null;
    }
    if (polylineRef.current) polylineRef.current = null;

    const map = new window.AMap.Map(mapRef.current, { zoom: 14, viewMode: '2D' });
    mapInstance.current = map;
    const path = detailPoints.map((p: any) => [p.longitude, p.latitude]);
    const polyline = new window.AMap.Polyline({
      path,
      strokeColor: '#1976d2',
      strokeWeight: 5,
      strokeOpacity: 0.85,
    });
    polylineRef.current = polyline;
    map.add(polyline);
    map.setFitView([polyline]);
    setTimeout(() => map.resize?.(), 200);

    return () => {
      if (mapInstance.current) {
        mapInstance.current.destroy();
        mapInstance.current = null;
      }
      polylineRef.current = null;
    };
  }, [detailOpen, detailLoading, detailPoints]);

  const openSegmentDetail = async (u: UserDay, seg: Segment) => {
    setDetailTitle(
      `${u.phone} · ${dayjs(seg.start_time).format('HH:mm')}–${dayjs(seg.end_time).format('HH:mm')}（${seg.point_count} 点）`,
    );
    setDetailOpen(true);
    setDetailLoading(true);
    setDetailPoints([]);
    try {
      const res = await getTrajectory(u.user_id, seg.start_time, seg.end_time);
      setDetailPoints(res.points || []);
    } catch (e) {
      console.error(e);
      setDetailPoints([]);
    } finally {
      setDetailLoading(false);
    }
  };

  const handleCloseDetail = () => {
    setDetailOpen(false);
    setDetailPoints([]);
  };

  const matrix = buildCalendarMatrix(month);
  const weekLabels = ['日', '一', '二', '三', '四', '五', '六'];

  const toggleUser = (id: string) => {
    setOpenUser((o) => ({ ...o, [id]: !o[id] }));
  };

  return (
    <Box sx={{ display: 'flex', flexDirection: 'column', height: '100%', overflow: 'auto', pb: 2 }}>
      <Card sx={{ m: 2, mb: 1 }}>
        <CardContent sx={{ py: 1.5, '&:last-child': { pb: 1.5 } }}>
          <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', mb: 1 }}>
            <IconButton size="small" onClick={() => setMonth((m) => m.subtract(1, 'month'))}>
              <ChevronLeft />
            </IconButton>
            <Typography variant="subtitle1" fontWeight={600}>{month.format('YYYY年 M月')}</Typography>
            <IconButton size="small" onClick={() => setMonth((m) => m.add(1, 'month'))}>
              <ChevronRight />
            </IconButton>
          </Box>
          <Box sx={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', gap: 0.5, textAlign: 'center' }}>
            {weekLabels.map((w) => (
              <Typography key={w} variant="caption" color="text.secondary" sx={{ py: 0.5 }}>{w}</Typography>
            ))}
            {matrix.flat().map((d, i) => (
              <Box key={i} sx={{ py: 0.5 }}>
                {d == null ? null : (
                  <button
                    type="button"
                    onClick={() => {
                      const ds = month.date(d).format('YYYY-MM-DD');
                      setSelectedDate(ds);
                    }}
                    style={{
                      width: 36,
                      height: 36,
                      borderRadius: '50%',
                      border: 'none',
                      cursor: 'pointer',
                      background:
                        month.date(d).format('YYYY-MM-DD') === selectedDate
                          ? '#1976d2'
                          : 'transparent',
                      color:
                        month.date(d).format('YYYY-MM-DD') === selectedDate
                          ? '#fff'
                          : 'inherit',
                      fontWeight: month.date(d).format('YYYY-MM-DD') === selectedDate ? 700 : 400,
                    }}
                  >
                    {d}
                  </button>
                )}
              </Box>
            ))}
          </Box>
          <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mt: 1 }}>
            当前选择：{selectedDate}（UTC 日） · 每 2 小时一段
          </Typography>
        </CardContent>
      </Card>

      <Card sx={{ mx: 2, mb: 2, flex: 1, minHeight: 200 }}>
        <CardContent>
          <Typography variant="subtitle2" gutterBottom>轨迹列表（按手机号分组）</Typography>
          {loading ? (
            <Box sx={{ display: 'flex', justifyContent: 'center', py: 4 }}><CircularProgress size={28} /></Box>
          ) : !summary?.users?.length ? (
            <Typography color="text.secondary" variant="body2">该日暂无轨迹数据</Typography>
          ) : (
            summary.users.map((u) => (
              <Box key={u.user_id} sx={{ border: '1px solid', borderColor: 'divider', borderRadius: 1, mb: 1 }}>
                <ListItemButton onClick={() => toggleUser(u.user_id)}>
                  <ListItemText
                    primary={`${u.phone}${u.nickname ? ` · ${u.nickname}` : ''}`}
                    secondary={`${u.segments.length} 段轨迹`}
                  />
                  {openUser[u.user_id] ? <ExpandLess /> : <ExpandMore />}
                </ListItemButton>
                <Collapse in={!!openUser[u.user_id]}>
                  <Divider />
                  <List dense disablePadding>
                    {u.segments.map((seg, idx) => (
                      <ListItemButton
                        key={`${seg.start_time}-${idx}`}
                        onClick={() => openSegmentDetail(u, seg)}
                      >
                        <ListItemText
                          primary={`${dayjs(seg.start_time).format('HH:mm')} – ${dayjs(seg.end_time).format('HH:mm')}`}
                          secondary={`${seg.point_count} 个点 · 点击查看地图轨迹`}
                        />
                      </ListItemButton>
                    ))}
                  </List>
                </Collapse>
              </Box>
            ))
          )}
        </CardContent>
      </Card>

      <Dialog open={detailOpen} onClose={handleCloseDetail} fullWidth maxWidth="md" keepMounted={false}>
        <DialogTitle sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <span style={{ fontSize: 16 }}>{detailTitle}</span>
          <IconButton onClick={handleCloseDetail} size="small"><Close /></IconButton>
        </DialogTitle>
        <DialogContent sx={{ p: 0, height: 420 }}>
          <Box sx={{ position: 'relative', width: '100%', height: 400 }}>
            {detailLoading && (
              <Box sx={{
                position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1, bgcolor: 'background.paper',
              }}
              >
                <CircularProgress />
              </Box>
            )}
            <Box ref={mapRef} sx={{ width: '100%', height: '100%' }} />
          </Box>
        </DialogContent>
      </Dialog>
    </Box>
  );
}
