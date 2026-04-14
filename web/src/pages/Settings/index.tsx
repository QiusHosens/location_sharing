import React, { useEffect, useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  Box,
  Typography,
  Paper,
  TextField,
  Button,
  Avatar,
  Snackbar,
  Alert,
  IconButton,
} from '@mui/material';
import { Edit, Logout } from '@mui/icons-material';
import { getProfile, updateProfile, uploadAvatar } from '@/api/user';
import { useAuthStore } from '@/store/auth';
import { resolveMediaUrl } from '@/utils/mediaUrl';
import { brandBlue } from '@/theme';

function maskPhone(raw: string | null | undefined): string {
  if (!raw?.trim()) return '—';
  const t = raw.replace(/\s/g, '');
  if (t.length === 11 && /^\d{11}$/.test(t)) {
    return `+86 ${t.slice(0, 3)} **** ${t.slice(7)}`;
  }
  if (t.length >= 8) {
    return `${t.slice(0, 3)} **** ${t.slice(-4)}`;
  }
  return raw;
}

const DISPLAY_VERSION = '0.1.0';

export default function SettingsPage() {
  const navigate = useNavigate();
  const { phone, setProfile, logout } = useAuthStore();
  const fileRef = useRef<HTMLInputElement>(null);
  const [nickname, setNickname] = useState('');
  const [displayAvatar, setDisplayAvatar] = useState<string | undefined>();
  const [loading, setLoading] = useState(false);
  const [snack, setSnack] = useState({ open: false, msg: '', severity: 'success' as 'success' | 'error' });

  useEffect(() => {
    getProfile()
      .then((p: Record<string, unknown>) => {
        setNickname((p.nickname as string) || '');
        setDisplayAvatar(resolveMediaUrl(p.avatar_url as string | undefined));
        setProfile((p.nickname as string) || null);
      })
      .catch(() => {});
  }, [setProfile]);

  const saveNickname = async () => {
    setLoading(true);
    try {
      await updateProfile({ nickname: nickname.trim() || undefined });
      setProfile(nickname.trim() || null);
      setSnack({ open: true, msg: '已保存', severity: 'success' });
    } catch {
      setSnack({ open: true, msg: '保存失败', severity: 'error' });
    } finally {
      setLoading(false);
    }
  };

  const onPickAvatar = () => fileRef.current?.click();

  const onFile = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const f = e.target.files?.[0];
    e.target.value = '';
    if (!f) return;
    setLoading(true);
    try {
      const data = await uploadAvatar(f);
      setDisplayAvatar(resolveMediaUrl((data as { avatar_url?: string }).avatar_url));
      setSnack({ open: true, msg: '头像已更新', severity: 'success' });
    } catch {
      setSnack({ open: true, msg: '上传失败', severity: 'error' });
    } finally {
      setLoading(false);
    }
  };

  const onLogout = () => {
    logout();
    navigate('/login');
  };

  const initial = (phone || '?')[0]?.toUpperCase() ?? '?';

  return (
    <Box sx={{ px: 2, pt: 1, pb: 3, maxWidth: 560, mx: 'auto' }}>
      <input ref={fileRef} type="file" accept="image/*" hidden onChange={onFile} />

      <Typography variant="h4" sx={{ fontSize: 24, fontWeight: 800, color: '#111827', px: 0.5, mb: 2, pt: 1 }}>
        设置与个人中心
      </Typography>

      <Paper elevation={2} sx={{ p: 3, borderRadius: '16px', bgcolor: '#fff' }}>
        <Box sx={{ display: 'flex', flexDirection: 'column', alignItems: 'center', position: 'relative' }}>
          <Box sx={{ position: 'relative', width: 112, height: 112 }}>
            <Avatar
              src={displayAvatar}
              sx={{
                width: 112,
                height: 112,
                borderRadius: '16px',
                bgcolor: '#37474F',
                color: '#fff',
                fontSize: 40,
                fontWeight: 700,
              }}
            >
              {!displayAvatar ? initial : null}
            </Avatar>
            <IconButton
              size="small"
              onClick={onPickAvatar}
              disabled={loading}
              sx={{
                position: 'absolute',
                right: -6,
                bottom: -6,
                bgcolor: brandBlue,
                color: '#fff',
                '&:hover': { bgcolor: brandBlue, opacity: 0.9 },
                boxShadow: 2,
              }}
            >
              <Edit sx={{ fontSize: 18 }} />
            </IconButton>
          </Box>
          <Typography variant="body2" color="text.secondary" sx={{ mt: 1.5 }}>
            点击更换头像
          </Typography>

          <Typography variant="body2" color="text.secondary" sx={{ alignSelf: 'stretch', mt: 3.5, mb: 1 }}>
            用户昵称
          </Typography>
          <TextField
            fullWidth
            value={nickname}
            onChange={(e) => setNickname(e.target.value)}
            placeholder="昵称"
            sx={{
              '& .MuiOutlinedInput-root': { bgcolor: '#F3F4F6', borderRadius: '14px', '& fieldset': { border: 'none' } },
            }}
            slotProps={{
              input: {
                endAdornment: <Edit sx={{ color: 'grey.600', fontSize: 20, mr: 0.5 }} />,
              },
            }}
          />
          <Button
            variant="text"
            onClick={saveNickname}
            disabled={loading}
            sx={{ alignSelf: 'flex-end', mt: 0.5, color: brandBlue, fontWeight: 600 }}
          >
            保存昵称
          </Button>

          <Typography variant="body2" color="text.secondary" sx={{ alignSelf: 'stretch', mt: 2, mb: 1 }}>
            手机号码
          </Typography>
          <Box
            sx={{
              width: '100%',
              py: 1.75,
              px: 2,
              borderRadius: '14px',
              bgcolor: '#F3F4F6',
              typography: 'body1',
              fontWeight: 500,
              color: '#111827',
            }}
          >
            {maskPhone(phone)}
          </Box>
        </Box>
      </Paper>

      <Button
        variant="outlined"
        color="error"
        fullWidth
        startIcon={<Logout />}
        onClick={onLogout}
        sx={{ mt: 3, py: 1.5, borderRadius: '14px', fontWeight: 700, borderWidth: 1.5 }}
      >
        退出登录
      </Button>

      <Typography align="center" variant="body2" color="text.secondary" sx={{ mt: 3 }}>
        版本 {DISPLAY_VERSION} ·{' '}
        <Box component="span" sx={{ color: 'primary.main', cursor: 'pointer' }} onClick={() => alert('隐私政策（即将接入）')}>
          隐私政策
        </Box>
        {' '}与{' '}
        <Box component="span" sx={{ color: 'primary.main', cursor: 'pointer' }} onClick={() => alert('服务条款（即将接入）')}>
          服务条款
        </Box>
      </Typography>

      <Snackbar open={snack.open} autoHideDuration={3000} onClose={() => setSnack({ ...snack, open: false })}>
        <Alert severity={snack.severity} variant="filled">
          {snack.msg}
        </Alert>
      </Snackbar>
    </Box>
  );
}
