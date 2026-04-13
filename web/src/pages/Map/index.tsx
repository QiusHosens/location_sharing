import React, { useEffect, useRef, useState } from 'react';
import { Box, CircularProgress, Fab, Chip, Avatar, Stack } from '@mui/material';
import { Refresh } from '@mui/icons-material';
import { getLatestLocation, getFamilyLocations } from '@/api/location';
import { getGroups } from '@/api/user';
import { useAuthStore } from '@/store/auth';
import { connectMqtt, disconnectMqtt } from '@/mqtt/client';
import { loadAmapScript } from '@/utils/amap';

export default function MapPage() {
  const mapRef = useRef<HTMLDivElement>(null);
  const mapInstance = useRef<any>(null);
  const markersRef = useRef<Map<string, any>>(new Map());
  const { userId } = useAuthStore();
  const [loading, setLoading] = useState(true);
  const [members, setMembers] = useState<any[]>([]);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        await loadAmapScript();
        if (cancelled || !mapRef.current || !window.AMap) return;
        mapInstance.current = new window.AMap.Map(mapRef.current, {
          zoom: 14, viewMode: '3D',
          center: [116.397, 39.908],
        });
        setLoading(false);
        await loadLocations();
        const uid = useAuthStore.getState().userId;
        if (uid) {
          connectMqtt(uid, handleLocationUpdate, handleNotification);
        }
      } catch (e) {
        console.error('地图初始化失败', e);
        setLoading(false);
      }
    })();
    return () => { cancelled = true; disconnectMqtt(); };
  }, []);

  const handleLocationUpdate = (data: any) => {
    updateMarker(data.user_id, data.longitude, data.latitude, data.nickname || data.user_id);
  };

  const handleNotification = (data: any) => {
    console.log('Notification:', data);
  };

  const updateMarker = (uid: string, lng: number, lat: number, label: string) => {
    if (!mapInstance.current) return;
    const existing = markersRef.current.get(uid);
    if (existing) {
      existing.setPosition([lng, lat]);
    } else {
      const color = uid === userId ? '#2196f3' : '#4caf50';
      const marker = new window.AMap.Marker({
        position: [lng, lat],
        content: `<div style="background:${color};color:#fff;padding:4px 10px;border-radius:12px;font-size:12px;white-space:nowrap">${label}</div>`,
        anchor: 'center',
      });
      mapInstance.current.add(marker);
      markersRef.current.set(uid, marker);
    }
  };

  const loadLocations = async () => {
    try {
      const myLoc = await getLatestLocation();
      if (myLoc) {
        updateMarker(userId!, myLoc.longitude, myLoc.latitude, '我');
        mapInstance.current?.setCenter([myLoc.longitude, myLoc.latitude]);
      }
      const groups = await getGroups();
      const allMembers: any[] = [];
      for (const g of groups) {
        try {
          const locs = await getFamilyLocations(g.id);
          locs.forEach((loc: any) => {
            allMembers.push(loc);
            updateMarker(loc.user_id, loc.longitude, loc.latitude, loc.nickname || '家人');
          });
        } catch {}
      }
      setMembers(allMembers);
    } catch (err) {
      console.error('Load locations error:', err);
    }
  };

  return (
    <Box sx={{ position: 'relative', height: '100%' }}>
      <div ref={mapRef} style={{ width: '100%', height: '100%' }} />
      {loading && (
        <Box sx={{ position: 'absolute', top: '50%', left: '50%', transform: 'translate(-50%,-50%)' }}>
          <CircularProgress />
        </Box>
      )}
      {members.length > 0 && (
        <Stack direction="row" spacing={1} sx={{ position: 'absolute', top: 12, left: 12, zIndex: 10 }}>
          {members.map((m) => (
            <Chip key={m.user_id} avatar={<Avatar>{(m.nickname || '?')[0]}</Avatar>}
              label={m.nickname || '家人'} variant="filled" color="success" size="small"
              onClick={() => mapInstance.current?.setCenter([m.longitude, m.latitude])} />
          ))}
        </Stack>
      )}
      <Fab color="primary" size="small" onClick={loadLocations}
        sx={{ position: 'absolute', bottom: 16, right: 16, zIndex: 10 }}>
        <Refresh />
      </Fab>
    </Box>
  );
}
