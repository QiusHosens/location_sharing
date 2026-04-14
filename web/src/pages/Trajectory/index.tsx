import React, { useCallback, useEffect, useRef, useState } from 'react';
import {
  Box,
  Typography,
  Card,
  CardContent,
  CircularProgress,
  Dialog,
  DialogTitle,
  DialogContent,
  IconButton,
  Collapse,
  Avatar,
  Button,
  Popover,
} from '@mui/material';
import {
  ChevronRight,
  Close,
  ExpandMore,
  ExpandLess,
  FilterList,
  Place,
} from '@mui/icons-material';
import { getTrajectoryDaySummary, getTrajectory } from '@/api/location';
import { loadAmapScript } from '@/utils/amap';
import { wgs84ToGcj02 } from '@/utils/coord';
import dayjs from 'dayjs';
import { brandBlue } from '@/theme';

type Segment = { start_time: string; end_time: string; point_count: number };
type UserDay = { user_id: string; phone: string; nickname?: string; segments: Segment[] };

const WEEK: string[] = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];

function maskPhone(p: string) {
  const s = (p || '').replace(/\s/g, '');
  if (s.length >= 11) return `${s.slice(0, 3)}****${s.slice(-4)}`;
  if (s.length >= 7) return `${s.slice(0, 3)}****${s.slice(-2)}`;
  return s || '—';
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
  const [monthAnchor, setMonthAnchor] = useState<HTMLElement | null>(null);

  const dayCount = month.daysInMonth();
  const daysArr = Array.from({ length: dayCount }, (_, i) => i + 1);

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
    if (!summary?.users?.length) {
      setOpenUser({});
      return;
    }
    setOpenUser({ [summary.users[0].user_id]: true });
  }, [summary]);

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
    const path = detailPoints
      .map((p: any) => {
        const gcj = wgs84ToGcj02(Number(p.latitude), Number(p.longitude));
        return [gcj.longitude, gcj.latitude];
      })
      .filter((x) => Number.isFinite(x[0]) && Number.isFinite(x[1]));
    if (!path.length) return;
    const polyline = new window.AMap.Polyline({
      path,
      strokeColor: brandBlue,
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
      `${maskPhone(u.phone)} · ${dayjs(seg.start_time).format('HH:mm')}–${dayjs(seg.end_time).format('HH:mm')} · ${seg.point_count} 点`,
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

  const toggleUser = (id: string) => {
    setOpenUser((o) => ({ ...o, [id]: !o[id] }));
  };

  const displayName = (u: UserDay) => {
    if (u.nickname && u.nickname.trim()) return u.nickname;
    return maskPhone(u.phone);
  };

  const subtitleForUser = (u: UserDay) => {
    const n = u.segments.length;
    if (n === 0) return '无记录 · 状态：静止';
    return `${n} 条轨迹`;
  };

  return (
    <Box
      sx={{
        display: 'flex',
        flexDirection: 'column',
        height: '100%',
        overflow: 'auto',
        pb: 10,
        bgcolor: '#F3F4F6',
      }}
    >
      <Box sx={{ px: 2, pt: 2, pb: 1, display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between' }}>
        <Typography sx={{ color: '#111827', fontWeight: 800, fontSize: 22 }}>
          历史轨迹
        </Typography>
        <IconButton
          size="small"
          onClick={(e) => setMonthAnchor(e.currentTarget)}
          sx={{ color: brandBlue }}
          aria-label="筛选月份"
        >
          <FilterList />
        </IconButton>
      </Box>

      <Box sx={{ px: 2, pb: 1.5, display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <Typography sx={{ fontWeight: 700, color: '#111827', fontSize: 16 }}>
          {month.format('YYYY年M月')}
        </Typography>
        <Button
          size="small"
          onClick={(e) => setMonthAnchor(e.currentTarget)}
          sx={{ color: brandBlue, fontWeight: 700, textTransform: 'none' }}
        >
          选择月份
        </Button>
      </Box>

      <Popover
        open={Boolean(monthAnchor)}
        anchorEl={monthAnchor}
        onClose={() => setMonthAnchor(null)}
        anchorOrigin={{ vertical: 'bottom', horizontal: 'right' }}
        transformOrigin={{ vertical: 'top', horizontal: 'right' }}
      >
        <Box sx={{ p: 2, minWidth: 260 }}>
          <Typography variant="subtitle2" sx={{ mb: 1, fontWeight: 700 }}>
            选择月份
          </Typography>
          <input
            type="month"
            value={month.format('YYYY-MM')}
            onChange={(e) => {
              const v = e.target.value;
              if (!v) return;
              const next = dayjs(v + '-01');
              setMonth(next);
              const d = Math.min(dayjs(selectedDate).date(), next.daysInMonth());
              setSelectedDate(next.date(d).format('YYYY-MM-DD'));
              setMonthAnchor(null);
            }}
            style={{ width: '100%', padding: 8, borderRadius: 8, border: '1px solid #e5e7eb' }}
          />
        </Box>
      </Popover>

      <Box
        sx={{
          mx: 2,
          mb: 1.5,
          display: 'flex',
          gap: 1,
          overflowX: 'auto',
          pb: 0.5,
          flexShrink: 0,
          '&::-webkit-scrollbar': { height: 4 },
        }}
      >
        {daysArr.map((d) => {
          const ds = month.date(d).format('YYYY-MM-DD');
          const sel = ds === selectedDate;
          const wd = month.date(d).day();
          return (
            <Card
              key={ds}
              elevation={sel ? 4 : 0}
              onClick={() => setSelectedDate(ds)}
              sx={{
                minWidth: 56,
                borderRadius: '14px',
                cursor: 'pointer',
                flexShrink: 0,
                bgcolor: sel ? brandBlue : '#fff',
                color: sel ? '#fff' : 'text.secondary',
                border: sel ? 'none' : '1px solid rgba(0,0,0,0.06)',
                boxShadow: sel ? '0 4px 14px rgba(25,118,210,0.35)' : undefined,
                transition: 'background 0.15s, color 0.15s, box-shadow 0.15s',
              }}
            >
              <CardContent sx={{ py: 1.25, px: 1, '&:last-child': { pb: 1.25 }, textAlign: 'center' }}>
                <Typography variant="caption" sx={{ display: 'block', opacity: sel ? 0.95 : 0.85, fontWeight: 600 }}>
                  {WEEK[wd]}
                </Typography>
                <Typography sx={{ fontWeight: 800, fontSize: 17, lineHeight: 1.2 }}>{d}</Typography>
              </CardContent>
            </Card>
          );
        })}
      </Box>

      <Box sx={{ px: 2, pb: 2 }}>
        {loading ? (
          <Box sx={{ display: 'flex', justifyContent: 'center', py: 6 }}>
            <CircularProgress sx={{ color: brandBlue }} size={32} />
          </Box>
        ) : !summary?.users?.length ? (
          <Card sx={{ borderRadius: '18px', boxShadow: '0 2px 12px rgba(0,0,0,0.06)' }}>
            <CardContent>
              <Typography color="text.secondary" variant="body2" sx={{ textAlign: 'center', py: 2 }}>
                该日暂无轨迹数据
              </Typography>
            </CardContent>
          </Card>
        ) : (
          summary.users.map((u) => {
            const expanded = !!openUser[u.user_id];
            const letter = displayName(u)[0] || '?';
            return (
              <Card
                key={u.user_id}
                sx={{
                  mb: 1.5,
                  borderRadius: '18px',
                  overflow: 'hidden',
                  boxShadow: '0 2px 12px rgba(0,0,0,0.06)',
                  border: '1px solid rgba(0,0,0,0.04)',
                }}
              >
                <Box
                  onClick={() => toggleUser(u.user_id)}
                  sx={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: 1.5,
                    p: 2,
                    cursor: 'pointer',
                    bgcolor: '#fff',
                  }}
                >
                  <Avatar
                    sx={{
                      width: 48,
                      height: 48,
                      fontWeight: 800,
                      bgcolor: 'primary.light',
                    }}
                  >
                    {letter}
                  </Avatar>
                  <Box sx={{ flex: 1, minWidth: 0 }}>
                    <Typography sx={{ fontWeight: 800, fontSize: 16, color: '#111827' }}>
                      {displayName(u)}
                    </Typography>
                    <Typography variant="body2" color="text.secondary" sx={{ mt: 0.25 }}>
                      {subtitleForUser(u)}
                    </Typography>
                  </Box>
                  {expanded ? <ExpandLess sx={{ color: 'text.secondary' }} /> : <ExpandMore sx={{ color: 'text.secondary' }} />}
                </Box>

                <Collapse in={expanded}>
                  <Box sx={{ px: 2, pb: 2, pt: 0, display: 'flex', flexDirection: 'column', gap: 1 }}>
                    {u.segments.map((seg, idx) => (
                      <Box
                        key={`${seg.start_time}-${idx}`}
                        onClick={() => openSegmentDetail(u, seg)}
                        sx={{
                          display: 'flex',
                          alignItems: 'stretch',
                          gap: 1.25,
                          bgcolor: '#F3F4F6',
                          borderRadius: '14px',
                          p: 1.25,
                          cursor: 'pointer',
                          border: '1px solid rgba(0,0,0,0.04)',
                          '&:hover': { bgcolor: '#EEF2F7' },
                        }}
                      >
                        <Box
                          sx={{
                            width: 64,
                            height: 64,
                            borderRadius: '12px',
                            bgcolor: '#E5E7EB',
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'center',
                            flexShrink: 0,
                          }}
                        >
                          <Place sx={{ fontSize: 32, color: brandBlue }} />
                        </Box>
                        <Box sx={{ flex: 1, minWidth: 0, py: 0.25 }}>
                          <Typography sx={{ color: brandBlue, fontWeight: 700, fontSize: 14 }}>
                            {dayjs(seg.start_time).format('HH:mm')} - {dayjs(seg.end_time).format('HH:mm')}
                          </Typography>
                          <Typography sx={{ fontWeight: 800, color: '#111827', mt: 0.5, fontSize: 15 }}>
                            轨迹分段 #{idx + 1}
                          </Typography>
                          <Typography variant="caption" color="text.secondary" sx={{ mt: 0.25, display: 'block' }}>
                            {maskPhone(u.phone)}
                          </Typography>
                        </Box>
                        <Box sx={{ display: 'flex', alignItems: 'center', pr: 0.5 }}>
                          <ChevronRight sx={{ color: brandBlue, fontSize: 28 }} />
                        </Box>
                      </Box>
                    ))}
                  </Box>
                </Collapse>
              </Card>
            );
          })
        )}
      </Box>

      <Dialog open={detailOpen} onClose={handleCloseDetail} fullWidth maxWidth="md" keepMounted={false}>
        <DialogTitle sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <span style={{ fontSize: 16 }}>{detailTitle}</span>
          <IconButton onClick={handleCloseDetail} size="small"><Close /></IconButton>
        </DialogTitle>
        <DialogContent sx={{ p: 0, height: 420 }}>
          <Box sx={{ position: 'relative', width: '100%', height: 400 }}>
            {detailLoading && (
              <Box
                sx={{
                  position: 'absolute',
                  inset: 0,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  zIndex: 1,
                  bgcolor: 'background.paper',
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
