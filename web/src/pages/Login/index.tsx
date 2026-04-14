import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  Box,
  Button,
  TextField,
  Typography,
  Checkbox,
  FormControlLabel,
  InputAdornment,
  IconButton,
  Link,
  Paper,
  CircularProgress,
} from '@mui/material';
import {
  Visibility,
  VisibilityOff,
  Smartphone,
  Lock,
  VerifiedUser,
  PersonAddAlt,
  ChatBubbleOutlined,
  Fingerprint,
} from '@mui/icons-material';
import { login, register } from '@/api/auth';
import { useAuthStore } from '@/store/auth';
import { brandBlue } from '@/theme';

const SUBTITLE = 'THE GUARDIAN LINK.';

function axiosErrorMessage(err: unknown): string {
  const ex = err as { response?: { status?: number; data?: unknown } };
  const d = ex.response?.data;
  if (d && typeof d === 'object' && d !== null) {
    const o = d as Record<string, unknown>;
    if (typeof o.error === 'string' && o.error.trim()) return o.error.trim();
    if (typeof o.message === 'string' && o.message.trim()) return o.message.trim();
  }
  if (typeof d === 'string' && d.trim()) return d.trim();
  const code = ex.response?.status;
  if (code) return `请求失败（HTTP ${code}）`;
  return '请求失败，请稍后重试';
}

const fieldSx = {
  '& .MuiOutlinedInput-root': {
    bgcolor: '#F3F4F6',
    borderRadius: '14px',
    '& fieldset': { border: 'none' },
  },
};

export default function LoginPage() {
  const navigate = useNavigate();
  const { setAuth } = useAuthStore();
  const [isLogin, setIsLogin] = useState(true);
  const [phone, setPhone] = useState('');
  const [password, setPassword] = useState('');
  const [confirm, setConfirm] = useState('');
  const [agree, setAgree] = useState(false);
  const [showPwd, setShowPwd] = useState(false);
  const [showConfirm, setShowConfirm] = useState(false);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const passwordOk = /^[a-zA-Z0-9]{6,16}$/.test(password);

  const submit = async () => {
    const p = phone.trim();
    if (p.length !== 11 || !/^\d{11}$/.test(p)) {
      setError('请输入11位手机号码');
      return;
    }
    if (isLogin) {
      if (!password) {
        setError('请输入登录密码');
        return;
      }
    } else {
      if (!passwordOk) {
        setError('密码需为6-16位字母与数字组合');
        return;
      }
      if (password !== confirm) {
        setError('两次输入的密码不一致');
        return;
      }
      if (!agree) {
        setError('请阅读并同意服务条款与隐私政策');
        return;
      }
    }
    setError('');
    setLoading(true);
    try {
      const res = isLogin ? await login(p, password) : await register(p, password);
      setAuth(res.access_token, res.refresh_token, res.user_id, p);
      navigate('/');
    } catch (e) {
      setError(axiosErrorMessage(e));
    } finally {
      setLoading(false);
    }
  };

  return (
    <Box
      sx={{
        minHeight: '100vh',
        bgcolor: '#fff',
        py: 2,
        px: 2,
        display: 'flex',
        justifyContent: 'center',
      }}
    >
      <Box sx={{ width: '100%', maxWidth: 420 }}>
        {isLogin ? (
          <>
            <Box sx={{ textAlign: 'center', pt: 2 }}>
              <Box
                sx={{
                  width: 76,
                  height: 76,
                  mx: 'auto',
                  borderRadius: '50%',
                  bgcolor: `${brandBlue}20`,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                }}
              >
                <VerifiedUser sx={{ fontSize: 48, color: brandBlue }} />
              </Box>
              <Typography variant="h4" sx={{ mt: 2, fontWeight: 800, color: '#111827' }}>
                定位共享
              </Typography>
            </Box>

            <Paper elevation={3} sx={{ mt: 3, p: 3, borderRadius: '20px' }}>
              <Typography variant="h6" sx={{ mb: 3, color: '#111827', fontWeight: 800 }}>
                欢迎回来
              </Typography>
              <Typography variant="body2" color="text.secondary" sx={{ mb: 0.5 }}>
                手机号
              </Typography>
              <TextField
                fullWidth
                placeholder="输入您的手机号码"
                value={phone}
                onChange={(e) => setPhone(e.target.value.replace(/\D/g, '').slice(0, 11))}
                sx={{ ...fieldSx, mb: 2 }}
                slotProps={{
                  input: {
                    startAdornment: (
                      <InputAdornment position="start">
                        <Smartphone sx={{ color: 'grey.600', fontSize: 22 }} />
                      </InputAdornment>
                    ),
                  },
                }}
              />
              <Box sx={{ display: 'flex', alignItems: 'center', mb: 0.5 }}>
                <Typography variant="body2" color="text.secondary">
                  密码
                </Typography>
                <Box sx={{ flex: 1 }} />
              </Box>
              <TextField
                fullWidth
                type="password"
                placeholder="输入您的登录密码"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                sx={{ ...fieldSx, mb: 2 }}
                slotProps={{
                  input: {
                    startAdornment: (
                      <InputAdornment position="start">
                        <Lock sx={{ color: 'grey.600', fontSize: 22 }} />
                      </InputAdornment>
                    ),
                  },
                }}
              />
              {error && (
                <Typography color="error" variant="body2" sx={{ mb: 2 }}>
                  {error}
                </Typography>
              )}
              <Button
                variant="contained"
                fullWidth
                size="large"
                disabled={loading}
                onClick={submit}
                sx={{ py: 1.5, borderRadius: '14px', fontSize: 16, fontWeight: 700 }}
              >
                {loading ? <CircularProgress size={24} color="inherit" /> : '登录 →'}
              </Button>
            </Paper>

            <Typography align="center" sx={{ mt: 2.5 }}>
              <Link
                component="button"
                type="button"
                underline="hover"
                sx={{ fontSize: 14, color: 'text.secondary' }}
                onClick={() => {
                  setIsLogin(false);
                  setError('');
                }}
              >
                还没有账号？<Box component="span" sx={{ color: brandBlue, fontWeight: 700 }}>去注册</Box>
              </Link>
            </Typography>
          </>
        ) : (
          <>
            <Box sx={{ display: 'flex', alignItems: 'center', pt: 1 }}>
              <Typography variant="body1" sx={{ fontWeight: 700, color: '#111827' }}>
                定位共享
              </Typography>
            </Box>
            <Box sx={{ textAlign: 'center', mt: 2 }}>
              <Box
                sx={{
                  width: 88,
                  height: 88,
                  mx: 'auto',
                  borderRadius: '50%',
                  bgcolor: `${brandBlue}20`,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                }}
              >
                <PersonAddAlt sx={{ fontSize: 44, color: brandBlue }} />
              </Box>
              <Typography variant="h5" sx={{ mt: 2, fontWeight: 800 }}>
                注册新账号
              </Typography>
              <Typography variant="body2" color="text.secondary" sx={{ mt: 1, lineHeight: 1.5 }}>
                开启您的守护之旅，共享安心每一刻
              </Typography>
            </Box>

            <Box sx={{ mt: 3 }}>
              <Typography variant="body2" color="text.secondary" sx={{ mb: 0.5 }}>
                手机号
              </Typography>
              <TextField
                fullWidth
                placeholder="请输入11位手机号码"
                value={phone}
                onChange={(e) => setPhone(e.target.value.replace(/\D/g, '').slice(0, 11))}
                sx={{ ...fieldSx, mb: 2 }}
                slotProps={{
                  input: {
                    startAdornment: (
                      <InputAdornment position="start">
                        <Smartphone sx={{ color: 'grey.600', fontSize: 22 }} />
                      </InputAdornment>
                    ),
                  },
                }}
              />
              <Typography variant="body2" color="text.secondary" sx={{ mb: 0.5 }}>
                设置密码
              </Typography>
              <TextField
                fullWidth
                type={showPwd ? 'text' : 'password'}
                placeholder="6-16位字母与数字组合"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                sx={{ ...fieldSx, mb: 2 }}
                slotProps={{
                  input: {
                    startAdornment: (
                      <InputAdornment position="start">
                        <Lock sx={{ color: 'grey.600', fontSize: 22 }} />
                      </InputAdornment>
                    ),
                    endAdornment: (
                      <InputAdornment position="end">
                        <IconButton size="small" onClick={() => setShowPwd(!showPwd)}>
                          {showPwd ? <VisibilityOff /> : <Visibility />}
                        </IconButton>
                      </InputAdornment>
                    ),
                  },
                }}
              />
              <Typography variant="body2" color="text.secondary" sx={{ mb: 0.5 }}>
                确认密码
              </Typography>
              <TextField
                fullWidth
                type={showConfirm ? 'text' : 'password'}
                placeholder="请再次输入密码"
                value={confirm}
                onChange={(e) => setConfirm(e.target.value)}
                sx={{ ...fieldSx, mb: 2 }}
                slotProps={{
                  input: {
                    startAdornment: (
                      <InputAdornment position="start">
                        <VerifiedUser sx={{ color: 'grey.600', fontSize: 22 }} />
                      </InputAdornment>
                    ),
                    endAdornment: (
                      <InputAdornment position="end">
                        <IconButton size="small" onClick={() => setShowConfirm(!showConfirm)}>
                          {showConfirm ? <VisibilityOff /> : <Visibility />}
                        </IconButton>
                      </InputAdornment>
                    ),
                  },
                }}
              />
              <FormControlLabel
                control={
                  <Checkbox
                    checked={agree}
                    onChange={(_, v) => setAgree(v)}
                    sx={{ color: brandBlue, '&.Mui-checked': { color: brandBlue } }}
                  />
                }
                label={
                  <Typography variant="body2" component="span">
                    我已阅读并同意 <Box component="span" sx={{ color: brandBlue, fontWeight: 700 }}>服务条款</Box>
                    与 <Box component="span" sx={{ color: brandBlue, fontWeight: 700 }}>隐私政策</Box>
                  </Typography>
                }
              />
              {error && (
                <Typography color="error" variant="body2" sx={{ mt: 1 }}>
                  {error}
                </Typography>
              )}
              <Button
                variant="contained"
                fullWidth
                size="large"
                disabled={loading}
                onClick={submit}
                sx={{ mt: 2, py: 1.5, borderRadius: '14px', fontSize: 16, fontWeight: 700 }}
              >
                {loading ? <CircularProgress size={24} color="inherit" /> : '注册 →'}
              </Button>
              <Typography align="center" sx={{ mt: 2 }}>
                <Link
                  component="button"
                  type="button"
                  underline="hover"
                  sx={{ fontSize: 14, color: 'text.secondary' }}
                  onClick={() => {
                    setIsLogin(true);
                    setError('');
                    setConfirm('');
                    setAgree(false);
                  }}
                >
                  已有账号？<Box component="span" sx={{ color: brandBlue, fontWeight: 700 }}>去登录</Box>
                </Link>
              </Typography>
            </Box>
          </>
        )}
      </Box>
    </Box>
  );
}
