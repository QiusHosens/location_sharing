import React from 'react';
import { Outlet, useNavigate, useLocation } from 'react-router-dom';
import {
  Box,
  BottomNavigation,
  BottomNavigationAction,
  AppBar,
  Toolbar,
  Typography,
  IconButton,
  Avatar,
} from '@mui/material';
import { Map, Group, Route, Settings, NotificationsNone } from '@mui/icons-material';
import { useAuthStore } from '@/store/auth';
import { brandBlue } from '@/theme';

/** 与移动端 HomeShell 一致：地图、家庭、足迹、设置；通知从顶栏进入（共享页直达 /sharing） */
const navItems = [
  { label: '地图', icon: <Map sx={{ fontSize: 26 }} />, path: '/' },
  { label: '家庭', icon: <Group sx={{ fontSize: 26 }} />, path: '/family' },
  { label: '足迹', icon: <Route sx={{ fontSize: 26 }} />, path: '/trajectory' },
  { label: '设置', icon: <Settings sx={{ fontSize: 26 }} />, path: '/settings' },
];

function bottomIndex(pathname: string): number {
  if (pathname === '/notifications' || pathname === '/sharing') return 3;
  const i = navItems.findIndex((n) => n.path === pathname);
  return i >= 0 ? i : 0;
}

export default function AppLayout() {
  const navigate = useNavigate();
  const location = useLocation();
  const { nickname, phone } = useAuthStore();
  const currentIndex = bottomIndex(location.pathname);
  const initial = (nickname || phone || '?').trim()[0]?.toUpperCase() ?? '?';

  return (
    <Box sx={{ display: 'flex', flexDirection: 'column', height: '100vh', bgcolor: 'background.default' }}>
      <AppBar
        position="static"
        elevation={0}
        sx={{
          bgcolor: 'background.default',
          borderBottom: '1px solid',
          borderColor: 'rgba(0,0,0,0.06)',
          color: 'text.primary',
        }}
      >
        <Toolbar sx={{ minHeight: 56, py: 0.5 }}>
          <Avatar
            sx={{
              width: 36,
              height: 36,
              mr: 1.25,
              bgcolor: 'primary.light',
              color: 'primary.dark',
              fontSize: 16,
              fontWeight: 700,
            }}
          >
            {initial}
          </Avatar>
          <Typography variant="h6" sx={{ flexGrow: 1, fontWeight: 800, fontSize: 17, letterSpacing: 0.2 }}>
            位置共享
          </Typography>
          <IconButton
            edge="end"
            size="small"
            onClick={() => navigate('/notifications')}
            aria-label="通知"
            sx={{ color: 'text.primary', ml: 0.5 }}
          >
            <NotificationsNone />
          </IconButton>
        </Toolbar>
      </AppBar>
      <Box sx={{ flex: 1, overflow: 'auto', position: 'relative' }}>
        <Outlet />
      </Box>
      <BottomNavigation
        value={currentIndex}
        showLabels
        onChange={(_, idx) => navigate(navItems[idx].path)}
        sx={{
          bgcolor: 'background.paper',
          '& .MuiBottomNavigationAction-label': {
            fontSize: 11,
            fontWeight: 600,
            mt: 0.25,
            '&.Mui-selected': { fontSize: 11, color: brandBlue },
          },
        }}
      >
        {navItems.map((item) => (
          <BottomNavigationAction key={item.path} label={item.label} icon={item.icon} />
        ))}
      </BottomNavigation>
    </Box>
  );
}
