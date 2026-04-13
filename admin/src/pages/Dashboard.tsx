import React, { useEffect, useState } from 'react';
import { Box, Grid, Card, CardContent, Typography, CircularProgress } from '@mui/material';
import { People, Group, ShareLocation, MyLocation } from '@mui/icons-material';
import { getStats } from '@/api/client';

interface Stats {
  total_users: number;
  total_groups: number;
  active_sharing: number;
  today_locations: number;
}

const statCards = [
  { key: 'total_users' as const, label: '总用户数', icon: <People />, color: '#1976d2' },
  { key: 'total_groups' as const, label: '家庭组数', icon: <Group />, color: '#4caf50' },
  { key: 'active_sharing' as const, label: '活跃共享', icon: <ShareLocation />, color: '#ff9800' },
  { key: 'today_locations' as const, label: '今日定位', icon: <MyLocation />, color: '#e91e63' },
];

export default function DashboardPage() {
  const [stats, setStats] = useState<Stats | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    getStats().then(setStats).finally(() => setLoading(false));
  }, []);

  if (loading) return <Box sx={{ display: 'flex', justifyContent: 'center', mt: 8 }}><CircularProgress /></Box>;

  return (
    <Box>
      <Typography variant="h5" fontWeight={700} gutterBottom>仪表盘</Typography>
      <Grid container spacing={3}>
        {statCards.map((card) => (
          <Grid item xs={12} sm={6} md={3} key={card.key}>
            <Card>
              <CardContent sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
                <Box sx={{ p: 1.5, borderRadius: 2, bgcolor: card.color + '15', color: card.color, display: 'flex' }}>
                  {React.cloneElement(card.icon, { sx: { fontSize: 32 } })}
                </Box>
                <Box>
                  <Typography variant="body2" color="text.secondary">{card.label}</Typography>
                  <Typography variant="h4" fontWeight={700}>{stats?.[card.key]?.toLocaleString() ?? '-'}</Typography>
                </Box>
              </CardContent>
            </Card>
          </Grid>
        ))}
      </Grid>
    </Box>
  );
}
