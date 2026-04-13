import React, { useEffect, useState } from 'react';
import {
  Box, Typography, Card, CardContent, List, ListItem, ListItemAvatar, ListItemText,
  Avatar, IconButton, Button, Dialog, DialogTitle, DialogContent, DialogActions,
  TextField, Fab, Divider, Chip, Alert, Snackbar,
} from '@mui/material';
import { Add, Delete, PersonAdd, Group as GroupIcon } from '@mui/icons-material';
import { getGroups, createGroup, deleteGroup, addMember, removeMember } from '@/api/user';
import { useAuthStore } from '@/store/auth';

export default function FamilyPage() {
  const { userId } = useAuthStore();
  const [groups, setGroups] = useState<any[]>([]);
  const [createOpen, setCreateOpen] = useState(false);
  const [addMemberOpen, setAddMemberOpen] = useState<string | null>(null);
  const [groupName, setGroupName] = useState('');
  const [memberPhone, setMemberPhone] = useState('');
  const [snack, setSnack] = useState({ open: false, msg: '', severity: 'success' as 'success' | 'error' });

  const load = async () => { try { setGroups(await getGroups()); } catch {} };
  useEffect(() => { load(); }, []);

  const handleCreate = async () => {
    try { await createGroup(groupName); setCreateOpen(false); setGroupName(''); load();
      setSnack({ open: true, msg: '家庭组已创建', severity: 'success' }); } catch { setSnack({ open: true, msg: '创建失败', severity: 'error' }); }
  };

  const handleDelete = async (id: string) => {
    if (!confirm('确定删除该家庭组？')) return;
    try { await deleteGroup(id); load(); } catch { setSnack({ open: true, msg: '删除失败', severity: 'error' }); }
  };

  const handleAddMember = async () => {
    if (!addMemberOpen) return;
    try { await addMember(addMemberOpen, memberPhone); setAddMemberOpen(null); setMemberPhone(''); load();
      setSnack({ open: true, msg: '成员已添加', severity: 'success' }); } catch (e: any) {
      setSnack({ open: true, msg: e.response?.data?.error || '添加失败', severity: 'error' }); }
  };

  const handleRemoveMember = async (groupId: string, memberId: string) => {
    try { await removeMember(groupId, memberId); load(); } catch {}
  };

  return (
    <Box sx={{ p: 2, maxWidth: 600, mx: 'auto' }}>
      <Typography variant="h5" fontWeight={700} gutterBottom>家庭组</Typography>
      {groups.length === 0 && <Typography color="text.secondary" sx={{ textAlign: 'center', py: 4 }}>暂无家庭组，点击右下角按钮创建</Typography>}
      {groups.map((g) => (
        <Card key={g.id} sx={{ mb: 2 }}>
          <CardContent>
            <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
              <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                <GroupIcon color="primary" />
                <Typography variant="h6">{g.name}</Typography>
                <Chip label={`${g.members?.length || 0}人`} size="small" />
              </Box>
              <Box>
                <IconButton size="small" onClick={() => setAddMemberOpen(g.id)}><PersonAdd /></IconButton>
                {g.creator_id === userId && <IconButton size="small" color="error" onClick={() => handleDelete(g.id)}><Delete /></IconButton>}
              </Box>
            </Box>
            <Divider sx={{ my: 1 }} />
            <List dense>
              {g.members?.map((m: any) => (
                <ListItem key={m.user_id} secondaryAction={
                  m.user_id !== userId && g.creator_id === userId ? (
                    <IconButton size="small" onClick={() => handleRemoveMember(g.id, m.user_id)}><Delete fontSize="small" /></IconButton>
                  ) : null
                }>
                  <ListItemAvatar><Avatar sx={{ width: 32, height: 32 }}>{(m.nickname || m.phone)[0]}</Avatar></ListItemAvatar>
                  <ListItemText primary={m.nickname || m.phone} secondary={m.role === 'owner' ? '创建者' : '成员'} />
                </ListItem>
              ))}
            </List>
          </CardContent>
        </Card>
      ))}

      <Fab color="primary" onClick={() => setCreateOpen(true)} sx={{ position: 'fixed', bottom: 80, right: 24 }}><Add /></Fab>

      <Dialog open={createOpen} onClose={() => setCreateOpen(false)}>
        <DialogTitle>创建家庭组</DialogTitle>
        <DialogContent><TextField label="家庭组名称" fullWidth value={groupName} onChange={(e) => setGroupName(e.target.value)} sx={{ mt: 1 }} /></DialogContent>
        <DialogActions><Button onClick={() => setCreateOpen(false)}>取消</Button><Button variant="contained" onClick={handleCreate}>创建</Button></DialogActions>
      </Dialog>

      <Dialog open={!!addMemberOpen} onClose={() => setAddMemberOpen(null)}>
        <DialogTitle>添加成员</DialogTitle>
        <DialogContent><TextField label="成员手机号" fullWidth value={memberPhone} onChange={(e) => setMemberPhone(e.target.value)} sx={{ mt: 1 }} /></DialogContent>
        <DialogActions><Button onClick={() => setAddMemberOpen(null)}>取消</Button><Button variant="contained" onClick={handleAddMember}>添加</Button></DialogActions>
      </Dialog>

      <Snackbar open={snack.open} autoHideDuration={3000} onClose={() => setSnack({ ...snack, open: false })}>
        <Alert severity={snack.severity} variant="filled">{snack.msg}</Alert>
      </Snackbar>
    </Box>
  );
}
