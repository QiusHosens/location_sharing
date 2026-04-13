import React, { useEffect, useState, useCallback } from 'react';
import { Box, Typography, List, ListItem, ListItemText, IconButton, Button, Chip, Divider, CircularProgress } from '@mui/material';
import { MarkEmailRead, DoneAll } from '@mui/icons-material';
import { getNotifications, markRead, markAllRead } from '@/api/location';

export default function NotificationsPage() {
  const [notifications, setNotifications] = useState<any[]>([]);
  const [total, setTotal] = useState(0);
  const [unreadCount, setUnreadCount] = useState(0);
  const [loading, setLoading] = useState(true);
  const [page, setPage] = useState(1);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const res = await getNotifications({ page, page_size: 20 });
      setNotifications(res.items || []);
      setTotal(res.total || 0);
      setUnreadCount(res.unread_count || 0);
    } finally { setLoading(false); }
  }, [page]);

  useEffect(() => { load(); }, [load]);

  const handleMarkRead = async (id: string) => { await markRead(id); load(); };
  const handleMarkAll = async () => { await markAllRead(); load(); };

  return (
    <Box sx={{ p: 2, maxWidth: 600, mx: 'auto' }}>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 2 }}>
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
          <Typography variant="h5" fontWeight={700}>通知中心</Typography>
          {unreadCount > 0 && <Chip label={`${unreadCount} 条未读`} color="error" size="small" />}
        </Box>
        {unreadCount > 0 && <Button startIcon={<DoneAll />} onClick={handleMarkAll} size="small">全部已读</Button>}
      </Box>
      {loading ? <Box sx={{ textAlign: 'center', py: 4 }}><CircularProgress /></Box> : (
        <List>
          {notifications.length === 0 && <Typography color="text.secondary" sx={{ textAlign: 'center', py: 4 }}>暂无通知</Typography>}
          {notifications.map((n, i) => (
            <React.Fragment key={n.id}>
              <ListItem sx={{ bgcolor: n.is_read ? 'transparent' : 'action.hover', borderRadius: 1 }}
                secondaryAction={!n.is_read ? <IconButton size="small" onClick={() => handleMarkRead(n.id)}><MarkEmailRead /></IconButton> : null}>
                <ListItemText
                  primary={<Typography fontWeight={n.is_read ? 400 : 600}>{n.title || n.type}</Typography>}
                  secondary={<>{n.body && <Typography variant="body2" color="text.secondary">{n.body}</Typography>}
                    <Typography variant="caption" color="text.disabled">{new Date(n.created_at).toLocaleString('zh-CN')}</Typography></>}
                />
              </ListItem>
              {i < notifications.length - 1 && <Divider />}
            </React.Fragment>
          ))}
        </List>
      )}
      {total > 20 && (
        <Box sx={{ display: 'flex', justifyContent: 'center', gap: 1, mt: 2 }}>
          <Button disabled={page <= 1} onClick={() => setPage(page - 1)}>上一页</Button>
          <Button disabled={page * 20 >= total} onClick={() => setPage(page + 1)}>下一页</Button>
        </Box>
      )}
    </Box>
  );
}
