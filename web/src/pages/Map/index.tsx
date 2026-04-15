import React, { useEffect, useRef, useState, useCallback, useMemo } from 'react';
import {
  Box,
  CircularProgress,
  Fab,
  Typography,
  Paper,
  Avatar,
  IconButton,
} from '@mui/material';
import { Refresh, TurnRight, BatteryStd, BatteryAlert } from '@mui/icons-material';
import { brandBlue } from '@/theme';
import { getLatestLocation, getFamilyLocations } from '@/api/location';
import { getGroups } from '@/api/user';
import { useAuthStore } from '@/store/auth';
import { connectMqtt, disconnectMqtt } from '@/mqtt/client';
import { loadAmapScript } from '@/utils/amap';
import { resolveMediaUrl } from '@/utils/mediaUrl';

type LocRow = {
  user_id: string;
  nickname?: string;
  longitude: number;
  latitude: number;
  battery_level?: number | null;
  avatar_url?: string;
  recorded_at?: string;
};

function dedupeLatest(locs: LocRow[]): LocRow[] {
  const map = new Map<string, LocRow>();
  for (const l of locs) {
    const id = String(l.user_id);
    const cur = map.get(id);
    if (!cur) {
      map.set(id, l);
      continue;
    }
    const t1 = cur.recorded_at || '';
    const t2 = l.recorded_at || '';
    if (t2 > t1) map.set(id, l);
  }
  return Array.from(map.values());
}

/** 与后端一致存 GCJ-02，直接用于高德 JS API / uri.amap */
function openAmapNavigation(lng: number, lat: number, name: string) {
  const to = `${lng},${lat},${encodeURIComponent(name)}`;
  window.open(`https://uri.amap.com/navigation?to=${to}&mode=car&src=location-sharing&coordinate=gaode`, '_blank');
}

export default function MapPage() {
  const mapRef = useRef<HTMLDivElement>(null);
  const mapInstance = useRef<any>(null);
  const markersRef = useRef<Map<string, any>>(new Map());
  const { userId } = useAuthStore();
  const [loading, setLoading] = useState(true);
  const [members, setMembers] = useState<LocRow[]>([]);

  const buildMarkerContent = (label: string, letter: string, color: string, isSelf: boolean) => {
    const esc = (s: string) =>
      s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
    const dot = isSelf
      ? '<div style="width:10px;height:10px;background:#fff;border:3px solid ' +
        esc(color) +
        ';border-radius:50%;margin-top:2px;box-shadow:0 1px 4px rgba(0,0,0,.2)"></div>'
      : '';
    return `<div style="display:flex;flex-direction:column;align-items:center;pointer-events:auto;">
      <div style="width:52px;height:52px;border-radius:50%;background:${esc(color)};color:#fff;
        display:flex;align-items:center;justify-content:center;font-weight:800;font-size:18px;
        border:3px solid #fff;box-shadow:0 2px 10px rgba(0,0,0,.18);">${esc(letter)}</div>
      <div style="margin-top:6px;background:#fff;padding:3px 10px;border-radius:10px;font-size:11px;
        color:#111;box-shadow:0 1px 6px rgba(0,0,0,.12);white-space:nowrap;max-width:120px;overflow:hidden;text-overflow:ellipsis;">${esc(label)}</div>
      ${dot}
    </div>`;
  };

  const updateMarker = useCallback(
    (uid: string, lng: number, lat: number, label: string, isSelf: boolean) => {
      if (!mapInstance.current || !window.AMap) return;
      const letter = (label && label[0]) || '?';
      const color = uid === userId ? brandBlue : '#22C55E';
      const content = buildMarkerContent(label, letter, color, isSelf);
      const existing = markersRef.current.get(uid);
      if (existing) {
        existing.setPosition([lng, lat]);
        existing.setContent(content);
      } else {
        const marker = new window.AMap.Marker({
          position: [lng, lat],
          content,
          anchor: new window.AMap.Pixel(-26, -70),
          offset: new window.AMap.Pixel(0, 0),
        });
        mapInstance.current.add(marker);
        markersRef.current.set(uid, marker);
      }
    },
    [userId]
  );

  const loadLocations = useCallback(async () => {
    const collected: LocRow[] = [];
    try {
      const myLoc = await getLatestLocation();
      if (myLoc && userId) {
        const row: LocRow = {
          user_id: userId,
          nickname: '我',
          longitude: myLoc.longitude,
          latitude: myLoc.latitude,
          battery_level:
            myLoc.battery_level != null ? Number(myLoc.battery_level) : null,
          recorded_at: myLoc.recorded_at,
        };
        collected.push(row);
        updateMarker(userId, myLoc.longitude, myLoc.latitude, '我', true);
        mapInstance.current?.setCenter([myLoc.longitude, myLoc.latitude]);
      }
      const groups = await getGroups();
      for (const g of groups || []) {
        try {
          const locs = await getFamilyLocations(g.id);
          for (const raw of locs || []) {
            const loc = raw as LocRow;
            collected.push(loc);
            const id = String(loc.user_id);
            const name =
              id === userId ? '我' : loc.nickname || loc.user_id?.toString().slice(0, 6) || '家人';
            updateMarker(id, loc.longitude, loc.latitude, name, id === userId);
          }
        } catch {
          /* ignore */
        }
      }
      setMembers(dedupeLatest(collected));
    } catch (err) {
      console.error('Load locations error:', err);
    }
  }, [updateMarker, userId]);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        await loadAmapScript();
        if (cancelled || !mapRef.current || !window.AMap) return;
        mapInstance.current = new window.AMap.Map(mapRef.current, {
          zoom: 15,
          viewMode: '3D',
          center: [116.397428, 39.90923],
        });
        setLoading(false);
        await loadLocations();
        const uid = useAuthStore.getState().userId;
        if (uid) connectMqtt(uid, handleLocationUpdate, handleNotification);
      } catch (e) {
        console.error('地图初始化失败', e);
        setLoading(false);
      }
    })();
    return () => {
      cancelled = true;
      disconnectMqtt();
    };
  }, []);

  const handleLocationUpdate = (data: {
    user_id: string;
    longitude: number;
    latitude: number;
    nickname?: string;
  }) => {
    const id = String(data.user_id);
    const name = id === userId ? '我' : data.nickname || '家人';
    updateMarker(id, data.longitude, data.latitude, name, id === userId);
    setMembers((prev) => {
      const next = prev.filter((p) => String(p.user_id) !== id);
      next.push({
        user_id: id,
        nickname: name,
        longitude: data.longitude,
        latitude: data.latitude,
      } as LocRow);
      return dedupeLatest(next);
    });
  };

  const handleNotification = () => {};

  const focusMember = useCallback((m: LocRow) => {
    if (!mapInstance.current) return;
    mapInstance.current.setZoomAndCenter?.(16, [m.longitude, m.latitude]);
  }, []);

  const panelList = useMemo(() => {
    return members
      .filter((m) => String(m.user_id) !== String(userId))
      .sort((a, b) =>
        (a.nickname || '').localeCompare(b.nickname || '', 'zh-CN')
      );
  }, [members, userId]);

  const selfRow = useMemo(
    () => members.find((m) => String(m.user_id) === String(userId)),
    [members, userId]
  );

  const displayRows = useMemo(() => {
    const list = [...panelList];
    if (selfRow) list.unshift(selfRow);
    else return panelList;
    const seen = new Set<string>();
    return list.filter((x) => {
      const id = String(x.user_id);
      if (seen.has(id)) return false;
      seen.add(id);
      return true;
    });
  }, [panelList, selfRow]);

  return (
    <Box sx={{ display: 'flex', flexDirection: 'column', height: '100%', bgcolor: '#E8EDF3' }}>
      <Box sx={{ flex: 1, position: 'relative', minHeight: 0 }}>
        <div ref={mapRef} style={{ width: '100%', height: '100%' }} />
        {loading && (
          <Box
            sx={{
              position: 'absolute',
              top: '50%',
              left: '50%',
              transform: 'translate(-50%,-50%)',
              zIndex: 5,
            }}
          >
            <CircularProgress />
          </Box>
        )}
        <Fab
          color="primary"
          size="small"
          onClick={loadLocations}
          sx={{
            position: 'absolute',
            bottom: 'min(52%, 420px)',
            right: 16,
            zIndex: 8,
            boxShadow: 3,
          }}
        >
          <Refresh />
        </Fab>

        <Paper
          elevation={12}
          sx={{
            position: 'absolute',
            left: 0,
            right: 0,
            bottom: 0,
            maxHeight: '48%',
            minHeight: 220,
            borderRadius: '24px 24px 0 0',
            zIndex: 9,
            display: 'flex',
            flexDirection: 'column',
            bgcolor: '#fff',
            overflow: 'hidden',
          }}
        >
          <Box
            sx={{
              width: 40,
              height: 4,
              borderRadius: 2,
              bgcolor: 'grey.300',
              alignSelf: 'center',
              mt: 1.25,
              mb: 0.5,
            }}
          />
          <Typography
            sx={{ px: 2, pt: 0.5, pb: 1, fontWeight: 800, fontSize: 17, color: '#111827' }}
          >
            家人状态
          </Typography>
          <Box sx={{ overflow: 'auto', px: 2, pb: 2, flex: 1 }}>
            {displayRows.length === 0 && (
              <Typography variant="body2" color="text.secondary" sx={{ py: 2 }}>
                暂无家人，加入家庭组后将显示在此
              </Typography>
            )}
            {displayRows.map((m) => {
              const name = m.nickname || m.user_id?.toString().slice(0, 8) || '家人';
              const batt = m.battery_level;
              const battNum =
                typeof batt === 'number' && !Number.isNaN(batt)
                  ? Math.round(Math.min(100, Math.max(0, batt)))
                  : null;
              const lowBatt = battNum != null && battNum < 35;
              return (
                <Box
                  key={m.user_id}
                  onClick={() => focusMember(m)}
                  sx={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: 1.5,
                    py: 1.5,
                    cursor: 'pointer',
                    borderBottom: '1px solid',
                    borderColor: 'rgba(0,0,0,0.06)',
                    '&:last-child': { borderBottom: 'none' },
                  }}
                >
                  <Avatar
                    src={resolveMediaUrl(m.avatar_url as string | undefined)}
                    sx={{
                      width: 48,
                      height: 48,
                      fontWeight: 800,
                      bgcolor: 'primary.light',
                    }}
                  >
                    {name[0]}
                  </Avatar>
                  <Box sx={{ flex: 1, minWidth: 0 }}>
                    <Typography sx={{ fontWeight: 800, fontSize: 16, color: '#111827' }}>
                      {name}
                    </Typography>
                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5, mt: 0.75 }}>
                      {lowBatt ? (
                        <BatteryAlert sx={{ fontSize: 18, color: '#ed6c02' }} />
                      ) : (
                        <BatteryStd sx={{ fontSize: 18, color: battNum != null ? '#2E7D32' : 'grey.400' }} />
                      )}
                      <Typography
                        variant="caption"
                        sx={{ color: lowBatt ? '#ed6c02' : battNum != null ? '#2E7D32' : 'text.secondary' }}
                      >
                        {battNum != null ? `${battNum}%` : '—'}
                      </Typography>
                    </Box>
                  </Box>
                  <IconButton
                    size="small"
                    onClick={(e) => {
                      e.stopPropagation();
                      openAmapNavigation(m.longitude, m.latitude, name);
                    }}
                    sx={{
                      bgcolor: brandBlue,
                      color: '#fff',
                      borderRadius: 2,
                      width: 44,
                      height: 44,
                      '&:hover': { bgcolor: brandBlue, opacity: 0.92 },
                    }}
                  >
                    <TurnRight sx={{ fontSize: 24 }} />
                  </IconButton>
                </Box>
              );
            })}
          </Box>
        </Paper>
      </Box>
    </Box>
  );
}
