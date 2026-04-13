import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Box, Card, CardContent, TextField, Button, Typography, Alert, Tabs, Tab } from '@mui/material';
import { LocationOn } from '@mui/icons-material';
import { login, register } from '@/api/auth';
import { useAuthStore } from '@/store/auth';

export default function LoginPage() {
  const navigate = useNavigate();
  const { setAuth } = useAuthStore();
  const [tab, setTab] = useState(0);
  const [phone, setPhone] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const submit = async () => {
    if (phone.length < 11) { setError('请输入正确的手机号'); return; }
    if (!password) { setError('请输入密码'); return; }
    setError('');
    setLoading(true);
    try {
      const res = tab === 0
        ? await login(phone, password)
        : await register(phone, password);
      setAuth(res.access_token, res.user_id, phone);
      navigate('/');
    } catch (err: any) {
      const msg = err.response?.data?.error;
      setError(typeof msg === 'string' ? msg : (tab === 0 ? '登录失败' : '注册失败'));
    } finally {
      setLoading(false);
    }
  };

  return (
    <Box sx={{ minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center', bgcolor: 'background.default' }}>
      <Card sx={{ width: 420, mx: 2 }}>
        <CardContent sx={{ p: 4 }}>
          <Box sx={{ textAlign: 'center', mb: 2 }}>
            <LocationOn sx={{ fontSize: 48, color: 'primary.main' }} />
            <Typography variant="h5" fontWeight={700}>定位共享</Typography>
            <Typography variant="body2" color="text.secondary">家人位置，安心守护</Typography>
          </Box>
          <Tabs value={tab} onChange={(_, v) => { setTab(v); setError(''); }} sx={{ mb: 2 }}>
            <Tab label="登录" />
            <Tab label="注册" />
          </Tabs>
          {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}
          <TextField label="手机号" fullWidth value={phone} onChange={(e) => setPhone(e.target.value)} inputProps={{ maxLength: 15 }} sx={{ mb: 2 }} />
          <TextField label="密码" type="password" fullWidth value={password} onChange={(e) => setPassword(e.target.value)} sx={{ mb: 3 }} />
          <Button variant="contained" fullWidth size="large" onClick={submit} disabled={loading}>
            {loading ? '提交中...' : tab === 0 ? '登 录' : '注 册'}
          </Button>
        </CardContent>
      </Card>
    </Box>
  );
}
