import React, { useState } from 'react';
import { Outlet, useNavigate, useLocation } from 'react-router-dom';
import {
  Box, Drawer, AppBar, Toolbar, Typography, List, ListItemButton,
  ListItemIcon, ListItemText, IconButton, Divider, Avatar, Menu, MenuItem,
} from '@mui/material';
import {
  Dashboard as DashboardIcon, People as PeopleIcon,
  Settings as SettingsIcon, Menu as MenuIcon, Logout as LogoutIcon,
} from '@mui/icons-material';
import { useAuthStore } from '@/store/auth';

const DRAWER_WIDTH = 240;

const menuItems = [
  { text: '仪表盘', icon: <DashboardIcon />, path: '/' },
  { text: '用户管理', icon: <PeopleIcon />, path: '/users' },
  { text: '系统配置', icon: <SettingsIcon />, path: '/configs' },
];

export default function Layout() {
  const navigate = useNavigate();
  const location = useLocation();
  const { username, logout } = useAuthStore();
  const [mobileOpen, setMobileOpen] = useState(false);
  const [anchorEl, setAnchorEl] = useState<null | HTMLElement>(null);

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  const drawer = (
    <Box>
      <Toolbar>
        <Typography variant="h6" noWrap sx={{ fontWeight: 700 }}>
          定位共享
        </Typography>
      </Toolbar>
      <Divider />
      <List>
        {menuItems.map((item) => (
          <ListItemButton
            key={item.path}
            selected={location.pathname === item.path}
            onClick={() => { navigate(item.path); setMobileOpen(false); }}
          >
            <ListItemIcon>{item.icon}</ListItemIcon>
            <ListItemText primary={item.text} />
          </ListItemButton>
        ))}
      </List>
    </Box>
  );

  return (
    <Box sx={{ display: 'flex' }}>
      <AppBar position="fixed" sx={{ zIndex: (t) => t.zIndex.drawer + 1 }}>
        <Toolbar>
          <IconButton color="inherit" edge="start" onClick={() => setMobileOpen(!mobileOpen)} sx={{ mr: 2, display: { sm: 'none' } }}>
            <MenuIcon />
          </IconButton>
          <Typography variant="h6" noWrap sx={{ flexGrow: 1 }}>管理后台</Typography>
          <IconButton color="inherit" onClick={(e) => setAnchorEl(e.currentTarget)}>
            <Avatar sx={{ width: 32, height: 32, bgcolor: 'secondary.main' }}>
              {username?.[0]?.toUpperCase() || 'A'}
            </Avatar>
          </IconButton>
          <Menu anchorEl={anchorEl} open={!!anchorEl} onClose={() => setAnchorEl(null)}>
            <MenuItem disabled><Typography variant="body2">{username}</Typography></MenuItem>
            <Divider />
            <MenuItem onClick={handleLogout}><LogoutIcon sx={{ mr: 1 }} fontSize="small" />退出登录</MenuItem>
          </Menu>
        </Toolbar>
      </AppBar>
      <Drawer variant="temporary" open={mobileOpen} onClose={() => setMobileOpen(false)}
        sx={{ display: { xs: 'block', sm: 'none' }, '& .MuiDrawer-paper': { width: DRAWER_WIDTH } }}>
        {drawer}
      </Drawer>
      <Drawer variant="permanent"
        sx={{ display: { xs: 'none', sm: 'block' }, '& .MuiDrawer-paper': { width: DRAWER_WIDTH, boxSizing: 'border-box' } }}>
        {drawer}
      </Drawer>
      <Box component="main" sx={{ flexGrow: 1, p: 3, ml: { sm: `${DRAWER_WIDTH}px` } }}>
        <Toolbar />
        <Outlet />
      </Box>
    </Box>
  );
}
