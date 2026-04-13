import React, { useEffect, useState } from 'react';
import { Box, Typography, Card, CardContent, TextField, Button, Avatar, Snackbar, Alert, Divider } from '@mui/material';
import { Person, Save } from '@mui/icons-material';
import { getProfile, updateProfile } from '@/api/user';
import { useAuthStore } from '@/store/auth';

export default function SettingsPage() {
  const { phone, setProfile, logout } = useAuthStore();
  const [nickname, setNickname] = useState('');
  const [avatarUrl, setAvatarUrl] = useState('');
  const [loading, setLoading] = useState(false);
  const [snack, setSnack] = useState({ open: false, msg: '', severity: 'success' as 'success' | 'error' });

  useEffect(() => {
    getProfile().then((p: any) => {
      setNickname(p.nickname || '');
      setAvatarUrl(p.avatar_url || '');
      setProfile(p.nickname);
    }).catch(() => {});
  }, []);

  const handleSave = async () => {
    setLoading(true);
    try {
      await updateProfile({ nickname: nickname || undefined, avatar_url: avatarUrl || undefined });
      setProfile(nickname);
      setSnack({ open: true, msg: '个人资料已更新', severity: 'success' });
    } catch {
      setSnack({ open: true, msg: '更新失败', severity: 'error' });
    } finally { setLoading(false); }
  };

  return (
    <Box sx={{ p: 2, maxWidth: 500, mx: 'auto' }}>
      <Typography variant="h5" fontWeight={700} gutterBottom>个人设置</Typography>
      <Card sx={{ mb: 2 }}>
        <CardContent>
          <Box sx={{ display: 'flex', alignItems: 'center', gap: 2, mb: 3 }}>
            <Avatar sx={{ width: 64, height: 64, bgcolor: 'primary.main' }} src={avatarUrl || undefined}>
              <Person sx={{ fontSize: 32 }} />
            </Avatar>
            <Box>
              <Typography variant="h6">{nickname || '未设置昵称'}</Typography>
              <Typography variant="body2" color="text.secondary">{phone}</Typography>
            </Box>
          </Box>
          <TextField label="昵称" fullWidth value={nickname} onChange={(e) => setNickname(e.target.value)} sx={{ mb: 2 }} />
          <TextField label="头像URL" fullWidth value={avatarUrl} onChange={(e) => setAvatarUrl(e.target.value)} sx={{ mb: 3 }} helperText="输入头像图片链接" />
          <Button variant="contained" startIcon={<Save />} onClick={handleSave} disabled={loading} fullWidth>
            {loading ? '保存中...' : '保存修改'}
          </Button>
        </CardContent>
      </Card>
      <Card>
        <CardContent>
          <Typography variant="subtitle2" color="text.secondary" gutterBottom>关于</Typography>
          <Typography variant="body2">定位共享 v0.1.0</Typography>
          <Typography variant="body2" color="text.secondary">家人位置，安心守护</Typography>
        </CardContent>
      </Card>
    </Box>
  );
}
