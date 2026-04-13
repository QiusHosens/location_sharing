import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Box, Card, CardContent, TextField, Button, Typography, Alert, Stepper, Step, StepLabel } from '@mui/material';
import { LocationOn } from '@mui/icons-material';
import { sendCode, verifyCode } from '@/api/auth';
import { useAuthStore } from '@/store/auth';

export default function LoginPage() {
  const navigate = useNavigate();
  const { setAuth } = useAuthStore();
  const [step, setStep] = useState(0);
  const [phone, setPhone] = useState('');
  const [code, setCode] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [countdown, setCountdown] = useState(0);

  const handleSendCode = async () => {
    if (phone.length < 11) { setError('请输入正确的手机号'); return; }
    setError(''); setLoading(true);
    try {
      await sendCode(phone);
      setStep(1);
      setCountdown(60);
      const timer = setInterval(() => {
        setCountdown((c) => { if (c <= 1) { clearInterval(timer); return 0; } return c - 1; });
      }, 1000);
    } catch (err: any) {
      setError(err.response?.data?.error || '发送验证码失败');
    } finally { setLoading(false); }
  };

  const handleVerify = async () => {
    if (code.length !== 6) { setError('请输入6位验证码'); return; }
    setError(''); setLoading(true);
    try {
      const res = await verifyCode(phone, code);
      setAuth(res.access_token, res.user_id, phone);
      navigate('/');
    } catch (err: any) {
      setError(err.response?.data?.error || '验证码错误');
    } finally { setLoading(false); }
  };

  return (
    <Box sx={{ minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center', bgcolor: 'background.default' }}>
      <Card sx={{ width: 420, mx: 2 }}>
        <CardContent sx={{ p: 4 }}>
          <Box sx={{ textAlign: 'center', mb: 3 }}>
            <LocationOn sx={{ fontSize: 48, color: 'primary.main' }} />
            <Typography variant="h5" fontWeight={700}>定位共享</Typography>
            <Typography variant="body2" color="text.secondary">家人位置，安心守护</Typography>
          </Box>
          <Stepper activeStep={step} sx={{ mb: 3 }}>
            <Step><StepLabel>输入手机号</StepLabel></Step>
            <Step><StepLabel>验证码登录</StepLabel></Step>
          </Stepper>
          {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}
          {step === 0 ? (
            <>
              <TextField label="手机号" fullWidth value={phone} onChange={(e) => setPhone(e.target.value)} inputProps={{ maxLength: 15 }} sx={{ mb: 3 }} />
              <Button variant="contained" fullWidth size="large" onClick={handleSendCode} disabled={loading}>{loading ? '发送中...' : '获取验证码'}</Button>
            </>
          ) : (
            <>
              <Typography variant="body2" color="text.secondary" sx={{ mb: 1 }}>验证码已发送至 {phone}</Typography>
              <TextField label="验证码" fullWidth value={code} onChange={(e) => setCode(e.target.value)} inputProps={{ maxLength: 6 }} sx={{ mb: 2 }} />
              <Button variant="contained" fullWidth size="large" onClick={handleVerify} disabled={loading} sx={{ mb: 1 }}>{loading ? '登录中...' : '登 录'}</Button>
              <Button fullWidth disabled={countdown > 0} onClick={handleSendCode}>{countdown > 0 ? `重新发送(${countdown}s)` : '重新发送'}</Button>
            </>
          )}
        </CardContent>
      </Card>
    </Box>
  );
}
