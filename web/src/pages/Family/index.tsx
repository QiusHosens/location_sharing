import React, { useCallback, useEffect, useState } from 'react';
import {
  Box,
  Typography,
  Card,
  CardContent,
  Button,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  TextField,
  IconButton,
  Switch,
  Snackbar,
  Alert,
  Avatar,
} from '@mui/material';
import {
  Add,
  Delete,
  PersonAdd,
  HomeRounded,
  ParkRounded,
  SchoolRounded,
  Phone,
} from '@mui/icons-material';
import {
  getGroups,
  createGroup,
  deleteGroup,
  addMember,
  getFamilyInvitations,
  respondFamilyInvitation,
  removeMember,
  getSharing,
  setSharingPeer,
} from '@/api/user';
import { getFamilyLocations } from '@/api/location';
import { useAuthStore } from '@/store/auth';
import { brandBlue } from '@/theme';
import { resolveMediaUrl } from '@/utils/mediaUrl';

const PAGE_BG = '#F3F4F6';
const STATUS_ICONS = [HomeRounded, ParkRounded, SchoolRounded];

type SnackState = { open: boolean; msg: string; severity: 'success' | 'error' };

function sharingEnabledForPeer(
  sharingList: any[],
  ownerId: string,
  viewerId: string
): boolean {
  for (const s of sharingList) {
    if (String(s.owner_id) !== ownerId || String(s.viewer_id) !== viewerId) continue;
    const status = String(s.status ?? '');
    const paused = s.is_paused === true;
    return status === 'accepted' && !paused;
  }
  return false;
}

export default function FamilyPage() {
  const { userId } = useAuthStore();
  const [groups, setGroups] = useState<any[]>([]);
  const [invitations, setInvitations] = useState<any[]>([]);
  const [sharingList, setSharingList] = useState<any[]>([]);
  const [batteryByUserId, setBatteryByUserId] = useState<Record<string, number | null>>({});
  const [createOpen, setCreateOpen] = useState(false);
  const [addMemberOpen, setAddMemberOpen] = useState<string | null>(null);
  const [groupName, setGroupName] = useState('');
  const [memberPhone, setMemberPhone] = useState('');
  const [togglingId, setTogglingId] = useState<string | null>(null);
  const [snack, setSnack] = useState<SnackState>({ open: false, msg: '', severity: 'success' });

  const load = useCallback(async () => {
    try {
      const [g, inv] = await Promise.all([getGroups(), getFamilyInvitations()]);
      let sharing: any[] = [];
      try {
        sharing = await getSharing();
      } catch {
        sharing = [];
      }
      const battery: Record<string, number | null> = {};
      for (const raw of g || []) {
        const gid = raw?.id;
        if (!gid) continue;
        try {
          const locs = await getFamilyLocations(String(gid));
          for (const l of locs || []) {
            const uid = l?.user_id != null ? String(l.user_id) : null;
            if (!uid) continue;
            const b = l?.battery_level;
            battery[uid] =
              typeof b === 'number' ? b : b != null && b !== '' ? Number(b) : null;
          }
        } catch {
          /* ignore */
        }
      }
      setGroups(g || []);
      setInvitations(inv || []);
      setSharingList(Array.isArray(sharing) ? sharing : []);
      setBatteryByUserId(battery);
    } catch {
      setGroups([]);
      setInvitations([]);
      setSharingList([]);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const handleCreate = async () => {
    try {
      await createGroup(groupName);
      setCreateOpen(false);
      setGroupName('');
      await load();
      setSnack({ open: true, msg: '家庭组已创建', severity: 'success' });
    } catch {
      setSnack({ open: true, msg: '创建失败', severity: 'error' });
    }
  };

  const handleDeleteGroup = async (id: string) => {
    if (!confirm('确定删除该家庭组？')) return;
    try {
      await deleteGroup(id);
      await load();
    } catch {
      setSnack({ open: true, msg: '删除失败', severity: 'error' });
    }
  };

  const handleAddMember = async () => {
    if (!addMemberOpen) return;
    try {
      await addMember(addMemberOpen, memberPhone);
      setAddMemberOpen(null);
      setMemberPhone('');
      await load();
      setSnack({ open: true, msg: '邀请已发送，对方同意后才会加入', severity: 'success' });
    } catch (e: unknown) {
      const msg =
        typeof e === 'object' &&
        e !== null &&
        'response' in e &&
        typeof (e as { response?: { data?: { error?: string } } }).response?.data?.error === 'string'
          ? (e as { response: { data: { error: string } } }).response.data.error
          : '发送失败';
      setSnack({ open: true, msg, severity: 'error' });
    }
  };

  const handleRespondInvite = async (id: string, accept: boolean) => {
    try {
      await respondFamilyInvitation(id, accept);
      await load();
      setSnack({
        open: true,
        msg: accept ? '已加入家庭组' : '已拒绝邀请',
        severity: 'success',
      });
    } catch {
      setSnack({ open: true, msg: '操作失败', severity: 'error' });
    }
  };

  const handleRemoveMember = async (groupId: string, memberId: string) => {
    if (!confirm('确定从家庭组移除此成员？')) return;
    try {
      await removeMember(groupId, memberId);
      await load();
    } catch {
      setSnack({ open: true, msg: '移除失败', severity: 'error' });
    }
  };

  const handleSharingToggle = async (viewerId: string, enabled: boolean) => {
    if (!userId) return;
    setTogglingId(viewerId);
    try {
      await setSharingPeer(viewerId, enabled);
      await load();
    } catch {
      setSnack({ open: true, msg: '共享设置失败', severity: 'error' });
    } finally {
      setTogglingId(null);
    }
  };

  const empty = (groups?.length ?? 0) === 0 && (invitations?.length ?? 0) === 0;

  return (
    <Box sx={{ bgcolor: PAGE_BG, minHeight: '100%', pb: 14 }}>
      <Box sx={{ px: 2, pt: 2, maxWidth: 680, mx: 'auto' }}>
        <Typography variant="h5" sx={{ fontWeight: 800, color: '#111827', letterSpacing: -0.3 }}>
          家庭
        </Typography>

        {invitations.length > 0 && (
          <Box sx={{ mt: 2 }}>
            <Typography variant="caption" color="text.secondary" sx={{ fontWeight: 600 }}>
              待处理邀请
            </Typography>
            {invitations.map((inv) => (
              <Card
                key={inv.id}
                sx={{ mt: 1, borderRadius: '18px', boxShadow: '0 2px 12px rgba(0,0,0,0.06)' }}
              >
                <CardContent sx={{ py: 1.5, '&:last-child': { pb: 1.5 } }}>
                  <Typography variant="body2">
                    {inv.inviter_nickname || inv.inviter_phone} 邀请你加入「{inv.group_name}」
                  </Typography>
                  <Box sx={{ display: 'flex', justifyContent: 'flex-end', gap: 1, mt: 1 }}>
                    <Button size="small" onClick={() => handleRespondInvite(inv.id, false)}>
                      拒绝
                    </Button>
                    <Button size="small" variant="contained" onClick={() => handleRespondInvite(inv.id, true)}>
                      同意
                    </Button>
                  </Box>
                </CardContent>
              </Card>
            ))}
          </Box>
        )}

        {empty && (
          <Typography color="text.secondary" sx={{ textAlign: 'center', py: 6 }}>
            暂无家庭组，点击下方按钮创建
          </Typography>
        )}

        {groups.map((g, gi) => {
          const gid = String(g.id);
          const members = (g.members as any[]) || [];
          const others = userId
            ? members.filter((m) => String(m.user_id) !== String(userId))
            : members;
          const creatorId = g.creator_id != null ? String(g.creator_id) : '';
          const isOwner = creatorId && userId && creatorId === userId;

          return (
            <Box key={gid} sx={{ mt: gi === 0 && invitations.length === 0 ? 2 : 3 }}>
              <Box
                sx={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  mb: 1.5,
                  px: 0.5,
                }}
              >
                <Typography variant="h6" sx={{ fontWeight: 800, fontSize: 18, color: '#111827' }}>
                  {groups.length > 1 ? (g.name || '家庭组') : '家庭圈'}
                </Typography>
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}>
                  <Typography variant="body2" sx={{ color: brandBlue, fontWeight: 700 }}>
                    {members.length} 位成员
                  </Typography>
                  {isOwner && (
                    <>
                      <IconButton size="small" onClick={() => setAddMemberOpen(gid)} aria-label="邀请">
                        <PersonAdd fontSize="small" />
                      </IconButton>
                      <IconButton size="small" onClick={() => handleDeleteGroup(gid)} aria-label="删除组" color="error">
                        <Delete fontSize="small" />
                      </IconButton>
                    </>
                  )}
                </Box>
              </Box>

              {others.length === 0 ? (
                <Typography variant="body2" color="text.secondary" sx={{ px: 1, py: 2 }}>
                  暂无其他成员，邀请家人加入后可在此共享位置
                </Typography>
              ) : (
                others.map((m, idx) => (
                  <MemberRow
                    key={m.user_id}
                    member={m}
                    index={idx}
                    ownerId={userId || ''}
                    battery={batteryByUserId[String(m.user_id)] ?? null}
                    shareOn={
                      userId
                        ? sharingEnabledForPeer(sharingList, userId, String(m.user_id))
                        : false
                    }
                    toggling={togglingId === String(m.user_id)}
                    onToggle={(en) => handleSharingToggle(String(m.user_id), en)}
                    isOwner={!!isOwner}
                    onRemove={() => handleRemoveMember(gid, String(m.user_id))}
                  />
                ))
              )}
            </Box>
          );
        })}

        <Button
          fullWidth
          variant="contained"
          size="large"
          startIcon={<Add />}
          onClick={() => setCreateOpen(true)}
          sx={{
            mt: 3,
            py: 1.75,
            borderRadius: '999px',
            fontWeight: 700,
            fontSize: 16,
            boxShadow: '0 8px 24px rgba(25, 118, 210, 0.35)',
            bgcolor: brandBlue,
          }}
        >
          创建家庭组
        </Button>
      </Box>

      <Dialog open={createOpen} onClose={() => setCreateOpen(false)}>
        <DialogTitle>创建家庭组</DialogTitle>
        <DialogContent>
          <TextField
            label="家庭组名称"
            fullWidth
            value={groupName}
            onChange={(e) => setGroupName(e.target.value)}
            sx={{ mt: 1 }}
          />
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setCreateOpen(false)}>取消</Button>
          <Button variant="contained" onClick={handleCreate}>
            创建
          </Button>
        </DialogActions>
      </Dialog>

      <Dialog open={!!addMemberOpen} onClose={() => setAddMemberOpen(null)}>
        <DialogTitle>邀请成员</DialogTitle>
        <DialogContent>
          <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
            将向对方发送邀请，对方同意后方可加入家庭组。
          </Typography>
          <TextField
            label="对方手机号"
            fullWidth
            value={memberPhone}
            onChange={(e) => setMemberPhone(e.target.value)}
          />
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setAddMemberOpen(null)}>取消</Button>
          <Button variant="contained" onClick={handleAddMember}>
            发送邀请
          </Button>
        </DialogActions>
      </Dialog>

      <Snackbar
        open={snack.open}
        autoHideDuration={3000}
        onClose={() => setSnack({ ...snack, open: false })}
      >
        <Alert severity={snack.severity} variant="filled">
          {snack.msg}
        </Alert>
      </Snackbar>
    </Box>
  );
}

function MemberRow({
  member,
  index,
  ownerId,
  battery,
  shareOn,
  toggling,
  onToggle,
  isOwner,
  onRemove,
}: {
  member: Record<string, unknown>;
  index: number;
  ownerId: string;
  battery: number | null;
  shareOn: boolean;
  toggling: boolean;
  onToggle: (enabled: boolean) => void;
  isOwner: boolean;
  onRemove: () => void;
}) {
  const id = String(member.user_id ?? '');
  const name = String(member.nickname || member.phone || '家人');
  const phone = String(member.phone ?? '');
  const roleRaw = String(member.role ?? '');
  const roleLabel = roleRaw === 'owner' ? '创建者' : '成员';
  const letter = name.charAt(0) || '?';
  const StatusIcon = STATUS_ICONS[index % STATUS_ICONS.length];
  const avatarUrl = resolveMediaUrl(member.avatar_url as string | undefined);

  const battLabel = battery != null && !Number.isNaN(battery) ? `${Math.round(battery)}% 电量` : '— 电量';
  const subPrimary = shareOn ? `${roleLabel} • ${battLabel}` : `${roleLabel} • 已暂停共享`;

  return (
    <Card
      sx={{
        mb: 1.5,
        borderRadius: '20px',
        boxShadow: '0 2px 14px rgba(0,0,0,0.06)',
        opacity: shareOn ? 1 : 0.72,
      }}
    >
      <CardContent sx={{ py: 2, px: 2, '&:last-child': { pb: 2 } }}>
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5 }}>
          <Box sx={{ position: 'relative', width: 56, height: 56, flexShrink: 0 }}>
            <Avatar
              src={avatarUrl}
              variant="rounded"
              sx={{
                width: 56,
                height: 56,
                borderRadius: '14px',
                bgcolor: shareOn ? 'primary.light' : 'grey.300',
                color: shareOn ? 'primary.dark' : 'grey.600',
                fontWeight: 800,
                fontSize: 20,
              }}
            >
              {!avatarUrl ? letter : null}
            </Avatar>
            <Box
              sx={{
                position: 'absolute',
                right: -4,
                bottom: -4,
                bgcolor: '#fff',
                borderRadius: '50%',
                width: 22,
                height: 22,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                boxShadow: 1,
              }}
            >
              <StatusIcon sx={{ fontSize: 14, color: shareOn ? '#2E7D32' : 'grey.400' }} />
            </Box>
          </Box>

          <Box sx={{ flex: 1, minWidth: 0 }}>
            <Typography
              sx={{
                fontWeight: 800,
                fontSize: 16,
                color: shareOn ? '#111827' : 'text.secondary',
              }}
            >
              {name}
            </Typography>
            <Typography variant="body2" color="text.secondary" sx={{ mt: 0.25 }}>
              {subPrimary}
            </Typography>
          </Box>

          {isOwner && (
            <IconButton size="small" onClick={onRemove} aria-label="移除成员" sx={{ color: 'grey.500' }}>
              <Delete fontSize="small" />
            </IconButton>
          )}

          {shareOn && phone ? (
            <IconButton
              component="a"
              href={`tel:${phone}`}
              sx={{
                width: 44,
                height: 44,
                bgcolor: '#E8F5E9',
                flexShrink: 0,
              }}
            >
              <Phone sx={{ color: '#2E7D32', fontSize: 22 }} />
            </IconButton>
          ) : (
            <IconButton
              disabled
              sx={{
                width: 44,
                height: 44,
                bgcolor: 'grey.200',
                flexShrink: 0,
              }}
            >
              <Phone sx={{ color: 'grey.400', fontSize: 22 }} />
            </IconButton>
          )}

          <Switch
            checked={shareOn}
            disabled={toggling || !ownerId}
            onChange={(_, v) => onToggle(v)}
            color="primary"
            sx={{
              '& .MuiSwitch-switchBase.Mui-checked': { color: brandBlue },
              '& .MuiSwitch-switchBase.Mui-checked + .MuiSwitch-track': {
                backgroundColor: `${brandBlue}80`,
              },
            }}
          />
        </Box>
      </CardContent>
    </Card>
  );
}
