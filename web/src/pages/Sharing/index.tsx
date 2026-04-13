import React, { useEffect, useState } from 'react';
import {
  Box, Typography, Card, CardContent, List, ListItem, ListItemAvatar, ListItemText,
  Avatar, IconButton, Button, Chip, Switch, Dialog, DialogTitle, DialogContent,
  DialogActions, TextField, Snackbar, Alert, FormControlLabel,
} from '@mui/material';
import { Check, Close, Delete, Pause, PlayArrow, Add } from '@mui/icons-material';
import { getSharing, requestSharing, respondSharing, updateSharing, deleteSharing } from '@/api/user';
import { useAuthStore } from '@/store/auth';

export default function SharingPage() {
  const { userId } = useAuthStore();
  const [sharingList, setSharingList] = useState<any[]>([]);
  const [reqOpen, setReqOpen] = useState(false);
  const [targetId, setTargetId] = useState('');
  const [snack, setSnack] = useState({ open: false, msg: '' });

  const load = async () => { try { setSharingList(await getSharing()); } catch {} };
  useEffect(() => { load(); }, []);

  const statusColor = (s: string) => s === 'accepted' ? 'success' : s === 'pending' ? 'warning' : 'error';
  const statusLabel = (s: string) => s === 'accepted' ? '已接受' : s === 'pending' ? '待确认' : '已拒绝';

  const handleRequest = async () => {
    try { await requestSharing(targetId); setReqOpen(false); setTargetId(''); load();
      setSnack({ open: true, msg: '共享请求已发送' }); } catch (e: any) { setSnack({ open: true, msg: e.response?.data?.error || '发送失败' }); }
  };

  const handleRespond = async (id: string, accept: boolean) => {
    try { await respondSharing(id, accept); load(); } catch {}
  };

  const handleTogglePause = async (item: any) => {
    try { await updateSharing(item.id, { is_paused: !item.is_paused }); load(); } catch {}
  };

  const handleDelete = async (id: string) => {
    if (!confirm('确定撤销此共享？')) return;
    try { await deleteSharing(id); load(); } catch {}
  };

  const pendingForMe = sharingList.filter((s) => s.status === 'pending' && s.owner_id === userId);
  const others = sharingList.filter((s) => !(s.status === 'pending' && s.owner_id === userId));

  return (
    <Box sx={{ p: 2, maxWidth: 600, mx: 'auto' }}>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 2 }}>
        <Typography variant="h5" fontWeight={700}>位置共享</Typography>
        <Button startIcon={<Add />} variant="outlined" onClick={() => setReqOpen(true)}>请求共享</Button>
      </Box>

      {pendingForMe.length > 0 && (
        <>
          <Typography variant="subtitle2" color="text.secondary" gutterBottom>待处理的共享请求</Typography>
          {pendingForMe.map((s) => (
            <Card key={s.id} sx={{ mb: 1 }}>
              <CardContent sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', py: 1, '&:last-child': { pb: 1 } }}>
                <Typography>{s.peer_nickname || s.peer_phone} 请求查看你的位置</Typography>
                <Box>
                  <IconButton color="success" onClick={() => handleRespond(s.id, true)}><Check /></IconButton>
                  <IconButton color="error" onClick={() => handleRespond(s.id, false)}><Close /></IconButton>
                </Box>
              </CardContent>
            </Card>
          ))}
        </>
      )}

      <Typography variant="subtitle2" color="text.secondary" gutterBottom sx={{ mt: 2 }}>共享列表</Typography>
      {others.length === 0 && <Typography color="text.secondary" sx={{ textAlign: 'center', py: 4 }}>暂无共享记录</Typography>}
      {others.map((s) => (
        <Card key={s.id} sx={{ mb: 1 }}>
          <CardContent sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', py: 1.5, '&:last-child': { pb: 1.5 } }}>
            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5 }}>
              <Avatar sx={{ width: 36, height: 36 }}>{(s.peer_nickname || s.peer_phone)[0]}</Avatar>
              <Box>
                <Typography variant="body1">{s.peer_nickname || s.peer_phone}</Typography>
                <Chip label={statusLabel(s.status)} color={statusColor(s.status)} size="small" />
              </Box>
            </Box>
            <Box>
              {s.status === 'accepted' && s.owner_id === userId && (
                <IconButton size="small" onClick={() => handleTogglePause(s)}>{s.is_paused ? <PlayArrow /> : <Pause />}</IconButton>
              )}
              <IconButton size="small" color="error" onClick={() => handleDelete(s.id)}><Delete /></IconButton>
            </Box>
          </CardContent>
        </Card>
      ))}

      <Dialog open={reqOpen} onClose={() => setReqOpen(false)}>
        <DialogTitle>请求位置共享</DialogTitle>
        <DialogContent><TextField label="对方用户ID" fullWidth value={targetId} onChange={(e) => setTargetId(e.target.value)} sx={{ mt: 1 }} helperText="输入想要查看其位置的用户ID" /></DialogContent>
        <DialogActions><Button onClick={() => setReqOpen(false)}>取消</Button><Button variant="contained" onClick={handleRequest}>发送请求</Button></DialogActions>
      </Dialog>

      <Snackbar open={snack.open} autoHideDuration={3000} onClose={() => setSnack({ ...snack, open: false })}>
        <Alert severity="info" variant="filled">{snack.msg}</Alert>
      </Snackbar>
    </Box>
  );
}
