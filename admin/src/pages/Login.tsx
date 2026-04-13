import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Box, Card, CardContent, TextField, Button, Typography, Alert, InputAdornment, IconButton } from '@mui/material';
import { Visibility, VisibilityOff, LocationOn } from '@mui/icons-material';
import { adminLogin } from '@/api/client';
import { useAuthStore } from '@/store/auth';

export default function LoginPage() {
  const navigate = useNavigate();
  const { setAuth } = useAuthStore();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [showPwd, setShowPwd] = useState(false);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      const res = await adminLogin(username, password);
      setAuth(res.access_token, res.admin_id, res.username);
      navigate('/');
    } catch (err: any) {
      setError(err.response?.data?.error || '登录失败，请检查用户名和密码');
    } finally {
      setLoading(false);
    }
  };

  return (
    <Box sx={{ minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center', bgcolor: 'background.default' }}>
      <Card sx={{ width: 400, mx: 2 }}>
        <CardContent sx={{ p: 4 }}>
          <Box sx={{ textAlign: 'center', mb: 3 }}>
            <LocationOn sx={{ fontSize: 48, color: 'primary.main' }} />
            <Typography variant="h5" fontWeight={700}>定位共享管理后台</Typography>
            <Typography variant="body2" color="text.secondary" sx={{ mt: 0.5 }}>请登录管理员账号</Typography>
          </Box>
          {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}
          <form onSubmit={handleSubmit}>
            <TextField label="用户名" fullWidth required value={username} onChange={(e) => setUsername(e.target.value)} sx={{ mb: 2 }} />
            <TextField label="密码" type={showPwd ? 'text' : 'password'} fullWidth required value={password}
              onChange={(e) => setPassword(e.target.value)} sx={{ mb: 3 }}
              InputProps={{ endAdornment: (
                <InputAdornment position="end">
                  <IconButton onClick={() => setShowPwd(!showPwd)} edge="end">{showPwd ? <VisibilityOff /> : <Visibility />}</IconButton>
                </InputAdornment>
              ) }} />
            <Button type="submit" variant="contained" fullWidth size="large" disabled={loading}>
              {loading ? '登录中...' : '登 录'}
            </Button>
          </form>
        </CardContent>
      </Card>
    </Box>
  );
}
