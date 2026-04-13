import React from 'react';
import { Outlet, useNavigate, useLocation } from 'react-router-dom';
import { Box, BottomNavigation, BottomNavigationAction, AppBar, Toolbar, Typography, IconButton, Badge } from '@mui/material';
import { Map, Group, ShareLocation, Timeline, Notifications, Settings, Logout } from '@mui/icons-material';
import { useAuthStore } from '@/store/auth';

const navItems = [
  { label: '地图', icon: <Map />, path: '/' },
  { label: '家庭', icon: <Group />, path: '/family' },
  { label: '共享', icon: <ShareLocation />, path: '/sharing' },
  { label: '轨迹', icon: <Timeline />, path: '/trajectory' },
  { label: '通知', icon: <Notifications />, path: '/notifications' },
  { label: '设置', icon: <Settings />, path: '/settings' },
];

export default function AppLayout() {
  const navigate = useNavigate();
  const location = useLocation();
  const { logout, nickname, phone } = useAuthStore();
  const currentIndex = navItems.findIndex((n) => n.path === location.pathname);

  return (
    <Box sx={{ display: 'flex', flexDirection: 'column', height: '100vh' }}>
      <AppBar position="static" elevation={1}>
        <Toolbar>
          <Typography variant="h6" sx={{ flexGrow: 1, fontWeight: 700 }}>定位共享</Typography>
          <Typography variant="body2" sx={{ mr: 1 }}>{nickname || phone}</Typography>
          <IconButton color="inherit" onClick={() => { logout(); navigate('/login'); }}><Logout /></IconButton>
        </Toolbar>
      </AppBar>
      <Box sx={{ flex: 1, overflow: 'auto' }}>
        <Outlet />
      </Box>
      <BottomNavigation value={currentIndex >= 0 ? currentIndex : 0} showLabels
        onChange={(_, idx) => navigate(navItems[idx].path)}
        sx={{ borderTop: 1, borderColor: 'divider' }}>
        {navItems.map((item) => (
          <BottomNavigationAction key={item.path} label={item.label} icon={item.icon} />
        ))}
      </BottomNavigation>
    </Box>
  );
}
